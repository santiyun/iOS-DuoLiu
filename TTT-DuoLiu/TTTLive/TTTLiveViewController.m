//
//  TTTLiveViewController.m
//  TTTLive
//
//  Created by yanzhen on 2018/8/21.
//  Copyright © 2018年 yanzhen. All rights reserved.
//

#import "TTTLiveViewController.h"
#import "TTTVideoPosition.h"
#import "TTTAVRegion.h"

@interface TTTLiveViewController ()<TTTRtcEngineDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *anchorVideoView;
@property (weak, nonatomic) IBOutlet UIButton *voiceBtn;
@property (weak, nonatomic) IBOutlet UIButton *switchBtn;
@property (weak, nonatomic) IBOutlet UILabel *roomIDLabel;
@property (weak, nonatomic) IBOutlet UILabel *anchorIdLabel;
@property (weak, nonatomic) IBOutlet UILabel *audioStatsLabel;
@property (weak, nonatomic) IBOutlet UILabel *videoStatsLabel;
@property (weak, nonatomic) IBOutlet UIView *avRegionsView;

@property (nonatomic, strong) NSMutableArray<TTTUser *> *users;
@property (nonatomic, strong) NSMutableArray<TTTAVRegion *> *avRegions;
@property (nonatomic, strong) TTTRtcVideoCompositingLayout *videoLayout;
//主播大窗口设备Id
@property (nonatomic, copy) NSString *anchorMainDevId;
@end

@implementation TTTLiveViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _users = [NSMutableArray array];
    _avRegions = [NSMutableArray arrayWithCapacity:6];
    
    _roomIDLabel.text = [NSString stringWithFormat:@"房号: %lld", TTManager.roomID];
    [_users addObject:TTManager.me];
    for (UIView *subView in _avRegionsView.subviews) {
        if ([subView isKindOfClass:[TTTAVRegion class]]) {
            [_avRegions addObject:(TTTAVRegion *)subView];
        }
    }
    TTManager.rtcEngine.delegate = self;
    if (TTManager.me.clientRole == TTTRtc_ClientRole_Anchor) {
        _anchorIdLabel.text = [NSString stringWithFormat:@"主播ID: %lld", TTManager.me.uid];
        [TTManager.rtcEngine startPreview];
        TTTRtcVideoCanvas *videoCanvas = [[TTTRtcVideoCanvas alloc] init];
        videoCanvas.renderMode = TTTRtc_Render_Adaptive;
        videoCanvas.uid = TTManager.me.uid;
        videoCanvas.view = _anchorVideoView;
        [TTManager.rtcEngine setupLocalVideo:videoCanvas];
        //for sei
        _videoLayout = [[TTTRtcVideoCompositingLayout alloc] init];
        _videoLayout.canvasWidth = 360;
        _videoLayout.canvasHeight = 640;
        _videoLayout.backgroundColor = @"#e8e6e8";
    } else if (TTManager.me.clientRole == TTTRtc_ClientRole_Broadcaster) {
        [TTManager.rtcEngine startPreview];
        _switchBtn.hidden = YES;
    }
    //必须确保UI更新完成，否则接受SEI可能找不到对应位置-iPhone5c
    [self.view layoutIfNeeded];
}

- (IBAction)leftBtnsAction:(UIButton *)sender {
    if (sender.tag == 1001) {
        if (TTManager.me.isAnchor) {
            sender.selected = !sender.isSelected;
            TTManager.me.mutedSelf = sender.isSelected;
            [TTManager.rtcEngine muteLocalAudioStream:sender.isSelected];
        }
    } else {
        [TTManager.rtcEngine switchCamera];
    }
}

