//
//  DrawerNavigationController.swift
//
//  Created by Collin Hundley on 8/26/15.
//

import UIKit

class DrawerNavigationController: UIViewController, UIGestureRecognizerDelegate {
   
    let drawerWidth = UIScreen.mainScreen().bounds.width * 0.6
    let navBar = NavigationBar()
    var drawerViewController: DrawerViewController!
    var viewControllers = [UIViewController]()
    var drawerLocked = false
    
    // Private state variables
    private var views = [UIView]()
    private var currentView: UIView!
    private var touchBeginLocation: CGPoint?
    private var open = false
    
    private var infoView: InfoView?
    /// Once infoView has been dragged this far, it will be dismissed
    private let infoViewThreshold: CGFloat = 80
    
    private static var globalDrawerNavController: DrawerNavigationController!
    
    convenience init(viewControllers: [UIViewController]) {
        self.init()
        self.viewControllers = viewControllers
        DrawerNavigationController.setGlobalDrawerController(self)
    }
    
    /// Returns the singleton instance of the app's top-level drawer navigation controller.
    class func globalDrawerController() -> DrawerNavigationController {
        return self.globalDrawerNavController
    }
    
    /// Assigns the app's top-level drawer navigation controller.
    class func setGlobalDrawerController(controller: DrawerNavigationController) {
        self.globalDrawerNavController = controller
    }
    
    /// Sets the status bar style for the whole app
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .drawerColor()
        
        // Configure nav bar
        self.navBar.hamburgerButton.addTarget(self, action: #selector(hamburgerTapped), forControlEvents: .TouchUpInside)
        self.view.addSubview(self.navBar)
        navBar.addConstraints(
            Constraint.llrr.of(view),
            Constraint.tt.of(view),
            Constraint.h.of(64))
        
//        self.navBar.constrainUsing(constraints: [
//            Constraint.ll : (of: self.view, offset: 0),
//            Constraint.rr : (of: self.view, offset: 0),
//            Constraint.tt : (of: self.view, offset: 0),
//            Constraint.h : (of: nil, offset: 64)])
        
        // Configure drawer
        self.drawerViewController = DrawerViewController()
        self.drawerViewController.viewControllers = self.viewControllers
        self.view.addSubview(self.drawerViewController.view)
        
        drawerViewController.view.addConstraints(
            Constraint.ll.of(view),
            Constraint.w.of(drawerWidth),
            Constraint.tt.of(view, offset: 64),
            Constraint.bb.of(view))
        
//        self.drawerViewController.view.constrainUsing(constraints: [
//            Constraint.ll : (of: self.view, offset: 0),
//            Constraint.w : (of: nil, offset: drawerWidth),
//            Constraint.tt : (of: self.view, offset: 64),
//            Constraint.bb : (of: self.view, offset: 0)])
        
        // Configure view controllers
        self.views = self.viewControllers.map({ (viewController) -> UIView in
            return viewController.view
        })
        // Assign first view as initial view
        self.view.addSubview(self.views[0])
        views[0].addConstraints(
            Constraint.llrr.of(view),
            Constraint.tt.of(view, offset: 64),
            Constraint.bb.of(view))
//        self.views[0].constrainUsing(constraints: [
//            Constraint.ll : (of: self.view, offset: 0),
//            Constraint.rr : (of: self.view, offset: 0),
//            Constraint.tt : (of: self.view, offset: 64),
//            Constraint.bb : (of: self.view, offset: 0)])
        self.currentView = self.views[0]
        self.addShadowToCurrentView()
    }
    
    private func addShadowToCurrentView() {
        self.currentView.layer.shadowColor = UIColor.darkGrayColor().CGColor
        self.currentView.layer.shadowOpacity = 0.7
        self.currentView.layer.shadowRadius = 5
        self.currentView.layer.shadowOffset = CGSize(width: -3, height: 5)
    }
    
