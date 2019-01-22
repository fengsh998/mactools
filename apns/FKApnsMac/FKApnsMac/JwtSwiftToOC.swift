//
//  JwtSwiftToOC.swift
//  FKApnsMac
//
//  Created by fengsh on 2019/1/22.
//  Copyright © 2019 fengsh. All rights reserved.
//

import Cocoa

class JwtSwiftToOC: NSObject {
    @objc public func jwtGenerateToken(teamId:String,Keyid:String,p8:String) -> String? {
        let jwtobj = JWT(keyID: Keyid, teamID: teamId, issueDate: Date(), expireDuration: 60*60);
        
        do {
            let token = try jwtobj.sign(with: p8)
            return token;
        } catch {
            
        }
        
        return nil;
    }
}