- (IBAction)exitChannel:(id)sender {
    UIAlertController *alert  = [UIAlertController alertControllerWithTitle:@"提示" message:@"您确定要退出房间吗？" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIAlertAction *sureAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [TTManager.rtcEngine leaveChannel:nil];
    }];
    [alert addAction:sureAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - TTTRtcEngineDelegate

-(void)rtcEngine:(TTTRtcEngineKit *)engine didJoinedOfUid:(int64_t)uid clientRole:(TTTRtcClientRole)clientRole isVideoEnabled:(BOOL)isVideoEnabled elapsed:(NSInteger)elapsed {
    TTTUser *user = [[TTTUser alloc] initWith:uid];
    user.clientRole = clientRole;
    [_users addObject:user];
    if (clientRole == TTTRtc_ClientRole_Anchor) {
        _anchorIdLabel.text = [NSString stringWithFormat:@"主播ID: %lld", uid];
    } else {
        if (TTManager.me.isAnchor) {
            [self refreshVideoCompositingLayout];
        }
    }
}

//通过该方法获取设备状态--enable=YES认为是新增设备，enable=NO认为是减少的设备
- (void)rtcEngine:(TTTRtcEngineKit *)engine didVideoEnabled:(BOOL)enabled deviceId:(NSString *)devId byUid:(int64_t)uid {
    NSLog(@"3TFunc------%lld: %@ %d",uid, devId, enabled);
    if (enabled) {
        if (TTManager.me.isAnchor) {
            TTTUser *user = [[TTTUser alloc] initWith:uid];
            [[self getAvaiableAVRegion] configureRegion:user deviceId:devId];
            [self refreshVideoCompositingLayout];
        }
    } else {
        [[self getAVRegion:uid devId:devId] closeRegion];
    }
}

- (void)rtcEngine:(TTTRtcEngineKit *)engine onSetSEI:(NSString *)SEI {
    NSLog(@"3TLogSEI------%@",SEI);
    if (TTManager.me.isAnchor) { return; }
    NSData *seiData = [SEI dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:seiData options:NSJSONReadingMutableLeaves error:nil];
    NSArray<NSDictionary *> *posArray = json[@"pos"];
    for (NSDictionary *obj in posArray) {
        NSString *devId = obj[@"id"];
        int64_t uid = [devId longLongValue];
        TTTUser *user = [self getUser:uid];
        //非主播通过SEI打开
        if ([obj[@"w"] intValue] != 1 && [obj[@"w"] intValue] != 1) {
            if (![self getAVRegion:uid devId:devId]) {
                TTTVideoPosition *videoPosition = [[TTTVideoPosition alloc] init];
                videoPosition.x = [obj[@"x"] doubleValue];
                videoPosition.y = [obj[@"y"] doubleValue];
                videoPosition.w = [obj[@"w"] doubleValue];
                videoPosition.h = [obj[@"h"] doubleValue];
                [[self positionAVRegion:videoPosition] configureRegion:user deviceId:devId];
            }
        } else {
            //未考虑主播切换主摄像头
            if (![self.anchorMainDevId isEqualToString:devId]) {
                TTTRtcVideoCanvas *videoCanvas = [[TTTRtcVideoCanvas alloc] init];
                videoCanvas.renderMode = TTTRtc_Render_Adaptive;
                videoCanvas.deviceId = devId;
                videoCanvas.uid = uid;
                videoCanvas.view = _anchorVideoView;
                [engine setupRemoteVideo:videoCanvas];
                self.anchorMainDevId = devId;
            }
        }
    }
}

- (void)rtcEngine:(TTTRtcEngineKit *)engine didOfflineOfUid:(int64_t)uid reason:(TTTRtcUserOfflineReason)reason {
    TTTUser *user = [self getUser:uid];
    if (!user) { return; }
    [_avRegions enumerateObjectsUsingBlock:^(TTTAVRegion * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.user.uid == uid) {
            [obj closeRegion];
        }
    }];
    [_users removeObject:user];
}

