//
//  NKTraceManager.h
//  CLPDemo
//
//  Created by KyleWong on 4/8/16.
//  Copyright © 2016 KyleWong. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mach/mach_types.h>
#import <mach/task.h>
#import <mach/mach_init.h>
#import <mach/thread_act.h>
#import <mach/vm_map.h>
#import <mach/mach_port.h>
#import <signal.h>
#import <assert.h>
#import <stdlib.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

typedef void (^NKTraceManagerBlock)(id aCallbackInfo);
void nk_log(char *format,...);

@interface NKTraceManager : NSObject
+ (instancetype)sharedInstance;
- (long)loadAddress;
- (void)setTimeoutBlock:(NKTraceManagerBlock)aTimeoutBlock forThreadId:(thread_t)aThreadId runloop:(CFRunLoopRef)aRunloopRef runloopModes:(CFStringRef)aRunloopModes timeLimit:(CGFloat)aTimeLimit;
@end