//
//  LearnViewController.swift
//  Synapse
//
//  Created by 23 on 4/17/16.
//  Copyright © 2016 Escape Plan. All rights reserved.
//

import UIKit

class LearnViewController: UIViewController {

    // MARK: - Public Properties 
    
    var shapeClassifyingNetwork: ShapeClasifyingNetwork?
    
    // MARK: - Private Properties
    
    @IBOutlet private weak var sampleView: UIView!
    @IBOutlet private weak var sampleImageView: UIImageView!
    @IBOutlet private weak var sampleBackgroundView: UIView!
    @IBOutlet private weak var detectedLabel: UILabel!
    @IBOutlet private weak var detectedBackgroundView: UIView!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var scratchPadView: DrawingView!
    @IBOutlet private weak var scratchPadViewLabel: UILabel!
    
    @IBOutlet private weak var learnSquareSwitch: UISwitch!
    @IBOutlet private weak var learnCircleSwitch: UISwitch!
    @IBOutlet private weak var learnTriangleSwitch: UISwitch!
    
    // MARK: UIViewController 
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.statusLabel.text = ""
        self.detectedLabel.text = ""
        
        self.sampleImageView.layer.cornerRadius = 10.0
        self.sampleImageView.layer.masksToBounds = true
        self.sampleBackgroundView.layer.cornerRadius = 10.0
        self.sampleBackgroundView.layer.masksToBounds = true
        self.detectedBackgroundView.layer.cornerRadius = 10.0
        self.detectedBackgroundView.layer.masksToBounds = true
        self.detectedLabel.layer.cornerRadius = 10.0
        self.detectedLabel.layer.masksToBounds = true
        
        self.learnSquareSwitch.setOn(false, animated: false)
        self.learnCircleSwitch.setOn(false, animated: false)
        self.learnTriangleSwitch.setOn(false, animated: false)
        
        self.scratchPadView.delegate = self
    }
    
    // MARK: Actions
    
    @IBAction private func saveButtonTapped(sender: AnyObject) {
        self.shapeClassifyingNetwork?.neuralNework.writeToFile("shapes-ffnn")
        print("Saved network to documents directory")
    }
    
    @IBAction private func learnSwitchChanged(sender: AnyObject) {
        
        var title = "⬇︎ Draw a Shape Here ⬇︎"
        
        if (sender as? UISwitch != self.learnSquareSwitch ) {
            self.learnSquareSwitch.setOn(false, animated: true)
        }
        else if ( self.learnSquareSwitch.on ) {
            title = "⬇︎ Draw a Square Here ⬇︎"
        }
        
        if (sender as? UISwitch != self.learnCircleSwitch ) {
            self.learnCircleSwitch.setOn(false, animated: true)
        }
        else if ( self.learnCircleSwitch.on ) {
            title = "⬇︎ Draw a Circle Here ⬇︎"
        }
        
        if (sender as? UISwitch != self.learnTriangleSwitch ) {
            self.learnTriangleSwitch.setOn(false, animated: true)
        }
        else if ( self.learnTriangleSwitch.on ) {
            title = "⬇︎ Draw a Triangle Here ⬇︎"
        }
     
        UIView.transitionWithView(self.scratchPadViewLabel, duration: 0.33, options: UIViewAnimationOptions.TransitionCrossDissolve, animations: { 
            self.scratchPadViewLabel.text = title;
            }, completion: nil)
    }
    
    //MARK: Training
    
    func trainNetwork(withInputData inputData: [Float], correctShape: Shape) {
        
        // translate from Shape to output array:
        var answer = [Float](count: 3, repeatedValue:0.0)
        answer[correctShape.rawValue] = 1.0
        
        print("Learning that last shape was a: \(correctShape.toString())")
        print("(answer: \(answer)")
        
        var statusString = self.statusLabel.text ?? ""
        statusString = statusString + "\nLearing last shape was a \(correctShape)."
        self.statusLabel.text = statusString
        
        guard let neuralNetwork = self.shapeClassifyingNetwork?.neuralNework else {
            return
        }
        
        var error: Float = 1.0
        while error > 0.1 {
            do {
                try error = neuralNetwork.backpropagate(answer: answer)
                try neuralNetwork.update(inputs: inputData)
                print ("TRAINED: \(error)")
            }
            catch {
                print("Problem trianing network: \(error)")
            }
        }
    }
    
    func saveTrainingImage(image: UIImage, forShapeType shapeType:Shape) {
        let manager = NSFileManager.defaultManager()
        let documentsDirectory = try! manager.URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
        let shapesDirectory = documentsDirectory.URLByAppendingPathComponent(shapeType.toString())
        let filename = NSUUID.init().UUIDString
        
        do {
            try manager.createDirectoryAtURL(shapesDirectory!, withIntermediateDirectories: false, attributes: nil)
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
        
        let imageURL = shapesDirectory!.URLByAppendingPathComponent(filename)
        let result = imageData.writeToURL(imageURL!, atomically: true)
        
        if ( !result ) { print("Could not save training image to URL: \(imageURL)") }
    }
}

