//
//  VideoProcessor.h
//  Vibes
//
//  Created by Muhammad Abed Ekrazek on 8/15/18.
//  Copyright © 2018 MuzeLabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "MuzeCircleMergeVideoComposer.h"


@interface VideoProcessor : NSObject<CustomVideoCompositorDelegate>


- (instancetype)init;

-(void) mergeBgVideo:(NSURL*)bgVideo withForeGroundVideo:(NSURL*)foreGVideo frontVideoSize:(CGSize)frontSize frontOrigin:(CGPoint)frontOrigin completion:(void(^)(NSURL*))callback;
-(void)cropSquareVideoWithUrl:(NSURL*)url makeItCircle:(BOOL)isCricle completionHandler:(void(^)(NSURL*))callback;


@property(nonatomic) Boolean shouldStroke;


@end
