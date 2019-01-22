//
//  FKAPNSHttp2_0.m
//  FKApnsMac
//
//  Created by fengsh on 2019/1/18.
//  Copyright © 2019年 fengsh. All rights reserved.
//
/*
    Provider 为后台或本类实现
    1.基于证书的方式
         a)Provider通过TLS向APNs请求连接。
         b)APNs向Provider返回一个APNs证书。
         c)Provider验证这个APNs证书，并将从苹果官网获取的证书返回给APNs。
         d)APNs验证通过后，这个链接就算是建立了。
    2.基于Token的方式 token的最大有效期为1小时，并且不能频繁更换token。
         a)Provider通过TLS向APNs发起请求。
         b)APNs返回一个证书给Provider。
         c)Provier验证这个证书。通过后，发送push数据并带上JWT token。
         d)APNs验证token，并返回请求的结果。
 
    TLS 的建立
    建立TLS连接必须要有一个GeoTrust Global CA root certificate，在macOS中，这个证书已经安装在keychain中，
    如果是其他操作系统则可以在https://www.geotrust.com/resources/root-certificates/下载。
 
    使用https /2 进行推送,(注意：APNs只支持ES256签名的JWT，否则会返回InvalidProviderToken(403)错误)
    POST
    host      api.development.push.apple.com    开发环境
              api.push.apple.com                生产环境
    path      /3/device/<device-token>
 
    http request headers  如下:
    authorization       提供的发送到指定（app）主题通知的APNs验证token，token是以Base64 URL编码的JWT(JSON Web Token)格式。指定为bearer <provider token>
                        当使用证书连接的时候，这个请求头将会被忽略;JWT(https://tools.ietf.org/html/rfc7519):
                        kid:登入苹果开发者账号后，进入到Certificates, Identifiers & Profiles，然后点击APNs Auth Key，最后在右侧找到
                            Apple Push Notification Authentication Key (Sandbox & Production)选项，点击创建后可以创建一个p8文件。）
 
                         {
                            "alg": "ES256",                 //用以加密token的加密算法(alg) ，比如：ES256
                            "kid": "ABC123DEFG"             //10个字符长度的标识符(kid)，（苹果开发者网站创建的APNs Auth Key详情中的key id）
                         }
                         {                                  //同时他的claims payload部分必须包含
                            "iss": "DEF123GHIJ",            //issuer(iss) registered claim key，其值就是10个字符长的Team ID,从账号里找到Membership 里找到
                            "iat": 1437179036               //issued at (iat) registered claim key，其值是一个秒级的UTC时间戳
                         }
 
    apns-id             一个规范的的 UUID 用来标识通知。如果发送通知时发生错误，APNs 使用此值来标识通知，通知到您的服务器。
                        规范的格式是 32 个小写的十六进制数字，由连字符分隔为5，8-4-4-4-12。UUID一个例子如下：
                        123e4567-e89b-12d3-a456-42665544000
                        如果您省略这个头,一个新的UUID由APNs创建并且在response中返回
 
    apns-expiration     通知过期时间，秒级的UTC时间戳，这个header标识通知 从何时起不再有效，可以丢弃。
                        如果这个值非零，APNs保存通知并且尽量至少送达一次。如果无法第一时间送达，根据需要重复尝试。
                        如果这个值为0，APNs认为通知立即过期，不会存储与重新推送。
 
    apns-priority       通知的优先级，指定以下值:
                            10 立即推送消息. 这个优先级的通知必须再目标设备上触发alert, 声音, 或者badge . 仅仅包含content-available key使用此优先级是错误的。
                            5  一次性发送通知，需要考虑设备的电量。具有此优先级的通知可能分组推送并且几种爆发推送
                            Notifications with this priority might be grouped and delivered他们会被节流，并且在某些情况下不会送达。
                        如果省略这个头，APNs服务器会把优先级设置为10
 
    apns-topic          (使用JWT时一定要带)远程通知的主题，通常是你App的bundle id，在开发者账号中创建的证书必须包含此bundle id
                        如果证书包含多个主题，这个头必须指定一个值
                        如果省略此头并且APNs证书不包含指定的主题，APNs服务器使用证书的Subject作为默认主题。
                        如果使用token代替证书，必须指定此头，提供的主题应该被在开发者账号中的team提供。即bundle id的app应该与auth key同属于一个开发者组。
 
                        如果是voip时，需要在bundleid 后面加上.voip
 
    apns-collapse-id    具有相同的折叠标识符的多个通知推送给用户合并显示为单个通知。比如： apns-collapse-id : 2 ，那么value为2的消息将被APNS合并成一条消息推送给设备。
                        此关键字的值不能超过 64 个字节。
 
    http reqeust body 如下:
                        body内容是将要推送的消息负载的JSON对象。body数据不必须压缩，其最大大小为 4 KB （4096 字节）。
                        对于 (VoIP) 通知，body数据最大大小为 5 KB （5120 字节）。
    payload :https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/PayloadKeyReference.html#//apple_ref/doc/uid/TP40008194-CH17-SW1
 
    http Response headers 如下 :
        apns-id         apns-id从request得到， 如果request中没有此值, APNs服务器创建一个新的UUID并且在header中返回
        status          HTTP状态码，HTTP status code.可能status codes
 
             200    成功
             400    无效请求
             403    证书错误或者验证token错误
             405    :method 设置错误. 只支持 POST 请求
             410    device token不在有效与topic
             413    负载payload太大
             429    服务端对于同一个device token发送了太多了请求
             500    内部服务器错误
             503    服务器关闭,不可用
 
 
 基于证书的方式的request: 非json类型请求
 
 HEADERS
    apns-id = eabeae54-14a8-11e5-b60b-1697f925ec7b //可以不填，如果不填APNs会自己创建一个UUID并在response中返回
    apns-expiration = 0
    apns-priority = 10
 DATA
    { "aps" : { "alert" : "Hello" } }
 
 
 基于token方式的request:
 官方文档:https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html
 HEADERS
    authorization = bearer eyAia2lkIjogIjhZTDNHM1JSWDciIH0.eyAiaXNzIjogIkM4Nk5WOUpYM0QiLCAiaWF0I
            jogIjE0NTkxNDM1ODA2NTAiIH0.MEYCIQDzqyahmH1rz1s-LFNkylXEa2lZ_aOCX4daxxTZkVEGzwIhALvkClnx5m5eAT6
            Lxw7LZtEQcH6JENhJTMArwLf3sXwi
    apns-id = eabeae54-14a8-11e5-b60b-1697f925ec7b
    apns-expiration = 0
    apns-priority = 10
    apns-topic = <MyAppTopic>
 DATA
    { "aps" : { "alert" : "Hello" } }

 
 两种方式的响应:
 失败:
 HEADERS
    :status = 400
    content-type = application/json
    apns-id: <a_UUID>
 DATA
    { "reason" : "BadDeviceToken" }
 
 成功:
 HEADERS
 apns-id = eabeae54-14a8-11e5-b60b-1697f925ec7b
 :status = 200
 
 
    JWT token 包含三部分 head.payload.Signature 库 ：https://jwt.io
    每部分base64urlencode
 
 eg:
     header :
         {
         "alg": "ES256",                 //用以加密token的加密算法(alg) ，比如：ES256
         "kid": "ABC123DEFG"             //10个字符长度的标识符(kid)，（苹果开发者网站创建的APNs Auth Key详情中的key id）
         }
     payload(claims) :
         {                                  //同时他的claims payload部分必须包含
         "iss": "DEF123GHIJ",            //issuer(iss) registered claim key，其值就是10个字符长的Team ID,从账号里找到Membership 里找到
         "iat": 1437179036               //issued at (iat) registered claim key，其值是一个秒级的UTC时间戳
         }
    Signature :
       使用的是header中alg算法将 base64UrlEncode(Header) + "." + base64UrlEncode(Claims) 的字符串进行加密得到的结果。
 */

