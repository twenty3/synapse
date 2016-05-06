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
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var scratchPadView: DrawingView!
    @IBOutlet private weak var scratchPadViewLabel: UILabel!
    
    @IBOutlet private weak var learnSquareSwitch: UISwitch!
    @IBOutlet private weak var learnCircleSwitch: UISwitch!
    @IBOutlet private weak var learnTriangleSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.statusLabel.text = ""
        
        self.sampleImageView.layer.cornerRadius = 10.0
        self.sampleImageView.layer.masksToBounds = true
        self.sampleBackgroundView.layer.cornerRadius = 10.0
        self.sampleBackgroundView.layer.masksToBounds = true
        
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
        
        // This scaling also results in a scaled stroke:
        //let scaledImage = image.imageScaledToSize(CGSize(width:dimension, height:dimension), withBorder:4.0)
        
        // This scaling keeps the stroke width constant:
        let scaledImage = drawingView.drawingAsImage(withSize: CGSize(width: dimension, height: dimension))
        self.sampleImageView.image = scaledImage
        
        let grayscaleData = scaledImage.grayscaleImageData(inverted:true)
        //printInputData(grayscaleData, stride: dimension)

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
            
            switch shape! {
            case .Circle:
                shapeName = "Circle"
                print("Detected: Circle, \(confidence)");
            case.Square:
                shapeName = "Square"
                print("Detected: Square, \(confidence)")
            case .Triangle:
                shapeName = "Triangle"
                print("Detected: Triangle, \(confidence)")
            default:
                print("Detected: Unknown shape, \(confidence)")
            }

            var statusString = String(format: "Detected a %@, confidence %.2f%%", shapeName, confidence * 100.0)
            
            var shapeToLearn: Shape? = nil
            if ( self.learnSquareSwitch.on ) { shapeToLearn = .Square }
            if ( self.learnCircleSwitch.on ) { shapeToLearn = .Circle }
            if ( self.learnTriangleSwitch.on ) { shapeToLearn = .Triangle }
            
            guard let selectedShape = shapeToLearn else {
                self.statusLabel.text = statusString
                return
            }
            
            var answer = [Float](count: 3, repeatedValue:0.0)
            answer[selectedShape.rawValue] = 1.0
            
            print("Learning that last shape was a: \(selectedShape.toString())")
            print("(answer: \(answer)")

            statusString = statusString + "\nLearing last shape was a \(selectedShape)."
            self.statusLabel.text = statusString
            
            var error: Float = 1.0
            while error > 0.1 {
                try error = neuralNetwork.backpropagate(answer: answer)
                try neuralNetwork.update(inputs: grayscaleData)
                print ("TRAINED: \(error)")
            }
            
            // stash off the shape to build up an archive for training:
            
            let manager = NSFileManager.defaultManager()
            let documentsDirectory = try! manager.URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
            let shapesDirectory = documentsDirectory.URLByAppendingPathComponent(selectedShape.toString())
            let filename = NSUUID.init().UUIDString
            
            do {
                try manager.createDirectoryAtURL(shapesDirectory, withIntermediateDirectories: false, attributes: nil)
            }
            catch let error as NSError {
                if ( error.code != NSFileWriteFileExistsError )
                {
                    print(error)
                }
            }
            
            guard let imageData = UIImagePNGRepresentation(scaledImage) else {
                print(error)
                return
            }
            
            let imageURL = shapesDirectory.URLByAppendingPathComponent(filename)
            imageData.writeToURL(imageURL, atomically: true)
            
            
        } catch {
            print(error)
        }
    }
    
    //MARK: Debugging
    
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
