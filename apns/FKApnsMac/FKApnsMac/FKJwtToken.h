//
//  FKJwtToken.h
//  FKApnsMac
//
//  Created by fengsh on 2019/1/22.
//  Copyright © 2019年 fengsh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FKJwtToken : NSObject

///将json对象转字符串后进行base64 coding
+ (NSString *)fk_jwtBase64UrlEncodeJson:(NSDictionary *)json;
/*
 取出key。入参的时候可以带BEGIN .. 也可以直接是key。
 移除 -----BEGIN PRIVATE KEY----- -----END PRIVATE KEY-----及\n
 eg:
 -----BEGIN PRIVATE KEY-----
 MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg/HA2HPrA6ohj+q9l
 0RtdOuzzBd/rYeQturbRTIP+D7agCgYIKoZIzj0DAQehRANCAATMl0JFThE0xFxJ
 ZdlV8A0UXcgg4QVbdgI62E91QWTr5YktHgvGyzw6RGfwF19Ucy+zS0zdaKDO2wgG
 WsAfNqFQ
 -----END PRIVATE KEY-----
 */
+ (NSString *)fk_jwtSecertFromPrivateKey:(NSString *)key;

/**
 实例化

 @param teamid 企业开发者账号中membership中的team id
 @param kid 企业开发者账号中，证书里创建的auth keys 中具体对应的keyid
 @param duration 过期时效(单位秒)，官网是一小时，一小时内不建议频繁生成token校验。0 时默认1小时,60*60
 @return 实例
 */
- (instancetype)initWithTeamId:(nonnull NSString *)teamid Keyid:(nonnull NSString *)kid expireDuration:(NSUInteger)duration;

- (NSString *)fk_jwtHeaderString;
- (NSString *)fk_jwtPayloadString;

///通过p8文件生成token
- (NSString *)fk_jwtGenerateTokenWithP8File:(NSString *)filepath;

/**
 通过私有key加密得到token,其实p8中的内容就是私key

 @param privatekey ANSI 9.63格式的私钥
 @return token, nil 失败
 
 eg:
 -----BEGIN PRIVATE KEY-----
 MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg/HA2HPrA6ohj+q9l
 0RtdOuzzBd/rYeQturbRTIP+D7agCgYIKoZIzj0DAQehRANCAATMl0JFThE0xFxJ
 ZdlV8A0UXcgg4QVbdgI62E91QWTr5YktHgvGyzw6RGfwF19Ucy+zS0zdaKDO2wgG
 WsAfNqFQ
 -----END PRIVATE KEY-----
 */
- (NSString *)fk_jwtGenerateTokenWithPrivateKey:(NSString *)privatekey;

@end

NS_ASSUME_NONNULL_END
