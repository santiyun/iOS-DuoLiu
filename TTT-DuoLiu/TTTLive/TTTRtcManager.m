//
//  TTTRtcManager.m
//  TTTLive
//
//  Created by yanzhen on 2018/8/21.
//  Copyright © 2018年 yanzhen. All rights reserved.
//

#import "TTTRtcManager.h"

@implementation TTTRtcManager
static id _manager;
+ (instancetype)manager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manager = [[self alloc] init];
    });
    return _manager;
}

+(instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manager = [super allocWithZone:zone];
    });
    return _manager;
}

- (id)copyWithZone:(NSZone *)zone
{
    return _manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        //a967ac491e3acf92eed5e1b5ba641ab7
        _rtcEngine = [TTTRtcEngineKit sharedEngineWithAppId:@"test900572e02867fab8131651339518" delegate:nil];
        _me = [[TTTUser alloc] initWith:0];
    }
    return self;
}

- (UIImage *)getVoiceImage:(NSUInteger)level {
    UIImage *image = nil;
    if (level < 4) {
        image = [UIImage imageNamed:@"volume_1"];
    } else if (level < 7) {
        image = [UIImage imageNamed:@"volume_2"];
    } else {
        image = [UIImage imageNamed:@"volume_3"];
    }
    return image;
}
@end