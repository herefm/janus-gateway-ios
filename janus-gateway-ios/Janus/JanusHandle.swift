//
//  JanusHandle.swift
//  janus-gateway-ios
//
//  Created by Jesse Boyes on 11/27/20.
//  Copyright © 2020 H3R3. All rights reserved.
//

import Foundation

/*
 typedef void (^OnJoined)(JanusHandle *handle);
 typedef void (^OnRemoteJsep)(JanusHandle *handle, NSDictionary *jsep);

 @interface JanusHandle : NSObject

 @property (readwrite, nonatomic) NSNumber *handleId;
 @property (readwrite, nonatomic) NSNumber *feedId;
 @property (readwrite, nonatomic) NSString *display;

 @property (copy) OnJoined onJoined;
 @property (copy) OnRemoteJsep onRemoteJsep;
 @property (copy) OnJoined onLeaving;
*/
public typealias OnHandleStateChange = (JanusHandle) -> Void
public typealias OnRemoteJsep = (JanusHandle, Dictionary<String, Any>) -> Void

@objcMembers public class JanusHandle: NSObject {
    public var onJoined: OnHandleStateChange?
    public var onLeaving: OnHandleStateChange?
    public var onRemoteJsep: OnRemoteJsep?
    public var handleId: UInt64
    public var feedId: String?
    public var display: String?

    init(_ handleId: UInt64) {
        self.handleId = handleId;
    }
}
