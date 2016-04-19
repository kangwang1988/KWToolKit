//
//  NKTraceManager.m
//  CLPDemo
//
//  Created by KyleWong on 4/8/16.
//  Copyright © 2016 KyleWong. All rights reserved.
//

#import "NKTraceManager.h"
#import "PLCrashFrameWalker.h"

//const double kRunloopDurationMonitorThreshold = 5.f;
static CGFloat kRunloopMonitorInterval = 0.1f;
typedef void (^NKRunloopHandlerBlock)(CFRunLoopObserverRef observer, CFRunLoopActivity activity);
int main(int argc, char *argv[]);
static NKTraceManager *gTraceManager = nil;
void nk_log(char *format,...){
    va_list args;
    va_start(args, format);
    NSString *contents = [[NSString alloc] initWithFormat:[NSString stringWithCString:format encoding:NSUTF8StringEncoding] arguments:args];
    NSLog(@"%@",contents);
    va_end(args);
}

@interface NKTraceManager()
@property (nonatomic,assign) thread_t monitorThreadId;
@property (nonatomic,assign) BOOL isMonitorThreadEnabled;
@property (nonatomic,strong) NSNumber *monitorRunloopSTime;
@property (nonatomic,strong) NSNumber *monitorRunloopETime;
@property (nonatomic,assign) CGFloat monitorTimeoutLimit;
@property (nonatomic,copy) NKTraceManagerBlock timeoutBlock;
@property (nonatomic,copy) NKRunloopHandlerBlock runloopHandlerBlock;
@property (nonatomic,copy) __attribute__((NSObject)) CFStringRef runloopModes;
@property (nonatomic,strong) __attribute__((NSObject)) CFRunLoopObserverRef runloopObserverRef;
@property (nonatomic,strong) __attribute__((NSObject)) CFRunLoopRef runloopRef;
@end

@implementation NKTraceManager
+ (instancetype)sharedInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gTraceManager = [NKTraceManager new];
    });
    return gTraceManager;
}

- (instancetype)init{
    if(self = [super init]){
        [self loadAddress];
        __weak NKTraceManager *weakSelf = self;
        [self setRunloopHandlerBlock:^(CFRunLoopObserverRef observer, CFRunLoopActivity activity){
            switch (activity) {
                case kCFRunLoopEntry:
                    break;
                case kCFRunLoopBeforeTimers:
                case kCFRunLoopBeforeSources:
                    break;
                case kCFRunLoopBeforeWaiting:
                    [weakSelf setMonitorRunloopETime:@([[NSDate date] timeIntervalSince1970])];
                    break;
                case kCFRunLoopAfterWaiting:
                    // About to process a timer or source
                    [weakSelf setMonitorRunloopSTime:@([[NSDate date] timeIntervalSince1970])];
                    [weakSelf setMonitorRunloopETime:nil];
                    break;
                case kCFRunLoopExit:
                    break;
                default:
                    break;
            }
        }];
    }
    return self;
}

- (void)setTimeoutBlock:(NKTraceManagerBlock)aTimeoutBlock forThreadId:(thread_t)aThreadId runloop:(CFRunLoopRef)aRunloopRef runloopModes:(CFStringRef)aRunloopModes timeLimit:(CGFloat)aTimeLimit{
    if(!aTimeoutBlock || !aThreadId || !aRunloopRef || !aRunloopModes || aTimeLimit<=0){
        [self setIsMonitorThreadEnabled:NO];
        return;
    }
    if(self.runloopObserverRef){
        CFRunLoopRemoveObserver(self.runloopRef, self.runloopObserverRef, self.runloopModes);
        [self setRunloopObserverRef:nil];
        [self setMonitorThreadId:0];
        [self setRunloopRef:nil];
        [self setRunloopModes:nil];
        [self setMonitorTimeoutLimit:CGFLOAT_MAX];
    }
    CFRunLoopObserverRef obs = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopAllActivities, true, 0 /* order */, self.runloopHandlerBlock);
    CFRunLoopAddObserver(aRunloopRef, obs, kCFRunLoopCommonModes);
    [self setRunloopObserverRef:obs];
    CFRelease(obs);
    [self setMonitorThreadId:aThreadId];
    [self setRunloopRef:aRunloopRef];
    [self setRunloopModes:aRunloopModes];
    [self setMonitorTimeoutLimit:aTimeLimit];
    [self setTimeoutBlock:aTimeoutBlock];
    if(!self.isMonitorThreadEnabled){
        [NSThread detachNewThreadSelector:@selector(runloopMonitorThread:) toTarget:[self class] withObject:self];
    }
    [self setIsMonitorThreadEnabled:YES];
}

