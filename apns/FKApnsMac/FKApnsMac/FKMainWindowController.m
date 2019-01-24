//
//  FKMainWindowController.m
//  FKApnsMac
//
//  Created by fengsh on 2019/1/18.
//  Copyright © 2019年 fengsh. All rights reserved.
//

#import "FKMainWindowController.h"
///system
#import <SecurityInterface/SFChooseIdentityPanel.h>
#import <Security/Security.h>
///
#import "APNSSecIdentityType.h"
#import "APNSDocument.h"

///请求
#import "FKAPNSHttp2_0.h"
#import "FKJwtToken.h"
#import <JWT/JWT.h>
#import <Masonry/Masonry.h>
#import <pop/pop.h>

@interface FKMainWindowController ()<FKAPNSHttpDelegate>
@property (weak) IBOutlet NSView *titleview;
@property (weak) IBOutlet NSView *certchooseview;
@property (weak) IBOutlet NSView *pkeyview;
@property (weak) IBOutlet NSView *payloadview;
@property (weak) IBOutlet NSView *logview;
@property (weak) IBOutlet NSTextField *lb_identity;

///标题切换
@property (weak) IBOutlet NSSegmentedControl *segmentTitle;
@property (weak) IBOutlet NSTextField *tf_teamid;
@property (unsafe_unretained) IBOutlet NSTextView *txv_pkey;
@property (weak) IBOutlet NSTextField *tf_keyid;
///开发环境和测试环境
@property (weak) IBOutlet NSSegmentedControl *segmentEnv;
///显示选中的证书或p8文件
@property (weak) IBOutlet NSTextField *lb_cerIdentity;
///选择证书按钮
@property (weak) IBOutlet NSButton *btn_chooseIdentity;
///发送给谁的token,批量的时候逗号隔开吧
@property (weak) IBOutlet NSTextField *tf_token;
///优先级，
@property (weak) IBOutlet NSSegmentedControl *segmentPriority;
///输入的topics
@property (weak) IBOutlet NSComboBox *cbx_topics;
///帮助说明
@property (weak) IBOutlet NSButton *btn_priority_help;
///日志显示
@property (unsafe_unretained) IBOutlet NSTextView *txv_logs;
///消息聚合
@property (weak) IBOutlet NSTextField *tf_collapseid;
///pyaload
@property (unsafe_unretained) IBOutlet NSTextView *txv_payload;

@property (nonatomic, strong) FKAPNSHttp2_0                 *apnsEngine;

@property (nonatomic, assign) NSInteger                 mode;

@end

@implementation FKMainWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    self.mode = 0;
    [self.segmentTitle setSelectedSegment:self.mode];
    ///默认sandbox
    [self.segmentEnv setSelectedSegment:1];
    [self.segmentPriority setSelectedSegment:1];
    [self.txv_payload setString:[self defaultpayload]];
    
    [self.segmentTitle setTarget:self];
    [self.segmentTitle setAction:@selector(onSegmentChanged:)];
    [self.segmentEnv setTarget:self];
    [self.segmentEnv setAction:@selector(onSegmentChanged:)];
    [self.segmentPriority setTarget:self];
    [self.segmentPriority setAction:@selector(onSegmentChanged:)];
    [self.cbx_topics removeAllItems];
    
    [self layoutBaseUI];
    
    [self.tf_token setStringValue:@"4c001d0eb5906e30279df053ac8f2aecdcb41ebb0eca66074aebfc099370b1d4"];
    [self.tf_teamid setStringValue:@"XUUYEB97Z2"];
    [self.tf_keyid setStringValue:@"HB5ZXX7MYQ"];
    
    BOOL p8 = (self.segmentTitle.selectedSegment == 1);
    [self showPrivateKeyInputview:p8];
}

- (NSString *)defaultpayload
{
    return @"{\n\t\"aps\":{\n\t\t\"alert\":\"Test\",\n\t\t\"sound\":\"default\",\n\t\t\"badge\":1\n\t}\n}";
}

- (FKAPNSHttp2_0 *)apnsEngine
{
    if (!_apnsEngine) {
        _apnsEngine = [[FKAPNSHttp2_0 alloc]init];
        _apnsEngine.delegate = self;
    }
    return _apnsEngine;
}

- (void)onSegmentChanged:(NSSegmentedControl *)segment
{
    if (segment == self.segmentTitle) {
        if (self.mode == segment.selectedSegment) {
            return;
        }
        self.mode = segment.selectedSegment;
        BOOL p8 = (self.segmentTitle.selectedSegment == 1);
        [self showPrivateKeyInputview:p8];
        if (p8) {
            [self.lb_cerIdentity setStringValue:@"Choose an p8 file."];
        } else {
            [self.lb_cerIdentity setStringValue:@"Choose an indentity of cert from keychian."];
        }

    } else if (segment == self.segmentEnv) {
        
    } else if (segment == self.segmentPriority) {
        
    }
}

