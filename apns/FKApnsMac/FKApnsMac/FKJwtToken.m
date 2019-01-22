//
//  FKJwtToken.m
//  FKApnsMac
//
//  Created by fengsh on 2019/1/22.
//  Copyright © 2019年 fengsh. All rights reserved.
//

/*
 + (void)test
 {
 NSString *pkey = @"-----BEGIN PRIVATE KEY-----\n"
 "MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg/HA2HPrA6ohj+q9l\n"
 "0RtdOuzzBd/rYeQturbRTIP+D7agCgYIKoZIzj0DAQehRANCAATMl0JFThE0xFxJ\n"
 "ZdlV8A0UXcgg4QVbdgI62E91QWTr5YktHgvGyzw6RGfwF19Ucy+zS0zdaKDO2wgG\n"
 "WsAfNqFQ\n"
 "-----END PRIVATE KEY-----";
 
 pkey = @"MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg/HA2HPrA6ohj+q9l"
 "0RtdOuzzBd/rYeQturbRTIP+D7agCgYIKoZIzj0DAQehRANCAATMl0JFThE0xFxJ"
 "ZdlV8A0UXcgg4QVbdgI62E91QWTr5YktHgvGyzw6RGfwF19Ucy+zS0zdaKDO2wgG"
 "WsAfNqFQ";
 
 [[self class]fk_jwtSecertFromPrivateKey:pkey];
 }
 */

#import "FKJwtToken.h"
#import <JWT/JWT.h>

@interface FKJwtToken ()
@property (nonatomic, copy) NSString                        *teamid;
@property (nonatomic, copy) NSString                        *keyid;
@property (nonatomic, assign) NSUInteger                    expireduration;

@end

@implementation FKJwtToken

+ (NSString *)fk_jwtBase64UrlEncodeJson:(NSDictionary *)json
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:0 error:&error];
    if (error)
    {
        NSLog(@"json object serialization error : %@",error);
        return nil;
    }

    NSString *base64string = [jsonData base64EncodedStringWithOptions:0];
    base64string = [base64string stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    base64string = [base64string stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    base64string = [base64string stringByReplacingOccurrencesOfString:@"=" withString:@""];
    
    return base64string;
}

+ (NSString *)fk_jwtSecertFromPrivateKey:(NSString *)key
{
    NSArray *parts = [key componentsSeparatedByString:@"\n"];
    NSString *regex = @"^-----.+";//以-----开头的过滤掉
    NSPredicate *pre = [NSPredicate predicateWithFormat:@"NOT (SELF MATCHES %@)",regex];
    parts = [parts filteredArrayUsingPredicate:pre];
    
    return [parts componentsJoinedByString:@""];
}

- (instancetype)init
{
    NSAssert(NO, @"please use initWithTeamId:Keyid:expireDuration: initizalition!");
    return nil;
}

- (instancetype)initWithTeamId:(NSString *)teamid Keyid:(NSString *)kid expireDuration:(NSUInteger)duration
{
    self = [super init];
    if (self) {
        _teamid = teamid;
        _keyid = kid;
        _expireduration = duration == 0 ? 60 * 60 : duration;
    }
    return self;
}

- (NSString *)fk_jwtHeaderString
{
    NSDictionary *header = @{@"alg":@"ES256",@"kid":_keyid};
    NSLog(@"header = %@",header);
    return [[self class]fk_jwtBase64UrlEncodeJson:header];
}

- (NSString *)fk_jwtPayloadString
{
    ///秒级
    NSTimeInterval t = [[NSDate date]timeIntervalSince1970];
    NSUInteger unixtime = (NSUInteger)t;
    NSUInteger exp = unixtime+_expireduration;
    NSDictionary *payload = @{@"iss":_teamid,@"iat":@(unixtime),@"exp":@(exp)};
    payload = @{@"iss":@"XUUYEB97Z2",@"iat":@(1548136258),@"exp":@(1548139858)};
    NSLog(@"payload = %@",payload);
    return [[self class]fk_jwtBase64UrlEncodeJson:payload];
}

- (NSString *)fk_jwtDigestString
{
    return [NSString stringWithFormat:@"%@.%@",[self fk_jwtHeaderString],[self fk_jwtPayloadString]];
}

- (NSString *)fk_jwtGenerateTokenWithPrivateKey:(NSString *)privatekey
{
    NSAssert(privatekey, @"privatekey is null!");
    
#define swift_sign 1
#if swift_sign
    JwtSwiftToOC *ocToken = [[JwtSwiftToOC alloc]init];
    return [ocToken jwtGenerateTokenWithTeamId:_teamid Keyid:_keyid p8:privatekey];
#else
    NSString *secert = [[self class]fk_jwtSecertFromPrivateKey:privatekey];
    NSData *sdata = [[NSData alloc]initWithBase64EncodedString:secert options:0];
    if (!sdata) {
        NSLog(@"The privatekey string has invalid format.");
        return nil;
    }
    
//    SecKeyRef sckref = [self checkCreatePrivateSecKey:sdata password:nil];
    [self toASN1Element:sdata];
    return [self fk_jwtDigestString];
#endif
}

- (SecKeyRef)checkCreatePrivateSecKey:(NSData *)privateKeyData password:(NSString *)password
{
    SecKeyRef privateKeyRef = NULL;
    
    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);

    NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
    if (password.length > 0) {
        [options setObject:password forKey:(__bridge id<NSCopying>)(kSecImportExportPassphrase)];
    }
   OSStatus status = SecPKCS12Import((__bridge CFDataRef)(privateKeyData), (__bridge CFDictionaryRef)(options), &items);

    NSAssert(noErr == status, @"SecPKCS12Import failed. Error Code: %d", status);
    NSAssert(CFArrayGetCount(items) > 0, @"SecPKCS12Import failed. CFArrayGetCount(items): %ld", CFArrayGetCount(items));
    
    CFDictionaryRef identityDict = CFArrayGetValueAtIndex(items, 0);
    SecIdentityRef identityApp = (SecIdentityRef)CFDictionaryGetValue(identityDict, kSecImportItemIdentity);
    status = SecIdentityCopyPrivateKey(identityApp, &privateKeyRef);
    NSAssert(noErr == status, @"SecIdentityCopyPrivateKey failed. Error Code: %d", status);
    
    CFRelease(items);
    
    return privateKeyRef;
}

