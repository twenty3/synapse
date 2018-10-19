//
//  LearnViewController.swift
//  Synapse
//
//  Created by 23 on 4/17/16.
//  Copyright © 2016 Escape Plan. All rights reserved.
//

import UIKit
import CoreML
import Vision

class LearnViewController: UIViewController {

    // MARK: - Public Properties 
    
    var shapeClassifyingNetwork: ShapeClasifyingNetwork?
    var coreMLClassifier: ImageClassifier?
    
    // MARK: - Private Properties
    
    @IBOutlet private weak var sampleView: UIView!
    @IBOutlet private weak var sampleImageView: UIImageView!
    @IBOutlet private weak var sampleBackgroundView: UIView!
    @IBOutlet private weak var detectedLabel: UILabel!
    @IBOutlet private weak var detectedBackgroundView: UIView!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var scratchPadView: DrawingView!
    @IBOutlet private weak var scratchPadViewLabel: UILabel!
    
    @IBOutlet private weak var saveBarButtonItem: UIBarButtonItem!
    @IBOutlet private weak var learnSquareSwitch: UISwitch!
    @IBOutlet private weak var learnCircleSwitch: UISwitch!
    @IBOutlet private weak var learnTriangleSwitch: UISwitch!
    @IBOutlet private weak var useCoreMLSwitch: UISwitch!
    
    var selectedShape: Shape? {
        var selectedShape: Shape? = nil
        if ( learnSquareSwitch.isOn ) { selectedShape = .square }
        if ( learnCircleSwitch.isOn ) { selectedShape = .circle }
        if ( learnTriangleSwitch.isOn ) { selectedShape = .triangle }
        return selectedShape
    }
    
    // MARK: UIViewController 
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        statusLabel.text = ""
        detectedLabel.text = ""
        
        sampleImageView.layer.cornerRadius = 10.0
        sampleImageView.layer.masksToBounds = true
        sampleBackgroundView.layer.cornerRadius = 10.0
        sampleBackgroundView.layer.masksToBounds = true
        detectedBackgroundView.layer.cornerRadius = 10.0
        detectedBackgroundView.layer.masksToBounds = true
        detectedLabel.layer.cornerRadius = 10.0
        detectedLabel.layer.masksToBounds = true
        
        learnSquareSwitch.setOn(false, animated: false)
        learnCircleSwitch.setOn(false, animated: false)
        learnTriangleSwitch.setOn(false, animated: false)
        