#pragma mark - Monitor
+ (void)runloopMonitorThread:(NKTraceManager *)aTM{
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:kRunloopMonitorInterval target:self selector:@selector(onTimerFired:) userInfo:aTM repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    while (aTM.isMonitorThreadEnabled) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kRunloopMonitorInterval*10]];
    }
}

+ (void)onTimerFired:(NSTimer *)aTimer{
    NKTraceManager *tm = aTimer.userInfo;
    if(!tm.monitorRunloopSTime){
    }
    else if(tm.monitorRunloopETime){
    }
    else{
        double duration = [[NSDate date] timeIntervalSince1970]-tm.monitorRunloopSTime.doubleValue;
        if(duration>tm.monitorTimeoutLimit){
            [tm walkThreads];
        }
    }
}

#pragma mark - Aux
- (long)loadAddress{
    static long sLoadAddress = 0;
    if(sLoadAddress>0)
        return sLoadAddress;
    NSString *elfName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
    Dl_info dlinfo;
    /* Fetch the dlinfo for main() */
    if (dladdr(main, &dlinfo) == 0 || dlinfo.dli_fbase == NULL) {
        return NO;
    }
    NSString *tmpStr = [NSString stringWithCString:dlinfo.dli_fname encoding:NSUTF8StringEncoding];
    if([[tmpStr lastPathComponent] isEqualToString:elfName])
        sLoadAddress = (uint32_t)dlinfo.dli_fbase;
    return sLoadAddress;
}

#pragma mark - Lookup thread & frame infos.
- (void)walkThreads{
    thread_act_array_t threads;
    mach_msg_type_number_t thread_count;
    
    /* Threads */
    task_t taskt = mach_task_self();
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    thread_t curThread = mach_thread_self();
    /* Get a list of all threads */
    if (task_threads(taskt, &threads, &thread_count) != KERN_SUCCESS) {
        nk_log("Fetching thread list failed");
        thread_count = 0;
    }
    /* Suspend each thread and write out its state */
    // Walk threads
    for (mach_msg_type_number_t i = 0; i < thread_count; i++) {
        thread_t thread = threads[i];
        bool suspend_thread = true;
        /* Check if we're running on the to be examined thread */
        if (MACH_PORT_INDEX(self.monitorThreadId) == MACH_PORT_INDEX(thread)) {
            suspend_thread = false;
        }
        if(thread == curThread)
            continue;
        /* Suspend the thread */
        if (suspend_thread && thread_suspend(thread) != KERN_SUCCESS) {
            nk_log("Could not suspend thread %d", i);
            continue;
        }
        //Walk frames
        plframe_cursor_t cursor;
        plframe_error_t ferr;
        /* Set up the frame cursor. */
        ferr = plframe_cursor_thread_init(&cursor, thread);
        /* Did cursor initialization succeed? */
        if (ferr != PLFRAME_ESUCCESS) {
            nk_log("An error occured initializing the frame cursor: %s", plframe_strerror(ferr));
        }
        /* Walk the stack */
        NSMutableArray *array = [NSMutableArray array];
        while ((ferr = plframe_cursor_next(&cursor)) == PLFRAME_ESUCCESS) {
            plframe_error_t err;
            /* PC */
            plframe_greg_t pc = 0;
            if ((err = plframe_get_reg(&cursor, PLFRAME_REG_IP, &pc)) != PLFRAME_ESUCCESS) {
                nk_log("Could not retrieve frame PC register: %s", plframe_strerror(err));
            }
            [array addObject:@((uint64_t)pc-[self loadAddress])];
        }
        [dict setObject:array forKey:@(thread)];
        /* Did we reach the end successfully? */
        if (ferr != PLFRAME_ENOFRAME)
            nk_log("Terminated stack walking early: %s", plframe_strerror(ferr));
        /* Resume the thread */
        if (suspend_thread)
            thread_resume(thread);
    }
    if(self.timeoutBlock){
        self.timeoutBlock(dict);
    }
    /* Clean up the thread array */
    for (mach_msg_type_number_t i = 0; i < thread_count; i++)
        mach_port_deallocate(mach_task_self(), threads[i]);
    vm_deallocate(mach_task_self(), (vm_address_t)threads, sizeof(thread_t) * thread_count);
}
@end