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
        _shouldStroke = YES;
    }
    return self;
}




-(void) mergeBgVideo:(NSURL*)bgVideo withForeGroundVideo:(NSURL*)foreGVideo frontVideoSize:(CGSize)frontSize frontOrigin:(CGPoint)frontOrigin musicSoundUrl:(NSURL*)soundUrl volume:(float)soundUrlVolume completion:(void(^)(NSURL*))callback
{
    _frontSize = frontSize;
    _frontOrigin = frontOrigin;
    
    __block NSURL * bgSquareVideoUrl;
    __block NSURL * foreGroundSquareVideoUrl;
    dispatch_group_t croppVideosGroup = dispatch_group_create();
    
    
    
    
    
    AVAsset* frontAsset = [AVAsset assetWithURL:foreGVideo];
    AVAsset* bgAsset = [AVAsset assetWithURL:bgVideo];
    
    
//    NSArray * arr = [NSArray arrayWithObjects: frontAsset, frontAsset , nil];
//    dispatch_group_enter(croppVideosGroup);
//    [self combineAssets:arr completionHandler:^(NSURL* finalUrl) {
//
//        dispatch_group_leave(croppVideosGroup);
//
//        if (finalUrl != NULL)
//        {
//            callback(finalUrl);
//            NSLog(@"merging finished");
//        }
//
//    }];
//    return
    
    NSLog(@"cropping bg video...");
    dispatch_group_enter(croppVideosGroup);
    [self cropSquareVideoWithUrl:bgVideo completionHandler:^(NSURL* croppedBgUrl) {
        
        if (croppedBgUrl != NULL)
        {
            NSLog(@"cropping bg video finished");

            [self repeatVideo:croppedBgUrl mustBeVideoTime:frontAsset.duration completionHandler:^(NSURL * repeatedCroppedVideo) {
                
                bgSquareVideoUrl = repeatedCroppedVideo;
                dispatch_group_leave(croppVideosGroup);

                if (repeatedCroppedVideo != NULL)
                {
                    NSLog(@"repeated bg video finished");
                }
            }];
        }
        else
        {
            dispatch_group_leave(croppVideosGroup);
        }
    }];

    
    NSLog(@"cropping foreG video ...");
    dispatch_group_enter(croppVideosGroup);
    [self cropSquareVideoWithUrl:foreGVideo  completionHandler:^(NSURL* croppedForeGUrl) {
        
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
        
        
        AVMutableVideoCompositionInstruction * mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        
//        //see what the duration will be
        mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero,frontAsset.duration);
        
        AVMutableVideoCompositionLayerInstruction *frontLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:frontVideoTrack];
        frontLayerInstruction.trackID = 1;
        [self fixOrientation:frontLayerInstruction withAsset:frontAsset];
        
        AVMutableVideoCompositionLayerInstruction *backLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:backVideoTrack];
        backLayerInstruction.trackID = 2;
        [self fixOrientation:backLayerInstruction withAsset:backAsset];
        
        mainInstruction.layerInstructions = [NSArray arrayWithObjects:frontLayerInstruction,backLayerInstruction,nil];;
        
        AVMutableVideoComposition *MainCompositionInst = [AVMutableVideoComposition videoComposition];
        MainCompositionInst.instructions = [NSArray arrayWithObject:mainInstruction];
        MainCompositionInst.customVideoCompositorClass = [MuzeCircleMergeVideoComposer class];
        MainCompositionInst.frameDuration = CMTimeMake(1, 30);
        MainCompositionInst.renderSize = backVideoTrack.naturalSize;
        
        NSString *myPathDocs = [self getFilePathWithExtension:@"mp4"];
        
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
        
        if (soundUrl != nil)
        {
            AVAsset* soundAsset = [AVAsset assetWithURL:soundUrl];
            
            AVMutableCompositionTrack *soundTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            [soundTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, frontAsset.duration)
                                ofTrack:[[soundAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
                                 atTime:kCMTimeZero error:nil];
            
            // Set the parameters of the mix being applied
            AVMutableAudioMixInputParameters *mixParameters = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:soundTrack];
            [mixParameters setVolume:0.05 atTime:kCMTimeZero];
            // Add the parameters to the audio mix
            AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
            [audioMix setInputParameters:@[mixParameters]];
            exporter.audioMix = audioMix;
            
        }
        
        
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