- (NSString *)getP8PrivateKey
{
//    NSString *pkey = @"-----BEGIN PRIVATE KEY-----\n"
//    "MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg/HA2HPrA6ohj+q9l\n"
//    "0RtdOuzzBd/rYeQturbRTIP+D7agCgYIKoZIzj0DAQehRANCAATMl0JFThE0xFxJ\n"
//    "ZdlV8A0UXcgg4QVbdgI62E91QWTr5YktHgvGyzw6RGfwF19Ucy+zS0zdaKDO2wgG\n"
//    "WsAfNqFQ\n"
//    "-----END PRIVATE KEY-----";
//    return pkey;

    return self.txv_pkey.string;
}

#pragma mark - 发起推送
- (IBAction)onPushClicked:(id)sender
{
    NSString *topic = self.cbx_topics.stringValue.length > 0 ? self.cbx_topics.stringValue : nil;
    NSString *teamid = self.tf_teamid.stringValue;
    NSString *keyid = self.tf_keyid.stringValue;
    NSDictionary *payload = [self payload];
    NSString *toToken = [self preparedToken];
    
    if (toToken.length == 0) {
        [self appendLogs:@"APNS > : token can not empty!"];
        return;
    }
    
    if (!payload) {
        [self appendLogs:@"APNS > : payload can not empty!"];
        return;
    }
    
    NSInteger priority = (self.segmentPriority.segmentCount == 0) ? 5 : 10;
    
    BOOL isprod = (self.segmentEnv.segmentCount == 0);
    
    if (self.mode == 0) {
        if (!self.apnsEngine.authIdentity) {
            [self appendLogs:@"APNS > : please choose push certificate!"];
            return ;
        }
        [self.apnsEngine pushPayload:payload toToken:toToken topic:topic priority:priority collapseId:nil inProduction:isprod];
    } else if (self.mode == 1) {
        
        if (!topic) {
            [self appendLogs:@"APNS > : topic can not empty!"];
            return;
        }
        NSString *pkey = [self getP8PrivateKey];
        pkey = [pkey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (pkey.length == 0) {
            [self appendLogs:@"APNS > : p8 file error or private key empty!"];
            return ;
        }
        
        FKJwtToken *jwttoken = [[FKJwtToken alloc]initWithTeamId:teamid Keyid:keyid expireDuration:0];
        NSString *auth = [jwttoken fk_jwtGenerateTokenWithPrivateKey:pkey];
        [self.apnsEngine setAuthIdentity:NULL];
        self.apnsEngine.authorization = auth;
        [self.apnsEngine pushPayload:payload toToken:toToken topic:topic priority:priority collapseId:nil inProduction:isprod];
    }
}

- (NSString *)preparedToken
{
    NSString *token = self.tf_token.stringValue;
    token = self.tf_token.stringValue;
    NSCharacterSet *removeCharacterSet = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    token = [[token componentsSeparatedByCharactersInSet:removeCharacterSet] componentsJoinedByString:@""];
    return [token lowercaseString];
}

- (NSDictionary *)payload
{
    NSString *json = self.txv_payload.string;
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    if (data.length > 0) {
        NSError *error = nil;
        NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        
        if (error) {
            [self appendLogs:[NSString stringWithFormat:@"APNS > : %@",@"输入的为非json字符串"]];
            return nil;
        }
        
        if (payload && [payload isKindOfClass:[NSDictionary class]]) {
            return payload;
        }
    }
    
    return nil;
}

#pragma mark - 选证书
///从keyChian中选取
- (IBAction)onChooseIdentity:(id)sender
{
    if (self.mode == 0) {
        SFChooseIdentityPanel *panel = [SFChooseIdentityPanel sharedChooseIdentityPanel];
        [panel setAlternateButtonTitle:@"Cancel"];
        
        [panel beginSheetForWindow:self.window
                     modalDelegate:self
                    didEndSelector:@selector(onChooseIdentityPanelDidEnd:returnCode:contextInfo:)
                       contextInfo:nil
                        identities:[self identities]
                           message:@"Choose the identity to use for delivering notifications: \n(Issued by Apple in the Provisioning Portal)"];
    } else {
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        [panel setAllowsMultipleSelection:NO];
        [panel setCanChooseDirectories:YES];
        [panel setCanChooseFiles:YES];
        [panel setAllowedFileTypes:@[@"p8"]];
        [panel setAllowsOtherFileTypes:YES];
        if ([panel runModal] == NSModalResponseOK) {
            NSString *path = [panel.URLs.firstObject path];
            [self.lb_cerIdentity setStringValue:path];
            NSData *p8key = [NSData dataWithContentsOfFile:path];
            NSString *content = [[NSString alloc]initWithData:p8key encoding:NSUTF8StringEncoding];
            [self.txv_pkey setString:content];
        }
    }
}

///证书选择结果
-(void)onChooseIdentityPanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSFileHandlingPanelOKButton) {
        
        SecIdentityRef identity = [SFChooseIdentityPanel sharedChooseIdentityPanel].identity;
        
        // Prevent crach if the user press "Choose" without an identity
        // There should be an error here maybe? An even better thing would be to disable the "Choose" button
        if (identity == NULL) {
            return;
        }
        
//        APNSSecIdentityType type = APNSSecIdentityGetType(identity);
        
        SecCertificateRef cert = NULL;
        if (noErr == SecIdentityCopyCertificate(identity, &cert)) {
            CFStringRef commonName = NULL;
            SecCertificateCopyCommonName(cert, &commonName);
            CFRelease(cert);
            
            NSString *name = (__bridge_transfer NSString *)commonName;
            
            [self.lb_cerIdentity setStringValue:name?:@""];
        }
        
        ///读取证书中的topics
        NSArray *topics = APNSSecIdentityGetTopics(identity);
        [self.cbx_topics setStringValue:@""];
        [self.cbx_topics removeAllItems];
        if (topics.count > 0) {
            [self.cbx_topics addItemsWithObjectValues:topics];
            [self.cbx_topics selectItemAtIndex:0];
        } else { ///取bundle id
            NSString *bundleid = APNSSecIdentityGetSubjectUserID(identity);
            if (bundleid) {
                [self.cbx_topics addItemWithObjectValue:bundleid];
                [self.cbx_topics selectItemAtIndex:0];
            }
        }

//        self.cbx_topics.enabled = (topics.count > 0);

        [self.apnsEngine setAuthIdentity:identity];
    }
}

