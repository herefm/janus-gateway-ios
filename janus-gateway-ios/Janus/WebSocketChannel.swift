//
//  WebSocketChannel.swift
//  janus-gateway-ios
//
//  Created by Jesse Boyes on 12/9/20.
//  Copyright © 2020 MineWave. All rights reserved.
//

import Foundation


// #import "WebRTC/RTCLogging.h"
// #import "SRWebSocket.h"
// #import "janus_gateway_ios-Swift.h"

// static NSString const *kJanus = @"janus";
// static NSString const *kJanusData = @"data";

/*
@interface WebSocketChannel () <SRWebSocketDelegate>
@property(nonatomic, readonly) ARDSignalingChannelState state;

@end
*/

enum ARDSignalingChannelState {
    case kARDSignalingChannelStateClosed
    case kARDSignalingChannelStateOpen
    case kARDSignalingChannelStateCreate
    case kARDSignalingChannelStateAttach
    case kARDSignalingChannelStateJoin
    case kARDSignalingChannelStateOffer
    case kARDSignalingChannelStateError
};

protocol WebSocketDelegate {
    func onPublisherJoined(_ handleId: Int)
    func onPublisherRemoteJsep(_ handleId: Int, jsep: Dictionary<String, Any>)
    func subscriberHandleRemoteJsep(_ handleId: Int, jsep: Dictionary<String, Any>)
    func onLeaving(_ handleId: Int)
}


@objc class WebSocketChannel: NSObject {
    public var delegate: WebSocketDelegate?

    public var roomName: String = "ZInARgyrVYXjj2NukBNu"
    public var userDisplayName: String = "j9s1h5MVf2OJ5eHIK2zU43uJufk2"


    static let kJanus = "janus"
    static let kJanusData = "data"

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /*
    @implementation WebSocketChannel {
        NSURL *_url;
        SRWebSocket *_socket;
        NSNumber *sessionId;
        NSTimer *keepAliveTimer;
        NSMutableDictionary *transDict;
        NSMutableDictionary *handleDict;
        NSMutableDictionary *feedDict;
    }

    @synthesize state = _state;
*/
    var state: ARDSignalingChannelState = .kARDSignalingChannelStateClosed
    //

    private var url: URL
    private var session: URLSession
    private var socket: URLSessionWebSocketTask!
    var sessionId: Int!
    var keepAliveTimer: Timer!
    var transDict: Dictionary<String, JanusTransaction>
    var handleDict: Dictionary<Int, JanusHandle>
    var feedDict: Dictionary<Int, JanusHandle>

    /*
     - (instancetype)initWithURL:(NSURL *)url {
         if (self = [super init]) {
             _url = url;
             NSArray<NSString *> *protocols = [NSArray arrayWithObject:@"janus-protocol"];
             _socket = [[SRWebSocket alloc] initWithURL:url protocols:(NSArray *)protocols];
             _socket.delegate = self;
             keepAliveTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(keepAlive) userInfo:nil repeats:YES];
             transDict = [NSMutableDictionary dictionary];
             handleDict = [NSMutableDictionary dictionary];
             feedDict = [NSMutableDictionary dictionary];

             RTCLog(@"Opening WebSocket.");
             [_socket open];
         }
         return self;
     }
     */

