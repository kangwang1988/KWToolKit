//
//  NKHomeController.m
//  KWToolKit
//
//  Created by KyleWong on 4/18/16.
//  Copyright © 2016 KyleWong. All rights reserved.
//

#import "NKHomeController.h"
#import "View+MASAdditions.h"
#import "NKStuckTraceController.h"

NSString * kFeatureUIStuck = @"UI卡顿跟踪";

@interface NKHomeController ()<UITableViewDataSource,UITableViewDelegate>
@property (nonatomic,strong) NSMutableArray *dataSource;
@end

@implementation NKHomeController
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self setTitle:@"特性"];
    [self setDataSource:[@[kFeatureUIStuck] mutableCopy]];
    UITableView *tableView = [UITableView new];
    [tableView setDataSource:self];
    [tableView setDelegate:self];
    [self.view addSubview:tableView];
    [tableView setTableFooterView:[[UIView alloc] initWithFrame:CGRectZero]];
    [tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.width.height.equalTo(self.view);
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *reuseIdentifier = @"reuseIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if(!cell){
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    }
    [cell.textLabel setText:[self.dataSource objectAtIndex:indexPath.row]];
    return cell;
}

#pragma mark - UITableVideDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    NSString *feature = [self.dataSource objectAtIndex:indexPath.row];
    NKCommonController *cc = nil;
    if([feature isEqualToString:kFeatureUIStuck]){
        cc = [NKStuckTraceController new];
    }
    if(cc){
        [cc setTitle:feature];
        [self.navigationController pushViewController:cc animated:YES];
    }
}
@end