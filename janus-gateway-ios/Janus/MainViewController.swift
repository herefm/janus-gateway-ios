//
//  MainViewController.swift
//  janus-gateway-ios
//
//  Created by Jesse Boyes on 12/13/20.
//  Copyright © 2020 MineWave. All rights reserved.
//

import UIKit

class MainViewController: UIViewController {
    static let kARDMediaStreamId = "ARDAMS"
    static let kARDAudioTrackId = "ARDAMSa0"
    static let kARDVideoTrackId = "ARDAMSv0"

    var localView: RTCCameraPreviewView!

    var websocket: WebSocketChannel!
    var peerConnectionDict: [UInt64: JanusConnection] = [:]
    var publisherPeerConnection: RTCPeerConnection!
    var localTrack: RTCVideoTrack? // TODO: Rename localVideoTrack
    var localAudioTrack: RTCAudioTrack?

    var height: Int = 0

    var factory: RTCPeerConnectionFactory!


    override func viewDidLoad() {
        super.viewDidLoad()

        localView = RTCCameraPreviewView(frame: CGRect(x: 0, y: 0, width: 480, height: 360))
        self.view.addSubview(localView)

        self.websocket = WebSocketChannel(url: "wss://v2.here.fm:443/janus")
        websocket.delegate = self

        factory = RTCPeerConnectionFactory()
        localTrack = createLocalVideoTrack()
        localAudioTrack = createLocalAudioTrack()
    }


    /*    - (RTCVideoTrack *)createLocalVideoTrack {
            RTCMediaConstraints *cameraConstraints = [[RTCMediaConstraints alloc]
                                                      initWithMandatoryConstraints:[self currentMediaConstraint]
                                                      optionalConstraints: nil];

            RTCAVFoundationVideoSource *source = [_factory avFoundationVideoSourceWithConstraints:cameraConstraints];
            RTCVideoTrack *localVideoTrack = [_factory videoTrackWithSource:source trackId:kARDVideoTrackId];
            _localView.captureSession = source.captureSession;

            return localVideoTrack;
        }*/
    private func createLocalVideoTrack() -> RTCVideoTrack {
        let cameraConstraints = currentMediaVideoConstraints()
        let source = factory.avFoundationVideoSource(with: cameraConstraints)
        let localVideoTrack = factory.videoTrack(with: source, trackId: MainViewController.kARDAudioTrackId)
        localView.captureSession = source.captureSession

        return localVideoTrack;
    }

    /*
     - (nullable NSDictionary *)currentMediaConstraint {
         NSDictionary *mediaConstraintsDictionary = nil;

         NSString *widthConstraint = @"480";
         NSString *heightConstraint = @"360";
         NSString *frameRateConstrait = @"20";
         if (widthConstraint && heightConstraint) {
             mediaConstraintsDictionary = @{
                                            kRTCMediaConstraintsMinWidth : widthConstraint,
                                            kRTCMediaConstraintsMaxWidth : widthConstraint,
                                            kRTCMediaConstraintsMinHeight : heightConstraint,
                                            kRTCMediaConstraintsMaxHeight : heightConstraint,
                                            kRTCMediaConstraintsMaxFrameRate: frameRateConstrait,
                                            };
         }
         return mediaConstraintsDictionary;
     }     */
    func currentMediaVideoConstraints() -> RTCMediaConstraints {
        let widthConstraint = "480"
        let heightConstraint = "360"
        let frameRateConstraint = "20"
        let constraints = [
            kRTCMediaConstraintsMinWidth : widthConstraint,
            kRTCMediaConstraintsMaxWidth : widthConstraint,
            kRTCMediaConstraintsMinHeight : heightConstraint,
            kRTCMediaConstraintsMaxHeight : heightConstraint,
            kRTCMediaConstraintsMaxFrameRate: frameRateConstraint
        ]
        return RTCMediaConstraints(mandatoryConstraints: constraints, optionalConstraints: nil)
    }

    /*
     - (RTCAudioTrack *)createLocalAudioTrack {

         RTCMediaConstraints *constraints = [self defaultMediaAudioConstraints];
         RTCAudioSource *source = [_factory audioSourceWithConstraints:constraints];
         RTCAudioTrack *track = [_factory audioTrackWithSource:source trackId:kARDAudioTrackId];

         return track;
     }
     */

