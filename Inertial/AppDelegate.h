//
//  AppDelegate.h
//  Inertial
//
//  Created by Jie Xiao on 2019/11/3.
//  Copyright © 2019 Jie Xiao. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

-(void) PostMouseEventButton: (CGMouseButton) button Type: (CGEventType) type Point: (const CGPoint *) point Count: (int64_t) clickCount;

@end

