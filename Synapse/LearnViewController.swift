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
    
    @IBOutlet fileprivate weak var sampleView: UIView!
    @IBOutlet fileprivate weak var sampleImageView: UIImageView!
    @IBOutlet fileprivate weak var sampleBackgroundView: UIView!
    @IBOutlet fileprivate weak var detectedLabel: UILabel!
    @IBOutlet fileprivate weak var detectedBackgroundView: UIView!
    @IBOutlet fileprivate weak var statusLabel: UILabel!
    @IBOutlet fileprivate weak var scratchPadView: DrawingView!
    @IBOutlet fileprivate weak var scratchPadViewLabel: UILabel!
    
    @IBOutlet fileprivate weak var learnSquareSwitch: UISwitch!
    @IBOutlet fileprivate weak var learnCircleSwitch: UISwitch!
    @IBOutlet fileprivate weak var learnTriangleSwitch: UISwitch!
    
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
    
    @IBAction fileprivate func saveButtonTapped(_ sender: AnyObject) {
        self.shapeClassifyingNetwork?.neuralNework.writeToFile("shapes-ffnn")
        print("Saved network to documents directory")
    }
    
    @IBAction fileprivate func learnSwitchChanged(_ sender: AnyObject) {
        
        var title = "⬇︎ Draw a Shape Here ⬇︎"
        
        if (sender as? UISwitch != self.learnSquareSwitch ) {
            self.learnSquareSwitch.setOn(false, animated: true)
        }
        else if ( self.learnSquareSwitch.isOn ) {
            title = "⬇︎ Draw a Square Here ⬇︎"
        }
        
        if (sender as? UISwitch != self.learnCircleSwitch ) {
            self.learnCircleSwitch.setOn(false, animated: true)
        }
        else if ( self.learnCircleSwitch.isOn ) {
            title = "⬇︎ Draw a Circle Here ⬇︎"
        }
        
        if (sender as? UISwitch != self.learnTriangleSwitch ) {
            self.learnTriangleSwitch.setOn(false, animated: true)
        }
        else if ( self.learnTriangleSwitch.isOn ) {
            title = "⬇︎ Draw a Triangle Here ⬇︎"
        }
     
        UIView.transition(with: self.scratchPadViewLabel, duration: 0.33, options: UIViewAnimationOptions.transitionCrossDissolve, animations: { 
            self.scratchPadViewLabel.text = title;
            }, completion: nil)
    }
    
    //MARK: Training
    
    func trainNetwork(withInputData inputData: [Float], correctShape: Shape) {
        
        // translate from Shape to output array:
        var answer = [Float](repeating: 0.0, count: 3)
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
                try _ = neuralNetwork.update(inputs: inputData)
                print ("TRAINED: \(error)")
            }
            catch {
                print("Problem trianing network: \(error)")
            }
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

// MARK: DrawingViewDelegate

extension LearnViewController : DrawingViewDelegate {
    
    func minimumImageSizeForDrawingView(_ drawingView: DrawingView) -> CGSize {
        var minimumSize = CGSize(width: 28.0, height: 28.0)
        if let inputDimension = self.shapeClassifyingNetwork?.inputDimension {
            minimumSize = CGSize(width: inputDimension, height: inputDimension)
        }
        return minimumSize
    }
    
    func drawingView(_ drawingView: DrawingView, didFinishDrawingImage image: UIImage) {
        
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
            
            guard let detected = output.max() else {
                return
            }
            
            let confidence = detected;
            
            let shape = Shape(rawValue: output.index(of: detected)!)

            var shapeName = "Unknown Shape"
            var shapeSymbol = ""
            
            switch shape! {
            case .circle:
                shapeName = "Circle"
                shapeSymbol = "⚫︎"
                print("Detected: Circle, \(confidence)");
            case.square:
                shapeName = "Square"
                shapeSymbol = "■"
                print("Detected: Square, \(confidence)")
            case .triangle:
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
            if ( self.learnSquareSwitch.isOn ) { selectedShape = .square }
            if ( self.learnCircleSwitch.isOn ) { selectedShape = .circle }
            if ( self.learnTriangleSwitch.isOn ) { selectedShape = .triangle }
            
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
