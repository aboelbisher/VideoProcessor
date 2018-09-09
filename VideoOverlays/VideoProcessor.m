//
//  VideoProcessor.m
//  Vibes
//
//  Created by Muhammad Abed Ekrazek on 8/15/18.
//  Copyright © 2018 MuzeLabs. All rights reserved.
//

#import "VideoProcessor.h"

#define DEGREES_TO_RADIANS(degrees)((M_PI * degrees)/180)

@interface VideoProcessor()

@property(nonatomic) CGSize frontSize;
@property(nonatomic) CGPoint frontOrigin;


@end

@implementation VideoProcessor


- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _frontSize = CGSizeZero;
    }
    return self;
}




-(void) mergeBgVideo:(NSURL*)bgVideo withForeGroundVideo:(NSURL*)foreGVideo frontVideoSize:(CGSize)frontSize frontOrigin:(CGPoint)frontOrigin completion:(void(^)(NSURL*))callback
{
    _frontSize = frontSize;
    _frontOrigin = frontOrigin;
    
    __block NSURL * bgSquareVideoUrl;
    __block NSURL * foreGroundSquareVideoUrl;
    dispatch_group_t croppVideosGroup = dispatch_group_create();
    
    NSLog(@"cropping bg video...");
    dispatch_group_enter(croppVideosGroup);
    [self cropSquareVideoWithUrl:bgVideo makeItCircle:NO completionHandler:^(NSURL* croppedBgUrl) {
        
        bgSquareVideoUrl = croppedBgUrl;
        dispatch_group_leave(croppVideosGroup);
        
        if (croppedBgUrl != NULL)
        {
            NSLog(@"cropping bg video finished");
        }
    }];
    
    
    NSLog(@"cropping foreG video ...");
    dispatch_group_enter(croppVideosGroup);
    [self cropSquareVideoWithUrl:foreGVideo makeItCircle:NO completionHandler:^(NSURL* croppedForeGUrl) {
        
        foreGroundSquareVideoUrl = croppedForeGUrl;
        dispatch_group_leave(croppVideosGroup);
        
        if (croppedForeGUrl != NULL)
        {
            NSLog(@"cropping fore ground video finished");
        }
        
    }];
    
    dispatch_group_notify(croppVideosGroup,dispatch_get_main_queue(),^{
        
        if (bgSquareVideoUrl == NULL)
        {
            NSLog(@"bgSquareVideoUrl is NULL");
            return;
        }
        if (foreGroundSquareVideoUrl == NULL)
        {
            NSLog(@"foreGroundSquareVideoUrl is NULL");
            return;
        }
        
        
//        callback(foreGroundSquareVideoUrl);
//        return;
        
        NSLog(@"merging the two cropped videos");
        
        AVAsset* frontAsset = [AVAsset assetWithURL:foreGroundSquareVideoUrl];
        AVAsset* backAsset = [AVAsset assetWithURL:bgSquareVideoUrl];
        
        AVMutableComposition* mixComposition = [[AVMutableComposition alloc] init];
        
        AVMutableCompositionTrack *frontVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [frontVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, frontAsset.duration)
                                 ofTrack:[[frontAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                                  atTime:kCMTimeZero error:nil];
        
        
        AVMutableCompositionTrack *backVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [backVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, backAsset.duration) ofTrack:[[backAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
        
        
        AVMutableCompositionTrack *frontAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [frontAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, frontAsset.duration)
                                 ofTrack:[[frontAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
                                  atTime:kCMTimeZero error:nil];

        
        AVMutableVideoCompositionInstruction * MainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        
        //see what the duration will be
        MainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero,frontAsset.duration);
        
        AVMutableVideoCompositionLayerInstruction *frontLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:frontVideoTrack];
        frontLayerInstruction.trackID = 1;
        [self fixOrientation:frontLayerInstruction withAsset:frontAsset];// withTransform:(CGAffineTransformConcat(frontScale, frontMove))];
        
        AVMutableVideoCompositionLayerInstruction *backLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:backVideoTrack];
        backLayerInstruction.trackID = 2;
        [self fixOrientation:backLayerInstruction withAsset:backAsset];
        
        MainInstruction.layerInstructions = [NSArray arrayWithObjects:frontLayerInstruction,backLayerInstruction,nil];;
        
        AVMutableVideoComposition *MainCompositionInst = [AVMutableVideoComposition videoComposition];
        MainCompositionInst.instructions = [NSArray arrayWithObject:MainInstruction];
        MainCompositionInst.customVideoCompositorClass = [MuzeCircleMergeVideoComposer class];
        MainCompositionInst.frameDuration = CMTimeMake(1, 30);
        MainCompositionInst.renderSize = backVideoTrack.naturalSize;
        
        NSString *myPathDocs = [self getFilePathWithExtension:@"mp4"];//[documentsDirectory stringByAppendingPathComponent:@"overlapVideo.mp4"];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:myPathDocs])
        {
            [[NSFileManager defaultManager] removeItemAtPath:myPathDocs error:nil];
        }
        
        NSURL *url = [NSURL fileURLWithPath:myPathDocs];
        
        AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
        exporter.outputURL=url;
        exporter.videoComposition = MainCompositionInst;
        
        MuzeCircleMergeVideoComposer* compositor = (MuzeCircleMergeVideoComposer*) exporter.customVideoCompositor;
        compositor.delegate = self;
        
        exporter.outputFileType = AVFileTypeMPEG4;
        
        [exporter exportAsynchronouslyWithCompletionHandler:^
         {
             if(exporter.status == AVAssetExportSessionStatusCompleted)
             {
                 NSLog(@"compleeeteteted");
             }
             else
             {
                 NSLog(@"error , %@", exporter.error);
                 
             }
             dispatch_async(dispatch_get_main_queue(), ^{
                 callback(url);
             });
         }];
    });
}


-(void)fixOrientation:(AVMutableVideoCompositionLayerInstruction*)videolayerInstruction withAsset:(AVAsset*)videoAsset withTransform:(CGAffineTransform)trans
{
    AVAssetTrack *videoAssetTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    //    UIImageOrientation videoAssetOrientation_  = UIImageOrientationUp;
    //    BOOL isVideoAssetPortrait_ = NO;
    //    CGAffineTransform videoTransform = videoAssetTrack.preferredTransform;
    //    if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0)
    //    {
    //        videoAssetOrientation_ = UIImageOrientationRight;
    //        isVideoAssetPortrait_ = YES;
    //    }
    //    if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0)
    //    {
    //        videoAssetOrientation_ =  UIImageOrientationLeft;
    //        isVideoAssetPortrait_ = YES;
    //    }
    //    if (videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0)
    //    {
    //        videoAssetOrientation_ =  UIImageOrientationUp;
    //    }
    //    if (videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0)
    //    {
    //        videoAssetOrientation_ = UIImageOrientationDown;
    //    }
    
    [videolayerInstruction setTransform:CGAffineTransformConcat(videoAssetTrack.preferredTransform,trans) atTime:kCMTimeZero];
}

-(void)fixOrientation:(AVMutableVideoCompositionLayerInstruction*)videolayerInstruction withAsset:(AVAsset*)videoAsset
{
    AVAssetTrack *videoAssetTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    [videolayerInstruction setTransform:videoAssetTrack.preferredTransform atTime:kCMTimeZero];
}

-(void)cropAsCircleWithComposistion:(AVMutableVideoComposition*)composition size:(CGSize)size
{
    // 1 - Layer setup
    CALayer *parentLayer = [CALayer layer];
    CALayer *videoLayer = [CALayer layer];
    
    parentLayer.frame = CGRectMake(0, 0, size.width, size.height);
    videoLayer.frame = CGRectMake(0, 0, size.width, size.height);
    
    [parentLayer addSublayer:videoLayer];
    
    [videoLayer setCornerRadius:size.height / 2];
    [videoLayer setMasksToBounds:YES];
    
    [videoLayer setBackgroundColor:[UIColor redColor].CGColor];
    [parentLayer setBackgroundColor:[UIColor clearColor].CGColor];

    

    // 5 - Composition
    composition.animationTool = [AVVideoCompositionCoreAnimationTool
                                 videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
}


-(void)cropSquareVideoWithUrl:(NSURL*)url makeItCircle:(BOOL)isCricle completionHandler:(void(^)(NSURL*))callback
{
    NSString* outputPath = [self getFilePathWithExtension:@"mp4"];///[docFolder stringByAppendingPathComponent:@"croppedVideo.mp4"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
        
    }
    
    // input file
    AVAsset* asset = [AVAsset assetWithURL:url];
    
    AVMutableComposition *composition = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *videoTrack = [composition  addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                        ofTrack:[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                         atTime:kCMTimeZero error:nil];

    
    
    
    AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                        ofTrack:[[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
                         atTime:kCMTimeZero error:nil];

    
    // input clip
    AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    // make it square
    AVMutableVideoComposition* videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.renderSize = CGSizeMake(clipVideoTrack.naturalSize.height, clipVideoTrack.naturalSize.height);
    
    videoComposition.frameDuration = CMTimeMake(1, 30);
    if (isCricle)
    {
        [self cropAsCircleWithComposistion:videoComposition size:videoComposition.renderSize];
    }
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(60, 30) );
    
    // rotate to portrait
    AVMutableVideoCompositionLayerInstruction* transformer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:clipVideoTrack];
    CGAffineTransform t1 = CGAffineTransformMakeTranslation(clipVideoTrack.naturalSize.height, -(clipVideoTrack.naturalSize.width - clipVideoTrack.naturalSize.height) /2 );
    CGAffineTransform t2 = CGAffineTransformRotate(t1, M_PI_2);
    
    CGAffineTransform finalTransform = t2;
    [transformer setTransform:finalTransform atTime:kCMTimeZero];
    instruction.layerInstructions = [NSArray arrayWithObject:transformer];
    videoComposition.instructions = [NSArray arrayWithObject: instruction];
    
    // export
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHighestQuality] ;
    exporter.videoComposition = videoComposition;
    exporter.outputURL=[NSURL fileURLWithPath:outputPath];
    exporter.outputFileType = AVFileTypeMPEG4;
    
    [exporter exportAsynchronouslyWithCompletionHandler:^(void){
        if(exporter.status == AVAssetExportSessionStatusCompleted)
        {
            callback(exporter.outputURL);
        }
        else
        {
            NSLog(@"error cropping video : %@", exporter.error);
            callback(NULL);
        }
    }];
}


-(NSString*)getFilePathWithExtension:(NSString*)extension
{
    NSString* docFolder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    double date = round([[NSDate date] timeIntervalSince1970]) * 1000;
    
    CFUUIDRef udid = CFUUIDCreate(NULL);
    NSString *udidString = (NSString *) CFBridgingRelease(CFUUIDCreateString(NULL, udid));
    NSString* videoName = [NSString stringWithFormat:@"croppedVideo_%@_%f.%@",udidString, date, extension];

    NSString* outputPath = [docFolder stringByAppendingPathComponent:videoName];
    return outputPath;
}


- (CGSize)customVideoCompositorDelegateGetFrontSize
{
    return _frontSize;
}

- (CGPoint)customVideoCompositorDelegateGetOrigin
{
    return _frontOrigin;
}
@end
















