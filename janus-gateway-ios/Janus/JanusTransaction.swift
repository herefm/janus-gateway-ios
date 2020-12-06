//
//  JanusTransaction.swift
//  janus-gateway-ios
//
//  Created by Jesse Boyes on 12/4/20.
//  Copyright © 2020 MineWave. All rights reserved.
//

import Foundation

/*
 typedef void (^TransactionSuccessBlock)(NSDictionary *data);
 typedef void (^TransactionErrorBlock)(NSDictionary *data);

 @interface JanusTransaction : NSObject

 @property (nonatomic, readwrite) NSString *tid;
 @property (copy) TransactionSuccessBlock success;
 @property (copy) TransactionErrorBlock error;

 @end

 */
public typealias TransactionSuccess = (Dictionary<String, Any>) -> Void
public typealias TransactionError = (Dictionary<String, Any>) -> Void

@objcMembers public class JanusTransaction: NSObject {
    public var tid: String?
    public var success: TransactionSuccess?
    public var error: TransactionError?
}