    func createLocalAudioTrack() -> RTCAudioTrack {

        let constraints = defaultMediaAudioConstraints()
        let source = factory.audioSource(with: constraints)
        let track = factory.audioTrack(with: source, trackId: MainViewController.kARDAudioTrackId)

        return track;
    }

    /*
     - (RTCMediaConstraints *)defaultMediaAudioConstraints {
         NSDictionary *mandatoryConstraints = @{ kRTCMediaConstraintsLevelControl : kRTCMediaConstraintsValueFalse };
         RTCMediaConstraints *constraints =
         [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                               optionalConstraints:nil];
         return constraints;
     }
     */

    func defaultMediaAudioConstraints() -> RTCMediaConstraints {
        return RTCMediaConstraints(mandatoryConstraints: [kRTCMediaConstraintsLevelControl: kRTCMediaConstraintsValueFalse],
                                   optionalConstraints: nil)
    }

  /*  - (RTCEAGLVideoView *)createRemoteView {
        height += 360;
        RTCEAGLVideoView *remoteView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, height, 480, 360)];
        remoteView.delegate = self;
        [self.view addSubview:remoteView];
        return remoteView;
    }
*/
    // TODO Move layout stuff out of here, gross
    func createRemoteView() -> RTCEAGLVideoView {
        height += 360;
        let remoteView = RTCEAGLVideoView(frame: CGRect(x: 0, y: height, width: 480, height: 360))
        remoteView.delegate = self
        self.view.addSubview(remoteView)
        return remoteView
    }

}

extension MainViewController: WebSocketDelegate {
/*
     - (void)onPublisherJoined: (NSUInteger) handleId {
         [self offerPeerConnection:[[NSNumber alloc] initWithUnsignedLong:handleId]];
     }


     */
    func onPublisherJoined(_ handleId: UInt64) {
        offerPeerConnection(handleId: handleId)
    }

    /*
     - (void)onPublisherRemoteJsep:(NSUInteger)handleId jsep:(NSDictionary *)jsep {
         NSNumber *handleIdNum = [[NSNumber alloc] initWithUnsignedLong:handleId];
         JanusConnection *jc = peerConnectionDict[handleIdNum];
         RTCSessionDescription *answerDescription = [RTCSessionDescription descriptionFromJSONDictionary:jsep];
         [jc.connection setRemoteDescription:answerDescription completionHandler:^(NSError * _Nullable error) {
         }];
     }
     */
    func onPublisherRemoteJsep(_ handleId: UInt64, jsep: Dictionary<String, Any>) {
        let jc = peerConnectionDict[handleId]
        guard let answerDescription = RTCSessionDescription.description(from: jsep) else {
            return
        }
        jc?.connection?.setRemoteDescription(answerDescription, completionHandler: { (err) in
            if let err = err {
                print("Error setting remote description: \(err)")
            }
        })
    }