// MARK: DrawingViewDelegate

extension LearnViewController : DrawingViewDelegate {
    
    func minimumImageSizeForDrawingView(drawingView: DrawingView) -> CGSize {
        var minimumSize = CGSize(width: 28.0, height: 28.0)
        if let inputDimension = self.shapeClassifyingNetwork?.inputDimension {
            minimumSize = CGSize(width: inputDimension, height: inputDimension)
        }
        return minimumSize
    }
    
    func drawingView(drawingView: DrawingView, didFinishDrawingImage image: UIImage) {
        
        guard let dimension = self.shapeClassifyingNetwork?.inputDimension else {
            print("Learn controller does not have a neural network to work with!")
            return
        }
        
        // Get an appropriately scaled image and convert it to
        // an array of grayscale Float values:
        
        // This scaling also results in a scaled stroke:
        //let scaledImage = image.imageScaledToSize(CGSize(width:dimension, height:dimension), withBorder:4.0)
        
        // This scaling keeps the stroke width constant:
        let scaledImage = drawingView.drawingAsImage(withSize: CGSize(width: dimension, height: dimension))
        self.sampleImageView.image = scaledImage
        
        let grayscaleData = scaledImage.grayscaleImageData(inverted:true)
            //printInputData(grayscaleData, stride: dimension)

        // Classify the data:
        
        guard let neuralNetwork = self.shapeClassifyingNetwork?.neuralNework else {
            print("Learn controller does not have a neural network to work with!")
            return
        }
        
        assert(neuralNetwork.numInputs == grayscaleData.count, "number of inputs provided does not match FFNN's expected number of inputs")
        
        do {
            let output = try neuralNetwork.update(inputs: grayscaleData)
            
            print("Output: \(output)")
            
            guard let detected = output.maxElement() else {
                return
            }
            
            let confidence = detected;
            
            let shape = Shape(rawValue: output.indexOf(detected)!)

            var shapeName = "Unknown Shape"
            var shapeSymbol = ""
            
            switch shape! {
            case .Circle:
                shapeName = "Circle"
                shapeSymbol = "⚫︎"
                print("Detected: Circle, \(confidence)");
            case.Square:
                shapeName = "Square"
                shapeSymbol = "■"
                print("Detected: Square, \(confidence)")
            case .Triangle:
                shapeName = "Triangle"
                shapeSymbol = "▲"
                print("Detected: Triangle, \(confidence)")
            default:
                print("Detected: Unknown shape, \(confidence)")
            }

            let statusString = String(format: "Detected a %@, confidence %.2f%%", shapeName, confidence * 100.0)
            self.statusLabel.text = statusString
            self.detectedLabel.text = shapeSymbol
            
            // Train with the result if user indicated
            
            var selectedShape: Shape? = nil
            if ( self.learnSquareSwitch.on ) { selectedShape = .Square }
            if ( self.learnCircleSwitch.on ) { selectedShape = .Circle }
            if ( self.learnTriangleSwitch.on ) { selectedShape = .Triangle }
            
            if let shapeToLearn = selectedShape {
                self.trainNetwork(withInputData: grayscaleData, correctShape: shapeToLearn)
                self.saveTrainingImage(scaledImage, forShapeType: shapeToLearn)
                   // stash off the shape to build up an archive for training:
            }
            
        } catch {
            print(error)
        }
    }
}

//MARK: Debugging

extension LearnViewController {
    
    func printInputData(data: [Float], stride: Int) {
        for index in 0.stride(to:stride * stride, by:stride) {
            
            let pretty = data[index ..< index + stride].map({ (grayValue) -> String in
                if ( grayValue == 1.0 ){ return "." }
                return "*"
            })
            
            print(pretty)
        }
    }
}
