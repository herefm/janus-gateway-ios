//
//  RTCSessionDescription+JSON.swift
//  janus-gateway-ios
//
//  Created by Jesse Boyes on 12/14/20.
//  Copyright © 2020 H3R3. All rights reserved.
//

import Foundation

extension RTCSessionDescription {
    static let kRTCSessionDescriptionTypeKey = "type"
    static let kRTCSessionDescriptionSdpKey = "sdp"

    static func description(from JSONDictionary: [String: Any]) -> RTCSessionDescription? {
        guard let typeString = JSONDictionary[kRTCSessionDescriptionTypeKey] as? String else {
            print("error: Invalid RTC Session Description Type Key")
            return nil
        }
        let type = self.type(for: typeString)
        guard let sdp = JSONDictionary[kRTCSessionDescriptionSdpKey] as? String else {
            print("error: missing SDP, can't build session description")
            return nil
        }
        return RTCSessionDescription(type: type, sdp: sdp)
    }
}
/*
- (NSData *)JSONData {
  NSString *type = [[self class] stringForType:self.type];
  NSDictionary *json = @{
    kRTCSessionDescriptionTypeKey : type,
    kRTCSessionDescriptionSdpKey : self.sdp
  };
  return [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
}

*/