#import "FKAPNSHttp2_0.h"
#import <Security/Security.h>
#import "APNSSecIdentityType.h"
#import <JWT/JWT.h>

@interface FKAPNSHttp2_0 () <NSURLSessionDelegate>
@property (nonatomic, strong) NSURLSession          *session;

@end

@implementation FKAPNSHttp2_0

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:config
                                                     delegate:self
                                                delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}

- (void)setAuthIdentity:(SecIdentityRef)authIdentity
{
    if (_authIdentity != authIdentity) {
        if (_authIdentity) {
            CFRelease(_authIdentity);
        }
        if (authIdentity) {
            _authIdentity = (SecIdentityRef)CFRetain(authIdentity);
        } else {
            _authIdentity = authIdentity;//NULL
        }
    }
}

- (NSString *)getUUID
{
    CFUUIDRef puuid = CFUUIDCreate( nil );
    CFStringRef uuidString = CFUUIDCreateString(nil, puuid);
    NSString *result = (NSString *)CFBridgingRelease(CFStringCreateCopy( NULL, uuidString));
    return result;
}

- (NSString *)pushPayload:(nonnull NSDictionary *)payload
                  toToken:(nonnull NSString *)token
                    topic:(nullable NSString *)topic
                 priority:(NSInteger)priority
               collapseId:(nullable NSString *)collapseid
             inProduction:(BOOL)isProduction
{
    NSAssert(_authIdentity || _authorization, @"证书和Jwt Token都为空!两者必须选择一种！");
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api%@.push.apple.com/3/device/%@", isProduction ? @"" : @".development", token]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    request.HTTPMethod = @"POST";
    
    NSError *err = nil;
    NSString *apnsid = [self getUUID];
    ///请求body
    NSData *body = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&err];
    
    if (err) {
        NSString * errmsg = [NSString stringWithFormat:@"Push Request body Error: %@",err.localizedDescription];
        NSError *bodyjsonerror = [NSError errorWithDomain:@"com.fsh.apns.errdomain" code:err.code userInfo:@{NSLocalizedDescriptionKey:errmsg}];
        if ([self.delegate respondsToSelector:@selector(fk_apns:didFailedWithError:forReqid:)]) {
            [self.delegate fk_apns:self didFailedWithError:bodyjsonerror forReqid:apnsid];
        }
        return apnsid;
    }
    
    request.HTTPBody = body;
    
    ///请求头
    if (topic) {
        [request addValue:topic forHTTPHeaderField:@"apns-topic"];
    }
    
    if (collapseid.length > 0) {
        [request addValue:collapseid forHTTPHeaderField:@"apns-collapse-id"];
    }
    
    [request addValue:[NSString stringWithFormat:@"%lu", (unsigned long)priority] forHTTPHeaderField:@"apns-priority"];
    
    // apns-expiration
    // apns-id
    [request addValue:apnsid forHTTPHeaderField:@"apns-id"];
    
    ///如果有authIdentity证书，则这个字段被忽略
    NSString *authorization = self.authorization;
    if (authorization) {
        authorization = [NSString stringWithFormat:@"bearer %@",authorization];
        [request addValue:authorization forHTTPHeaderField:@"authorization"];
    }
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
        NSString *apnsid_resp = r.allHeaderFields[@"apns-id"];
        
        if (r == nil && error) {
            if ([self.delegate respondsToSelector:@selector(fk_apns:didFailedWithError:forReqid:)]) {
                [self.delegate fk_apns:self didFailedWithError:error forReqid:apnsid];
            }
            return;
        }
        
        if (r.statusCode != 200 && data) { //响应error
            NSError *error = nil;
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                if ([self.delegate respondsToSelector:@selector(fk_apns:didFailedWithError:forReqid:)]) {
                    [self.delegate fk_apns:self didFailedWithError:error forReqid:apnsid];
                }
                return;
            }
            
            NSString *reason = dict[@"reason"];
            if ([self.delegate respondsToSelector:@selector(fk_apns:didResponseStatus:reason:forReqid:)]) {
                [self.delegate fk_apns:self didResponseStatus:r.statusCode reason:reason forReqid:apnsid_resp];
            }
        } else if (r.statusCode == 200) {
            if ([self.delegate respondsToSelector:@selector(fk_apns:didResponseStatus:reason:forReqid:)]) {
                [self.delegate fk_apns:self didResponseStatus:r.statusCode reason:@"push success!" forReqid:apnsid_resp];
            }
        }
    }];
    [task resume];
    
    return apnsid;
}

