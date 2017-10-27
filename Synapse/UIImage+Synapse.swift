//
//  UIImage+Synapse.swift
//  Synapse
//
//  Created by 23 on 5/1/16.
//  Copyright © 2016 Escape Plan. All rights reserved.
//

import UIKit

extension UIImage {
    
    /// Creates a new image scaled to the specified size. The size is treated as pixels and the resulting new image has a scale of 1.0 (1 pt = 1 px). The resulting image has alpha values stripped and the background will be white with a uniform border.
    ///
    /// - Parameters:
    ///   - size: size in pixels of the generated image
    ///   - borderWidth: the thickness of the white border added to all sides of the image in pixels
    /// - Returns: scaled and bordered image
    func imageScaledToSize(_ size: CGSize, withBorder borderWidth: CGFloat) -> UIImage {
      
        assert(borderWidth >= 0.0, "Border should be a positive value")
        assert(borderWidth <= size.width, "Border should be a less than desired width")
        assert(borderWidth <= size.height, "Border should be a less than desired height")
        
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
            // true says we want an opaque resulting image
        
        // clear to white
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: CGPoint.zero, size: size))

        let context = UIGraphicsGetCurrentContext()
        context!.interpolationQuality = CGInterpolationQuality.none

        var targetRect = CGRect(origin: CGPoint.zero, size: size)
        targetRect = targetRect.insetBy(dx: borderWidth, dy: borderWidth)
        
        self .draw(in: targetRect)
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return scaledImage!
    }
    
    /// Returns the raw pixel data of this iamge, converted to grayscale as an array of floats
    ///
    /// - Parameter inverted: invert the image so white is black and black is white.
    /// - Returns: array of floats that will be self.size.width * self.size.height in length
    func grayscaleImageData(inverted:Bool ) -> [Float] {

        /*
         pixel format can vary for a lot of reasons, so it is a bit easier
         to draw the image into a bitmap with a format of our choosing
         rather than account for all the possible variants we need to convert from
         
         in performance critical situations, it may make sense to decode the source pixel format directly instead of re-drawing
         */
        
        let imageRef = self.cgImage;
        
        let imageHeight = imageRef!.height           
        let imageWidth = imageRef!.width
        
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        bitmapInfo |= 0 & CGBitmapInfo.floatInfoMask.rawValue

        let bitsPerComponent = 8
        let bytesPerPixel = 4
        let bytesPerRow = imageWidth * bytesPerPixel
        let imageData = UnsafeMutablePointer<UInt8>.allocate(capacity: imageWidth * imageHeight * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let imageContext = CGContext(data: imageData, width: imageWidth, height: imageHeight, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return [Float]()
        }
        
        imageContext.draw(imageRef!, in: CGRect(origin: CGPoint.zero, size: self.size))

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



