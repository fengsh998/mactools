//
//  APNSSecIdentityType.m
//  FKApnsMac
//
//  Created by fengsh on 2019/1/18.
//  Copyright © 2019年 fengsh. All rights reserved.
//
//https://opensource.apple.com/source/libsecurity_keychain/libsecurity_keychain-55044/lib/CertificateValues.cpp

#import "APNSSecIdentityType.h"

static NSString * const CertificateSubjectKey = @"2.16.840.1.113741.2.1.1.1.8";
static NSString * const CertificateOIDUserIdKey = @"0.9.2342.19200300.100.1.1";

// http://www.apple.com/certificateauthority/Apple_WWDR_CPS
///开发apple Push Dev
static NSString * const APNSSecIdentityTypeDevelopmentCustomExtension = @"1.2.840.113635.100.6.3.1";
///生产apple Push Prod
static NSString * const APNSSecIdentityTypeProductionCustomExtension = @"1.2.840.113635.100.6.3.2";
///apple PushTopics
static NSString * const APNSSecIdentityTypeUniversalCustomExtension = @"1.2.840.113635.100.6.3.6";

//voip push 扩展
///voip apple Push BundleId
static NSString * const APNSSecIdentityTypeVoip3CustomExtension = @"1.2.840.113635.100.6.3.3";
///voip apple PushVoIP Topics
static NSString * const APNSSecIdentityTypeVoip4CustomExtension = @"1.2.840.113635.100.6.3.4";
static NSString * const APNSSecIdentityTypeVoip5CustomExtension = @"1.2.840.113635.100.6.3.5";

NSDictionary * APNSecValuesForIndentity(SecIdentityRef identity) {
    
    SecCertificateRef certificate;
    SecIdentityCopyCertificate(identity, &certificate);
    NSArray *keys = @[
                      APNSSecIdentityTypeDevelopmentCustomExtension,
                      APNSSecIdentityTypeProductionCustomExtension,
                      APNSSecIdentityTypeUniversalCustomExtension,
                      CertificateSubjectKey,
                      APNSSecIdentityTypeVoip3CustomExtension,
                      APNSSecIdentityTypeVoip4CustomExtension,
                      APNSSecIdentityTypeVoip5CustomExtension,
                      ];
//    keys = nil;//取全部时为nil
    NSDictionary *values = (__bridge_transfer NSDictionary *)SecCertificateCopyValues(certificate, (__bridge CFArrayRef)keys, NULL);
    
    CFRelease(certificate);
    
    return values;
}

NSArray<NSString *> * APNSSecIdentityGetTopics(SecIdentityRef identity) {
    
    NSDictionary *values = APNSecValuesForIndentity(identity);
    
    if (values[APNSSecIdentityTypeDevelopmentCustomExtension] && values[APNSSecIdentityTypeProductionCustomExtension]) {
        
        NSDictionary *topicContents = values[APNSSecIdentityTypeUniversalCustomExtension];
        if (topicContents) {
            NSMutableArray<NSString *> *array = [NSMutableArray new];
            NSArray *topicArray = topicContents[@"value"];
            
            for (NSDictionary *topic in topicArray) {
                if ([topic[@"label"] isEqualToString:@"Data"]) {
                    [array addObject:topic[@"value"]];
                }
            }
            
            return array;
        }
        ///对于voip的证书
        NSDictionary *voipTopicContents = values[APNSSecIdentityTypeVoip4CustomExtension];
        if (voipTopicContents) {
            NSArray *voipvalues = voipTopicContents[@"value"];
            NSMutableArray<NSString *> *array = [NSMutableArray new];
            for (NSDictionary *item in voipvalues) {
                if ([item[@"label"]isEqualToString:@"Unparsed Data"]) {
                    if ([item[@"type"]isEqualToString:@"data"]) {
                        NSData *topicsdata = item[@"value"];
                        topicsdata = [topicsdata subdataWithRange:NSMakeRange(2, topicsdata.length - 2)];
                        NSString *topics_str = [[NSString alloc]initWithData:topicsdata encoding:NSUTF8StringEncoding];
                        topics_str = [topics_str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                        NSArray *ts = [topics_str componentsSeparatedByString:@","];
                        
                        for (NSString *s in ts) {
                            [array addObject:[s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                        }
                        
                        return array;
                    }
                }
            }
        }
    }
    
    return @[];
}

NSString * APNSSecIdentityGetSubjectUserID(SecIdentityRef identity)
{
    NSDictionary *values = APNSecValuesForIndentity(identity);
    if (values[CertificateSubjectKey]) {
        NSDictionary *subjects = values[CertificateSubjectKey];
        NSArray *subject_values = subjects[@"value"];
        for (NSDictionary *value in subject_values) {
            if ([value[@"label"] isEqualToString:CertificateOIDUserIdKey]) {
                return value[@"value"];
            }
        }
    }
    return nil;
}

APNSSecIdentityType APNSSecIdentityGetType(SecIdentityRef identity) {
    
    NSDictionary *values = APNSecValuesForIndentity(identity);
    
    if (values[APNSSecIdentityTypeDevelopmentCustomExtension] && values[APNSSecIdentityTypeProductionCustomExtension]) {
        return APNSSecIdentityTypeUniversal;
    } else if (values[APNSSecIdentityTypeDevelopmentCustomExtension]) {
        return APNSSecIdentityTypeDevelopment;
    } else if (values[APNSSecIdentityTypeProductionCustomExtension]) {
        return APNSSecIdentityTypeProduction;
    } else {
        return APNSSecIdentityTypeInvalid;
    }
}

NSArray * filterAPNSSecIndentity(void)
{
    NSDictionary *query = @{
                            (id)kSecClass:(id)kSecClassIdentity,
                            (id)kSecMatchLimit:(id)kSecMatchLimitAll,
                            (id)kSecReturnRef:(id)kCFBooleanTrue
                            };
    
    CFArrayRef identities;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&identities);
    
    if (status != noErr) {
        return nil;
    }
    
    NSMutableArray *result = [NSMutableArray arrayWithArray:(__bridge_transfer NSArray *) identities];
    
    // Allow only identities with APNS certificate
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^(id object, NSDictionary *bindings) {
        SecIdentityRef identity = (__bridge SecIdentityRef) object;
        APNSSecIdentityType type = APNSSecIdentityGetType(identity);
        BOOL isValid = (type != APNSSecIdentityTypeInvalid);
        return isValid;
    }];
    [result filterUsingPredicate:predicate];
    
    // Sort identities by name
    NSComparator comparator = (NSComparator) ^(SecIdentityRef id1, SecIdentityRef id2) {
        SecCertificateRef cert1;
        SecIdentityCopyCertificate(id1, &cert1);
        NSString *name1 = (__bridge_transfer NSString*)SecCertificateCopyShortDescription(NULL, cert1, NULL);
        CFRelease(cert1);
        
        SecCertificateRef cert2;
        SecIdentityCopyCertificate(id2, &cert2);
        NSString *name2 = (__bridge_transfer NSString*)SecCertificateCopyShortDescription(NULL, cert2, NULL);
        CFRelease(cert2);
        
        return [name1 compare:name2];
    };
    [result sortUsingComparator:comparator];
    
    return result;
}