#pragma mark - NSURLSessionDelegate
///TLS
- (void)URLSession:(NSURLSession *)session task:(nonnull NSURLSessionTask *)task didReceiveChallenge:(nonnull NSURLAuthenticationChallenge *)challenge completionHandler:(nonnull void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    
    if (self.authIdentity) {
        SecCertificateRef certificate;

        SecIdentityCopyCertificate(self.authIdentity, &certificate);

        NSURLCredential *cred = [[NSURLCredential alloc] initWithIdentity:self.authIdentity
                                                             certificates:@[(__bridge_transfer id)certificate]
                                                              persistence:NSURLCredentialPersistenceForSession];

        completionHandler(NSURLSessionAuthChallengeUseCredential, cred);
    } else { //没设证书的时候走jwt token request
        NSURLCredential *card = [[NSURLCredential alloc]initWithTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential , card);
    }
}

/*
- (void)pushPayloadJWT:(nonnull NSDictionary *)payload
               toToken:(nonnull NSString *)token
                 topic:(nullable NSString *)topic
              priority:(NSInteger)priority
            collapseId:(nullable NSString *)collapseid
          inProduction:(BOOL)isProduction
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api%@.push.apple.com/3/device/%@", isProduction ? @"" : @".development", token]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    request.HTTPMethod = @"POST";
    
    NSError *err = nil;
    
    ///请求body
    NSData *body = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&err];
    
    if (err) {
        NSString * errmsg = [NSString stringWithFormat:@"Push Request body Error: %@",err.localizedDescription];
        NSError *bodyjsonerror = [NSError errorWithDomain:@"com.fsh.apns.errdomain" code:err.code userInfo:@{NSLocalizedDescriptionKey:errmsg}];
        if ([self.delegate respondsToSelector:@selector(fk_apns:didFailedWithError:)]) {
            [self.delegate fk_apns:self didFailedWithError:bodyjsonerror];
        }
        return;
    }
    
    request.HTTPBody = body;
    
    ///请求头
    if (topic) {
        [request addValue:topic forHTTPHeaderField:@"apns-topic"];
    }
    
    NSString *authorization = @"eyJhbGciOiJFUzI1NiIsImtpZCI6IkhCNVpYWDdNWVEifQ.eyJpc3MiOiJYVVVZRUI5N1oyIiwiaWF0IjoxNTQ4MDY4NzgxLCJleHAiOjE1NDgwNzIzODF9.cwljudPfZxkOOPFF3esj-mxqWuSCvWhh6481Gk4l1I16-Mj0Xb2OENB-krXazRHikSY5cdpn-XyGBwDxSeMPaA";//[self test];
    if (authorization) {
        authorization = [NSString stringWithFormat:@"bearer %@",authorization];
        [request addValue:authorization forHTTPHeaderField:@"authorization"];
    }
    
    if (collapseid.length > 0) {
        [request addValue:collapseid forHTTPHeaderField:@"apns-collapse-id"];
    }
    
    [request addValue:[NSString stringWithFormat:@"%lu", (unsigned long)priority] forHTTPHeaderField:@"apns-priority"];
    
    // apns-expiration
    // apns-id
    
    NSLog(@"request headers = %@",request.allHTTPHeaderFields);
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSHTTPURLResponse *r = (NSHTTPURLResponse *)response;
        NSString *apnsid_resp = r.allHeaderFields[@"apns-id"];
        
        if (r == nil && error) {
            if ([self.delegate respondsToSelector:@selector(fk_apns:didFailedWithError:)]) {
                [self.delegate fk_apns:self didFailedWithError:error];
            }
            return;
        }
        
        if (r.statusCode != 200 && data) { //响应error
            NSError *error = nil;
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                if ([self.delegate respondsToSelector:@selector(fk_apns:didFailedWithError:)]) {
                    [self.delegate fk_apns:self didFailedWithError:error];
                }
                return;
            }
            
            NSString *reason = dict[@"reason"];
            if ([self.delegate respondsToSelector:@selector(fk_apns:didResponseStatus:reason:forReqid:)]) {
                [self.delegate fk_apns:self didResponseStatus:r.statusCode reason:reason forReqid:apnsid_resp];
            }
        } else if (r.statusCode == 200) {
            if ([self.delegate respondsToSelector:@selector(fk_apns:didResponseStatus:reason:forReqid:)]) {
                [self.delegate fk_apns:self didResponseStatus:r.statusCode reason:@"push success!" forReqid:apnsid_resp];
            }
        }
    }];
    [task resume];
}
*/

