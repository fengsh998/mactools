//
//  APNSSecIdentityType.h
//  FKApnsMac
//
//  Created by fengsh on 2019/1/18.
//  Copyright © 2019年 fengsh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

///APNS 证书类型
typedef NS_ENUM(NSInteger, APNSSecIdentityType) {
    APNSSecIdentityTypeInvalid,                     //无效
    APNSSecIdentityTypeDevelopment,                 //开发环境
    APNSSecIdentityTypeProduction,                  //生产环境
    APNSSecIdentityTypeUniversal                    //通用
};

NSArray<NSString *> * APNSSecIdentityGetTopics(SecIdentityRef identity);
extern APNSSecIdentityType APNSSecIdentityGetType(SecIdentityRef identity);
NSString * APNSSecIdentityGetSubjectUserID(SecIdentityRef identity);
//SecIdentityRef
NSArray * filterAPNSSecIndentity(void);
