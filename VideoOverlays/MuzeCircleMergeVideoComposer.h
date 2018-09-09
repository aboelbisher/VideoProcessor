//
//  CustomVideoCompositor.h
//  VideoOverlays
//
//  Created by Muhammad Abed Ekrazek on 9/6/18.
//  Copyright © 2018 Muhammad Abed Ekrazek. All rights reserved.
//

#import <UIKit/UIKit.h>

@import AVFoundation;

@protocol CustomVideoCompositorDelegate <NSObject>

-(CGSize) customVideoCompositorDelegateGetFrontSize;
-(CGPoint) customVideoCompositorDelegateGetOrigin;

@end


@interface MuzeCircleMergeVideoComposer : NSObject<AVVideoCompositing>


@property (nonatomic, weak) id <CustomVideoCompositorDelegate> delegate;


@end