    init(url: URL) {
        self.url = url
        self.transDict = Dictionary()
        self.handleDict = Dictionary()
        self.feedDict = Dictionary()
        self.session = URLSession(configuration: .default)
        super.init()

        socket = session.webSocketTask(with: url)
        self.listen()
        socket.resume();

        self.keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true, block: { (timer) in
            let keepAlive: [String: Encodable] = [
                "janus": "keepalive",
                "session_id": self.sessionId,
                "transaction": self.randomStringWithLength(12)
            ]
            self.sendMessage(keepAlive)
        })
    }

    func listen() {
      self.socket.receive { [weak self] (result) in
        guard let self = self else { return }
        switch result {
        case .failure(let error):
          print(error)
            // -- TODO: error callback
            /*
          let alert = Alert(
              title: Text("Unable to connect to server!"),
              dismissButton: .default(Text("Retry")) {
                self.alert = nil
                self.socket.cancel(with: .goingAway, reason: nil)
                self.connect()
              }
          )
          self.alert = alert
 */
          self.state = .kARDSignalingChannelStateError;
          return
        case .success(let message):
          // 4
          switch message {
          case .data(let data):
            do {
                try self.handleMessage(data)
            } catch {
                print("Error handling message: \(error)")
            }
          case .string(let str):
            guard let data = str.data(using: .utf8) else { return }
            do {
                try self.handleMessage(data)
            } catch {
                print("Error handling message: \(error)")
            }
          @unknown default:
            break
          }
        }
        // 5
        self.listen()
      }
    }

    /*
     - (void)dealloc {
       [self disconnect];
     }
*/
    deinit {
        if (state == .kARDSignalingChannelStateClosed ||
                state == .kARDSignalingChannelStateError) {
          return
        }
        socket.cancel(with: .goingAway, reason: nil)
        RTCLog("C->WSS DELETE close")
    }

    /*
    - (void)disconnect {
      if (_state == kARDSignalingChannelStateClosed ||
          _state == kARDSignalingChannelStateError) {
        return;
      }
      [_socket close];
        RTCLog(@"C->WSS DELETE close");
    }*/

}

/*
 - (void)webSocketDidOpen:(SRWebSocket *)webSocket {
   RTCLog(@"WebSocket connection opened.");
   self.state = kARDSignalingChannelStateOpen;
   [self createSession];
 }
 */
extension WebSocketChannel: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        RTCLog("WebSocket connection opened.")
        state = .kARDSignalingChannelStateOpen;
        self.createSession()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        /*- (void)webSocket:(SRWebSocket *)webSocket
         didCloseWithCode:(NSInteger)code
                   reason:(NSString *)reason
                 wasClean:(BOOL)wasClean {
            RTCLog(@"WebSocket closed with code: %ld reason:%@ wasClean:%d",
                   (long)code, reason, wasClean);
            NSParameterAssert(_state != kARDSignalingChannelStateError);
            self.state = kARDSignalingChannelStateClosed;
            [keepAliveTimer invalidate];
        }
*/

        self.RTCLogInfo("WebSocket closed with code: \(closeCode)");
        self.state = .kARDSignalingChannelStateClosed
        keepAliveTimer.invalidate();
    }
    
    /*
     - (void)createSession {
         NSString *transaction = [self randomStringWithLength:12];

         JanusTransaction *jt = [[JanusTransaction alloc] init];
         jt.tid = transaction;
         jt.success = ^(NSDictionary *data) {
             sessionId = data[@"data"][@"id"];
             [keepAliveTimer fire];
             [self publisherCreateHandle];
         };
         jt.error = ^(NSDictionary *data) {
         };
         transDict[transaction] = jt;

         NSDictionary *createMessage = @{
             @"janus": @"create",
             @"transaction" : transaction,
                                         };
       [_socket send:[self jsonMessage:createMessage]];
     }
     */

    private func createSession() {
        let transaction = randomStringWithLength(12);

        let jt = JanusTransaction()
        jt.tid = transaction
        jt.success = { (result) in
            let data = result["data"] as! Dictionary<String, Any>
            self.sessionId = data["id"] as! Int
            self.keepAliveTimer.fire()
            self.publisherCreateHandle()
        }
        jt.error = { (result) in
            self.RTCLogError("JanusTransaction error :(")
        }
        transDict[transaction] = jt

        let createMessage: Dictionary<String, Encodable> = [
            "janus": "create",
            "transaction" : transaction
        ]

        sendMessage(createMessage);
    }
