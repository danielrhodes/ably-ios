//
//  NSObject+TestSuite.m
//  ably
//
//  Created by Ricardo Pereira on 08/02/16.
//  Copyright © 2016 Ably. All rights reserved.
//

#import "NSObject+TestSuite.h"
#import <Aspects/Aspects.h>

@implementation NSObject (TestSuite)

- (id<AspectToken>)testSuite_getReturnValueFrom:(SEL)selector callback:(void (^)(id))callback {
    return [self aspect_hookSelector:selector withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info) {
        __autoreleasing id result;
        [[info originalInvocation] getReturnValue:&result];
        callback([result copy]);
    } error:nil];
}

- (void)testSuite_getArgumentFrom:(SEL)selector atIndex:(NSInteger)index callback:(void (^)(id))callback {
    [self aspect_hookSelector:selector withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info) {
        __autoreleasing id arg;
        [[info originalInvocation] getArgument:&arg atIndex:2+index];
        callback([arg copy]);
    } error:nil];
}

- (id<AspectToken>)testSuite_injectIntoMethodBefore:(SEL)selector code:(void (^)(void))block {
    return [self aspect_hookSelector:selector withOptions:AspectPositionBefore usingBlock:^(id<AspectInfo> info) {
        block();
    } error:nil];
}

- (id<AspectToken>)testSuite_injectIntoMethodAfter:(SEL)selector code:(void (^)(void))block {
    return [self aspect_hookSelector:selector withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info) {
        block();
    } error:nil];
}

@end