///证书
- (NSArray *)identities {
    return filterAPNSSecIndentity();
}

- (void)appendLogs:(NSString *)msg
{
    NSAttributedString *tmp = [[NSAttributedString alloc]initWithString:[NSString stringWithFormat:@"%@\n",msg]];
    [[self.txv_logs textStorage]appendAttributedString:tmp];
}

#pragma mark - push callback
- (void)fk_apns:(FKAPNSHttp2_0 *)apns didResponseStatus:(NSInteger)statusCode reason:(NSString *)reason forReqid:(NSString *)apnsid
{
    NSString *log = [NSString stringWithFormat:@"APNS > :【requestid = %@ 】: status = %ld,reason = %@",apnsid,statusCode,reason];
    [self appendLogs:log];
}

- (void)fk_apns:(FKAPNSHttp2_0 *)apns didFailedWithError:(NSError *)error forReqid:(nonnull NSString *)apnsid
{
    NSString *log = [NSString stringWithFormat:@"APNS > :【requestid = %@ 】: error = %@",apnsid,error];
    [self appendLogs:log];
}

- (IBAction)onbtn_topic_help:(id)sender {
    
}

- (IBAction)onbtn_priority_help:(id)sender {
    
}

- (IBAction)onCleanLogs:(id)sender {
    [self.txv_logs setString:@""];
}

- (void)layoutBaseUI
{
    [self.titleview mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.leading.trailing.equalTo(@(0));
        make.height.equalTo(@(60));
    }];
    
    [self.certchooseview mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.titleview.mas_bottom);
        make.leading.trailing.equalTo(@(0));
        make.height.equalTo(@(50));
    }];
    
    [self.pkeyview mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.trailing.equalTo(@(0));
        make.top.equalTo(self.certchooseview.mas_bottom);
        make.height.equalTo(@(100));
    }];
    
    [self.payloadview setWantsLayer:YES];
    self.payloadview.layer.backgroundColor = [NSColor windowBackgroundColor].CGColor;
    self.payloadview.layer.masksToBounds = YES;
    
    [self.payloadview mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.trailing.equalTo(@(0));
        make.top.equalTo(self.certchooseview.mas_bottom);
        make.height.equalTo(@(340));
    }];
    
    [self.logview mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.payloadview.mas_bottom);
        make.leading.trailing.equalTo(@(0));
        make.bottom.equalTo(@(-20));
    }];
    
//    float minh = 60 + 50 + 340 + 30 + 200;
//    [self.window setMinSize:NSMakeSize(200, minh)];
//    [self.window setMaxSize:NSMakeSize([NSScreen.mainScreen frame].size.width - 50, minh)];
//    [self.window setFrame:NSMakeRect(0, 0, 640, minh) display:NO];
}

- (void)showPrivateKeyInputview:(BOOL)disable
{
    self.pkeyview.hidden = !disable;
    if (disable) {
        [self.payloadview mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.leading.trailing.equalTo(@(0));
            make.top.equalTo(self.pkeyview.mas_bottom);
            make.height.equalTo(@(340));
        }];
    } else {
        [self.payloadview mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.leading.trailing.equalTo(@(0));
            make.top.equalTo(self.certchooseview.mas_bottom);
            make.height.equalTo(@(340));
        }];
    }
}

@end