/*
     - (void)publisherCreateHandle {
         NSString *transaction = [self randomStringWithLength:12];
         JanusTransaction *jt = [[JanusTransaction alloc] init];
         jt.tid = transaction;
         jt.success = ^(NSDictionary *data){
             JanusHandle *handle = [[JanusHandle alloc] init];
             handle.handleId = data[@"data"][@"id"];
             handle.onJoined = ^(JanusHandle *handle) {
                 [self.delegate onPublisherJoined: handle.handleId];
             };
             handle.onRemoteJsep = ^(JanusHandle *handle, NSDictionary *jsep) {
                 [self.delegate onPublisherRemoteJsep:handle.handleId dict:jsep];
             };

             handleDict[handle.handleId] = handle;
             [self publisherJoinRoom: handle];
         };
         jt.error = ^(NSDictionary *data) {
         };
         transDict[transaction] = jt;

         NSDictionary *attachMessage = @{
                                         @"janus": @"attach",
                                         @"plugin": @"janus.plugin.videoroom",
                                         @"transaction": transaction,
                                         @"session_id": sessionId,
                                         };
         [_socket send:[self jsonMessage:attachMessage]];
     }
*/
    func publisherCreateHandle() {
        // TODO wrap this transaction stuff that we keep doing in a JanusTransaction constructor?
        let transaction = randomStringWithLength(12)
        let jt = JanusTransaction()
        jt.tid = transaction
        jt.success = { (result) in
            let data = result["data"] as! Dictionary<String, Any>
            let handle = JanusHandle(data["id"] as! Int)
            handle.onJoined = { (handle: JanusHandle) in
                self.delegate?.onPublisherJoined(handle.handleId)
            }
            handle.onRemoteJsep = { (handle, jsep) in
                self.delegate?.onPublisherRemoteJsep(handle.handleId, jsep: jsep)
            }

            self.handleDict[handle.handleId] = handle;
            self.publisherJoinRoom(handle);
        }
        jt.error = { (result) in
            self.RTCLogError("JanusTransaction error :(")
        }

        transDict[transaction] = jt;

        let attachMessage: [String: Encodable] = [
            "janus": "attach",
            "plugin": "janus.plugin.videoroom",
            "transaction": transaction,
            "session_id": sessionId,
        ];
        sendMessage(attachMessage);
    }

    /*
     - (void)publisherJoinRoom : (JanusHandle *)handle {
         NSString *transaction = [self randomStringWithLength:12];

         NSDictionary *body = @{
                                @"request": @"join",
                                @"room": @"ZInARgyrVYXjj2NukBNu",
                                @"ptype": @"publisher",
                                @"display": @"j9s1h5MVf2OJ5eHIK2zU43uJufk2",
                                };
         NSDictionary *joinMessage = @{
                                       @"janus": @"message",
                                       @"transaction": transaction,
                                       @"session_id":sessionId,
                                       @"handle_id":handle.handleId,
                                       @"body": body
                                       };

         [_socket send:[self jsonMessage:joinMessage]];
     }
     */
    private func publisherJoinRoom(_ handle: JanusHandle) {
        let transaction = randomStringWithLength(12)

        let body = [
            "request": "join",
            "room": roomName,
            "ptype": "publisher",
            "display": userDisplayName
        ];
        let joinMessage: [String: Encodable] = [
            "janus": "message",
            "transaction": transaction,
            "session_id": sessionId,
            "handle_id": handle.handleId,
            "body": body
        ];

        sendMessage(joinMessage);
    }

    /*
     - (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
       NSLog(@"====onMessage=%@", message);
       NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
       id jsonObject = [NSJSONSerialization JSONObjectWithData:messageData options:0 error:nil];
       if (![jsonObject isKindOfClass:[NSDictionary class]]) {
         NSLog(@"Unexpected message: %@", jsonObject);
         return;
       }
       NSDictionary *wssMessage = jsonObject;
       NSString *janus = wssMessage[kJanus];
         if ([janus isEqualToString:@"success"]) {
             NSString *transaction = wssMessage[@"transaction"];

             JanusTransaction *jt = transDict[transaction];
             if (jt.success != nil) {
                 jt.success(wssMessage);
             }
             [transDict removeObjectForKey:transaction];
         } else if ([janus isEqualToString:@"error"]) {
             NSString *transaction = wssMessage[@"transaction"];
             JanusTransaction *jt = transDict[transaction];
             if (jt.error != nil) {
                 jt.error(wssMessage);
             }
             [transDict removeObjectForKey:transaction];
         } else if ([janus isEqualToString:@"ack"]) {
             NSLog(@"Just an ack");
         } else {
             JanusHandle *handle = handleDict[wssMessage[@"sender"]];
             if (handle == nil) {
                 NSLog(@"missing handle?");
             } else if ([janus isEqualToString:@"event"]) {
                 NSDictionary *plugin = wssMessage[@"plugindata"][@"data"];
                 if ([plugin[@"videoroom"] isEqualToString:@"joined"]) {
                     handle.onJoined(handle);
                 }

                 NSArray *arrays = plugin[@"publishers"];
                 if (arrays != nil && [arrays count] > 0) {
                     for (NSDictionary *publisher in arrays) {
                         NSNumber *feed = publisher[@"id"];
                         NSString *display = publisher[@"display"];
                         [self subscriberCreateHandle:feed display:display];
                     }
                 }

                 if (plugin[@"leaving"] != nil) {
                     JanusHandle *jHandle = feedDict[plugin[@"leaving"]];
                     if (jHandle) {
                         jHandle.onLeaving(jHandle);
                     }
                 }

                 if (wssMessage[@"jsep"] != nil) {
                     handle.onRemoteJsep(handle, wssMessage[@"jsep"]);
                 }
             } else if ([janus isEqualToString:@"detached"]) {
                 handle.onLeaving(handle);
             }
         }
     }

     */

    func handleMessage(_ data: Data) throws {
        guard let message = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            print("Can't deserialize JSON message")
            return
        }
        print("====onMessage=%@", message);
        guard let janus: String = message[WebSocketChannel.kJanus] as? String else {
            print("No Janus response key in message")
            return
        }

        if (janus == "success") {
            if let transaction = message["transaction"] as? String,
               let jt = transDict[transaction] {
                jt.success?(message);
                transDict.removeValue(forKey: transaction)
            }
        } else if (janus == "error") {
            if let transaction = message["transaction"] as? String,
               let jt = transDict[transaction] {
                jt.error?(message)
                transDict.removeValue(forKey: transaction)
            }
        } else if (janus == "ack") {
            print("Just an ack");
        } else {
            guard let sender = message["sender"] as? Int,
                  let handle = handleDict[sender] else {
                print("Missing handle?")
                return
            }
            if (janus == "event") {
                guard let pluginData = message["plugindata"] as? [String: Any],
                      let plugin = pluginData["data"] as? [String: Any] else {
                    print("Missing plugin data on event")
                    return
                }
                if (plugin["videoroom"] as? String == "joined") {
                    handle.onJoined?(handle);
                }

                if let publishers = plugin["publishers"] as? [[String: Any]] {
                    for publisher in publishers {
                        if let feed = publisher["id"] as? Int,
                           let display = publisher["display"] as? String {
                            subscriberCreateHandle(feed, display: display)
                        } else {
                            print("Bad publisher data: \(publisher)")
                        }
                    }
                }

                if let leavingId = plugin["leaving"] as? Int,
                   let jHandle = feedDict[leavingId] {
                    jHandle.onLeaving?(jHandle)
                }

                if let jsep = message["jsep"] as? [String: Any] {
                    handle.onRemoteJsep?(handle, jsep);
                }
            } else if (janus == "detached") {
                handle.onLeaving?(handle);
            }
        }
    }

    /*
     - (void)publisherCreateOffer:(NSNumber *)handleId sdp: (RTCSessionDescription *)sdp {
         NSString *transaction = [self randomStringWithLength:12];

         NSDictionary *publish = @{
                                  @"request": @"configure",
                                  @"audio": @YES,
                                  @"video": @YES,
                                  };

         NSString *type = [RTCSessionDescription stringForType:sdp.type];

         NSDictionary *jsep = @{
                                @"type": type,
                               @"sdp": [sdp sdp],
                                };
         NSDictionary *offerMessage = @{
                                        @"janus": @"message",
                                        @"body": publish,
                                        @"jsep": jsep,
                                        @"transaction": transaction,
                                        @"session_id": sessionId,
                                        @"handle_id": handleId,
                                        };


         [_socket send:[self jsonMessage:offerMessage]];
     }
     */
    func publisherCreateOffer(_ handleId: Int, sdp: RTCSessionDescription) {
        let transaction = randomStringWithLength(12)

        let publish: Encodable = [
            "request": "configure",
            "audio": "true",
            "video": "true",
        ]

        let type = RTCSessionDescription.string(for: sdp.type)
        let jsep: Encodable = [
            "type": type,
            "sdp": sdp.sdp,
        ]
        let offerMessage: [String: Encodable] = [
            "janus": "message",
            "body": publish,
            "jsep": jsep,
            "transaction": transaction,
            "session_id": sessionId,
            "handle_id": handleId,
        ];

        sendMessage(offerMessage)
    }

    /*

     - (void)subscriberCreateHandle: (NSNumber *)feed display:(NSString *)display {
         NSString *transaction = [self randomStringWithLength:12];
         JanusTransaction *jt = [[JanusTransaction alloc] init];
         jt.tid = transaction;
         jt.success = ^(NSDictionary *data){
             JanusHandle *handle = [[JanusHandle alloc] init];
             handle.handleId = data[@"data"][@"id"];
             handle.feedId = feed;
             handle.display = display;

             handle.onRemoteJsep = ^(JanusHandle *handle, NSDictionary *jsep) {
                 [self.delegate subscriberHandleRemoteJsep:handle.handleId dict:jsep];
             };

             handle.onLeaving = ^(JanusHandle *handle) {
                 [self subscriberOnLeaving:handle];
             };
             handleDict[handle.handleId] = handle;
             feedDict[handle.feedId] = handle;
             [self subscriberJoinRoom: handle];
         };
         jt.error = ^(NSDictionary *data) {
         };
         transDict[transaction] = jt;

         NSDictionary *attachMessage = @{
                                         @"janus": @"attach",
                                         @"plugin": @"janus.plugin.videoroom",
                                         @"transaction": transaction,
                                         @"session_id": sessionId,
                                         };
         [_socket send:[self jsonMessage:attachMessage]];
     }
     */


    func subscriberCreateHandle(_ feed: Int, display: String) {
        let transaction = randomStringWithLength(12)
        let jt = JanusTransaction();
        jt.tid = transaction;
        jt.success = { data in
            guard let handleId = (data["data"] as? [String: Any])?["id"] as? Int else {
                print("No handle ID found")
                return
            }
            let handle = JanusHandle(handleId)
            handle.feedId = feed
            handle.display = display

            handle.onRemoteJsep = { (handle, jsep) in
                self.delegate?.subscriberHandleRemoteJsep(handle.handleId, jsep: jsep)
            }
            handle.onLeaving = { handle in
                self.subscriberOnLeaving(handle)
            };
            self.handleDict[handle.handleId] = handle
            self.feedDict[feed] = handle
            self.subscriberJoinRoom(handle)
        }
        jt.error = { (result) in
            self.RTCLogError("JanusTransaction error :(")
        }
        transDict[transaction] = jt

        let attachMessage: [String: Encodable] = [
            "janus": "attach",
            "plugin": "janus.plugin.videoroom",
            "transaction": transaction,
            "session_id": sessionId,
        ]
        sendMessage(attachMessage)
    }

    /*- (void)trickleCandidate:(NSNumber *) handleId candidate: (RTCIceCandidate *)candidate {
        NSDictionary *candidateDict = @{
                                    @"candidate": candidate.sdp,
                                    @"sdpMid": candidate.sdpMid,
                                    @"sdpMLineIndex": [NSNumber numberWithInt: candidate.sdpMLineIndex],
                                    };

        NSDictionary *trickleMessage = @{
                                         @"janus": @"trickle",
                                         @"candidate": candidateDict,
                                         @"transaction": [self randomStringWithLength:12],
                                         @"session_id":sessionId,
                                         @"handle_id":handleId,
                                         };

        NSLog(@"===trickle==%@", trickleMessage);
        [_socket send:[self jsonMessage:trickleMessage]];
    }
 */
    func trickleCandidate(_ handleId: Int, candidate: RTCIceCandidate) {
        let candidateDict: [String: Encodable] = [
            "candidate": candidate.sdp,
            "sdpMid": candidate.sdpMid,
            "sdpMLineIndex": candidate.sdpMLineIndex,
        ]

        let trickleMessage: [String: Encodable] = [
            "janus": "trickle",
            "candidate": candidateDict as! Encodable, // TODO not sure if this will work...
            "transaction": self.randomStringWithLength(12),
            "session_id": sessionId,
            "handle_id": handleId,
        ]

        print("===trickle==\(trickleMessage)")
        sendMessage(trickleMessage)
    }

   /* - (void)trickleCandidateComplete:(NSNumber *) handleId {
        NSDictionary *candidateDict = @{
           @"completed": @YES,
           };
        NSDictionary *trickleMessage = @{
                                         @"janus": @"trickle",
                                         @"candidate": candidateDict,
                                         @"transaction": [self randomStringWithLength:12],
                                         @"session_id":sessionId,
                                         @"handle_id":handleId,
                                         };

        [_socket send:[self jsonMessage:trickleMessage]];
    }*/


    func trickleCandidateComplete(_ handleId: Int) {
        let trickleMessage: [String: Encodable] = [
            "janus": "trickle",
            "candidate": ["completed": "true"],
            "transaction": self.randomStringWithLength(12),
            "session_id": sessionId,
            "handle_id": handleId,
        ]

        self.sendMessage(trickleMessage);
    }

    /*

     - (void)subscriberJoinRoom:(JanusHandle*)handle {

         NSString *transaction = [self randomStringWithLength:12];
         transDict[transaction] = @"subscriber";

         NSDictionary *body = @{
                                @"request": @"join",
                                @"room": @"ZInARgyrVYXjj2NukBNu",
                                @"ptype": @"listener",
                                @"feed": handle.feedId,
                                };

         NSDictionary *message = @{
                                       @"janus": @"message",
                                       @"transaction": transaction,
                                       @"session_id": sessionId,
                                       @"handle_id": handle.handleId,
                                       @"body": body,
                                       };

         [_socket send:[self jsonMessage:message]];
     }
     */

    func subscriberJoinRoom(_ handle: JanusHandle) {
        let transaction = self.randomStringWithLength(12)
        // TODO originial code had this weird thing in it ... ???
        // transDict[transaction] = "subscriber"

        let body: [String: Encodable] = [
            "request": "join",
            "room": self.roomName,
            "ptype": "listener",
            "feed": handle.feedId,
        ]

        let message: [String: Encodable] = [
            "janus": "message",
            "transaction": transaction,
            "session_id": sessionId,
            "handle_id": handle.handleId,
            "body": body as! Encodable,
        ]

        self.sendMessage(message)
    }

    /*

     - (void)subscriberCreateAnswer:(NSNumber *)handleId sdp: (RTCSessionDescription *)sdp  {
         NSString *transaction = [self randomStringWithLength:12];

         NSDictionary *body = @{
                                   @"request": @"start",
                                   @"room": @"ZInARgyrVYXjj2NukBNu",
                                   };

         NSString *type = [RTCSessionDescription stringForType:sdp.type];

         NSDictionary *jsep = @{
                                @"type": type,
                                @"sdp": [sdp sdp],
                                };
         NSDictionary *offerMessage = @{
                                        @"janus": @"message",
                                        @"body": body,
                                        @"jsep": jsep,
                                        @"transaction": transaction,
                                        @"session_id": sessionId,
                                        @"handle_id": handleId,
                                        };

         [_socket send:[self jsonMessage:offerMessage]];
     }
     */

    func subscriberCreateAnswer(_ handleId: Int, sdp: RTCSessionDescription) {
        let transaction = self.randomStringWithLength(12)

        let body = [
            "request": "start",
            "room": roomName
        ]
        let type = RTCSessionDescription.string(for: sdp.type)
        let jsep = ["type": type,
                    "sdp": sdp.sdp]

        let offerMessage: [String: Encodable] = [
            "janus": "message",
            "body": body,
            "jsep": jsep,
            "transaction": transaction,
            "session_id": sessionId,
            "handle_id": handleId,
        ]

        sendMessage(offerMessage)
    }

    /*

     - (void)subscriberOnLeaving:(JanusHandle *) handle {
         NSString *transaction = [self randomStringWithLength:12];

         JanusTransaction *jt = [[JanusTransaction alloc] init];
         jt.tid = transaction;
         jt.success = ^(NSDictionary *data) {
             [self.delegate onLeaving:handle.handleId];
             [handleDict removeObjectForKey:handle.handleId];
             [feedDict removeObjectForKey:handle.feedId];
         };
         jt.error = ^(NSDictionary *data) {
         };
         transDict[transaction] = jt;

         NSDictionary *message = @{
                                        @"janus": @"detach",
                                        @"transaction": transaction,
                                        @"session_id": sessionId,
                                        @"handle_id": handle.handleId,
                                        };

         [_socket send:[self jsonMessage:message]];
     }

     */

    func subscriberOnLeaving(_ handle: JanusHandle) {
        let transaction = self.randomStringWithLength(12)

        let jt = JanusTransaction()
        jt.tid = transaction;
        jt.success = { data in
            self.delegate?.onLeaving(handle.handleId)
            self.handleDict.removeValue(forKey: handle.handleId)
            if let feedId = handle.feedId {
                self.feedDict.removeValue(forKey: feedId)
            }
        }
        jt.error = { (result) in
            self.RTCLogError("JanusTransaction error :(")
        }
        transDict[transaction] = jt;

        let message: [String: Encodable] = [
            "janus": "detach",
            "transaction": transaction,
            "session_id": sessionId,
            "handle_id": handle.handleId,
        ]

        sendMessage(message)
    }


    /*
 NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

 - (NSString *)randomStringWithLength: (int)len {
     NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
     for (int i = 0; i< len; i++) {
         uint32_t data = arc4random_uniform((uint32_t)[letters length]);
         [randomString appendFormat: @"%C", [letters characterAtIndex: data]];
     }
     return randomString;
 }
*/

    private func randomStringWithLength(_ len: Int) -> String {
        let letters: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString = String()
        randomString.reserveCapacity(len)

        for _ in [0..<len] {
            let idx = arc4random_uniform(UInt32(letters.count))
            let char: Character = letters[letters.index(letters.startIndex, offsetBy: Int(idx))]
            randomString.append(char)
        }
        return randomString
    }

    private func sendMessage(_ message: [String: Encodable]) {
        do {
            let data = try encoder.encode(message)
            self.socket.send(.data(data)) { (err) in
                if err != nil {
                    print(err.debugDescription)
                }
            }
        } catch {
            print(error)
        }

    }
}