//-(void)cropAsCircleWithComposistion:(AVMutableVideoComposition*)composition size:(CGSize)size
//{
//    // 1 - Layer setup
//    CALayer *parentLayer = [CALayer layer];
//    CALayer *videoLayer = [CALayer layer];
//
//    parentLayer.frame = CGRectMake(0, 0, size.width, size.height);
//    videoLayer.frame = CGRectMake(0, 0, size.width, size.height);
//
//    [parentLayer addSublayer:videoLayer];
//
//    [videoLayer setCornerRadius:size.height / 2];
//    [videoLayer setMasksToBounds:YES];
//
//    [videoLayer setBackgroundColor:[UIColor redColor].CGColor];
//    [parentLayer setBackgroundColor:[UIColor clearColor].CGColor];
//
//
//
//    // 5 - Composition
//    composition.animationTool = [AVVideoCompositionCoreAnimationTool
//                                 videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
//}


-(void)cropSquareVideoWithUrl:(NSURL*)url completionHandler:(void(^)(NSURL*))callback
{
    NSString* outputPath = [self getFilePathWithExtension:@"mp4"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
    }
    
    // input file
    AVAsset* asset = [AVAsset assetWithURL:url];
    AVMutableComposition *composition = [AVMutableComposition composition];
    // input clip
    AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    AVMutableCompositionTrack *videoTrack = [composition  addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *audioTrack = [composition  addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];


    [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero,asset.duration )
                        ofTrack:[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                         atTime:kCMTimeZero error:nil];
    
    [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                        ofTrack:[[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
                         atTime:kCMTimeZero error:nil];
    
    
    // make it square
    AVMutableVideoComposition* videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.renderSize = CGSizeMake(clipVideoTrack.naturalSize.height, clipVideoTrack.naturalSize.height);
    
    videoComposition.frameDuration = CMTimeMake(1, 30);
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
    
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

- (Boolean)customVideoCompositorDelegateShouldStrokeFrontCircle
{
    return _shouldStroke;
}




//AVMutableComposition *mixComposition = [AVMutableComposition composition];
//AVMutableCompositionTrack *compositionTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
//NSError * error = nil;
//NSMutableArray * timeRanges = [NSMutableArray arrayWithCapacity:videoClipPaths.count];
//NSMutableArray * tracks = [NSMutableArray arrayWithCapacity:videoClipPaths.count];
//for (int i=0; i<[videoClipPaths count]; i++) {
//    AVURLAsset *assetClip = [videoClipPaths objectAtIndex:i];
//    AVAssetTrack *clipVideoTrackB = [[assetClip tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
//
//    [timeRanges addObject:[NSValue valueWithCMTimeRange:CMTimeRangeMake(kCMTimeZero, assetClip.duration)]];
//    [tracks addObject:clipVideoTrackB];
//}
//[compositionTrack insertTimeRanges:timeRanges ofTracks:tracks atTime:kCMTimeZero error:&error];
//
//AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPreset1280x720];
//NSParameterAssert(exporter != nil);
//NSArray *t;
//NSString *u;
//
//t = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//u = [t objectAtIndex:0];
//NSString *finalPath = [u stringByAppendingPathComponent:@"final.mov"];
//NSURL *lastURL = [NSURL fileURLWithPath:finalPath];
//exporter.outputFileType = AVFileTypeQuickTimeMovie;
//exporter.outputURL = lastURL;
//[exporter exportAsynchronouslyWithCompletionHandler:^(void){
//    switch (exporter.status) {
//        case AVAssetExportSessionStatusFailed:
//            NSLog(@"exporting failed");
//            break;
//        case AVAssetExportSessionStatusCompleted:
//            NSLog(@"exporting completed");
//            //UISaveVideoAtPathToSavedPhotosAlbum(filePath, self, nil, NULL);
//            break;
//        case AVAssetExportSessionStatusCancelled:
//            NSLog(@"export cancelled");
//            break;
//    }
//}];


-(void)repeatVideo:(NSURL*) url mustBeVideoTime:(CMTime)mustBeTime completionHandler:(void(^)(NSURL*))callback
{
    NSString* outputPath = [self getFilePathWithExtension:@"mp4"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
    }
    
    // input file
    AVAsset* asset = [AVAsset assetWithURL:url];
    AVMutableComposition *composition = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *videoTrack = [composition  addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *audioTrack = [composition  addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];

    CMTime totalTime = kCMTimeZero;
    
    if (CMTimeCompare(mustBeTime, asset.duration) != 0) // diferrent
    {
        CMTime currentTime = kCMTimeZero;
        
        while(YES)
        {
            CMTime addedTime = asset.duration;
            totalTime = CMTimeAdd(totalTime, addedTime);
            if (CMTimeCompare(totalTime , mustBeTime) == 1 ) // totalTime > mustBeDuration
            {
                CMTime mustDeleteValue = CMTimeSubtract(totalTime , mustBeTime);
                addedTime = CMTimeSubtract(asset.duration, mustDeleteValue);
                totalTime = CMTimeSubtract(totalTime, mustDeleteValue);
            }

            [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero,addedTime )
                                ofTrack:[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                                 atTime:currentTime error:nil];

            [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, addedTime)
                                ofTrack:[[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
                                 atTime:currentTime error:nil];

            currentTime = CMTimeAdd(currentTime, addedTime);

            if  (CMTimeCompare(currentTime, mustBeTime) == 0)
            {
                break;
            }
        }
    }
    else
    {
        totalTime = asset.duration;
        
        [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero,asset.duration )
                            ofTrack:[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                             atTime:kCMTimeZero error:nil];
        
        [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                            ofTrack:[[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
                             atTime:kCMTimeZero error:nil];
    }
    
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
    
    NSURL *outptVideoUrl = [NSURL fileURLWithPath:outputPath];
    exporter.outputURL=outptVideoUrl;
    exporter.outputFileType =AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if(exporter.status == AVAssetExportSessionStatusCompleted)
            {
                callback(outptVideoUrl);
            }
            else
            {
                NSLog(@"error merging video : %@", exporter.error);
                callback(NULL);
            }
            
        });
    }];
}


-(void)combineAssets:(NSArray*)assets completionHandler:(void(^)(NSURL*))callback
{
    AVMutableComposition *mainComposition = [[AVMutableComposition alloc] init];
    AVMutableCompositionTrack *compositionVideoTrack = [mainComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];

    
    AVMutableCompositionTrack *soundtrackTrack = [mainComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    CMTime insertTime = kCMTimeZero;
    
    for (AVAsset *videoAsset in assets) {
        
        [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:insertTime error:nil];
        
        [soundtrackTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:insertTime error:nil];
        
        // Updating the insertTime for the next insert
        insertTime = CMTimeAdd(insertTime, videoAsset.duration);
    }
    
    NSString *myPathDocs = [self getFilePathWithExtension:@"mp4"];
    if([[NSFileManager defaultManager] fileExistsAtPath:myPathDocs])
    {
        [[NSFileManager defaultManager] removeItemAtPath:myPathDocs error:nil];
    }
    
    NSURL *outptVideoUrl = [NSURL fileURLWithPath:myPathDocs];
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mainComposition presetName:AVAssetExportPresetHighestQuality];
    
    // Setting attributes of the exporter
    exporter.outputURL=outptVideoUrl;
    exporter.outputFileType =AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if(exporter.status == AVAssetExportSessionStatusCompleted)
            {
                callback(outptVideoUrl);
            }
            else
            {
                NSLog(@"error merging video : %@", exporter.error);
                callback(NULL);
            }
            
        });
    }];
}





@end








