    /// Resets touchBeginLocation in order to track drag distance
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if self.drawerLocked {
            return
        }
        switch self.infoView {
        case nil:
            let location = touches.first!.locationInView(self.currentView)
            self.touchBeginLocation = location
        default:
            let location = touches.first!.locationInView(self.infoView)
            self.touchBeginLocation = location
        }
    }
    
    /// Transforms the top-level view as the user slides their finger
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if self.drawerLocked {
            return
        }
        switch self.infoView {
        case nil: // Info view not present; open drawer as usual
            let location = touches.first!.locationInView(self.currentView)
            // Current x position of drag
            let x = location.x
            if let start = self.touchBeginLocation {
                // Distance that has been dragged
                let diff = x - start.x
                // Transform top-level view to drag position
                self.currentView.transform = CGAffineTransformTranslate(self.currentView.transform, diff, 0)
                self.transformDrawer()
                if self.currentView.transform.tx < 0 {
                    // Don't allow the view to transform to the left of the screen
                    self.currentView.transform = CGAffineTransformIdentity
                } else if self.currentView.transform.tx > self.drawerWidth {
                    // Once the drawer is fully open, transform the view with a decaying curve
                    let distance = pow(self.currentView.transform.tx - self.drawerWidth, 0.8)
                    self.currentView.transform = CGAffineTransformMakeTranslation(self.drawerWidth + distance, 0)
                }
            }
        default: // Info view is present; control it instead of the drawer
            let location = touches.first!.locationInView(self.infoView)
            // Current y position of drag
            let y = location.y
            if let start = self.touchBeginLocation {
                // Distance that has been dragged
                let diff = y - start.y
                // Transform top-level view to drag position
                self.infoView!.transform = CGAffineTransformTranslate(self.infoView!.transform, 0, diff)
                if self.infoView!.transform.ty < 0 {
                    // Don't allow the view to transform above the screen
                    self.infoView!.transform = CGAffineTransformIdentity
                }
            }
        }
    }
    
    /// Calculates the drawer's transformation while in any state
    private func transformDrawer() {
        let x = self.currentView.transform.tx
        var scale = 0.00007 * x + 0.98
        scale = scale.clamp(min: 0.98, max: 1.0)
        self.drawerViewController.drawerView.transform = CGAffineTransformMakeScale(scale, scale)
        var translate = -0.033 * x + 10
        translate = translate.clamp(min: 0, max: 10)
        self.drawerViewController.drawerView.transform = CGAffineTransformTranslate(self.drawerViewController.drawerView.transform, translate, 0)
    }
    
    /// Snaps the drawer open/closed depending on current position
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if self.drawerLocked {
            return
        }
        if self.infoView != nil {
            if self.infoView!.transform.ty > self.infoViewThreshold {
                // Dismiss info view
                self.dismissInfoView()
            } else {
                // Pop info view back open
                UIView.animateWithDuration(0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: .AllowUserInteraction, animations: { () -> Void in
                    self.infoView!.transform = CGAffineTransformIdentity
                    }, completion: nil)
            }
            return
        }
        switch self.open {
        case true:
            if self.currentView.transform.tx < self.drawerWidth - 20 {
                // Snap closed
                UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 5, options: .AllowUserInteraction, animations: { () -> Void in
                    self.currentView.transform = CGAffineTransformIdentity
                    self.transformDrawer()
                    }, completion: { (Bool) -> Void in
                        self.open = false
                })
            } else {
                // Snap open
                UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 5, options: .AllowUserInteraction, animations: { () -> Void in
                    self.currentView.transform = CGAffineTransformMakeTranslation(self.drawerWidth, 0)
                    self.transformDrawer()
                    }, completion: { (Bool) -> Void in
                        self.open = true
                })
            }
        case false:
            if self.currentView.transform.tx < 20 {
                // Snap closed
                UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 5, options: .AllowUserInteraction, animations: { () -> Void in
                    self.currentView.transform = CGAffineTransformIdentity
                    self.transformDrawer()
                    }, completion: { (Bool) -> Void in
                        self.open = false
                })
            } else {
                // Snap open
                UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 5, options: .AllowUserInteraction, animations: { () -> Void in
                    self.currentView.transform = CGAffineTransformMakeTranslation(self.drawerWidth, 0)
                    self.transformDrawer()
                    }, completion: { (Bool) -> Void in
                        self.open = true
                })
            }
        }
    }
    
    /// Called when the hamburger button is tapped
    func hamburgerTapped() {
        self.transformDrawer()
        if self.open {
            self.closeDrawer(completion: nil)
        } else {
            self.openDrawer(completion: nil)
        }
    }
    
    /// Switches the top-level view to another view at the specified index, and closes the drawer
    /// - parameter index: The index of the view to present (from the drawer's `viewControllers` property)
    /// - parameter completion: An optional completion block to execute when animation has finished
    func switchToViewAtIndex(index: Int, completion: (() -> Void)?) {
        let view = self.views[index]
        // Just close the drawer if they select the current view
        if view == self.currentView {
            self.closeDrawer(completion: nil)
            completion?()
            return
        }
        view.alpha = 0
        self.view.insertSubview(view, aboveSubview: self.currentView)
        view.addConstraints(
            Constraint.llrr.of(self.view),
            Constraint.tt.of(self.view, offset: 64),
            Constraint.bb.of(self.view))
//        view.constrainUsing(constraints: [
//            Constraint.ll : (of: self.view, offset: 0),
//            Constraint.rr : (of: self.view, offset: 0),
//            Constraint.tt : (of: self.view, offset: 64),
//            Constraint.bb : (of: self.view, offset: 0)])
        view.transform = self.currentView.transform
        self.drawerViewController.drawerView.tableView.userInteractionEnabled = false
        // Swap the views and animate the drawer closed
        UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 5, options: .AllowUserInteraction, animations: { () -> Void in
            view.alpha = 1
            view.transform = CGAffineTransformIdentity
            self.currentView.transform = CGAffineTransformIdentity
            self.transformDrawer()
            }, completion: { (Bool) -> Void in
                self.currentView.removeFromSuperview()
                self.currentView = view
                self.addShadowToCurrentView()
                self.drawerViewController.drawerView.tableView.userInteractionEnabled = true
                self.open = false
                completion?()
        })
    }
    
    /// Opens the drawer menu
    func openDrawer(completion completion: (() -> Void)?) {
        // Don't allow opening if drawer is locked, and don't bother animating if drawer is already open
        if self.drawerLocked || self.open {
            completion?()
            return
        }
        // Animate to open position
        UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 5, options: .AllowUserInteraction, animations: { () -> Void in
            self.currentView.transform = CGAffineTransformMakeTranslation(self.drawerWidth, 0)
            self.transformDrawer()
            }, completion: { (Bool) -> Void in
                self.open = true
        })
    }
    
    /// Closes the drawer menu
    func closeDrawer(completion completion: (() -> Void)?) {
        // Don't allow closing if drawer is locked, and don't bother animating if drawer is already closed
        if self.drawerLocked || !self.open {
            completion?()
            return
        }
        // Animate to closed position
        UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 5, options: .AllowUserInteraction, animations: { () -> Void in
            self.currentView.transform = CGAffineTransformIdentity
            self.transformDrawer()
            }, completion: { (Bool) -> Void in
                self.open = false
                completion?()
        })
    }
    
    func presentInfoView(infoView: InfoView) {
        guard self.infoView == nil else {
            return
        }
        self.infoView = infoView
        self.view.addSubview(infoView)
        infoView.fillSuperview()
        infoView.dismissButton.addTarget(self, action: #selector(dismissInfoView), forControlEvents: .TouchUpInside)
        infoView.transform = CGAffineTransformMakeTranslation(0, UIScreen.mainScreen().bounds.height)
        UIView.animateWithDuration(0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: { () -> Void in
            infoView.transform = CGAffineTransformIdentity
        }, completion: nil)
    }
    
    func dismissInfoView() {
        guard let infoView = self.infoView else {
            return
        }
        UIView.animateWithDuration(0.4, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: [], animations: { () -> Void in
            infoView.transform = CGAffineTransformMakeTranslation(0, UIScreen.mainScreen().bounds.height)
        }) { (Bool) -> Void in
            infoView.removeFromSuperview()
            self.infoView = nil
        }
    }
    

}
