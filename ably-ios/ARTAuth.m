//
//  ARTAuth.m
//  ably-ios
//
//  Created by Jason Choy on 08/12/2014.
//  Copyright (c) 2014 Ably. All rights reserved.
//

#import "ARTAuth.h"

#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>

#import "ARTRest.h"
#import "ARTRest+Private.h"
#import "ARTEncoder.h"
#import "ARTLog.h"
#import "ARTPayload.h"

//X7: NSArray<NSString *>
static NSArray *decomposeKey(NSString *key) {
    return [key componentsSeparatedByString:@":"];
}

@implementation ARTAuthTokenDetails

- (instancetype)initWithToken:(NSString *)token expires:(NSDate *)expires issued:(NSDate *)issued capability:(NSString *)capability clientId:(NSString *)clientId {
    if (self = [super init]) {
        _token  = [token copy];
        _expires = expires;
        _issued = issued;
        _capability = [capability copy];
        _clientId = [clientId copy];
    }
    
    return self;
}

- (instancetype)initWithToken:(NSString *)token {
    if (self = [super init]) {
        _token = [token copy];
    }
    
    return self;
}

@end

@implementation ARTAuthTokenParams

- (instancetype)init {
    if (self = [super init]) {
        _ttl = 60 * 60;
        _timestamp = [NSDate date];
        _capability = @"{ \"*\": [ \"*\" ] }"; // allow all
    }
    
    return self;
}

- (void)setTimestamp:(NSDate *)timestamp {
    if (timestamp == nil) {
        timestamp = [NSDate date];
    }
    
    _timestamp = timestamp;
}

static NSString *generateNonce() {
    // Generate two random numbers up to 8 digits long and concatenate them to produce a 16 digit random number
    NSUInteger r1 = arc4random_uniform(100000000);
    NSUInteger r2 = arc4random_uniform(100000000);
    return [NSString stringWithFormat:@"%08lu%08lu", (long)r1, (long)r2];
}

static NSString *hmacForDataAndKey(NSData *data, NSData *key) {
    const void *cKey = [key bytes];
    const void *cData = [data bytes];
    size_t keyLen = [key length];
    size_t dataLen = [data length];
    
    unsigned char hmac[CC_SHA256_DIGEST_LENGTH];
    
    CCHmac(kCCHmacAlgSHA256, cKey, keyLen, cData, dataLen, hmac);
    NSData *mac = [[NSData alloc] initWithBytes:hmac length:sizeof(hmac)];
    NSString *str = [ARTBase64PayloadEncoder toBase64:mac];
    return str;
}

- (ARTAuthTokenRequest *)sign:(NSString *)key {
    //X7: NSArray<NSString *>
    NSArray *keyComponents = decomposeKey(key);
    NSString *keyName = keyComponents[0];
    NSString *keySecret = keyComponents[1];
    NSString *nonce = generateNonce();
    
    NSString *signText = [NSString stringWithFormat:@"%@\n%lld\n%@\n%@\n%lld\n%@\n", keyName, (int64_t)(self.ttl * 1000), self.capability, self.clientId, (int64_t)(self.timestamp.timeIntervalSince1970 * 1000), nonce];
    NSString *mac = hmacForDataAndKey([signText dataUsingEncoding:NSUTF8StringEncoding], [keySecret dataUsingEncoding:NSUTF8StringEncoding]);
    
    return [[ARTAuthTokenRequest alloc] initWithTokenParams:self keyName:keyName nonce:nonce mac:mac];
}

@end

@implementation ARTAuthTokenRequest

@dynamic timestamp;

- (instancetype)initWithTokenParams:(ARTAuthTokenParams *)tokenParams keyName:(NSString *)keyName nonce:(NSString *)nonce mac:(NSString *)mac {
    if (self = [super init]) {
        self.ttl = tokenParams.ttl;
        self.capability = tokenParams.capability;
        self.clientId = tokenParams.clientId;
        self.timestamp = tokenParams.timestamp;
        _keyName = [keyName copy];
        _nonce = [nonce copy];
        _mac = [mac copy];
    }
    
    return self;
}

- (NSDictionary *)asDictionary {
    return nil;
}

@end

@implementation ARTAuthOptions

