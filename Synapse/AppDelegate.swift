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
    var neuralNetwork: FFNN?
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem()
        splitViewController.delegate = self
        
        // load the trained handwritting nueral network
        //let url = NSBundle.mainBundle().URLForResource("handwriting-ffnn", withExtension: nil)!
        //self.neuralNetwork = FFNN.fromFile(url)
        
        self.neuralNetwork = FFNN.fromFile("shapes-ffnn")
        
        if ( self.neuralNetwork == nil )
        {
            print("Did not find a saved network, creating a new one")
            //TODO: this value shouldn't be a magic number
            let dimension = 28
            self.neuralNetwork = FFNN(inputs: dimension * dimension, hidden: 280, outputs: Shape.count, learningRate: 0.75, momentum: 0.1, weights: nil, activationFunction: ActivationFunction.Default, errorFunction: ErrorFunction.Default(average: true))
        }
        
        let learnNavigationController = splitViewController.viewControllers[0] as! UINavigationController
        let learnViewController = learnNavigationController.viewControllers[0] as! LearnViewController
        learnViewController.neuralNetwork = self.neuralNetwork
        
        return true
    }

}

