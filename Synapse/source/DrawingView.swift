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
    func minimumImageSizeForDrawingView(_ drawingView: DrawingView) -> CGSize
    func drawingView(_ drawingView: DrawingView, didFinishDrawingImage image: UIImage, at frame: CGRect)
}

// MARK: - DrawingView

class DrawingView: UIView {
    
    //MARK: Public Interface 

    weak var delegate: DrawingViewDelegate?

    //MARK: Public Methods

    ///  Creates an image of the current path in the view. The resulting image is cropped to the size that just contains what is drawn in the image
    ///
    /// - Returns: UIImage of the rasterized path, tightly cropped to the path's bounds
    func drawingAsImage() -> UIImage {
        
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0.0)
            // zero scale means scale factor of the main screen
        
        self.drawHierarchy(in: self.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // crop the image to just the bounds of the path
        var pathBounds = self.path.bounds
        pathBounds = pathBounds.insetBy(dx: -self.strokeWidth / 2.0, dy: -self.strokeWidth / 2.0)
            // the drawn bounds of the path is larger than the unstroked path defined by the UIBezierPath
            // so we enlarge the area by the stroke width to get something closer to the actual drawn bounds
        
        let minSize = self.delegate?.minimumImageSizeForDrawingView(self) ?? CGSize(width: 28.0, height: 28.0)
        
        if ( pathBounds.size.width < minSize.width ) {
            let delta = (minSize.width - pathBounds.size.width) / 2.0
            pathBounds = pathBounds.insetBy(dx: -delta, dy: 0)
        }

        if ( pathBounds.size.height < minSize.height ) {
            let delta = (minSize.height - pathBounds.size.height) / 2.0
            pathBounds = pathBounds.insetBy(dx: 0.0, dy: -delta)
        }
        
        let imageScale = image!.scale
        pathBounds = pathBounds.rectScaledBy(imageScale)
            // path bounds are in points, but we need to specify our cropping in pixels
        
        guard let croppedImageRef = image!.cgImage!.cropping(to: pathBounds) else {
            return image!
        }
        
        let croppedImage = UIImage(cgImage: croppedImageRef, scale: imageScale, orientation: image!.imageOrientation)
        
        return croppedImage
    }

    ///  Creates an image of the current path in the view. Path is scaled to exactly fit the given size and then the stroke is applied. This results in a rasterized image of the path with a consistent stroke weight regardless of how big or small the original path was before scaling
    /// - Parameter size: size in points for the generated UIImage
    /// - Returns: UIImage of the rasterized path
    func drawingAsImage(withSize size: CGSize) ->UIImage {
        
        let normalizedStrokeWidth: CGFloat = 4.0// * 10.0
        
        let borderWidth: CGFloat = 4.0// * 10.0
        
        let imageBounds = CGRect(origin: CGPoint.zero, size: size)
        let pathBounds = self.path.bounds
        
        let xScale = (size.width - normalizedStrokeWidth - (borderWidth * 2.0)) / pathBounds.size.width
        let yScale = (size.height - normalizedStrokeWidth - (borderWidth * 2.0)) / pathBounds.size.height

        let xDelta = pathBounds.origin.x + (pathBounds.size.width / 2.0)
        let yDelta = pathBounds.origin.y + (pathBounds.size.height / 2.0)

        let scaledPath:UIBezierPath = self.path.copy() as! UIBezierPath

        let centerTransform = CGAffineTransform(translationX: xDelta, y: yDelta)
        scaledPath.apply(centerTransform)

        let scaleTransform = CGAffineTransform(scaleX: xScale, y: yScale)
        scaledPath.apply(scaleTransform)
        
        // center the path in the image space
        let scaledPathBounds = scaledPath.bounds
        let originX = (normalizedStrokeWidth / 2.0) + borderWidth - scaledPathBounds.origin.x
        let originY = (normalizedStrokeWidth / 2.0) + borderWidth - scaledPathBounds.origin.y
        let translateTransform = CGAffineTransform(translationX: originX, y: originY)
        scaledPath.apply(translateTransform)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
            // 1.0 scale means scale means 1 px = 1 pt
        
        UIColor.white.setFill()
        UIRectFill(imageBounds);
        
        UIColor.black.setStroke()
        
        scaledPath.lineWidth = normalizedStrokeWidth
        scaledPath.lineCapStyle = .round
        
        scaledPath.stroke()
        
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image!;
    }
    
    // MARK: - Private Properties
    
    private let path: UIBezierPath = UIBezierPath()
    private let strokeWidth: CGFloat = 10.0
    
    private var previousPanLocation: CGPoint = CGPoint.zero
    private var strokeBoundingRect: CGRect = CGRect.zero

    private var strokeTimer: Timer?

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
    
    override func draw(_ rect: CGRect) {
        
        UIColor.black.setStroke()
        self.path.lineWidth = self.strokeWidth
        self.path.lineCapStyle = .round
        
        self.path.stroke()
    }
    
    // MARK: Drawing
    
    private func clearDrawing() {
        self.path.removeAllPoints();
        self.setNeedsDisplay()
    }
    
    //MARK: Gestures
    
    @objc private func didPan(_ panRecognizer: UIPanGestureRecognizer) {
        let location = panRecognizer.location(in: self)
        
        if ( panRecognizer.state == .began )
        {
            self.panStartedAtLocation(location);
        }
        else if ( panRecognizer.state == .changed )
        {
            self.panMovedToLocation(location)
        }
        else if ( panRecognizer.state == .ended )
        {
            self.panEndedAtLocation(location)
        }
        
        self.previousPanLocation = location;
        
        self.setNeedsDisplay()
    }

    private func panStartedAtLocation(_ location: CGPoint) {
        self.path.move(to: location)
        self.strokeTimer?.invalidate()
    }
    
    private func panMovedToLocation(_ location: CGPoint) {
        let midPoint = location.midpointTo(self.previousPanLocation)
        self.path.addQuadCurve(to: midPoint, controlPoint: self.previousPanLocation);
        self.strokeTimer?.invalidate()
    }
    
    private func panEndedAtLocation(_ location: CGPoint) {
        let midPoint = location.midpointTo(self.previousPanLocation)
        self.path.addQuadCurve(to: midPoint, controlPoint: self.previousPanLocation);
        self.strokeTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(strokeTimerFired), userInfo: nil, repeats: false)
    }
    
    // MARK: Timer
    
    @objc private func strokeTimerFired(_ sender: Timer){
        let drawingImage = self.drawingAsImage()
        self.delegate?.drawingView(self, didFinishDrawingImage: drawingImage, at: self.path.bounds)
        
        self.clearDrawing()
    }
    
}


//MARK: - CGPoint Extension

extension CGPoint {
    
    func midpointTo(_ otherPoint: CGPoint) -> CGPoint {
        return CGPoint(x: (self.x + otherPoint.x) / 2.0, y:(self.y + otherPoint.y) / 2.0 );
    }
    
}

//MARK: - CGRect Extension

extension CGRect {

    /*
        returns a new rect scaled using the rects origin as the refernece point for the scale
     */
    func rectScaledBy(_ scale: CGFloat) -> CGRect {
        var scaledRect = CGRect(origin: self.origin, size: self.size)
        scaledRect.origin.x *= scale
        scaledRect.origin.y *= scale
        scaledRect.size.height *= scale
        scaledRect.size.width *= scale
        return scaledRect
    }
}
