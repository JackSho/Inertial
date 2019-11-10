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

#define INERTIAL_COUNT_ZERO 0

typedef CF_ENUM(int, INERTIAL_MOUSE_STATUS) {
	INERTIAL_MOUSE_STATUS_UNKNOW = 0,
	INERTIAL_MOUSE_STATUS_STOP = 1,
	INERTIAL_MOUSE_STATUS_INERTIAL_START = 2,
	INERTIAL_MOUSE_STATUS_INERTIAL_MOVE = 3,
	INERTIAL_MOUSE_STATUS_INERTIAL_STOP = 4
};

// 常量
const double inertialDuration = 0.6; //  惯性持续时间，以秒为单位
const double speedThreshold = 0.8; // 移动速度门槛
const double inertialPower = 3.0; // 幂
const int magnify = 30; // 惯性倍数
const NSTimeInterval interval = 1.0 / 60.0; // 定时器间隔

// 私有变量
NSTimer *timer = NULL;
int mouseStatus = INERTIAL_MOUSE_STATUS_UNKNOW;
int inertialCount = INERTIAL_COUNT_ZERO;
CGPoint inertialStartPoint, lastPoint, currentPoint;
CGEventTimestamp lastTimestamp, currentTimestamp;
double mouseMoveSpeed;
bool enableInertial;
bool autoInertial;
bool inertialBreak;


CGEventTimestamp moveTimestamp = 0;
double inertialOffsetX = 0.0; // 惯性移动的水平位移
double inertialOffsetY = 0.0; // 惯性移动的垂直位移


// 构造函数
-(id) init {
    if(self = [super init]) {
        enableInertial = true;
        autoInertial = false;
        inertialBreak = false;
        lastPoint = currentPoint = CGPointZero;
        lastTimestamp =  currentTimestamp = 0;
        mouseMoveSpeed = 0;

        timer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer * _Nonnull timer) {
            
            // 判断鼠标当前状态
            if(mouseStatus == INERTIAL_MOUSE_STATUS_UNKNOW)
            {
                if(moveTimestamp == currentTimestamp)
                {
                    mouseStatus = INERTIAL_MOUSE_STATUS_STOP; //停止状态
                    inertialBreak = false;
                }
                else
                {
                    moveTimestamp = currentTimestamp;
                    return;
                }
            }
            
            if(enableInertial == true)
            {
                if(mouseStatus == INERTIAL_MOUSE_STATUS_STOP)
                {
                    if(mouseMoveSpeed > speedThreshold)
                    {
                        mouseStatus = INERTIAL_MOUSE_STATUS_INERTIAL_START; // 鼠标处于惯性状态
                        inertialStartPoint = currentPoint; // 记下结束时的坐标
                    }
                }
                
                static double aX = 0.0, aY = 0.0;
                if(mouseStatus == INERTIAL_MOUSE_STATUS_INERTIAL_START)
                {
//                    NSLog(@"正在计算惯性属性");
                    // 计算出惯性将要移动的偏移量
                    inertialOffsetX = magnify * (currentPoint.x - lastPoint.x);
                    inertialOffsetY = magnify * (currentPoint.y - lastPoint.y);
                    
                    // 使用抛物线 y=a((x+b)^n)
                    // 持续 500 ms， b = -0.5
                    // 2 次 幂，n = 2
                    
                    // 起点时， x = 0， a*b^2 = 变化总区间
                    // a*(-500)^2 = distance
                    double inertialDurationPow = pow(inertialDuration, inertialPower);
                    aX = inertialOffsetX / inertialDurationPow;
                    aY = inertialOffsetY / inertialDurationPow;
                    mouseStatus = INERTIAL_MOUSE_STATUS_INERTIAL_MOVE;
                    inertialCount = INERTIAL_COUNT_ZERO;
                }
                
                if(mouseStatus == INERTIAL_MOUSE_STATUS_INERTIAL_MOVE)
                {
                    if(inertialBreak == true){
//                        NSLog(@"惯性被中断");
                        mouseStatus = INERTIAL_MOUSE_STATUS_INERTIAL_STOP; // 惯性移动结束
                        inertialCount = INERTIAL_COUNT_ZERO; // 惯性移动次数清 0
                        autoInertial = false;
                        return ;
                    }
                    
                    
                    autoInertial = true;
                    inertialCount ++;
                    CGPoint target;
                    double temp = pow(fabs(inertialCount * timer.timeInterval - inertialDuration), inertialPower);
                    target.x = inertialStartPoint.x + inertialOffsetX - (aX * temp);
                    target.y = inertialStartPoint.y + inertialOffsetY - (aY * temp);
                    
//                    NSLog(@"触发惯性移动第%d次, [%f, %f]", inertialCount, target.x, target.y);
                    [self PostMouseEventButton:kCGMouseButtonLeft Type: kCGEventMouseMoved Point: &target Count:1];
                    
                    if(inertialCount * timer.timeInterval >= inertialDuration)
                    {
//                        NSLog(@"惯性结束");
                        mouseStatus = INERTIAL_MOUSE_STATUS_INERTIAL_STOP; // 惯性移动结束
                        autoInertial = false;
                        inertialCount = INERTIAL_COUNT_ZERO; // 惯性移动次数清 0
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
    lastTimestamp =  currentTimestamp;
    currentTimestamp = CGEventGetTimestamp(event);// 启动后的纳秒计数
    double offsetTime = (currentTimestamp - lastTimestamp) / 1000000.0;
    double offsetPowX = pow(currentPoint.x - lastPoint.x, 2);
    double offsetPowY = pow(currentPoint.y - lastPoint.y, 2);
    // 三角形勾股定理求斜边
    mouseMoveSpeed = sqrt(offsetPowX + offsetPowY) / offsetTime;
    
//    NSLog(@"移动速度：%f px/ms", speed);
    if(mouseStatus != INERTIAL_MOUSE_STATUS_INERTIAL_MOVE)
        mouseStatus = INERTIAL_MOUSE_STATUS_UNKNOW; // 常规移动
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