- (void)rtcEngine:(TTTRtcEngineKit *)engine remoteVideoStats:(TTTRtcRemoteVideoStats *)stats {
    TTTUser *user = [self getUser:stats.uid];
    if (!user) { return; }
    if (user.isAnchor && [stats.deviceId isEqualToString:_anchorMainDevId]) {
        _videoStatsLabel.text = [NSString stringWithFormat:@"V-↓%ldkbps", stats.receivedBitrate];
    } else {
        [[self getAVRegion:stats.uid devId:stats.deviceId] setRemoterVideoStats:stats.receivedBitrate];
    }
}
#pragma mark - normal
- (void)rtcEngine:(TTTRtcEngineKit *)engine reportAudioLevel:(int64_t)userID audioLevel:(NSUInteger)audioLevel audioLevelFullRange:(NSUInteger)audioLevelFullRange {
    TTTUser *user = [self getUser:userID];
    if (!user) { return; }
    if (user.isAnchor) {
        [_voiceBtn setImage:[self getVoiceImage:audioLevel] forState:UIControlStateNormal];
    } else {
        [[self getAVRegion:userID devId:nil] reportAudioLevel:audioLevel];
    }
}

- (void)rtcEngine:(TTTRtcEngineKit *)engine didAudioMuted:(BOOL)muted byUid:(int64_t)uid {
    TTTUser *user = [self getUser:uid];
    if (!user) { return; }
    user.mutedSelf = muted;
    [[self getAVRegion:uid devId:nil] mutedSelf:muted];
}

- (void)rtcEngine:(TTTRtcEngineKit *)engine localAudioStats:(TTTRtcLocalAudioStats *)stats {
    if (TTManager.me.isAnchor) {
        _audioStatsLabel.text = [NSString stringWithFormat:@"A-↑%ldkbps", stats.sentBitrate];
    } else {
        [[self getAVRegion:TTManager.me.uid devId:nil] setLocalAudioStats:stats.sentBitrate];
    }
}

- (void)rtcEngine:(TTTRtcEngineKit *)engine localVideoStats:(TTTRtcLocalVideoStats *)stats {
    if (TTManager.me.isAnchor) {
        _videoStatsLabel.text = [NSString stringWithFormat:@"V-↑%ldkbps", stats.sentBitrate];
    } else {
        [[self getAVRegion:TTManager.me.uid devId:nil] setLocalVideoStats:stats.sentBitrate];
    }
}

- (void)rtcEngine:(TTTRtcEngineKit *)engine remoteAudioStats:(TTTRtcRemoteAudioStats *)stats {
    TTTUser *user = [self getUser:stats.uid];
    if (!user) { return; }
    if (user.isAnchor) {
        _audioStatsLabel.text = [NSString stringWithFormat:@"A-↓%ldkbps", stats.receivedBitrate];
    } else {
        [[self getAVRegion:stats.uid devId:nil] setRemoterAudioStats:stats.receivedBitrate];
    }
}

- (void)rtcEngine:(TTTRtcEngineKit *)engine didLeaveChannelWithStats:(TTTRtcStats *)stats {
    [engine stopPreview];
    [self dismissViewControllerAnimated:true completion:nil];
}

- (void)rtcEngineConnectionDidLost:(TTTRtcEngineKit *)engine {
    [TTProgressHud showHud:self.view message:@"网络链接丢失，正在重连..."];
}

- (void)rtcEngineReconnectServerTimeout:(TTTRtcEngineKit *)engine {
    [TTProgressHud hideHud:self.view];
    [self.view.window showToast:@"网络丢失，请检查网络"];
    [engine leaveChannel:nil];
    [engine stopPreview];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)rtcEngineReconnectServerSucceed:(TTTRtcEngineKit *)engine {
    [TTProgressHud hideHud:self.view];
}

