//
//  CustomVideoCompositor.m
//  VideoOverlays
//
//  Created by Muhammad Abed Ekrazek on 9/6/18.
//  Copyright © 2018 Muhammad Abed Ekrazek. All rights reserved.
//

#import "MuzeCircleMergeVideoComposer.h"

@import  UIKit;

@implementation MuzeCircleMergeVideoComposer


- (instancetype)init
{
    return self;
}


- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request
{
    CVPixelBufferRef destination = [request.renderContext newPixelBuffer];
    if (request.sourceTrackIDs.count == 2)
    {
        CVPixelBufferRef front = [request sourceFrameByTrackID:1];
        CVPixelBufferRef back = [request sourceFrameByTrackID:2];
        CVPixelBufferLockBaseAddress(front, kCVPixelBufferLock_ReadOnly);
        CVPixelBufferLockBaseAddress(back, kCVPixelBufferLock_ReadOnly);
        CVPixelBufferLockBaseAddress(destination, 0);
        [self renderFrontBuffer:front backBuffer:back toBuffer:destination];
        CVPixelBufferUnlockBaseAddress(destination, 0);
        CVPixelBufferUnlockBaseAddress(back, kCVPixelBufferLock_ReadOnly);
        CVPixelBufferUnlockBaseAddress(front, kCVPixelBufferLock_ReadOnly);
    }
    [request finishWithComposedVideoFrame:destination];
    CVBufferRelease(destination);
}

- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext
{
}

- (NSDictionary *)requiredPixelBufferAttributesForRenderContext {
    return @{ (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @[ @(kCVPixelFormatType_32BGRA) ] };
}

- (NSDictionary *)sourcePixelBufferAttributes {
    return @{ (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @[ @(kCVPixelFormatType_32BGRA) ] };
}

- (void)renderFrontBuffer:(CVPixelBufferRef)front backBuffer:(CVPixelBufferRef)back toBuffer:(CVPixelBufferRef)destination
{
    CGImageRef frontImage = [self createSourceImageFromBuffer:front];
    CGImageRef backImage = [self createSourceImageFromBuffer:back];
    
    size_t destwidth = CVPixelBufferGetWidth(destination);
    size_t destHeight = CVPixelBufferGetHeight(destination);
    
    CGSize frontSize = [[self delegate] customVideoCompositorDelegateGetFrontSize];
    CGPoint elipseUntraslatedOrigin = [[self delegate] customVideoCompositorDelegateGetOrigin];
    CGPoint elipseTranslatedOrigin = [self translatePoint:elipseUntraslatedOrigin destinationSize:CGSizeMake(destwidth, destHeight) frontImageSize:CGSizeMake(frontSize.width, frontSize.height)];
    CGRect elipseFrame = CGRectMake(elipseTranslatedOrigin.x, elipseTranslatedOrigin.y, frontSize.width, frontSize.height);

    CGRect frame = CGRectMake(0, 0, destwidth, destHeight);
    CGContextRef gc = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(destination), destwidth, destHeight, 8, CVPixelBufferGetBytesPerRow(destination), CGImageGetColorSpace(backImage), CGImageGetBitmapInfo(backImage));
    CGContextDrawImage(gc, frame, backImage);
    CGContextBeginPath(gc);
    CGContextAddEllipseInRect(gc, elipseFrame);
    CGContextClip(gc);
    CGContextDrawImage(gc, elipseFrame, frontImage);
    CGContextRelease(gc);
}

- (CGImageRef)createSourceImageFromBuffer:(CVPixelBufferRef)buffer
{
    size_t width = CVPixelBufferGetWidth(buffer);
    size_t height = CVPixelBufferGetHeight(buffer);
    size_t stride = CVPixelBufferGetBytesPerRow(buffer);
    void *data = CVPixelBufferGetBaseAddress(buffer);
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, data, height * stride, NULL);
    CGImageRef image = CGImageCreate(width, height, 8, 32, stride, rgb, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast, provider, NULL, NO, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(rgb);
    return image;
}


-(CGPoint) translatePoint:(CGPoint)point destinationSize:(CGSize)dstSize frontImageSize:(CGSize)frontSize
{
    return CGPointMake( point.x , dstSize.height - (point.y + frontSize.height));
}



@end
