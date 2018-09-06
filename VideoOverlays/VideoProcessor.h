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
#import "CustomVideoCompositor.h"


@interface VideoProcessor : NSObject


+ (void) mergeBgVideo:(NSURL*)bgVideo withForeGroundVideo:(NSURL*)foreGVideo completion:(void(^)(NSURL*))callback;
+(void)cropSquareVideoWithUrl:(NSURL*)url completionHandler:(void(^)(NSURL*))callback;


@end
