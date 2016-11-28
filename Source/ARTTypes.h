//
//  ARTTypes.h
//  ably-ios
//
//  Created by Jason Choy on 08/12/2014.
//  Copyright (c) 2014 Ably. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CompatibilityMacros.h"
#import "ARTStatus.h"

@class ARTStatus;
@class ARTHttpResponse;
@class ARTErrorInfo;
@class ARTMessage;
@class ARTPresenceMessage;
@class ARTTokenParams;
@class ARTTokenRequest;
@class ARTTokenDetails;
@class __GENERIC(ARTPaginatedResult, ItemType);
@class ARTStats;

typedef NS_ENUM(NSUInteger, ARTAuthentication) {
    ARTAuthenticationOff,
    ARTAuthenticationOn,
    ARTAuthenticationUseBasic,
    ARTAuthenticationNewToken
};

typedef NS_ENUM(NSUInteger, ARTAuthMethod) {
    ARTAuthMethodBasic,
    ARTAuthMethodToken
};

typedef NS_ENUM(NSUInteger, ARTRealtimeConnectionState) {
    ARTRealtimeInitialized,
    ARTRealtimeConnecting,
    ARTRealtimeConnected,
    ARTRealtimeDisconnected,
    ARTRealtimeSuspended,
    ARTRealtimeClosing,
    ARTRealtimeClosed,
    ARTRealtimeFailed
};


NSString *__art_nonnull ARTRealtimeConnectionStateToStr(ARTRealtimeConnectionState state);

typedef NS_ENUM(NSUInteger, ARTChannelState) {
    ARTChannelStateInitialized,
    ARTChannelStateAttaching,
    ARTChannelStateAttached,
    ARTChannelStateDetaching,
    ARTChannelStateDetached,
    ARTChannelStateSuspended,
    ARTChannelStateFailed
};

NSString *__art_nonnull ARTChannelStateToStr(ARTChannelState state);

typedef NS_ENUM(NSUInteger, ARTChannelEvent) {
    ARTChannelEventInitialized,
    ARTChannelEventAttaching,
    ARTChannelEventAttached,
    ARTChannelEventDetaching,
    ARTChannelEventDetached,
    ARTChannelEventSuspended,
    ARTChannelEventFailed,
    ARTChannelEventError
};

NSString *__art_nonnull ARTChannelEventToStr(ARTChannelEvent event);

typedef NS_ENUM(NSInteger, ARTDataQueryError) {
    ARTDataQueryErrorLimit = 1,
    ARTDataQueryErrorTimestampRange = 2,
};

typedef NS_ENUM(NSInteger, ARTRealtimeHistoryError) {
    ARTRealtimeHistoryErrorNotAttached = ARTDataQueryErrorTimestampRange + 1
};

ART_ASSUME_NONNULL_BEGIN

/// Decompose API key
__GENERIC(NSArray, NSString *) *decomposeKey(NSString *key);

NSString *encodeBase64(NSString *value);
NSString *decodeBase64(NSString *base64);

uint64_t dateToMilliseconds(NSDate *date);
uint64_t timeIntervalToMilliseconds(NSTimeInterval seconds);
NSTimeInterval millisecondsToTimeInterval(uint64_t msecs);

NSString *generateNonce();

// FIXME: review
@protocol ARTCancellable
- (void)cancel;
@end

#pragma mark - ARTConnectionStateChange

@interface ARTConnectionStateChange : NSObject

- (instancetype)initWithCurrent:(ARTRealtimeConnectionState)current
                       previous:(ARTRealtimeConnectionState)previous
                         reason:(ARTErrorInfo *__art_nullable)reason;

- (instancetype)initWithCurrent:(ARTRealtimeConnectionState)current
                       previous:(ARTRealtimeConnectionState)previous
                         reason:(ARTErrorInfo *__art_nullable)reason
                        retryIn:(NSTimeInterval)retryIn;

@property (readonly, nonatomic) ARTRealtimeConnectionState current;
@property (readonly, nonatomic) ARTRealtimeConnectionState previous;
@property (readonly, nonatomic, art_nullable) ARTErrorInfo *reason;
@property (readonly, nonatomic) NSTimeInterval retryIn;

@end

#pragma mark - ARTChannelStateChange

@interface ARTChannelStateChange : NSObject

- (instancetype)initWithCurrent:(ARTChannelState)current
                       previous:(ARTChannelState)previous
                         reason:(ARTErrorInfo *__art_nullable)reason;

- (instancetype)initWithCurrent:(ARTChannelState)current
                       previous:(ARTChannelState)previous
                         reason:(ARTErrorInfo *__art_nullable)reason
                        resumed:(BOOL)resumed;

@property (readonly, nonatomic) ARTChannelState current;
@property (readonly, nonatomic) ARTChannelState previous;
@property (readonly, nonatomic, art_nullable) ARTErrorInfo *reason;
@property (readonly, nonatomic) BOOL resumed;

@end

#pragma mark - ARTJsonCompatible

@protocol ARTJsonCompatible <NSObject>
- (NSDictionary *__art_nullable)toJSON:(NSError *__art_nullable *__art_nullable)error;
@end

@interface NSString (ARTJsonCompatible) <ARTJsonCompatible>
@end

@interface NSDictionary (ARTJsonCompatible) <ARTJsonCompatible>
@end

ART_ASSUME_NONNULL_END
