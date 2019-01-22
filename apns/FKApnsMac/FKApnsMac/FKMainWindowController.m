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

@interface FKMainWindowController ()<FKAPNSHttpDelegate>
///标题切换
@property (weak) IBOutlet NSSegmentedControl *segmentTitle;
///开发环境和测试环境
@property (weak) IBOutlet NSSegmentedControl *segmentEnv;
@property (weak) IBOutlet NSTextField *lb_cerIdentity;
@property (weak) IBOutlet NSButton *btn_chooseIdentity;
@property (weak) IBOutlet NSTextField *tf_token;
@property (weak) IBOutlet NSSegmentedControl *segmentPriority;
@property (weak) IBOutlet NSPopUpButton *cbx_topics;
@property (weak) IBOutlet NSTextField *tf_collapseid;
@property (unsafe_unretained) IBOutlet NSTextView *txv_payload;

@property (nonatomic, strong) FKAPNSHttp2_0                 *apnsEngine;

@end

@implementation FKMainWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    self.segmentEnv.hidden = YES;
    
    
    FKJwtToken *jwttoken = [[FKJwtToken alloc]initWithTeamId:@"XUUYEB97Z2" Keyid:@"HB5ZXX7MYQ" expireDuration:0];
    
    NSLog(@"s = %@",[jwttoken fk_jwtGenerateTokenWithPrivateKey:[self getP8PrivateKey]]);

    NSDictionary *token = [self.apnsEngine jwtDecodeWithJwtString:@"eyAia2lkIjogIjhZTDNHM1JSWDciIH0.eyAiaXNzIjogIkM4Nk5WOUpYM0QiLCAiaWF0IjogIjE0NTkxNDM1ODA2NTAiIH0.MEYCIQDzqyahmH1rz1s-LFNkylXEa2lZ_aOCX4daxxTZkVEGzwIhALvkClnx5m5eAT6Lxw7LZtEQcH6JENhJTMArwLf3sXwi"];
    NSLog(@"tk = %@",token);
    
    NSString *t1 = [self.apnsEngine test];
    NSLog(@"t1 = %@",t1);
    token = [self.apnsEngine jwtDecodeWithJwtString:t1];
    NSLog(@"tk = %@",token);
}

- (FKAPNSHttp2_0 *)apnsEngine
{
    if (!_apnsEngine) {
        _apnsEngine = [[FKAPNSHttp2_0 alloc]init];
        _apnsEngine.delegate = self;
    }
    return _apnsEngine;
}

- (NSString *)getP8PrivateKey
{
    NSString *pkey = @"-----BEGIN PRIVATE KEY-----\n"
    "MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg/HA2HPrA6ohj+q9l\n"
    "0RtdOuzzBd/rYeQturbRTIP+D7agCgYIKoZIzj0DAQehRANCAATMl0JFThE0xFxJ\n"
    "ZdlV8A0UXcgg4QVbdgI62E91QWTr5YktHgvGyzw6RGfwF19Ucy+zS0zdaKDO2wgG\n"
    "WsAfNqFQ\n"
    "-----END PRIVATE KEY-----";
    return pkey;
}

#pragma mark - 发起推送
- (IBAction)onPushClicked:(id)sender
{
//    [self.apnsEngine pushPayload:[self payload] toToken:[self preparedToken] topic:self.cbx_topics.selectedItem.title
//                        priority:10 collapseId:nil inProduction:NO];
    
    NSString *topic =  self.cbx_topics.selectedItem.title;
    topic = @"com.shimaowy.iot.voip";
    [self.apnsEngine pushPayloadJWT:[self payload] toToken:[self preparedToken] topic:topic
                        priority:10 collapseId:nil inProduction:NO];
}

- (NSString *)preparedToken
{
    NSString *token = self.tf_token.stringValue;
    token = @"4c001d0eb5906e30279df053ac8f2aecdcb41ebb0eca66074aebfc099370b1d4";
    NSCharacterSet *removeCharacterSet = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    token = [[token componentsSeparatedByCharactersInSet:removeCharacterSet] componentsJoinedByString:@""];
    return [token lowercaseString];
}

- (NSDictionary *)payload
{
    //  NSData *data = [self.fragariaView.string dataUsingEncoding:NSUTF8StringEncoding];
    NSString *json = @"{\"aps\":{\"alert\":\"Test\"}}";
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    if (data) {
        NSError *error;
        NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        
        if (payload && [payload isKindOfClass:[NSDictionary class]]) {
            return payload;
        }
    }
    
    return nil;
}

#pragma mark - 选证书
///从keyChian中选取
- (IBAction)onChooseIdentity:(id)sender {
    SFChooseIdentityPanel *panel = [SFChooseIdentityPanel sharedChooseIdentityPanel];
    [panel setAlternateButtonTitle:@"Cancel"];
    
    [panel beginSheetForWindow:self.window
                 modalDelegate:self
                didEndSelector:@selector(onChooseIdentityPanelDidEnd:returnCode:contextInfo:)
                   contextInfo:nil
                    identities:[self identities]
                       message:@"Choose the identity to use for delivering notifications: \n(Issued by Apple in the Provisioning Portal)"];
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
        
        APNSSecIdentityType type = APNSSecIdentityGetType(identity);
        
//        [self setShowSandbox:(type == APNSSecIdentityTypeUniversal) animated:YES];
        
        ///读取证书中的topics
        NSArray *topics = APNSSecIdentityGetTopics(identity);
        [self.cbx_topics removeAllItems];
        [self.cbx_topics addItemsWithTitles:topics];
        self.cbx_topics.enabled = (topics.count > 0);
        
//        [self willChangeValueForKey:@"identityName"];
        [self.apnsEngine setAuthIdentity:identity];
//        [self didChangeValueForKey:@"identityName"];
    }
}

///证书
- (NSArray *)identities {
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

#pragma mark - push callback
- (void)fk_apns:(FKAPNSHttp2_0 *)apns didResponseStatus:(NSInteger)statusCode reason:(NSString *)reason forReqid:(NSString *)apnsid
{
    NSLog(@"status = %ld,reason = %@,apnsid = %@",statusCode,reason,apnsid);
}

- (void)fk_apns:(FKAPNSHttp2_0 *)apns didFailedWithError:(NSError *)error
{
    NSLog(@"error = %@",error);
}

@end
