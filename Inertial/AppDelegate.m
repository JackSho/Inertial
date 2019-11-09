//
//  AppDelegate.m
//  Inertial
//
//  Created by Jie Xiao on 2019/11/3.
//  Copyright © 2019 Jie Xiao. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

// 私有变量
NSTimer *timer;
CGEventTimestamp timestamp;
NSTimeInterval interval;
const double inertialDuration = 0.6; //  惯性持续时间，以秒为单位
const double speedThreshold = 0.8; // 移动速度门槛
const double inertialPower = 3.0; // 幂
const int magnify = 30; // 惯性倍数

int mouseStatus = 0;

CGPoint pointFinish;

CGPoint lastPoint, currentPoint;
CGEventTimestamp lastTime, currentTime;
double speed;

bool enable;
bool autoInertial;
bool inertialBreak;


// 构造函数
-(id) init {
    if(self = [super init]) {
        enable = true;
        autoInertial = false;
        inertialBreak = false;
        lastPoint = currentPoint = CGPointZero;
        lastTime =  currentTime = 0;
        speed = 0;
        interval = 1.0 / 60; // 定时器间隔

        timer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer * _Nonnull timer) {
            
            static CGEventTimestamp moveTimestamp = 0;
            static double offsetX = 0.0;
            static double offsetY = 0.0;
            
            // 判断鼠标当前状态
            if(mouseStatus == 0)
            {
                if(moveTimestamp == currentTime)
                {
                    mouseStatus = 1; //停止状态
                    inertialBreak = false;
                }
                else
                {
                    moveTimestamp = currentTime;
                    return;
                }
            }
            
            if(enable == true)
            {
                if(mouseStatus == 1)
                {
                    if(speed > speedThreshold)
                    {
                        mouseStatus = 2; // 鼠标处于惯性状态
                        pointFinish = currentPoint; // 记下结束时的坐标
                    }
                }
                
                static int inertialCount = 0;
                static double aX = 0.0, aY = 0.0;
                if(mouseStatus == 2)
                {
//                    NSLog(@"正在计算惯性属性");
                    // 计算出惯性将要移动的偏移量
                    offsetX = magnify * (currentPoint.x - lastPoint.x);
                    offsetY = magnify * (currentPoint.y - lastPoint.y);
                    
                    // 使用抛物线 y=a((x+b)^n)
                    // 持续 500 ms， b = -0.5
                    // 2 次 幂，n = 2
                    
                    // 起点时， x = 0， a*b^2 = 变化总区间
                    // a*(-500)^2 = distance
                    double inertialDurationPow = pow(inertialDuration, inertialPower);
                    aX = offsetX / inertialDurationPow;
                    aY = offsetY / inertialDurationPow;
                    mouseStatus = 3;
                    inertialCount = 0;
                }
                
                if(mouseStatus == 3)
                {
                    if(inertialBreak == true){
//                        NSLog(@"惯性被中断");
                        mouseStatus = 4; // 惯性移动结束
                        inertialCount = 0; // 惯性移动次数清 0
                        autoInertial = false;
                        return ;
                    }
                    
                    
                    autoInertial = true;
                    inertialCount ++;
                    CGPoint target;
                    double temp = pow(fabs(inertialCount * timer.timeInterval - inertialDuration), inertialPower);
                    target.x = pointFinish.x + offsetX - (aX * temp);
                    target.y = pointFinish.y + offsetY - (aY * temp);
                    
//                    NSLog(@"触发惯性移动第%d次, [%f, %f]", inertialCount, target.x, target.y);
                    [self PostMouseEventButton:kCGMouseButtonLeft Type: kCGEventMouseMoved Point: &target Count:1];
                    
                    if(inertialCount * timer.timeInterval >= inertialDuration)
                    {
//                        NSLog(@"惯性结束");
                        mouseStatus = 4; // 惯性移动结束
                        autoInertial = false;
                        inertialCount = 0; // 惯性移动次数清 0
                    }
                }
            }
        }];
    }
    return self;
}


// 私有函数
- (void) applicationDidFinishLaunching:(NSNotification *)aNotification {
    CGEventMask eventMask = CGEventMaskBit(kCGEventMouseMoved) /*| CGEventMaskBit(kCGEventLeftMouseDragged) | CGEventMaskBit(kCGEventRightMouseDragged)*/; //鼠标移动和拖拽事件
    CFMachPortRef eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, eventMask, eventCallback, NULL);
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(eventTap, true);
    CFRelease(eventTap);
    CFRelease(runLoopSource);
}


-(void) PostMouseEventButton: (CGMouseButton) button Type: (CGEventType) type Point: (const CGPoint *) point Count: (int64_t) clickCount {
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStatePrivate);
    CGEventRef theEvent = CGEventCreateMouseEvent(source, type, *point, button);
    CGEventSetIntegerValueField(theEvent, kCGMouseEventClickState, clickCount);
    CGEventSetType(theEvent, type);
    CGEventPost(kCGHIDEventTap, theEvent);
    CFRelease(theEvent);
    CFRelease(source);
}


static CGEventRef eventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {

    lastPoint = currentPoint;
    currentPoint = CGEventGetLocation(event);;
    lastTime =  currentTime;
    currentTime = CGEventGetTimestamp(event);// 启动后的纳秒计数
    double offsetTime = (currentTime - lastTime) / 1000000.0;
    double offsetPowX = pow(currentPoint.x - lastPoint.x, 2);
    double offsetPowY = pow(currentPoint.y - lastPoint.y, 2);
    // 三角形勾股定理求斜边
    speed = sqrt(offsetPowX + offsetPowY) / offsetTime;
    
//    NSLog(@"移动速度：%f px/ms", speed);
    if(mouseStatus != 3)
        mouseStatus = 0; // 常规移动
    if(autoInertial == true) // 光标自动惯性移动
        autoInertial = false;
    else if(mouseStatus == 3)
        inertialBreak = true;
    return event;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
