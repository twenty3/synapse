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
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        splitViewController.delegate = self
        
        let inputDataDimension = 28
            // our input data is an image that is 28 x 28 'pixels'
        
        // load a saved network if we have one
        if let savedNetwork = FFNN.fromFile("shapes-ffnn") {
            print("Loaded a trained network from the documents directory")
            self.shapeClassifyingNetwork = ShapeClasifyingNetwork(neuralNework: savedNetwork, inputDimension: inputDataDimension)
        }
        else {
            print("Did not find a saved network, creating a new one")
        
            let newNetwork = FFNN(inputs: inputDataDimension * inputDataDimension, hidden: 280, outputs: Shape.count, learningRate: 0.75, momentum: 0.1, weights: nil, activationFunction: ActivationFunction.Default, errorFunction: ErrorFunction.default(average: true))
            self.shapeClassifyingNetwork = ShapeClasifyingNetwork(neuralNework: newNetwork, inputDimension: inputDataDimension)
        }
        
        
        let learnNavigationController = splitViewController.viewControllers[0] as! UINavigationController
        let learnViewController = learnNavigationController.viewControllers[0] as! LearnViewController
        learnViewController.shapeClassifyingNetwork = self.shapeClassifyingNetwork
        
        return true
    }

}

