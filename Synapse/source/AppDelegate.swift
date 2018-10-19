//
//  AppDelegate.swift
//  Synapse
//
//  Created by 23 on 4/17/16.
//  Copyright © 2016 Escape Plan. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?
    var shapeClassifyingNetwork: ShapeClasifyingNetwork?
    let shapeClassifier = ImageClassifier()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        splitViewController.delegate = self
        
        let inputDataDimension = 28
            // our input data is an image that is 28 x 28 'pixels'
        
        // load a saved network if we have one
        let documentsURL = URL.documentsURL(with: "shapes-ffnn")
        if !FileManager.default.fileExists(atPath: documentsURL.path),
           let bundlePath = Bundle.main.path(forResource: "shapes-ffnn", ofType: nil)  {
            do {
                try FileManager.default.copyItem(at: URL(fileURLWithPath: bundlePath), to: documentsURL)
                print("copied default network from bundle to documents")
            }
            catch {
                print("could not copy default network from bundle to documents");
            }
        }
        
        if let savedNetwork = try? NeuralNet(url: documentsURL) {
            print("Loaded a trained network from the documents directory")
            self.shapeClassifyingNetwork = ShapeClasifyingNetwork(neuralNework: savedNetwork, inputDimension: inputDataDimension)
        }
        else {
            print("Did not find a saved network, creating a new one")
        
            do {
                let structure = try NeuralNet.Structure(
                    nodes: [inputDataDimension*inputDataDimension, 280, Shape.count],
                    hiddenActivation: NeuralNet.ActivationFunction.Hidden.sigmoid,
                    outputActivation: NeuralNet.ActivationFunction.Output.sigmoid,
                    batchSize: 1,
                    learningRate: 0.1,
                    momentum: 0.25
                )
                
                let newNetwork = try NeuralNet(structure: structure)
                self.shapeClassifyingNetwork = ShapeClasifyingNetwork(neuralNework: newNetwork, inputDimension: inputDataDimension)
            }
            catch {
                print(error)
            }
        }
        
        let learnNavigationController = splitViewController.viewControllers[0] as! UINavigationController
        let learnViewController = learnNavigationController.viewControllers[0] as! LearnViewController
        learnViewController.shapeClassifyingNetwork = self.shapeClassifyingNetwork
        learnViewController.coreMLClassifier = self.shapeClassifier
        
        let canvasNavigationController = splitViewController.viewControllers[1] as! UINavigationController
        let canvasViewController = canvasNavigationController.viewControllers[0] as! CanvasViewController
        canvasViewController.shapeClassifyingNetwork = self.shapeClassifyingNetwork
        canvasViewController.coreMLClassifier = self.shapeClassifier
        
        return true
    }
}

extension URL {
    static func documentsURL(with filename: String) -> URL {
        let manager = FileManager.default
        let dirURL = try! manager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        return dirURL.appendingPathComponent(filename)
    }
}

