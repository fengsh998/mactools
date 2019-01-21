//
//  APNSDocument.h
//  FKApnsMac
//
//  Created by fengsh on 2019/1/18.
//  Copyright © 2019年 fengsh. All rights reserved.
//

/*
    APNS 设置项保存成文件
 */

#import <Cocoa/Cocoa.h>
#import "APNSItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface APNSDocument : NSDocument
@property (nonatomic, copy)     NSString                    *token;
@property (nonatomic, copy)     NSString                    *payload;
@property (nonatomic, assign)   APNSItemMode                mode;
@property (nonatomic, copy)     NSString                    *certificateDescription; // Unused
///10：立即接收，5：屏幕关闭，在省电时才会接收到的。如果是屏幕亮着，是不会接收到消息的。而且这种消息是没有声音提示的
@property (nonatomic, assign)   APNSItemPriority            priority;
///apns-collapse-id 合并消息时用
@property (nonatomic, copy)     NSString                    *collapseID;
@property (nonatomic, assign)   BOOL                        sandbox;
@end

NS_ASSUME_NONNULL_END