// MARK: RTC Logging convenience
extension WebSocketChannel {

    func RTCLogFormat(_ severity: RTCLoggingSeverity, _ format: String, _ args: String...) {
        RTCLogEx(severity, String.init(format: format, arguments: args))
    }

    func RTCLogVerbose(_ format: String, _ args: String...) {
        RTCLogFormat(.verbose, String.init(format: format, arguments: args))
    }

    func RTCLogInfo(_ format: String, _ args: String...) {
        RTCLogFormat(.info, String.init(format: format, arguments: args))
    }

    func RTCLogWarning(_ format: String, _ args: String...) {
        RTCLogFormat(.warning, String.init(format: format, arguments: args))
    }

    func RTCLogError(_ format: String, _ args: String...) {
        RTCLogFormat(.error, String.init(format: format, arguments: args))
    }

    func RTCLog(_ format: String, _ args: String...) {
        RTCLogFormat(.info, String.init(format: format, arguments: args))
    }
}

private extension Encodable {
    func encode(to container: inout SingleValueEncodingContainer) throws {
        try container.encode(self)
    }
}

extension JSONEncoder {
    private struct EncodableWrapper: Encodable {
        let wrapped: Encodable

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try self.wrapped.encode(to: &container)
        }
    }

    func encode<Key: Encodable>(_ dictionary: [Key: Encodable]) throws -> Data {
        let wrappedDict = dictionary.mapValues(EncodableWrapper.init(wrapped:))
        return try self.encode(wrappedDict)
    }
}