        scratchPadView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateSaveButton()
    }
    
    //MARK: State
    private func updateSaveButton() {
        saveBarButtonItem.isEnabled = !useCoreMLSwitch.isOn
    }
    
    private func update(with shape: Shape?, confidence: Float?) {
        let shapeName = shape?.toString() ?? "Unknown Shape"
        let shapeSymbol = shape?.toSymbol() ?? "🤔"
        
        let statusString: String
        if let confidence = confidence {
            statusString = String(format: "Detected a %@, confidence %.2f%%", shapeName, confidence * 100.0)
            print("Detected: \(shapeName), \(confidence)");
        }
        else {
            statusString = String(format: "Classification failed.")
            print("Classification failed.");
        }
        
        statusLabel.text = statusString
        detectedLabel.text = shapeSymbol
    }
    
    // MARK: Actions
    
    @IBAction private func saveButtonTapped(_ sender: AnyObject) {
        do {
            try shapeClassifyingNetwork?.neuralNework.save(to: URL.documentsURL(with: "shapes-ffnn"))
            print("Saved network to documents directory")
        } catch {
            print("Error attempting to save network: \(error)")
        }
    }
    
    @IBAction private func useCoreMLSwitchChanged(_ sender: AnyObject) {
        updateSaveButton()
    }
    
    @IBAction private func learnSwitchChanged(_ sender: AnyObject) {
        
        var title = "⬇︎ Draw a Shape Here ⬇︎"
        
        if (sender as? UISwitch != learnSquareSwitch ) {
            learnSquareSwitch.setOn(false, animated: true)
        }
        else if ( learnSquareSwitch.isOn ) {
            title = "⬇︎ Draw a Square Here ⬇︎"
        }
        
        if (sender as? UISwitch != learnCircleSwitch ) {
            learnCircleSwitch.setOn(false, animated: true)
        }
        else if ( learnCircleSwitch.isOn ) {
            title = "⬇︎ Draw a Circle Here ⬇︎"
        }
        
        if (sender as? UISwitch != learnTriangleSwitch ) {
            learnTriangleSwitch.setOn(false, animated: true)
        }
        else if ( learnTriangleSwitch.isOn ) {
            title = "⬇︎ Draw a Triangle Here ⬇︎"
        }
     
        UIView.transition(with: scratchPadViewLabel, duration: 0.33, options: UIViewAnimationOptions.transitionCrossDissolve, animations: {
                self.scratchPadViewLabel.text = title;
            }, completion: nil)
    }
    
    //MARK: Benchmarking
    
    private var startTime: DispatchTime?
    private func startTimer() {
        startTime = DispatchTime.now()
    }
    
    private func endTimer() -> Double {
        guard let startTime = self.startTime else { return 0 }
        let end = DispatchTime.now()
        let nanoseconds = end.uptimeNanoseconds - startTime.uptimeNanoseconds
        let milliseconds = Double(nanoseconds) / Double(NSEC_PER_MSEC)
        return milliseconds
    }
    
    //MARK: Training
    
    func trainNetwork(withInputData inputData: [Float], correctShape: Shape) {
        
        // translate from Shape to output array:
        var answer = [Float](repeating: 0.0, count: 3)
        answer[correctShape.rawValue] = 1.0
        
        print("Learning that last shape was a: \(correctShape.toString())")
        print("(answer: \(answer)")
        
        var statusString = statusLabel.text ?? ""
        statusString = statusString + "\nLearing last shape was a \(correctShape)."
        statusLabel.text = statusString
        
        guard let neuralNetwork = shapeClassifyingNetwork?.neuralNework else {
            return
        }

        let errorThreshold: Float = 0.1
        
        do {
            var lastInferred = [Float]()
            var error: Float = 1.0
            try _ = neuralNetwork.infer(inputData)
            
            while true {
                if ( error < errorThreshold ) { break }
                
                try neuralNetwork.backpropagate(answer)
                lastInferred = try neuralNetwork.infer(inputData)
                
                error = NeuralNet.ErrorFunction.meanSquared.computeError(real: lastInferred, target: answer, rows: 1, cols: answer.count)
                
                print ("TRAINED, error after back propagation: \(error)")
            }
            print ("Error less than \(errorThreshold), training finished. Last infered result: \(lastInferred)")
        }
        catch {
            print("Problem trianing network: \(error)")
        }
    }
    
    func saveTrainingImage(_ image: UIImage, forShapeType shapeType:Shape) {
        let manager = FileManager.default
        let documentsDirectory = try! manager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let shapesDirectory = documentsDirectory.appendingPathComponent(shapeType.toString())
        let filename = UUID.init().uuidString
        
        do {
            try manager.createDirectory(at: shapesDirectory, withIntermediateDirectories: false, attributes: nil)
        }
        catch let error as NSError {
            if ( error.code != NSFileWriteFileExistsError )
            {
                print(error)
            }
        }
        
        guard let imageData = UIImagePNGRepresentation(image) else {
            print("Could not create PNG represenation of training image: \(image)")
            return
        }
        
        let imageURL = shapesDirectory.appendingPathComponent(filename)
        let result = (try? imageData.write(to: imageURL, options: [.atomic])) != nil
        
        if ( !result ) { print("Could not save training image to URL: \(imageURL)") }
    }
}


// MARK: - Swift AI Classifcation
extension LearnViewController {
    private func classify(image: UIImage, with classifier: ShapeClasifyingNetwork, label: Shape?) -> (Shape?, Float?) {
        
        startTimer()
        let grayscaleData = image.grayscaleImageData(inverted:true)
        let milliseconds = endTimer()
        print("Grayscale conversion took \(milliseconds)ms")

        //printInputData(grayscaleData, stride: dimension)
        
        let neuralNetwork = classifier.neuralNework
        
        assert(neuralNetwork.layerNodeCounts[0] == grayscaleData.count, "number of inputs provided does not match the neural network's expected number of inputs")
        
        do {
            
            startTimer()
            let output = try neuralNetwork.infer(grayscaleData)
            let milliseconds = endTimer()
            
            print("Classifying took \(milliseconds) ms")
            print("Output: \(output)")
            
            if let shapeToLearn = label {
                trainNetwork(withInputData: grayscaleData, correctShape: shapeToLearn)
                saveTrainingImage(image, forShapeType: shapeToLearn)
                // stash off the shape to build up an archive for training
            }
            
            guard let detected = output.max() else {
                return (nil, nil)
            }
            
            let shape = Shape(rawValue: output.index(of: detected)!)
            
            return (shape, detected)

        }
        catch {
            print(error)
            return (nil, nil)
        }
    }
}