    /*
     - (void)subscriberHandleRemoteJsep:(NSUInteger)handleId jsep:(NSDictionary *)jsep {
         NSNumber *handleIdNum = [[NSNumber alloc] initWithUnsignedLong:handleId];

         RTCPeerConnection *peerConnection = [self createPeerConnection];

         JanusConnection *jc = [[JanusConnection alloc] init];
         jc.connection = peerConnection;
         jc.handleId = handleIdNum;
         peerConnectionDict[handleIdNum] = jc;

         RTCSessionDescription *answerDescription = [RTCSessionDescription descriptionFromJSONDictionary:jsep];
         [peerConnection setRemoteDescription:answerDescription completionHandler:^(NSError * _Nullable error) {
         }];
         NSDictionary *mandatoryConstraints = @{
                                                @"OfferToReceiveAudio" : @"true",
                                                @"OfferToReceiveVideo" : @"true",
                                                };
         RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints optionalConstraints:nil];

         [peerConnection answerForConstraints:constraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
             [peerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
             }];
             [websocket subscriberCreateAnswer:handleId sdp:sdp];
         }];

     }
     */
    func subscriberHandleRemoteJsep(_ handleId: UInt64, jsep: Dictionary<String, Any>) {
        let peerConnection = createPeerConnection()

        let jc = JanusConnection()
        jc.connection = peerConnection
        jc.handleId = handleId
        peerConnectionDict[handleId] = jc

        guard let answerDescription = RTCSessionDescription.description(from: jsep) else {
            print("Error getting answer description in subscriberHandleRemoteJsep")
            return
        }
        peerConnection.setRemoteDescription(answerDescription) { (err) in
            if let err = err {
                print("Error in setRemoteDescription: \(err)")
            }
        }
        let mandatoryConstraints = [
            "OfferToReceiveAudio" : "true",
            "OfferToReceiveVideo" : "true",
        ]
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: nil)
        peerConnection.answer(for: constraints) { (sdp, err) in
            guard let sdp = sdp else {
                print("SDP missing when generating answer in subscriberHandleRemoteJsep")
                return
            }
            if let err = err {
                print("Error creating answer: \(err)")
                return
            }
            peerConnection.setLocalDescription(sdp) { (err) in
                if let err = err {
                    print("Error setting local description: \(err)")
                    return
                }
                self.websocket.subscriberCreateAnswer(handleId, sdp: sdp)
            }
        }
    }

    /*
     - (void)onLeaving:(NSUInteger)handleId {
         NSNumber *handleIdNum = [[NSNumber alloc] initWithUnsignedLong:handleIdNum];
         JanusConnection *jc = peerConnectionDict[handleIdNum];
         [jc.connection close];
         jc.connection = nil;
         RTCVideoTrack *videoTrack = jc.videoTrack;
         [videoTrack removeRenderer: jc.videoView];
         videoTrack = nil;
         [jc.videoView renderFrame:nil];
         [jc.videoView removeFromSuperview];

         [peerConnectionDict removeObjectForKey:handleIdNum];
     }

     @end
     */
    func onLeaving(_ handleId: UInt64) {
        guard let jc = peerConnectionDict[handleId] else {
            print("Error: onLeaving, No peer connection found with handleId \(handleId)")
            return
        }
        jc.connection?.close()
        jc.connection = nil
        let videoTrack = jc.videoTrack
        videoTrack?.remove(jc.videoView!)
        DispatchQueue.main.async {
            jc.videoView?.renderFrame(nil)
            jc.videoView?.removeFromSuperview()
        }
        peerConnectionDict.removeValue(forKey: handleId)
    }

    /*
     - (void)offerPeerConnection: (NSNumber*) handleId {
         [self createPublisherPeerConnection];
         JanusConnection *jc = [[JanusConnection alloc] init];
         jc.connection = publisherPeerConnection;
         jc.handleId = handleId;
         peerConnectionDict[handleId] = jc;

         [publisherPeerConnection offerForConstraints:[self defaultOfferConstraints]
                            completionHandler:^(RTCSessionDescription *sdp,
                                                NSError *error) {
                                [publisherPeerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                                    [websocket publisherCreateOffer:[handleId unsignedLongValue] sdp:sdp];
                                }];
                            }];
     }
     */
    private func offerPeerConnection(handleId: UInt64) {
        createPublisherPeerConnection()

        let jc = JanusConnection()
        jc.connection = publisherPeerConnection
        jc.handleId = handleId
        peerConnectionDict[handleId] = jc
        publisherPeerConnection.offer(for: self.defaultOfferConstraints()) { (sdp, error) in
            if let sdp = sdp {
                self.publisherPeerConnection.setLocalDescription(sdp) { (err) in
                    self.websocket.publisherCreateOffer(handleId, sdp: sdp)
                }
            }
            if let error = error {
                print("Error creating publisher offer: \(error)")
            }
        }
    }

    /*
     - (RTCMediaConstraints *)defaultOfferConstraints {
         NSDictionary *mandatoryConstraints = @{
                                                @"OfferToReceiveAudio" : @"false",
                                                @"OfferToReceiveVideo" : @"false"
                                                };
         RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints optionalConstraints:nil];
         return constraints;
     }
     */
    func defaultOfferConstraints() -> RTCMediaConstraints {
        let mandatoryConstraints = [
            "OfferToReceiveAudio" : "false",
            "OfferToReceiveVideo" : "false"
        ]
        return RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: nil)
    }

    /*
     - (void)createPublisherPeerConnection {
         publisherPeerConnection = [self createPeerConnection];
         [self createAudioSender:publisherPeerConnection];
         [self createVideoSender:publisherPeerConnection];
     }
     */

    private func createPublisherPeerConnection() {
        publisherPeerConnection = createPeerConnection()
        // TODO Is this necessary?
        createAudioSender(publisherPeerConnection)
        createVideoSender(publisherPeerConnection)
    }