//- (void)tttt
//{
//    NSString *key = @"MHcCAQEEIJmVse5uPfj6B4TcXrUAvf9/8pJh+KrKKYLNcmOnp/vPoAoGCCqGSM49AwEHoUQDQgAEAr+WbDE5VtIDGhtYMxvEc6cMsDBc/DX1wuhIMu8dQzOLSt0tpqK9MVfXbVfrKdayVFgoWzs8MilcYq0QIhKx/w==";
//
//    NSData *data = [JWTBase64Coder dataWithBase64UrlEncodedString:key];
//    NSString *keyClass = (__bridge NSString *)kSecAttrKeyClassPrivate;
//    NSString *type = (__bridge NSString *)kSecAttrKeyTypeECSECPrimeRandom;
//    NSInteger sizeInBits = 256;//data.length * [JWTMemoryLayout createWithType:[JWTMemoryLayout typeUInt8]].size;
//    NSDictionary *attributes = @{
//                                 (__bridge NSString*)kSecAttrKeyType : type,
//                                 (__bridge NSString*)kSecAttrKeyClass : keyClass,
//                                 (__bridge NSString*)kSecAttrKeySizeInBits : @(sizeInBits)
//                                 };
//
//
//    if (SecKeyCreateWithData != NULL) {
//        CFErrorRef createError = NULL;
//        SecKeyRef key = SecKeyCreateWithData((__bridge CFDataRef)data, (__bridge CFDictionaryRef)attributes, &createError);
//        if (createError != NULL) {
//            (__bridge NSError*)createError;
//        }
//
//    }
//
//}

