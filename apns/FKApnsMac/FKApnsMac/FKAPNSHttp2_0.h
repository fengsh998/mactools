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
- (void)fk_apns:(FKAPNSHttp2_0 *)apns didFailedWithError:(NSError *)error forReqid:(NSString *)apnsid;

@end

@interface FKAPNSHttp2_0 : NSObject
///基于证书的请求方式
@property (nonatomic, strong)   __attribute__((NSObject)) SecIdentityRef                    authIdentity;
///基于JWT Token的方式,注意只有当 authIdentity 为null时token才会被使用，如果两者都存在的情况下,会被忽略
@property (nonatomic, copy)     NSString                                                    *authorization;
@property (nonatomic, weak)     id<FKAPNSHttpDelegate>                                      delegate;

///验证jwttoken 返回的是NSDictionary
-(id)jwtDecodeWithJwtString:(NSString *)jwtStr;

- (NSString *)test;

/**
 推送报文到APNS服务器

 @param payload payload
 @param token 具体推到那台机器上
 @param topic 通常这bundle id,如果是voip要记得在bundleid后加.voip
 @param priority 10立即推送,5一次性发送通知
 @param collapseid 消息合并用的id,不需要合并时nil
 @param isProduction 是否为线上环境
 @return apns-id 每推一次请求的id,返回nil说明还没有发起请求
 */
- (nullable NSString *)pushPayload:(nonnull NSDictionary *)payload
            toToken:(nonnull NSString *)token
              topic:(nullable NSString *)topic
           priority:(NSInteger)priority
         collapseId:(nullable NSString *)collapseid
       inProduction:(BOOL)isProduction;


@end

NS_ASSUME_NONNULL_END
