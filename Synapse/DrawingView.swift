//
//  DrawingView.swift
//  Synapse
//
//  Created by 23 on 4/17/16.
//  Copyright © 2016 Escape Plan. All rights reserved.
//

import UIKit

// MARK: DrawingViewDelegate

protocol DrawingViewDelegate: class {
    func drawingView(drawingView: DrawingView, didFinishDrawingImage image: UIImage)
}

// MARK: - DrawingView

class DrawingView: UIView {
    
    //MARK: Public Interface 

    weak var delegate: DrawingViewDelegate?

    //MARK: Public Methods

    /*
     Creates an image of the current path in the view.
     The resulting image is cropped to the size that just contains
     what is drawn in the image
     
     */
    func drawingAsImage() -> UIImage {
        
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0.0)
            // zero scale means scale factor of the main screen
        
        self.drawViewHierarchyInRect(self.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // crop the image to just the bounds of the path
        var pathBounds = self.path.bounds
        pathBounds = CGRectInset(pathBounds, -self.strokeWidth / 2.0, -self.strokeWidth / 2.0)
            // the drawn bounds of the path is larger than the unstroked path defined by the UIBezierPath
            // so we enlarge the area by the stroke width to get something closer to the actual drawn bounds
        
        //TODO: cleanup magic numbers
        let minDimension: CGFloat = 28.0
        
        if ( pathBounds.size.width < minDimension ) {
            let delta = (minDimension - pathBounds.size.width) / 2.0
            pathBounds = CGRectInset(pathBounds, -delta, 0)
        }

        if ( pathBounds.size.height < minDimension ) {
            let delta = (minDimension - pathBounds.size.height) / 2.0
            pathBounds = CGRectInset(pathBounds, 0.0, -delta)
        }
        
        let imageScale = image.scale
        pathBounds = pathBounds.rectScaledBy(imageScale)
            // path bounds are in points, but we need to specify our cropping in pixels
        
        guard let croppedImageRef = CGImageCreateWithImageInRect(image.CGImage, pathBounds) else {
            return image
        }
        
        let croppedImage = UIImage(CGImage: croppedImageRef, scale: imageScale, orientation: image.imageOrientation)
        
        return croppedImage
    }

    /*
        Here we scale our path to fit our image size and then stroke it so we have
        a consistent stroke width regardless of how big or small the original path was sketched
     */
    func drawingAsImage(withSize size: CGSize) ->UIImage {
        
        //TODO: should the line widths for this normal drawing and this drawing have a relation?
        let normalizedStrokeWidth: CGFloat = 4.0
        
        let borderWidth: CGFloat = 4.0
        
        let imageBounds = CGRect(origin: CGPointZero, size: size)
        let pathBounds = self.path.bounds
        
        let xScale = (size.width - normalizedStrokeWidth - (borderWidth * 2.0)) / pathBounds.size.width
        let yScale = (size.height - normalizedStrokeWidth - (borderWidth * 2.0)) / pathBounds.size.height

        let xDelta = pathBounds.origin.x + (pathBounds.size.width / 2.0)
        let yDelta = pathBounds.origin.y + (pathBounds.size.height / 2.0)

        let scaledPath:UIBezierPath = self.path.copy() as! UIBezierPath

        let centerTransform = CGAffineTransformMakeTranslation(xDelta, yDelta)
        scaledPath.applyTransform(centerTransform)

        let scaleTransform = CGAffineTransformMakeScale(xScale, yScale)
        scaledPath.applyTransform(scaleTransform)
        
        // center the path in the image space
        let scaledPathBounds = scaledPath.bounds
        let originX = (normalizedStrokeWidth / 2.0) + borderWidth - scaledPathBounds.origin.x
        let originY = (normalizedStrokeWidth / 2.0) + borderWidth - scaledPathBounds.origin.y
        let translateTransform = CGAffineTransformMakeTranslation(originX, originY)
        scaledPath.applyTransform(translateTransform)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
            // 1.0 scale means scale means 1 px = 1 pt
        
        UIColor.whiteColor().setFill()
        UIRectFill(imageBounds);
        
        UIColor.blackColor().setStroke()
        
        scaledPath.lineWidth = normalizedStrokeWidth
        scaledPath.lineCapStyle = .Round
        
        scaledPath.stroke()
        
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image;
    }
    
    // MARK: - Private Properties
    
    private let path: UIBezierPath = UIBezierPath()
    private let strokeWidth: CGFloat = 10.0
    
    private var previousPanLocation: CGPoint = CGPointZero
    private var strokeBoundingRect: CGRect = CGRectZero

    private var strokeTimer: NSTimer?

    
    //MARK: Life Cycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    

    private func commonInit() {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPan))
        panRecognizer.maximumNumberOfTouches = 1;
        panRecognizer.minimumNumberOfTouches = 1;
        
        self.addGestureRecognizer(panRecognizer)
    }
    
    // MARK: UIView
    
    override func drawRect(rect: CGRect) {
        
        UIColor.blackColor().setStroke()
        self.path.lineWidth = self.strokeWidth
        self.path.lineCapStyle = .Round
        
        self.path.stroke()
    }
    
    // MARK: Drawing
    
    private func clearDrawing() {
        self.path.removeAllPoints();
        self.setNeedsDisplay()
    }
    
    //MARK: Gestures
    
    @objc private func didPan(panRecognizer: UIPanGestureRecognizer) {
        let location = panRecognizer.locationInView(self)
        
        if ( panRecognizer.state == .Began )
        {
            self.panStartedAtLocation(location);
        }
        else if ( panRecognizer.state == .Changed )
        {
            self.panMovedToLocation(location)
        }
        else if ( panRecognizer.state == .Ended )
        {
            self.panEndedAtLocation(location)
        }
        
        self.previousPanLocation = location;
        
        self.setNeedsDisplay()
    }

    private func panStartedAtLocation(location: CGPoint) {
        self.path.moveToPoint(location)
        self.strokeTimer?.invalidate()
    }
    
    private func panMovedToLocation(location: CGPoint) {
        let midPoint = location.midpointTo(self.previousPanLocation)
        self.path.addQuadCurveToPoint(midPoint, controlPoint: self.previousPanLocation);
        self.strokeTimer?.invalidate()
    }
    
    private func panEndedAtLocation(location: CGPoint) {
        let midPoint = location.midpointTo(self.previousPanLocation)
        self.path.addQuadCurveToPoint(midPoint, controlPoint: self.previousPanLocation);
        self.strokeTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(strokeTimerFired), userInfo: nil, repeats: false)
    }
    
    // MARK: Timer
    
    @objc private func strokeTimerFired(sender: NSTimer){
        let drawingImage = self.drawingAsImage()
        self.delegate?.drawingView(self, didFinishDrawingImage: drawingImage)
        
        self.clearDrawing()
    }
    
}


//MARK: - CGPoint Extension

extension CGPoint {
    
    func midpointTo(otherPoint: CGPoint) -> CGPoint {
        return CGPoint(x: (self.x + otherPoint.x) / 2.0, y:(self.y + otherPoint.y) / 2.0 );
    }
    
}

//MARK: - CGRect Extension

extension CGRect {

    /*
        returns a new rect scaled using the rects origin as the refernece point for the scale
     */
    func rectScaledBy(scale: CGFloat) -> CGRect {
        var scaledRect = CGRect(origin: self.origin, size: self.size)
        scaledRect.origin.x *= scale
        scaledRect.origin.y *= scale
        scaledRect.size.height *= scale
        scaledRect.size.width *= scale
        return scaledRect
    }
}