//- (void)signWithAppleAPNS
//{
//    NSString *algorithmName = @"ES256";
//    NSString *privateKey = @"-----BEGIN PRIVATE KEY-----\n"
//"MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgpnX9ZXmgLCWQ+Hkpvae2PLU68XEzJdp+NjswuBS9RHWgCgYIKoZIzj0DAQehRANCAARMSO6bkKjLT+9Mx9wJRXoqUx+CbeOhAbVGS+3fgvVNGv3QM3NlMou3uguMrITwVvpWjuocXbSzjTwMstMMjsZg\n"
//    "-----END PRIVATE KEY-----";
//
//    id <JWTAlgorithmDataHolderProtocol> signDataHolder = [JWTAlgorithmRSFamilyDataHolder new]
//    .keyExtractorType([JWTCryptoKeyExtractor privateKeyWithPEMBase64].type)
//    .algorithmName(algorithmName)
//    .secret(privateKey);
//
//
//    // sign
//    NSDictionary *payloadDictionary = @{ @"hello": @"world" };
//
//    JWTCodingBuilder *signBuilder = [JWTEncodingBuilder encodePayload:payloadDictionary].addHolder(signDataHolder);
//    JWTCodingResultType *signResult = signBuilder.result;
//    NSString *token = nil;
//    if (signResult.successResult) {
//        // success
//        NSLog(@"%@ success: %@", self.debugDescription, signResult.successResult.encoded);
//        token = signResult.successResult.encoded;
//    } else {
//        // error
//        NSLog(@"%@ error: %@", self.debugDescription, signResult.errorResult.error);
//    }
//
//    // verify
//    if (token == nil) {
//        NSLog(@"something wrong");
//    }
//}