//MARK: CoreML Classification

extension LearnViewController {
    
    private func classify(image: UIImage, with coreMLModel: MLModel, label: Shape?) {
        guard let cgImage = image.cgImage else {
            print("No CGImage backing the drawing's UIImage")
            return
        }
        
        // We can't train the CoreML model in the app, but we can save off the input image and label for offline batch training
        if let shapeToLearn = label {
            saveTrainingImage(image, forShapeType: shapeToLearn)
        }
        
        let coreMLRequest: VNCoreMLRequest
        do {
            let visionModel = try VNCoreMLModel(for: coreMLModel)
            coreMLRequest = VNCoreMLRequest(model: visionModel) { [weak self] (request, error) in
                self?.processCoreMLClassification(for: request, error: error)
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
    
    private func processCoreMLClassification(for request: VNRequest, error:Error?) {
        guard let results = request.results else {
            print("Unable to classify image, error: \(String(describing: error))")
            return
        }
        
        let classifications = results as! [VNClassificationObservation]
        
        let milliseconds = endTimer()
        print("Classifying took \(milliseconds)ms")
        
        guard !classifications.isEmpty else {
            print("Nothing was recognized")
            return
        }
        
        let resultsString = classifications.map{ String(format:"   (%.2f) %@", $0.confidence, $0.identifier) }
        print("CoreML classification: \(resultsString)")
        
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
            self.update(with: shape, confidence: confidence)
        }
    }
    
}

// MARK: DrawingViewDelegate

extension LearnViewController : DrawingViewDelegate {
    
    func minimumImageSizeForDrawingView(_ drawingView: DrawingView) -> CGSize {
        var minimumSize = CGSize(width: 28.0, height: 28.0)
        if let inputDimension = shapeClassifyingNetwork?.inputDimension {
            minimumSize = CGSize(width: inputDimension, height: inputDimension)
        }
        return minimumSize
    }
    
    func drawingView(_ drawingView: DrawingView, didFinishDrawingImage image: UIImage) {
        
        let useCoreML = useCoreMLSwitch.isOn
        
        if useCoreML {
            // CoreML:
            
            // since our network was trained on images drawn at 28 x 28 (and then upscaled during training by CreateML) we'll use the same dimensions here to produce our source image and let the Vision framework scale the result up to what the model expects
            
            let inputDataDimension = 28.0
            startTimer()
            let downsampledImage = drawingView.drawingAsImage(withSize: CGSize(width: inputDataDimension, height: inputDataDimension))
            let milliseconds = endTimer()
            print("Scaling image took \(milliseconds)ms")
            sampleImageView.image = downsampledImage
            
            guard let model = coreMLClassifier?.model else{
                print("Learn controller does not have a coreML model to work with!")
                return
            }
            
            startTimer()
            classify(image: downsampledImage, with: model, label: selectedShape)
        }
        else  {

            // Swift AI:

            guard let dimension = shapeClassifyingNetwork?.inputDimension else {
                print("Learn controller does not have a neural network to work with!")
                return
            }
            
            // Get an appropriately scaled image with constant stroke width
            startTimer()
            let scaledImage = drawingView.drawingAsImage(withSize: CGSize(width: dimension, height: dimension))
            sampleImageView.image = scaledImage
            let milliseconds = endTimer()
            print("Scaling image took \(milliseconds)ms")
            
            guard let shapeClassifyingNetwork = shapeClassifyingNetwork else {
                print("Learn controller does not have a neural network to work with!")
                return
            }

            let (shape, confidence) = classify(image: scaledImage, with: shapeClassifyingNetwork, label: selectedShape)
            update(with: shape, confidence: confidence)
        }
    }
}

//MARK: Debugging

extension LearnViewController {
    
    func printInputData(_ data: [Float], stride s: Int) {
        for index in stride(from: 0, to:s * s, by:s) {
            
            let pretty = data[index ..< index + s].map({ (grayValue) -> String in
                if ( grayValue == 1.0 ){ return "." }
                return "*"
            })
            
            print(pretty)
        }
    }
}
