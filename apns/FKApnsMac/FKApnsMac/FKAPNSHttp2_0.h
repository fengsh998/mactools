//
//  FKAPNSHttp2_0.h
//  FKApnsMac
//
//  Created by fengsh on 2019/1/18.
//  Copyright © 2019年 fengsh. All rights reserved.
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FKAPNSHttp2_0;

@protocol FKAPNSHttpDelegate <NSObject>

- (void)fk_apns:(FKAPNSHttp2_0 *)apns didResponseStatus:(NSInteger)statusCode reason:(NSString *)reason forReqid:(NSString *)apnsid;
- (void)fk_apns:(FKAPNSHttp2_0 *)apns didFailedWithError:(NSError *)error;

@end

@interface FKAPNSHttp2_0 : NSObject
///身份认证
@property (nonatomic, strong)   __attribute__((NSObject)) SecIdentityRef                    authIdentity;
@property (nonatomic, weak)     id<FKAPNSHttpDelegate>                                      delegate;

///验证jwttoken 返回的是NSDictionary
-(id)jwtDecodeWithJwtString:(NSString *)jwtStr;

- (NSString *)test;

///推送消息
- (void)pushPayload:(nonnull NSDictionary *)payload
            toToken:(nonnull NSString *)token
              topic:(nullable NSString *)topic
           priority:(NSInteger)priority
         collapseId:(nullable NSString *)collapseid
       inProduction:(BOOL)isProduction;

- (void)pushPayloadJWT:(nonnull NSDictionary *)payload
            toToken:(nonnull NSString *)token
              topic:(nullable NSString *)topic
           priority:(NSInteger)priority
         collapseId:(nullable NSString *)collapseid
       inProduction:(BOOL)isProduction;
@end

NS_ASSUME_NONNULL_END
