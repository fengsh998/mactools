//
//  AppDelegate.swift
//  testjwt
//
//  Created by fengsh on 2019/1/21.
//  Copyright © 2019年 fengsh. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
//        let vc = viewcontroller();
//
//        self.window.contentViewController = vc;
        let keyID = "HB5ZXX7MYQ";//"OIX79H472E" // Get from https://developer.apple.com/account/ios/authkey/
        let teamID = "XUUYEB97Z2";//"TZD0DM3IU4" // Get from https://developer.apple.com/account/#/membership/
        createToken(keyID: keyID, teamID: teamID)
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func createToken(keyID: String, teamID: String) {
        // Get content of the .p8 file
//        let p8 = """
//-----BEGIN PRIVATE KEY-----
//MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgGH2MylyZjjRdauTk
//xxXW6p8VSHqIeVRRKSJPg1xn6+KgCgYIKoZIzj0DAQehRANCAAS/mNzQ7aBbIBr3
//DiHiJGIDEzi6+q3mmyhH6ZWQWFdFei2qgdyM1V6qtRPVq+yHBNSBebbR4noE/IYO
//hMdWYrKn
//-----END PRIVATE KEY-----
//"""
        
        let p8 = """
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg/HA2HPrA6ohj+q9l
0RtdOuzzBd/rYeQturbRTIP+D7agCgYIKoZIzj0DAQehRANCAATMl0JFThE0xFxJ
ZdlV8A0UXcgg4QVbdgI62E91QWTr5YktHgvGyzw6RGfwF19Ucy+zS0zdaKDO2wgG
WsAfNqFQ
-----END PRIVATE KEY-----
"""
        
        // Assign developer information and token expiration setting
        let jwt = JWT(keyID: keyID, teamID: teamID, issueDate: Date(), expireDuration: 60 * 60)
        
        do {
            let token = try jwt.sign(with: p8)
            // Use the token in the authorization header in your requests connecting to Apple’s API server.
            // e.g. urlRequest.addValue(_ value: "bearer \(token)", forHTTPHeaderField field: "authorization")
            print("Generated JWT: \(token)")
        } catch {
            // Handle error
        }
    }

}