- (void)rtcEngine:(TTTRtcEngineKit *)engine didKickedOutOfUid:(int64_t)uid reason:(TTTRtcKickedOutReason)reason {
    NSString *errorInfo = @"";
    switch (reason) {
        case TTTRtc_KickedOut_KickedByHost:
            errorInfo = @"被主播踢出";
            break;
        case TTTRtc_KickedOut_PushRtmpFailed:
            errorInfo = @"rtmp推流失败";
            break;
        case TTTRtc_KickedOut_MasterExit:
            errorInfo = @"主播已退出";
            break;
        case TTTRtc_KickedOut_ReLogin:
            errorInfo = @"重复登录";
            break;
        case TTTRtc_KickedOut_NewChairEnter:
            errorInfo = @"其他人以主播身份进入";
            break;
        default:
            errorInfo = @"未知错误";
            break;
    }
    [self.view.window showToast:errorInfo];
}

#pragma mark - helper mehtod
- (TTTAVRegion *)getAvaiableAVRegion {
    __block TTTAVRegion *region = nil;
    [_avRegions enumerateObjectsUsingBlock:^(TTTAVRegion * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (!obj.user) {
            region = obj;
            *stop = YES;
        }
    }];
    return region;
}

- (TTTAVRegion *)getAVRegion:(int64_t)uid devId:(NSString *)devId {
    __block TTTAVRegion *region = nil;
    [_avRegions enumerateObjectsUsingBlock:^(TTTAVRegion * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.user.uid == uid) {
            if (devId) {
                if ([devId isEqualToString:obj.devId]) {
                    region = obj;
                    *stop = YES;
                }
            } else {
                region = obj;
                *stop = YES;
            }
        }
    }];
    return region;
}

- (TTTUser *)getUser:(int64_t)uid {
    __block TTTUser *user = nil;
    [_users enumerateObjectsUsingBlock:^(TTTUser * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.uid == uid) {
            user = obj;
            *stop = YES;
        }
    }];
    return user;
}

- (void)refreshVideoCompositingLayout {
    TTTRtcVideoCompositingLayout *videoLayout = _videoLayout;
    if (!videoLayout) { return; }
    [videoLayout.regions removeAllObjects];
    TTTRtcVideoCompositingRegion *anchorRegion = [[TTTRtcVideoCompositingRegion alloc] init];
    anchorRegion.uid = TTManager.me.uid;
    anchorRegion.x = 0;
    anchorRegion.y = 0;
    anchorRegion.width = 1;
    anchorRegion.height = 1;
    anchorRegion.zOrder = 0;
    anchorRegion.alpha = 1;
    anchorRegion.renderMode = TTTRtc_Render_Adaptive;
    [videoLayout.regions addObject:anchorRegion];
    [_avRegions enumerateObjectsUsingBlock:^(TTTAVRegion * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.user) {
            TTTRtcVideoCompositingRegion *videoRegion = [[TTTRtcVideoCompositingRegion alloc] init];
            videoRegion.uid = obj.user.uid;
            videoRegion.deviceId = obj.devId;
            videoRegion.x = obj.videoPosition.x;
            videoRegion.y = obj.videoPosition.y;
            videoRegion.width = obj.videoPosition.w;
            videoRegion.height = obj.videoPosition.h;
            videoRegion.zOrder = 1;
            videoRegion.alpha = 1;
            videoRegion.renderMode = TTTRtc_Render_Adaptive;
            [videoLayout.regions addObject:videoRegion];
        }
    }];
    [TTManager.rtcEngine setVideoCompositingLayout:videoLayout];
}

- (TTTAVRegion *)positionAVRegion:(TTTVideoPosition *)position {
    __block TTTAVRegion *region = nil;
    [_avRegions enumerateObjectsUsingBlock:^(TTTAVRegion * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (position.column == obj.videoPosition.column && position.row == obj.videoPosition.row) {
            region = obj;
            *stop = YES;
        }
    }];
    return region;
}

- (UIImage *)getVoiceImage:(NSUInteger)level {
    if (TTManager.me.mutedSelf && TTManager.me.isAnchor) {
        return [UIImage imageNamed:@"audio_close"];
    }
    return [TTManager getVoiceImage:level];
}

@end