/*
    - (RTCRtpSender *)createAudioSender:(RTCPeerConnection *)peerConnection {
        RTCRtpSender *sender = [peerConnection senderWithKind:kRTCMediaStreamTrackKindAudio streamId:kARDMediaStreamId];
        if (localAudioTrack) {
            sender.track = localAudioTrack;
        }
        return sender;
    }
*/
    private func createAudioSender(_ peerConnection: RTCPeerConnection) -> RTCRtpSender {
        let sender = peerConnection.sender(withKind: kRTCMediaStreamTrackKindAudio, streamId: MainViewController.kARDMediaStreamId)
        if (localAudioTrack != nil) {
            sender.track = localAudioTrack
        }
        return sender
    }

    /*
    - (RTCRtpSender *)createVideoSender:(RTCPeerConnection *)peerConnection {
        RTCRtpSender *sender = [peerConnection senderWithKind:kRTCMediaStreamTrackKindVideo
                                                     streamId:kARDMediaStreamId];
        if (localTrack) {
            sender.track = localTrack;
        }

        return sender;
    }*/


    private func createVideoSender(_ peerConnection: RTCPeerConnection) -> RTCRtpSender {
        let sender = peerConnection.sender(withKind: kRTCMediaStreamTrackKindVideo,
                                           streamId: MainViewController.kARDMediaStreamId)
        if (localTrack != nil) {
            sender.track = localTrack
        }

        return sender
    }

    /*
     - (RTCPeerConnection *)createPeerConnection {
         RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
         RTCConfiguration *config = [[RTCConfiguration alloc] init];
         NSMutableArray *iceServers = [NSMutableArray arrayWithObject:[self defaultSTUNServer]];
         config.iceServers = iceServers;
         config.iceTransportPolicy = RTCIceTransportPolicyRelay;
         RTCPeerConnection *peerConnection = [_factory peerConnectionWithConfiguration:config
                                              constraints:constraints
                                                 delegate:self];
         return peerConnection;
     }
     */
    private func createPeerConnection() -> RTCPeerConnection {
        let constraints = defaultPeerConnectionConstraints()
        let config = RTCConfiguration()
        let iceServers = [defaultSTUNServers()]
        config.iceServers = iceServers
        config.iceTransportPolicy = .relay
        let peerConnection = factory.peerConnection(with: config, constraints: constraints, delegate: self)
        return peerConnection
    }

    /*
     - (RTCIceServer *)defaultSTUNServer {
         NSArray *array = [NSArray arrayWithObjects:
                           @"stun:turn1.here.fm:3478?transport=udp",
                           @"stun:turn2.here.fm:3478?transport=udp",
                           @"turn:turn1.here.fm:3478?transport=udp",
                           @"turn:turn2.here.fm:3478?transport=udp", nil];
         return [[RTCIceServer alloc] initWithURLStrings:array
                                                username:@"officeparty"
                                              credential:@"officeparty"];
     }
     */
    // TODO Move this to a protocol / config
    private func defaultSTUNServers() -> RTCIceServer {
        let urls = [
            "stun:turn1.here.fm:3478?transport=udp",
            "stun:turn2.here.fm:3478?transport=udp",
            "turn:turn1.here.fm:3478?transport=udp",
            "turn:turn2.here.fm:3478?transport=udp"]
        return RTCIceServer(urlStrings: urls, username: "officeparty", credential: "officeparty")
    }

    /*
     - (RTCMediaConstraints *)defaultPeerConnectionConstraints {
         NSDictionary *optionalConstraints = @{ @"DtlsSrtpKeyAgreement" : @"true" };
         RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil  optionalConstraints:optionalConstraints];
         return constraints;
     }
     */
    private func defaultPeerConnectionConstraints() -> RTCMediaConstraints {
        // This might not be necessary anymore / for much longer
        // https://bugs.chromium.org/p/chromium/issues/detail?id=804275
        let optionalConstraints = [ "DtlsSrtpKeyAgreement": "true" ];
        return RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: optionalConstraints)
    }
}