//- (NSString *)test
//{
////    FKJwt *jj = [[FKJwt alloc]init];
//
//    [self tttt];
////    NSString *path = [[NSBundle mainBundle]pathForResource:@"HB5ZXX7MYQ" ofType:@"p8"];
//    NSString *path = [[NSBundle mainBundle]pathForResource:@"test_private" ofType:@"txt"];
//    NSData *pk = [NSData dataWithContentsOfFile:path];
//
//    NSString *pks = [[NSString alloc]initWithData:pk encoding:NSUTF8StringEncoding];
//
//    NSString *privateKeyString = pks;//@"<ANSI X9.63 formatted key>";
//    NSString *publicKeyString = @"<ANSI X9.63 formatted key>";
//
//    // Note: We should pass type of key. Default type is RSA.
//    NSDictionary *parameters = @{JWTCryptoKey.parametersKeyBuilder : JWTCryptoKeyBuilder.new.keyTypeEC};
//
//    NSError *error = nil;
//
//    id <JWTCryptoKeyProtocol> privateKey = [[JWTCryptoKeyPrivate alloc] initWithPemEncoded:privateKeyString parameters:parameters error:&error];
//
//    id <JWTCryptoKeyProtocol> publicKey = [[JWTCryptoKeyPublic alloc] initWithPemEncoded:publicKeyString parameters:parameters error:nil];
//
//    // Note: JWTAlgorithmRSFamilyDataHolder will be renamed to something more appropriate. It can holds any asymmetric keys pair (private and public).
//    id <JWTAlgorithmDataHolderProtocol> holder = [JWTAlgorithmRSFamilyDataHolder new].signKey(privateKey).verifyKey(publicKey).algorithmName(JWTAlgorithmNameES256);
//
//
//    return nil;
//
//    NSArray *items = [self authkey];
//    NSMutableArray *ss = [NSMutableArray array];
//    for (NSDictionary *item in items) {
//        NSData *dt = [NSJSONSerialization dataWithJSONObject:item options:0 error:nil];
//        NSString *s1 = [JWTBase64Coder base64UrlEncodedStringWithData:dt];
//        [ss addObject:s1];
//    }
//
//    NSString *part1 = [ss componentsJoinedByString:@"."];
//
//    ///ES256
//    id<JWTAlgorithm> algorithm = [JWTAlgorithmFactory algorithmByName:JWTAlgorithmNameES256];
//    NSString *sec = [self secret];
//
//    NSData *a = [part1 dataUsingEncoding:NSUTF8StringEncoding];
//    NSData *b = [sec dataUsingEncoding:NSUTF8StringEncoding];
//    NSError *err = nil;
//
////    JWTAlgorithmAsymmetricBase *jjj = algorithm;
////
////    id <JWTAlgorithmDataHolderProtocol> firstHolder = [JWTAlgorithmHSFamilyDataHolder new].algorithmName(JWTAlgorithmNameES256).secret(sec);
////    jjj.signKey = firstHolder;
////    NSData *part3dt = [jjj signHash:a key:b error:&err];
//    NSData *part3dt = [algorithm encodePayloadData:a withSecret:b];
//    NSString *part3 = [JWTBase64Coder base64UrlEncodedStringWithData:part3dt];
//
////    JWTBuilder en
//
//
//    return [NSString stringWithFormat:@"%@.%@",part1,part3];
//}
//
//- (NSArray *)authkey
//{
//    NSTimeInterval t = [[NSDate date]timeIntervalSince1970]*1000;
////    NSString *timeString = [NSString stringWithFormat:@"%0.f", t];
//    NSUInteger unixtime = (NSUInteger)t;
//
//
//    return @[
//             @{@"alg": @"ES256",@"kid": @"HB5ZXX7MYQ",@"typ":@"JWT"},
//            @{@"iss": @"XUUYEB97Z2",@"iat": @(unixtime)}
//             ];
//}

