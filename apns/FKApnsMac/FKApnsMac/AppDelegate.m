//
//  AppDelegate.m
//  FKApnsMac
//
//  Created by fengsh on 2019/1/18.
//  Copyright © 2019年 fengsh. All rights reserved.
//

#import "AppDelegate.h"
#import "FKMainWindowController.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, strong) FKMainWindowController                    *mainfrm;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    self.mainfrm = [[FKMainWindowController alloc]initWithWindowNibName:@"FKMainWindowController"];
    self.window = self.mainfrm.window;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