- (instancetype)initWithKey:(NSString *)key {
    self = [self init];
    if (self) {
        if (decomposeKey(key).count != 2) {
            [NSException raise:@"Invalid key" format:@"%@ should be of the form <keyName>:<keySecret>", key];
        }
        _key = [key copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    ARTAuthOptions *options = [[ARTAuthOptions allocWithZone:zone] init];
    options.key = self.key;
    options.token = self.token;
    options.useTokenAuth = self.useTokenAuth;
    options.authCallback = self.authCallback;
    options.authUrl = self.authUrl;
    options.authMethod = self.authMethod;
    options.authHeaders = self.authHeaders;
    options.authParams = self.authParams;
    options.queryTime = self.queryTime;
    
    return options;
}

- (NSString *)token {
    return self.tokenDetails.token;
}

- (void)setToken:(NSString *)token {
    self.tokenDetails = [[ARTAuthTokenDetails alloc] initWithToken:token];
}

- (void)setAuthMethod:(NSString *)authMethod {
    if (authMethod == nil) {
        authMethod = @"GET";
    }
    
    _authMethod = [authMethod copy];
}

@end

@implementation ARTAuth {
    __weak ARTRest *_rest;
}

- (instancetype)initWithRest:(ARTRest *)rest options:(ARTAuthOptions *)options {
    if (self = [super init]) {
        _rest = rest;
        _currentToken = options.tokenDetails;
        _options = options;
        _logger = rest.logger;
        
        if (options.key != nil && !options.useTokenAuth) {
            [self.logger debug:@"ARTAuth: setting up auth method Basic"];
            _authMethod = ARTAuthMethodBasic;
        } else if ([self shouldUseTokenAuth]) {
            [self.logger debug:@"ARTAuth: setting up auth method Token"];
            _authMethod = ARTAuthMethodToken;
        } else {
            [NSException raise:@"ARTAuthException" format:@"Could not setup authentication method with given options."];
        }
    }
    
    return self;
}

- (BOOL)shouldUseTokenAuth {
    return NO;
}

- (void)requestToken:(ARTAuthTokenParams *)tokenParams options:(ARTAuthOptions *)options
            callback:(void (^)(ARTAuthTokenDetails *, NSError *))callback {
    ARTAuthOptions *mergedOptions = options;
    
    if (mergedOptions.authUrl) {
        NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:mergedOptions.authUrl resolvingAgainstBaseURL:YES];
        if (mergedOptions.authParams) {
            urlComponents.queryItems = [[NSArray arrayWithArray:urlComponents.queryItems] arrayByAddingObjectsFromArray:mergedOptions.authParams];
        }
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:urlComponents.URL];
        request.HTTPMethod = mergedOptions.authMethod;
        for (NSString *key in mergedOptions.authHeaders) {
            [request setValue:mergedOptions.authHeaders[key] forHTTPHeaderField:key];
        }
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        [_rest.httpExecutor executeRequest:request callback:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
            if (error) {
                callback(nil, error);
            } else {
                // check if response is TokenRequest or TokenDetails and act accordingly
            }
        }];
    } else {
        ARTAuthCallback tokenRequestFactory = mergedOptions.authCallback ?: ^(ARTAuthTokenParams *tokenParams, void(^callback)(ARTAuthTokenRequest *tokenRequest, NSError *error)) {
            [self createTokenRequest:tokenParams options:mergedOptions callback:callback];
        };
        
        tokenRequestFactory(tokenParams, ^(ARTAuthTokenRequest *tokenRequest, NSError *error) {
            if (error) {
                callback(nil, error);
            } else {
                [self requestToken:tokenRequest callback:callback];
            }
        });
    }
}

- (void)requestToken:(ARTAuthTokenRequest *)tokenRequest callback:(void (^)(ARTAuthTokenDetails *, NSError *))callback {
    NSURL *requestUrl = [NSURL URLWithString:[NSString stringWithFormat:@"/keys/%@/requestToken", tokenRequest.keyName]
                               relativeToURL:_rest.baseUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestUrl];
    request.HTTPMethod = @"POST";
    
    id<ARTEncoder> defaultEncoder = _rest.defaultEncoder;

    request.HTTPBody = [defaultEncoder encodeTokenRequest:tokenRequest];
    [request setValue:[defaultEncoder mimeType] forHTTPHeaderField:@"Accept"];
    [request setValue:[defaultEncoder mimeType] forHTTPHeaderField:@"Content-Type"];
    
    [_rest.httpExecutor executeRequest:request callback:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
        if (error) {
            callback(nil, error);
        } else {
            callback([defaultEncoder decodeAccessToken:data], nil);
        }
    }];
}

- (void)authorise:(ARTAuthTokenParams *)tokenParams options:(ARTAuthOptions *)options force:(BOOL)force
         callback:(void (^)(ARTAuthTokenDetails *, NSError *))callback {
    if (!force && self.currentToken && [self.currentToken.expires timeIntervalSinceNow] > 0) {
        [self.logger verbose:@"ARTAuth authorise not forced and current token is not expired yet, reuse current token."];
        callback(self.currentToken, nil);
    } else {
        [self.logger verbose:@"ARTAuth authorise requesting new token."];
        [self requestToken:tokenParams options:options callback:^(ARTAuthTokenDetails *tokenDetails, NSError *error) {
            if (error) {
                callback(nil, error);
            } else {
                _currentToken = tokenDetails;
                _authMethod = ARTAuthMethodToken;
                callback(tokenDetails, nil);
            }
        }];
    }
}

- (void)createTokenRequest:(ARTAuthTokenParams *)tokenParams options:(ARTAuthOptions *)options callback:(void (^)(ARTAuthTokenRequest *, NSError *))callback {
    ARTAuthOptions *mergedOptions = options;
    if (mergedOptions.queryTime) {
        ARTAuthTokenParams *newParams = [[ARTAuthTokenParams alloc] init];
        newParams.ttl = tokenParams.ttl;
        newParams.capability = tokenParams.capability;
        newParams.clientId = tokenParams.clientId;
        [_rest time:^(NSDate *time, NSError *error) {
            if (error) {
                callback(nil, error);
            } else {
                newParams.timestamp = time;
                callback([newParams sign:mergedOptions.key], nil);
            }
        }];
    } else {
        callback([tokenParams sign:mergedOptions.key], nil);
    }
}

- (BOOL)canRequestToken {
    if (self.options.authCallback) {
        [self.logger verbose:@"ARTAuth can request token via authCb"];
        return YES;
    } else if (self.options.authUrl) {
        [self.logger verbose:@"ARTAuth can request token via authURL"];
        return YES;
    } else if (self.options.key) {
        [self.logger verbose:@"ARTAuth can request token via key"];
        return YES;
    } else {
        [self.logger error:@"ARTAuth cannot request token"];
        return NO;
    }
}

@end
