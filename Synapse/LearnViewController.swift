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
    
    var neuralNetwork:FFNN?
    
    // MARK: - Private Properties
    
    @IBOutlet private weak var sampleView: UIView!
    @IBOutlet private weak var sampleImageView: UIImageView!
    @IBOutlet private weak var sampleBackgroundView: UIView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet private weak var scratchPadView: DrawingView!
    @IBOutlet private weak var scratchPadViewLabel: UILabel!
    
    @IBOutlet private weak var learnSquareSwitch: UISwitch!
    @IBOutlet private weak var learnCircleSwitch: UISwitch!
    @IBOutlet weak var learnTriangleSwitch: UISwitch!
    
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
        self.neuralNetwork?.writeToFile("shapes-ffnn")
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

// MARK: - DrawingViewDelegate

extension LearnViewController : DrawingViewDelegate {
    
    func drawingView(drawingView: DrawingView, didFinishDrawingImage image: UIImage) {
        
        //TODO: width and height should be tied to FFNN input size
        let dimension = 28
        
        //let scaledImage = image.imageScaledToSize(CGSize(width:dimension, height:dimension), withBorder:4.0)
        let scaledImage = drawingView.drawingAsImage(withSize: CGSize(width: dimension, height: dimension))
        self.sampleImageView.image = scaledImage
        
        let grayscaleData = scaledImage.grayscaleImageData(inverted:true)
        
        //TODO: pull this off into a function for clarity
        
        // visualize the array in characters for debugging:
        for index in 0.stride(to:dimension*dimension, by:dimension) {
            
            let pretty = grayscaleData[index..<index+dimension].map({ (grayValue) -> String in
                if ( grayValue == 1.0 ){ return "." }
                return "*"
            })
            
            print(pretty)
        }
        
        guard let neuralNetwork = self.neuralNetwork else {
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
//            let digit = Digit(rawValue: output.indexOf(detected)!)
//            
//            switch digit! {
//            case .Zero:
//                print("Detected: Zero, \(confidence)");
//            case .One:
//                print("Detected: One, \(confidence)");
//            case.Two:
//                print("Detected: Two, \(confidence)")
//            case .Three:
//                print("Detected: Three, \(confidence)")
//            case .Four:
//                print("Detected: Four, \(confidence)")
//            case .Five:
//                print("Detected: Five, \(confidence)")
//            case .Six:
//                print("Detected: Six, \(confidence)")
//            case .Seven:
//                print("Detected: Seven, \(confidence)")
//            case .Eight:
//                print("Detected: Eight, \(confidence)")
//            case .Nine:
//                print("Detected: Nine, \(confidence)")
//
//            default:
//                print("Detected: Unknown Digit, \(confidence)")
//            }
            
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
    
}
