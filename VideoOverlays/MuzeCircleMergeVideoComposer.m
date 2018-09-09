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
    
//    CGImageRef frontRegularImg = [self createSourceImageFromBuffer:front];
    
    
//    UIImage* maskImg = [MuzeCircleMergeVideoComposer gradientImageWithBounds:CGRectMake(0, 0, CGImageGetWidth(frontRegularImg) * 0.5, CGImageGetHeight(frontRegularImg) * 0.5)
//                                                                      colors:[NSArray arrayWithObjects: UIColor.yellowColor , UIColor.clearColor, nil]]; //[UIImage imageNamed:@"triangleImg"];
//    CGImageRef frontImage = [self getMaskedImageFromImg:frontRegularImg mask:maskImg.CGImage];
    CGImageRef backImage = [self createSourceImageFromBuffer:back];
    
    size_t destwidth = CVPixelBufferGetWidth(destination);
    size_t destHeight = CVPixelBufferGetHeight(destination);
    
    CGSize frontSize = [[self delegate] customVideoCompositorDelegateGetFrontSize];
    CGPoint elipseUntraslatedOrigin = [[self delegate] customVideoCompositorDelegateGetOrigin];
    CGPoint elipseTranslatedOrigin = [self translatePoint:elipseUntraslatedOrigin destinationSize:CGSizeMake(destwidth, destHeight) frontImageSize:CGSizeMake(frontSize.width, frontSize.height)];
    
    
    
    CGRect elipseFrame = CGRectMake(elipseTranslatedOrigin.x, elipseTranslatedOrigin.y, frontSize.width, frontSize.height);
//    CGRect elipseFrame = CGRectMake(0, 0, destwidth, destHeight);


    CGRect frame = CGRectMake(0, 0, destwidth, destHeight);
    CGContextRef gc = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(destination), destwidth, destHeight, 8, CVPixelBufferGetBytesPerRow(destination), CGImageGetColorSpace(backImage), CGImageGetBitmapInfo(backImage));
    CGContextDrawImage(gc, frame, backImage);
    
    
    if([[self delegate] customVideoCompositorDelegateShouldStrokeFrontCircle])
    {
        CGContextSetStrokeColorWithColor(gc, UIColor.whiteColor.CGColor);
        CGContextSetLineWidth(gc, 20);
        CGContextStrokeEllipseInRect(gc, elipseFrame);
    }
    
    
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


-(CGImageRef)getMaskedImageFromImg:(CGImageRef)image mask:(CGImageRef)mask
{
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat width = CGImageGetWidth(image);
    CGFloat height = CGImageGetHeight(image);
    
    CGImageRef imageMask = CGImageMaskCreate(CGImageGetWidth(mask),
                                             CGImageGetHeight(mask),
                                             CGImageGetBitsPerComponent(mask),
                                             CGImageGetBitsPerPixel(mask),
                                             CGImageGetBytesPerRow(mask),
                                             CGImageGetDataProvider(mask),
                                             NULL, // Decode is null
                                             YES // Should interpolate
                                             );

    
    CGContextRef ctxWithAlpha = CGBitmapContextCreate(nil, width, height, 8, 4*width, cs, kCGImageAlphaPremultipliedFirst);
    CGContextDrawImage(ctxWithAlpha, CGRectMake(0, 0, width, height), image);
    CGImageRef imageWithAlpha = CGBitmapContextCreateImage(ctxWithAlpha);
    CGImageRef masked = CGImageCreateWithMask(imageWithAlpha, imageMask);
    
    CGContextRelease(ctxWithAlpha);
    CGColorSpaceRelease(cs);
//    CGImageRelease(imageWithAlpha);
    
    return masked;
//
//
//
//    CGImageRef maskedReference = CGImageCreateWithMask(image, imageMask);
//    return maskedReference;
}


+ (UIImage *)gradientImageWithBounds:(CGRect)bounds colors:(NSArray *)colors
{
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = bounds;
    gradientLayer.colors = colors;
    
    UIGraphicsBeginImageContext(gradientLayer.bounds.size);
    [gradientLayer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

-(CGPoint) translatePoint:(CGPoint)point destinationSize:(CGSize)dstSize frontImageSize:(CGSize)frontSize
{
    return CGPointMake( point.x , dstSize.height - (point.y + frontSize.height));
}



@end
