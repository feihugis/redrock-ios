//
//  ContainerViewController.swift
//  RedRock
//
//  Created by Jonathan Alter on 5/28/15.
//

/**
* (C) Copyright IBM Corp. 2015, 2015
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
*/

import UIKit

@objc
protocol ContainerViewControllerDelegate {
    optional func displaySearchViewController()
}

enum SlideOutState {
    case BothCollapsed
    case RightPanelExpanded
}

class ContainerViewController: UIViewController {
    
    weak var delegate: ContainerViewControllerDelegate?
    
    var centerViewController: CenterViewController!
    var rightViewController: RightViewController!
    var rightPickerViewController: RightPickerViewController!
    
    var currentState: SlideOutState = .BothCollapsed
    let centerPanelExpandedOffset: CGFloat = 350
    
    var searchText: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centerViewController = UIStoryboard.centerViewController()
        centerViewController.delegate = self
        centerViewController.searchText = searchText
        
        view.addSubview(centerViewController.view)
        addChildViewController(centerViewController)
        
        centerViewController.didMoveToParentViewController(self)
    }
 
    func applicationWillResignActive(application: UIApplication) {
        if centerViewController != nil {
            centerViewController.applicationWillResignActive(application)
        }
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        if centerViewController != nil {
            centerViewController.applicationDidBecomeActive(application)
        }
    }
}

// MARK: - CenterViewControllerDelegate

extension ContainerViewController: RightViewControllerDelegate
{
    func executeActionOnGoClicked(searchTerms: String) {
        self.toggleRightPanel(false)
        self.searchText = searchTerms
        self.centerViewController.searchText = searchTerms
    }
}

extension ContainerViewController: CenterViewControllerDelegate {
    
    // If close is true, always close the panel
    // Necessary because if you go back to the main search screen and the side search is opened,
    // we need to close that
    func toggleRightPanel(close: Bool) {
        let notAlreadyExpanded = (currentState != .RightPanelExpanded)
        if close
        {
            if !notAlreadyExpanded
            {
                animateRightPanel(shouldExpand: false)
            }
        }
        else
        {
            if notAlreadyExpanded {
                addRightPanelViewController()
            }
            animateRightPanel(shouldExpand: notAlreadyExpanded)
        }

    }
    
    func addChildSidePanelController(sidePanelController: UIViewController) {
        view.insertSubview(sidePanelController.view, atIndex: 0)
        
        addChildViewController(sidePanelController)
        sidePanelController.didMoveToParentViewController(self)
    }
    
    func addRightPanelViewController() {
        if (Config.appState == .Live) {
            if (rightPickerViewController == nil) {
                rightPickerViewController = UIStoryboard.rightPickerViewController()
                self.rightPickerViewController.delegate = self
                addChildSidePanelController(rightPickerViewController!)
            }
            return
        } else {
            if (rightViewController == nil) {
                rightViewController = UIStoryboard.rightViewController()
                self.rightViewController.delegate = self
                self.rightViewController.searchString = self.searchText
                addChildSidePanelController(rightViewController!)
            }
        }
    }
    
    func animateRightPanel(shouldExpand shouldExpand: Bool) {
        if (shouldExpand) {
            if self.rightViewController != nil {
                self.rightViewController.searchString = self.searchText
                self.rightViewController.tableA.reloadData()
                self.rightViewController.tableB.reloadData()
            }
            currentState = .RightPanelExpanded
            animateCenterPanelXPosition(targetPosition: -centerPanelExpandedOffset)
        } else {
            animateCenterPanelXPosition(targetPosition: 0) { _ in
                self.currentState = .BothCollapsed
                
                if self.rightPickerViewController != nil {
                    self.rightPickerViewController!.view.removeFromSuperview()
                    self.rightPickerViewController = nil;
                }
                
                if self.rightViewController != nil {
                    self.rightViewController!.view.removeFromSuperview()
                    self.rightViewController = nil;
                }
            }
        }
    }
    
    func displaySearchViewController() {
        delegate?.displaySearchViewController?()
    }
    
    func animateCenterPanelXPosition(targetPosition targetPosition: CGFloat, completion: ((Bool) -> Void)! = nil) {
        UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .CurveEaseInOut, animations: {
            self.centerViewController.view.frame.origin.x = targetPosition
            }, completion: completion)
    }
    
}

extension UIStoryboard {
    class func mainStoryboard() -> UIStoryboard { return UIStoryboard(name: "Main", bundle: NSBundle.mainBundle()) }
    
    class func leftViewController() -> LeftViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("LeftViewController") as? LeftViewController
    }
    
    class func rightViewController() -> RightViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("RightViewController") as? RightViewController
    }
    
    class func rightPickerViewController() -> RightPickerViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("RightPickerViewController") as? RightPickerViewController
    }
    
    class func centerViewController() -> CenterViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("CenterViewController") as? CenterViewController
    }
    
    class func infoViewController() -> InfoViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("InfoViewController") as? InfoViewController
    }
    
    class func helpViewController() -> HelpViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("HelpViewController") as? HelpViewController
    }
    
    class func bottomDrawerViewController() -> BottomDrawerViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("BottomDrawerViewController") as? BottomDrawerViewController
    }
    
    class func rangeSliderViewController() -> RangeSliderViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("RangeSliderViewController") as? RangeSliderViewController
    }
    
    class func playBarViewController() -> PlayBarViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("PlayBarViewController") as? PlayBarViewController
    }
    
    class func visHolderViewController() -> VisHolderViewController? {
        return mainStoryboard().instantiateViewControllerWithIdentifier("VisHolderViewController") as? VisHolderViewController
    }
}
