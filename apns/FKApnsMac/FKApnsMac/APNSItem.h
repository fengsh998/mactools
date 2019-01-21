//
//  APNSItem.h
//  FKApnsMac
//
//  Created by fengsh on 2019/1/18.
//  Copyright © 2019年 fengsh. All rights reserved.
//

#import "MTLModel.h"

typedef NS_ENUM(NSUInteger, APNSItemMode) {
    APNSItemModeKeyChain,
    APNSItemModeiOS
};

typedef NS_ENUM(NSUInteger, APNSItemPriority) {
    APNSItemPriorityLater               = 5,
    APNSItemPriorityImmediately         = 10
};

//json 映谢
@interface APNSItem : MTLModel
@property (nonatomic, copy) NSString                *token;
@property (nonatomic, copy) NSString                *payload;
@property (nonatomic)       APNSItemMode            mode;
@property (nonatomic, copy) NSString                *certificateDescription;
@property (nonatomic)       APNSItemPriority        priority;
@property (nonatomic)       NSString                *collapseID;
@property (nonatomic)       BOOL                    sandbox; // Only used when an identity includes both development and production
@end
