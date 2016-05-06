//
//  UIImage+Synapse.swift
//  Synapse
//
//  Created by 23 on 5/1/16.
//  Copyright © 2016 Escape Plan. All rights reserved.
//

import UIKit

extension UIImage {
    
    /*
        returns a new image scaled to the specified size
        The size is treated as pixels and the resulting new image
        has a scale of 1.0 (1 pt = 1 px)
        The resulting image has alpha values stripped and
        the background will be white with a borderWidth pixel border
    */
    func imageScaledToSize(size: CGSize, withBorder borderWidth: CGFloat) -> UIImage {
      
        assert(borderWidth >= 0.0, "Border should be a positive value")
        assert(borderWidth <= size.width, "Border should be a less than desired width")
        assert(borderWidth <= size.height, "Border should be a less than desired height")
        
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
            // true says we want an opaque resulting image
        
        // clear to white
        UIColor.whiteColor().setFill()
        UIRectFill(CGRect(origin: CGPointZero, size: size))

        let context = UIGraphicsGetCurrentContext()
        CGContextSetInterpolationQuality(context, CGInterpolationQuality.None)

        var targetRect = CGRect(origin: CGPointZero, size: size)
        targetRect = CGRectInset(targetRect, borderWidth, borderWidth)
        
        self .drawInRect(targetRect)
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
    
    /* 
        returns the pixel data, converted to gray,
        possibily inverted and ignoring alpha
        as an array of floats
     
        pixel format can vary for a lot of reasons, so it is a bit easier
        to draw the image into a bitmap with a format of our choosing
        rather than account for all the possible variants
     
        in performance critical situations, it may make sense to decode
        the data in the format it came in
    */
    func grayscaleImageData(inverted inverted:Bool ) -> [Float] {
        let imageRef = self.CGImage;
        
        let imageHeight = CGImageGetHeight(imageRef)           
        let imageWidth = CGImageGetWidth(imageRef)
        
        var bitmapInfo: UInt32 = CGBitmapInfo.ByteOrder32Big.rawValue
        bitmapInfo |= CGImageAlphaInfo.PremultipliedLast.rawValue & CGBitmapInfo.AlphaInfoMask.rawValue
        bitmapInfo |= 0 & CGBitmapInfo.FloatInfoMask.rawValue

        let bitsPerComponent = 8
        let bytesPerPixel = 4
        let bytesPerRow = imageWidth * bytesPerPixel
        let imageData = UnsafeMutablePointer<UInt8>.alloc(imageWidth * imageHeight * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let imageContext = CGBitmapContextCreate(imageData, imageWidth, imageHeight, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo) else {
            return [Float]()
        }
        
        CGContextDrawImage(imageContext, CGRect(origin: CGPointZero, size: self.size), imageRef)

        let pixels = UnsafeMutableBufferPointer<UInt8>(start: imageData, count: imageWidth * imageHeight * bytesPerPixel)
        
        var byteIndex = 0
        var grayscaleData = [Float]()

        for _ in 0..<imageHeight {
            for _ in 0..<imageWidth {
                
                let r = pixels[byteIndex]
                let g = pixels[byteIndex+1]
                let b = pixels[byteIndex+2]
                let _ = pixels[byteIndex+3] // alpha
                
                var grayValue = Float(UInt32(r) + UInt32(g) + UInt32(b)) / 255.0 / 3.0
                    // 'naive' grayscale conversion
                
                if (inverted)
                {
                    grayValue = 1.0 - grayValue
                }
                
                grayscaleData.append(grayValue)
                byteIndex += 4
            }
        }
        
        return grayscaleData
    }
    
}