-(id)jwtDecodeWithJwtString:(NSString *)jwtStr
{
    NSArray * segments = [jwtStr componentsSeparatedByString:@"."];
    //解后面部份
    NSString * base64String = [segments objectAtIndex:1];
    
    int requiredLength = (int)(4 *ceil((float)[base64String length]/4.0));
    int nbrPaddings = requiredLength - (int)[base64String length];
    if(nbrPaddings > 0){
        NSString * pading = [[NSString string] stringByPaddingToLength:nbrPaddings withString:@"=" startingAtIndex:0];
        base64String = [base64String stringByAppendingString:pading];
    }
    base64String = [base64String stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    NSData * decodeData = [[NSData alloc] initWithBase64EncodedData:[base64String dataUsingEncoding:NSUTF8StringEncoding] options:0];
    NSString * decodeString = [[NSString alloc] initWithData:decodeData encoding:NSUTF8StringEncoding];
    NSDictionary * jsonDict = [NSJSONSerialization JSONObjectWithData:[decodeString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    
    
    return jsonDict;
}




/*


-(NSData*) SHA256withECDSA_JWT:(NSString*)privateKeyPEM and:(NSData*)dataToSign
{
    char *pemC = (char*)[privateKeyPEM cStringUsingEncoding:NSASCIIStringEncoding];
    
    EC_KEY *privEC;
    privEC = readPrivatePemToEC(pemC);
    
    NSMutableData *digest = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(dataToSign.bytes, (unsigned int)dataToSign.length, digest.mutableBytes);
    
    ECDSA_SIG *signature;
    signature = ECDSA_do_sign(digest.bytes, (unsigned int)digest.length, privEC);
    
    int signatureLength = i2d_ECDSA_SIG(signature, NULL);
    NSMutableData *derSignature = [[NSMutableData alloc] initWithLength:signatureLength];
    uint8_t *signatureBytes2 = derSignature.mutableBytes;
    i2d_ECDSA_SIG(signature, &signatureBytes2);
    
    const unsigned char* signatureBytes = [derSignature bytes];
    
    if (derSignature.length < 8 || signatureBytes[0] != (uint8_t)0x30) {
        //assert!
    }
    
    int offset;
    if (signatureBytes[1] > 0) {
        offset = 2;
    } else if (signatureBytes[1] == (uint8_t) 0x81) {
        offset = 3;
    } else {
        //assert!
    }
    
    int rLength = signatureBytes[offset + 1];
    
    int i = rLength;
    while ((i > 0) && (signatureBytes[(offset + 2 + rLength) - i] == 0))
        i--;
    
    int sLength = signatureBytes[offset + 2 + rLength + 1];
    
    int j = sLength;
    while ((j > 0) && (signatureBytes[(offset + 2 + rLength + 2 + sLength) - j] == 0))
        j--;
    
    int rawLen = MAX(i, j);
    rawLen = MAX(rawLen, 64 / 2);
    
    if ((signatureBytes[offset - 1] & 0xff) != derSignature.length - offset
        || (signatureBytes[offset - 1] & 0xff) != 2 + rLength + 2 + sLength
        || signatureBytes[offset] != 2
        || signatureBytes[offset + 2 + rLength] != 2) {
        //assert!
    }
    
    NSMutableData *concatSignature = [[NSMutableData alloc] initWithCapacity:2 * rawLen];
    
    [concatSignature replaceBytesInRange:NSMakeRange(rawLen - i, i) withBytes:(signatureBytes + (offset + 2 + rLength) - i)];
    [concatSignature replaceBytesInRange:NSMakeRange(2 * rawLen - j, j) withBytes:(signatureBytes + (offset + 2 + rLength + 2 + sLength) - j)];
    
    EC_KEY_free(privEC);
    ECDSA_SIG_free(signature);
    
    return concatSignature;
}


- (void)mmmmmm
{
    NSMutableDictionary *dicPayload = [[NSMutableDictionary alloc] init];
    //dicPayload all useful info goes in here
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dicPayload options:0 error:&error];
    
    NSString *payloadBase64 = [jsonData base64EncodedStringWithOptions:0];
    payloadBase64 = [payloadBase64 stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    payloadBase64 = [payloadBase64 stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    payloadBase64 = [payloadBase64 stringByReplacingOccurrencesOfString:@"=" withString:@""];
    
    NSMutableDictionary *dicHeader = [[NSMutableDictionary alloc] init];
    
    [dicHeader setObject:@"ES256" forKey:@"alg"];
    jsonData = [NSJSONSerialization dataWithJSONObject:dicHeader options:0 error:&error];
    NSString *headerBase64 = [jsonData base64EncodedStringWithOptions:0];
    headerBase64 = [headerBase64 stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    headerBase64 = [headerBase64 stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    headerBase64 = [headerBase64 stringByReplacingOccurrencesOfString:@"=" withString:@""];
    
    NSString *toSignStr = [NSString stringWithFormat:@"%@.%@",headerBase64,payloadBase64];
    NSData *toSignDat = [toSignStr dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *signedHash = [self SHA256withECDSA_JWT:privateKeyPEM and:toSignDat];
    NSString *signedHashBase64 = [signedHash base64EncodedStringWithOptions:0];
    signedHashBase64 = [signedHashBase64 stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    signedHashBase64 = [signedHashBase64 stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    signedHashBase64 = [signedHashBase64 stringByReplacingOccurrencesOfString:@"=" withString:@""];
    
    JWTtoken = [NSString stringWithFormat:@"%@.%@.%@",headerBase64,payloadBase64,signedHashBase64];
}

*/


@end
