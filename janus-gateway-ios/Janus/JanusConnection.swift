//
//  JanusConnection.swift
//  janus-gateway-ios
//
//  Created by Jesse Boyes on 12/4/20.
//  Copyright © 2020 MineWave. All rights reserved.
//

import Foundation

/*
 @property (readwrite, nonatomic) NSNumber *handleId;
 @property (readwrite, nonatomic) RTCPeerConnection *connection;
 @property (readwrite, nonatomic) RTCVideoTrack *videoTrack;
 @property (readwrite, nonatomic) RTCEAGLVideoView *videoView;

 */
@objcMembers class JanusConnection: NSObject {
    public var handleId: NSNumber?
    public var connection: RTCPeerConnection?
    public var videoTrack: RTCVideoTrack?
    public var videoView: RTCEAGLVideoView?
}