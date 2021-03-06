//
//  RIghtViewController.swift
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
protocol RightViewControllerDelegate {
    func executeActionOnGoClicked(searchTerms: String)
}

class RightViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate, UITextFieldDelegate {
    
    @IBOutlet weak var textField: UITextField!

    @IBOutlet weak var tableA: UITableView!
    @IBOutlet weak var tableB: UITableView!
    
    @IBOutlet weak var doneView: UIView!
    @IBOutlet weak var doneHolderView: UIView!
    @IBOutlet weak var goButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    
    private var listA: RefArray?
    private var listB: RefArray?
    
    private var tempView: UIView?
    
    private var dragging = false
    private var panning = false
    private var draggedIndex = -1
    
    private var fromTable: UITableView!
    private var toTable: UITableView!
    
    private var fromList: RefArray?
    private var toList: RefArray?
    
    private var beginDraggingRect: CGRect?
    
    weak var delegate: RightViewControllerDelegate?
    var canEditRow = false
    
    var searchString: String? {
        didSet {
            self.setListTerms()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // UI Tweaks
        let spacerView = UIView(frame: CGRectMake(0, 0, 10, textField.frame.size.height)) // Setting text inset
        textField.leftViewMode = .Always
        textField.leftView = spacerView
        textField.attributedPlaceholder = NSAttributedString(string: "Search", attributes: [NSForegroundColorAttributeName: Config.sideSearchTextFieldPlaceholderColor])
        textField.keyboardType = UIKeyboardType.Twitter
        self.textField.returnKeyType = UIReturnKeyType.Done
        
        // Add Gesture Recognizers
        let gr1a = UISwipeGestureRecognizer(target: self, action: "handleSwipeA:")
        gr1a.direction = .Right
        gr1a.numberOfTouchesRequired = 1
        tableA.addGestureRecognizer(gr1a)
        
        let gr1aa = UISwipeGestureRecognizer(target: self, action: "handleSwipeA:")
        gr1aa.direction = .Left
        gr1aa.numberOfTouchesRequired = 1
        tableA.addGestureRecognizer(gr1aa)
        
        // Disabled: causes problems when pan allowed to startDragging
        // var gr2a = UILongPressGestureRecognizer(target: self, action: "handleLPA:")
        // tableA.addGestureRecognizer(gr2a)
        
        let gr3a = UIPanGestureRecognizer(target: self, action: "handlePanA:")
        gr3a.delegate = self
        tableA.addGestureRecognizer(gr3a)
        
        
        let gr1b = UISwipeGestureRecognizer(target: self, action: "handleSwipeB:")
        gr1b.direction = .Right
        gr1b.numberOfTouchesRequired = 1
        tableB.addGestureRecognizer(gr1b)
        
        let gr1bb = UISwipeGestureRecognizer(target: self, action: "handleSwipeB:")
        gr1bb.direction = .Left
        gr1bb.numberOfTouchesRequired = 1
        tableB.addGestureRecognizer(gr1bb)
        
        // Disabled: causes problems when pan allowed to startDragging
        // var gr2b = UILongPressGestureRecognizer(target: self, action: "handleLPB:")
        // tableB.addGestureRecognizer(gr2b)
        
        let gr3b = UIPanGestureRecognizer(target: self, action: "handlePanB:")
        gr3b.delegate = self
        tableB.addGestureRecognizer(gr3b)
        
        // Set TextFieldDelegate
        self.textField.delegate = self
    }
    
    func setListTerms()
    {
        listA = RefArray(arr:[])
        listB = RefArray(arr:[])
        let terms = self.searchString?.componentsSeparatedByString(",")
        for var i = 0; i < terms?.count; i++
        {
            let term = terms?[i]
            if term != ""
            {
                var aux = Array((term!).characters)
                if aux[0] == "-"
                {
                    aux.removeAtIndex(0)
                    listB?.array?.append(String(aux))
                }
                else
                {
                    listA?.array?.append(term!)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return canEditRow
    }
    
    @IBAction func goClicked(sender: UIButton)
    {
        if validateBeforeGo()
        {
            var stringSearch = ""
            let includeList = self.listA?.array as! Array<String>
            let excludeList:Array = self.listB?.array as! Array<String>
            for including in includeList
            {
                stringSearch = stringSearch + including + ","
            }
            for excluding in excludeList
            {
                stringSearch = stringSearch + "-" + excluding + ","
            }
            var aux = Array(stringSearch.characters)
            aux.removeLast()
            self.delegate?.executeActionOnGoClicked(String(aux))
        }
    }
    
    func validateBeforeGo() -> Bool
    {
        if self.listA?.array?.count > 0
        {
            return true
        }
        else
        {
            let animation = CABasicAnimation(keyPath: "position")
            animation.duration = 0.05
            animation.repeatCount = 2
            animation.autoreverses = true
            animation.fromValue = NSValue(CGPoint: CGPointMake(self.textField.center.x - 5, self.textField.center.y))
            animation.toValue = NSValue(CGPoint: CGPointMake(self.textField.center.x + 5, self.textField.center.y))
            self.textField.layer.addAnimation(animation, forKey: "position")
            return false
        }
        
    }
    
    func enableDelete() {
        deleteButton.hidden = false
    }
    
    func disableDelete() {
        deleteButton.hidden = true
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Potentially incomplete method implementation.
        // Return the number of sections.
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        checkGoButtonCondition()
        let list = (tableView === tableA) ? listA?.array : listB?.array
        return list!.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var list = (tableView === tableA) ? listA?.array : listB?.array
        let identifier = (tableView === tableA) ? "IncludeCell" : "ExcludeCell"
        
        let cell = tableView.dequeueReusableCellWithIdentifier(identifier) as UITableViewCell!
        
        let label = cell.viewWithTag(100) as! UILabel
        let cellText = list?[indexPath.row] as! String
        label.text = cellText
        cell.backgroundColor = Config.darkBlueColor
        return cell
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if (textField.text != nil) {
            var searchText = self.textField.text!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            searchText = searchText.stringByReplacingOccurrencesOfString(" ", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
            var terms = searchText.componentsSeparatedByString(",")
            for var i = 0; i < terms.count;  i++
            {
                let term = terms[i]
                if term != ""
                {
                    var aux = Array(term.characters)
                    if aux[0] == "-"
                    {
                        aux.removeAtIndex(0)
                        listB?.array?.append(String(aux))
                    }
                    else
                    {
                        listA?.array?.append(term)
                    }
                }
            }
            tableB.reloadData()
            tableA.reloadData()
            textField.text = ""
        }
        return false
    }
    
    // MARK: - Drag and Drop
    
    func cancelDragging() {
        if (!dragging) {
            return
        }
        
        tempView?.removeFromSuperview()
        tempView = nil
        
        dragging = false
        panning = false
        draggedIndex = -1
        fromTable = nil
        toTable = nil
        fromList = nil
        toList = nil
        
        disableDelete()
    }
    
    func startDragging(draggingIndex: Int, draggedName: String, draggedColor: UIColor, location: CGPoint) {
        dragging = true
        draggedIndex = draggingIndex
        tempView = UIView(frame: CGRectMake(0, 0, 130, 34))
        tempView?.backgroundColor = Config.darkBlueColor
        tempView?.layer.borderColor = Config.lightSeaGreen.CGColor
        tempView?.layer.borderWidth = 1
        let label = UILabel(frame: CGRectMake(0, 0, 130, 34))
        label.text = draggedName
        label.backgroundColor = Config.darkBlueColor
        label.textColor = draggedColor
        label.textAlignment = NSTextAlignment.Center
        tempView?.addSubview(label)
        // Adding view to parent so it can be seen on the entire screen
        self.parentViewController!.view.addSubview(tempView!)
        tempView?.center = location
        beginDraggingRect = tempView?.frame
        
        enableDelete()
    }
    
    func handleSwipe(gestureRecongnizer: UIGestureRecognizer, table: UITableView, list: RefArray) {
        let state = gestureRecongnizer.state
        let loc = gestureRecongnizer.locationInView(table)
        let indexPath = table.indexPathForRowAtPoint(loc)
        
        if (indexPath == nil) {
            return
        }
        
        let cell = table.cellForRowAtIndexPath(indexPath!)
        
        if (cell == nil) {
            return
        }
        
        let label = cell?.viewWithTag(100) as! UILabel
        let title = label.text
        let color = label.textColor
        
        if (indexPath!.row >= list.array!.count) {
            return
        }
        
        if (state != UIGestureRecognizerState.Ended) {
            return
        }
        
        if (dragging) {
            self.cancelDragging()
        }
        
        startDragging(indexPath!.row, draggedName: title!, draggedColor: color, location: gestureRecongnizer.locationInView(self.view))
    }
    
    func handleSwipeA(gestureRecognizer: UIGestureRecognizer) {
        fromTable = tableA
        toTable = tableB
        fromList = listA
        toList = listB
        self.handleSwipe(gestureRecognizer, table: fromTable, list: fromList!)
    }
    
    func handleSwipeB(gestureRecognizer: UIGestureRecognizer) {
        fromTable = tableB
        toTable = tableA
        fromList = listB
        toList = listA
        self.handleSwipe(gestureRecognizer, table: fromTable, list: fromList!)
    }
    
    func handleLP(gestureRecognizer: UIGestureRecognizer, table: UITableView, list: RefArray) {
        let state = gestureRecognizer.state
        let loc = gestureRecognizer.locationInView(table)
        let indexPath = table.indexPathForRowAtPoint(loc)
        
        if (indexPath == nil) {
            return
        }
        
        let cell = table.cellForRowAtIndexPath(indexPath!)
        
        if (cell == nil) {
            return
        }
        
        let label = cell?.viewWithTag(100) as! UILabel
        let title = label.text
        let color = label.textColor
        
        if (indexPath!.row >= list.array!.count) {
            return
        }
        
        if (state == UIGestureRecognizerState.Began) {
            if (dragging) {
                self.cancelDragging()
            }
            
            self.startDragging(indexPath!.row, draggedName: title!, draggedColor: color, location: gestureRecognizer.locationInView(self.view))
        } else if (state == UIGestureRecognizerState.Ended) {
            if (dragging && !panning) {
                self.cancelDragging()
            }
        }
    }
    
    func handleLPA(gestureRecognizer: UIGestureRecognizer) {
        fromTable = tableA
        toTable = tableB
        fromList = listA
        toList = listB
        self.handleLP(gestureRecognizer, table: fromTable, list: fromList!)
    }
    
    func handleLPB(gestureRecognizer: UIGestureRecognizer) {
        fromTable = tableB
        toTable = tableA
        fromList = listB
        toList = listA
        self.handleLP(gestureRecognizer, table: fromTable, list: fromList!)
    }
    
    func handlePan(gestureRecognizer: UIGestureRecognizer, table: UITableView, list: RefArray) {
        let state = gestureRecognizer.state
        let loc = gestureRecognizer.locationInView(self.view)
        
        if (state == UIGestureRecognizerState.Began) {
            panning = true
            
            // Enabling startdrag on pan, this will not work well with a scrolling TableView
            let tableLoc = gestureRecognizer.locationInView(table)
            let indexPath = table.indexPathForRowAtPoint(tableLoc)
            
            if (indexPath == nil) {
                return
            }
            
            let cell = table.cellForRowAtIndexPath(indexPath!)
            
            if (cell == nil) {
                return
            }
            
            let label = cell?.viewWithTag(100) as! UILabel
            let title = label.text
            let color = label.textColor
            
            if (indexPath!.row >= list.array!.count) {
                // Log("Non in any row")
                return
            }
            
            self.startDragging(indexPath!.row, draggedName: title!, draggedColor: color, location: gestureRecognizer.locationInView(self.view))
        }
        
        if (state == UIGestureRecognizerState.Ended) {
            if (dragging) {
                var locInView = gestureRecognizer.locationInView(fromTable)
                if (CGRectContainsPoint(fromTable.bounds, locInView)) {
                    // Log("Dropped in FROM table")
                    return cancel()
                }
                
                locInView = gestureRecognizer.locationInView(toTable)
                if (CGRectContainsPoint(fromTable.bounds, locInView)) {
                    // Log("Dropped in TO table")
                    let rowData: AnyObject = fromList!.array!.removeAtIndex(draggedIndex)
                    toList!.array!.append(rowData)
                    
                    var arr = [NSIndexPath(forRow: draggedIndex, inSection: 0)]
                    fromTable.deleteRowsAtIndexPaths(arr, withRowAnimation: UITableViewRowAnimation.Automatic)
                    
                    let row = toList!.array!.count-1
                    arr = [NSIndexPath(forRow: row, inSection: 0)]
                    toTable.insertRowsAtIndexPaths(arr, withRowAnimation: UITableViewRowAnimation.Automatic)
                    
                    self.cancelDragging()
                    return
                }
                
                locInView = gestureRecognizer.locationInView(doneHolderView)
                if (CGRectContainsPoint(doneHolderView.bounds, locInView)) {
                    // Log("Dropped in TO DELETE")
                    fromList!.array!.removeAtIndex(draggedIndex)
                    let arr = [NSIndexPath(forRow: draggedIndex, inSection: 0)]
                    fromTable.deleteRowsAtIndexPaths(arr, withRowAnimation: UITableViewRowAnimation.Automatic)
                    
                    self.cancelDragging()
                    return
                }
                
                cancel()
            }
        }
        
        if (dragging) {
            tempView?.center = loc
            
            let locInView = gestureRecognizer.locationInView(doneHolderView)
            if (CGRectContainsPoint(doneHolderView.bounds, locInView)) {
                // Log("In DELETE")
                
                return
            } else {
                
            }
        }
        
    }
    
    func cancel() {
        self.cancelDragging()
    }
    
    func handlePanA(gestureRecognizer: UIGestureRecognizer) {
        // Log("PAN:" + __FUNCTION__)
        fromTable = tableA
        toTable = tableB
        fromList = listA
        toList = listB
        self.handlePan(gestureRecognizer, table: fromTable, list: fromList!)
    }
    
    func handlePanB(gestureRecognizer: UIGestureRecognizer) {
        // Log(__FUNCTION__)
        fromTable = tableB
        toTable = tableA
        fromList = listB
        toList = listA
        self.handlePan(gestureRecognizer, table: fromTable, list: fromList!)
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // MARK: - Actions
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        
        if tableView === tableA
        {
            listA?.array?.removeAtIndex(indexPath.row)
        }
        else
        {
            listB?.array?.removeAtIndex(indexPath.row)
        }
        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Fade)
    }
    
    func checkGoButtonCondition()
    {
        if listA?.array?.count == 0
        {
            goButton.enabled = false
        }
        else
        {
            goButton.enabled = true
        }
    }
    
    
    // MARK: - Utilities
    
    func stateToString(state: UIGestureRecognizerState) -> (String) {
        switch state {
        case .Possible:
            return "Possible"
        case .Began:
            return "Began"
        case .Changed:
            return "Changed"
        case .Ended:
            return "Ended"
        case .Cancelled:
            return "Cancelled"
        case .Failed:
            return "Failed"
        }
    }
    
    // MARK: Utility Classes
    
    // Pass an Array by reference
    class RefArray {
        var array: Array<AnyObject>?
        
        init(arr: Array<AnyObject>) {
            array = arr
        }
    }
}