- (NSData *)incStepByData:(NSData *)srcdata step:(NSInteger)step
{
   return [srcdata subdataWithRange:NSMakeRange(step, srcdata.length - step)];
}

- (NSInteger)readLengthInNSData:(NSData *)data byReadLen:(NSInteger *)readlen
{
    unsigned char *sbytes = (unsigned char *)data.bytes;
    unsigned char byte = sbytes[0];
    
    if ((byte & 0x80) == 0x00) { //short form
        *readlen = 1;
        return byte & 0xff; //转10进制
    } else {
        ///所占字节长度
        int len = byte & 0x7F;
        NSInteger bytelen = 0;
        for (int i = 1; i < (1 + len); i++) {
            bytelen = 256 * bytelen + (sbytes[i] & 0xff);
        }
        *readlen = 1 + len;
        return bytelen;
    }
}

- (void)toASN1Element:(NSData *)keydata
{
    if (keydata.length ==0 ) {
        return;
    }
    
    unsigned char *bytes = (unsigned char *)keydata.bytes;
    //取第0个字节
    unsigned long hex = (bytes[0]) & 0xff;
    switch (hex) {
        case 0x30://sequence
        {
            NSData *subdata = [self incStepByData:keydata step:1];
            NSInteger readlen = 0;
            NSInteger bytelen = [self readLengthInNSData:subdata byReadLen:&readlen];
            
            subdata = [self incStepByData:keydata step:1 + readlen];
            NSInteger alreadyRead = 0;
            while (alreadyRead < bytelen) {
                [self toASN1Element:subdata];
                
                alreadyRead += 1;
            }
        }
            break;
        case 0x02://interger
        {
            NSData *subdata = [keydata subdataWithRange:NSMakeRange(1, keydata.length -1)];
            unsigned char *sbytes = (unsigned char *)subdata.bytes;
            unsigned char byte = sbytes[0];
            if ((byte & 0x80) == 0x00) { //short form
                
            } else {
                ///所占字节长度
                int len = byte & 0x7F;
                len =len + 1;
                subdata = [subdata subdataWithRange:NSMakeRange(len, subdata.length - len)];
            }
            
        }
            break;
            
        default:
            break;
    }
    
    
   
    
    
    
}

//-(NSData*)convertIOSKeyToASNFormat:(NSData*)Keydata
//{
//
//    static const unsigned char _encodedRSAEncryptionOID[15] = {
//        /* Sequence of length 0xd made up of OID followed by NULL */
//        0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
//        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00
//    };
//
//    // OK - that gives us the "BITSTRING component of a full DER
//    // encoded RSA public key - we now need to build the rest
//
//    unsigned char builder[15];
//    NSMutableData * encKey = [[NSMutableData alloc] init];
//    unsigned long bitstringEncLength;
//
//    // When we get to the bitstring - how will we encode it?
//    if  ([Keydata length ] + 1  < 128 )
//        bitstringEncLength = 1 ;
//    else
//        bitstringEncLength = (([Keydata length ] +1 ) / 256 ) + 2 ;
//
//    // Overall we have a sequence of a certain length
//    builder[0] = 0x30;    // ASN.1 encoding representing a SEQUENCE
//
//    // Build up overall size made up of -
//    size_t i = sizeof(_encodedRSAEncryptionOID) + 2 + bitstringEncLength +
//    [Keydata length];
//
//    size_t j = [self encodeLen:&builder[1] length:i];
//    [encKey appendBytes:builder length:j +1];
//
//    // First part of the sequence is the OID
//    [encKey appendBytes:_encodedRSAEncryptionOID
//                 length:sizeof(_encodedRSAEncryptionOID)];
//
//    // Now add the bitstring
//    builder[0] = 0x03;
//    j = [self encodeLen:&builder[1] length:[Keydata length] + 1];
//
//    builder[j+1] = 0x00;
//    [encKey appendBytes:builder length:j + 2];
//
//    // Now the actual key
//    [encKey appendData:Keydata];
//    return encKey;
//}

@end
