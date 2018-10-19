//
//  CanvasViewController.swift
//  Synapse
//
//  Created by 23 on 4/17/16.
//  Copyright © 2016 Escape Plan. All rights reserved.
//

import UIKit
import CoreML
import Vision

class CanvasViewController: UIViewController {

    // MARK: - Public Properties
    
    var shapeClassifyingNetwork: ShapeClasifyingNetwork?
    var coreMLClassifier: ImageClassifier?
    
    // MARK: - Private Properties
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var drawingView: DrawingView!
    
    var shapeViews = [ShapeView]()
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        drawingView.delegate = self;
    }
    
    private func detected(_ shape: Shape?, confidence: Float?, at frame: CGRect) {
        guard let shape = shape, let confidence = confidence else {
            print("nothing detected")
            return;
        }
        
        print("detected: \(shape), confidence: \(confidence)")

        let shapeView = ShapeView(frame: frame, shape: shape)
        
        shapeViews.append(shapeView)
        self.contentView.addSubview(shapeView)
        
    }
}

// MARK: DrawingViewDelegate

extension CanvasViewController : DrawingViewDelegate {
    
    func minimumImageSizeForDrawingView(_ drawingView: DrawingView) -> CGSize {
        var minimumSize = CGSize(width: 28.0, height: 28.0)
        if let inputDimension = shapeClassifyingNetwork?.inputDimension {
            minimumSize = CGSize(width: inputDimension, height: inputDimension)
        }
        return minimumSize
    }
    
    func drawingView(_ drawingView: DrawingView, didFinishDrawingImage image: UIImage, at frame: CGRect) {
        
        let useCoreML = true
        
        if useCoreML {
            let inputDataDimension = 28.0
            let downsampledImage = drawingView.drawingAsImage(withSize: CGSize(width: inputDataDimension, height: inputDataDimension))
            
            guard let model = coreMLClassifier?.model else{
                return
            }
            classify(image: downsampledImage, with: model, at: frame)
        }
        else  {
            guard let dimension = shapeClassifyingNetwork?.inputDimension else {
                return
            }
            
            // Get an appropriately scaled image with constant stroke width
            let scaledImage = drawingView.drawingAsImage(withSize: CGSize(width: dimension, height: dimension))

            guard let shapeClassifyingNetwork = shapeClassifyingNetwork else {
                return
            }
            
            let (shape, confidence) = classify(image: scaledImage, with: shapeClassifyingNetwork)
            detected(shape, confidence: confidence, at: frame)
        }
    }
}

//TODO: this code is almost identical to LearnViewController, consolidate

// MARK: - Swift AI Classifcation
extension CanvasViewController {
    private func classify(image: UIImage, with classifier: ShapeClasifyingNetwork) -> (Shape?, Float?) {
        let grayscaleData = image.grayscaleImageData(inverted:true)
        let neuralNetwork = classifier.neuralNework
        do {
            let output = try neuralNetwork.infer(grayscaleData)
            guard let detected = output.max() else { return (nil, nil) }
            let shape = Shape(rawValue: output.index(of: detected)!)
            return (shape, detected)
        }
        catch {
            print(error)
            return (nil, nil)
        }
    }
}


// MARK: CoreML Classification
extension CanvasViewController {
    
    private func classify(image: UIImage, with coreMLModel: MLModel, at frame: CGRect) {
        guard let cgImage = image.cgImage else { return }
        
        let coreMLRequest: VNCoreMLRequest
        do {
            let visionModel = try VNCoreMLModel(for: coreMLModel)
            coreMLRequest = VNCoreMLRequest(model: visionModel) { [weak self] (request, error) in
                self?.processCoreMLClassification(for: request, error: error, at: frame)
            }
            coreMLRequest.imageCropAndScaleOption = .centerCrop
        }
        catch {
            print("Could not load Vision ML model from classifier: \(error)")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue)) ?? .up
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            
            do {
                try handler.perform([coreMLRequest])
            }
            catch {
                print("Failed to perform CoreML classificaiton request:\(error)")
            }
        }
    }
    
    private func processCoreMLClassification(for request: VNRequest, error: Error?, at frame: CGRect) {
        guard let results = request.results else {
            print("Unable to classify image, error: \(String(describing: error))")
            return
        }
        
        let classifications = results as! [VNClassificationObservation]
        guard !classifications.isEmpty else {
            print("Nothing was recognized")
            return
        }
        
        let label = classifications[0].identifier
        let confidence = classifications[0].confidence
        
        let shape: Shape?
        switch label {
        case "Circle": shape = .circle
        case "Square": shape = .square
        case "Triangle": shape = .triangle
        default: shape = nil
        }
        
        DispatchQueue.main.async {
            self.detected(shape, confidence: confidence, at: frame)
        }
    }
    
}

