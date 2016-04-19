//
//  NKStuckTraceController.m
//  KWToolKit
//
//  Created by KyleWong on 4/18/16.
//  Copyright © 2016 KyleWong. All rights reserved.
//

#import "NKStuckTraceController.h"

@interface NKStuckTraceController ()
@property (nonatomic,assign) BOOL isShowing;
@end

@implementation NKStuckTraceController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self setIsShowing:YES];
    [self performSelector:@selector(doEndlessLoop) withObject:nil afterDelay:1.f];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self setIsShowing:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)doEndlessLoop{
    NSDate *date = [NSDate date];
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setDateFormat:@"YYYY-MM-dd hh:mm:ss"];
    NSString *str = [formatter stringFromDate:date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    for(NSInteger i = 0;i<100;i++){
        date = [NSDate date];
        formatter = [NSDateFormatter new];
        [formatter setDateFormat:@"YYYY-MM-dd hh:mm:ss"];
        str = [formatter stringFromDate:date];
        calendar = [NSCalendar currentCalendar];
    }
    
    if(self.isShowing)
        [self doEndlessLoop];
}
@end