extension MainViewController: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("Signaling state changed \(stateChanged)")
    }

    /*
     - (void)peerConnection:(RTCPeerConnection *)peerConnection didAddStream:(RTCMediaStream *)stream {
         NSLog(@"=========didAddStream");
         JanusConnection *janusConnection;

         for (NSNumber *key in peerConnectionDict) {
             JanusConnection *jc = peerConnectionDict[key];
             if (peerConnection == jc.connection) {
                 janusConnection = jc;
                 break;
             }
         }

         dispatch_async(dispatch_get_main_queue(), ^{
             if (stream.videoTracks.count) {
                 RTCVideoTrack *remoteVideoTrack = stream.videoTracks[0];

                 RTCEAGLVideoView *remoteView = [self createRemoteView];
                 [remoteVideoTrack addRenderer:remoteView];
                 janusConnection.videoTrack = remoteVideoTrack;
                 janusConnection.videoView = remoteView;
             }
         });
     }
     */
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("=========didAddStream")
        guard let janusConnection = janusConnection(for: peerConnection) else {
            print("Error: Can't find matching JanusConnection for RTCPeerConnection")
            return
        }

        DispatchQueue.main.async {
            if (stream.videoTracks.count > 0) {
                let remoteVideoTrack = stream.videoTracks[0]
                let remoteView = self.createRemoteView()
                remoteVideoTrack.add(remoteView)
                janusConnection.videoTrack = remoteVideoTrack
                janusConnection.videoView = remoteView
            } else {
                print("**** No video tracks for stream");
            }
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("=========didRemoveStream")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("peerConnectionShouldNegotiate")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("**** peerConnectionDidChangeIceConnectionState: \(newState.rawValue)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("**** Did change ICE gathering state \(newState.rawValue)")
        if newState == .complete {
            guard let janusConnection = self.janusConnection(for: peerConnection) else {
                print("Error: finished ICE gathering but no recognized peerConnection")
                return;
            }
            websocket.trickleCandidateComplete(janusConnection.handleId!)
        }
    }

    /*
     - (void)peerConnection:(RTCPeerConnection *)peerConnection didGenerateIceCandidate:(RTCIceCandidate *)candidate {
         NSLog(@"=========didGenerateIceCandidate==%@", candidate.sdp);

         NSNumber *handleId;
         for (NSNumber *key in peerConnectionDict) {
             JanusConnection *jc = peerConnectionDict[key];
             if (peerConnection == jc.connection) {
                 handleId = jc.handleId;
                 break;
             }
         }
         if (candidate != nil) {
             [websocket trickleCandidate:[handleId unsignedLongValue] candidate:candidate];
         } else {
             [websocket trickleCandidateComplete: [handleId unsignedLongValue]];
         }
     }
     */
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("=========didGenerateIceCandidate==\(candidate.sdp)")
        guard let janusConnection = self.janusConnection(for: peerConnection) else {
            print("Error: Can't find matching JanusConnection for RTCPeerConnection in didGenerateIceCandidate")
            return
        }

        let handleId = janusConnection.handleId!
        // TODO Looks like we can remove this check, but when do we call trickleCandidateComplete?
        if (candidate != nil) {
            print("Trickle candidate: \(candidate)")
            websocket.trickleCandidate(handleId, candidate: candidate)
        } else {
            websocket.trickleCandidateComplete(handleId)
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("=========didRemoveIceCandidates")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        // TODO
    }

    private func janusConnection(for peerConnection: RTCPeerConnection) -> JanusConnection? {
        let (_, janusConnection) = peerConnectionDict.first(where: {
            return $0.value.connection == peerConnection
        }) ?? (nil, nil)
        return janusConnection
    }
}

extension MainViewController: RTCEAGLVideoViewDelegate {
    /*
     - (void)videoView:(RTCEAGLVideoView *)videoView didChangeVideoSize:(CGSize)size {
         CGRect rect = videoView.frame;
         rect.size = size;
         NSLog(@"========didChangeVideoSize %fx%f", size.width, size.height);
         videoView.frame = rect;
     }
     */
    func videoView(_ videoView: RTCEAGLVideoView, didChangeVideoSize size: CGSize) {
        var rect = videoView.frame
        rect.size = size
        print("========didChangeVideoSize \(size.width)x\(size.height)");
        videoView.frame = rect
    }
}
