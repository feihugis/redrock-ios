//
//  ViewController.swift
//  RedRock
//
//  Created by Jonathan Alter on 5/27/15.
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
import WebKit
import MessageUI
import Social
import MapKit
import Darwin

@objc
protocol CenterViewControllerDelegate {
    optional func toggleRightPanel(close: Bool)
    optional func collapseSidePanels()
    optional func displaySearchViewController()
}

class CenterViewController: UIViewController, MKMapViewDelegate, UIScrollViewDelegate, PageControlDelegate, LeftViewControllerDelegate, PlayBarViewControllerDelegate, MFMailComposeViewControllerDelegate, NetworkDelegate {

    var networkTimer : NSTimer!
    
    var networkError: NSError!
    var searchText: String? {
        didSet {
            self.cleanViews()
            
            switch Config.appState {
            case .Historic:
                self.loadDataFromServer()
            case .Live:
                startNetworkTimer()
            }
        }
    }
    weak var delegate: CenterViewControllerDelegate?
    var lineSeparatorWidth = CGFloat(4)
    
    var visualizationsByIndex = [VisMasterViewController]()
    var visualizationsByType = [VisTypes: VisMasterViewController]()
    
    var leftViewController: LeftViewController!
    static var leftViewOpen = false
    
    var bottomDrawerViewController: BottomDrawerViewController!
    var rangeSliderViewController: RangeSliderViewController!
    var playBarViewController: PlayBarViewController!
    
    var leftPanelInConstraint: [NSLayoutConstraint]?
    
    // last visited page
    var currentPage : Int = 0
    var previousPage : Int = 0
    var pageChanged = false
    
    var canUpdateSearch = false
    
    @IBOutlet weak var headerLabel: UIButton!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var liveButton: UIButton!
    
    @IBOutlet weak var pageControlViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var dummyView: UIView!
    @IBOutlet weak var scrollView: ResizingScrollView!
    @IBOutlet weak var holderView: UIView!
    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var scrollViewLoadingView: UIView!
    
    @IBOutlet weak var statusBarSeparator: UIView!
    @IBOutlet weak var pageControlView: PageControlView!
    @IBOutlet weak var bottomDrawerHolder: UIView!
    
    @IBOutlet weak var holderViewLeadingEdge: NSLayoutConstraint!
    @IBOutlet weak var dummyViewLeadingEdge: NSLayoutConstraint!
    @IBOutlet weak var footerViewLeadingEdge: NSLayoutConstraint!
    @IBOutlet weak var bottomDrawerHolderLeadingEdge: NSLayoutConstraint!
    @IBOutlet weak var bottomDrawerHolderBottomEdge: NSLayoutConstraint!
    
    var firstLoad = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.scrollView.delegate = self

        pageControlView.buttonBackgroundColor = UIColor.clearColor()
        pageControlView.buttonSelectedBackgroundColor = Config.darkBlueColor
        
        for i in 0..<Config.visualizationTypes.count{
            pageControlView.buttonData.append(PageControlButtonData(imageName: Config.visualizationButtons[i], selectedImageName: Config.visualizationButtonsSelected[i]))
        }
        
        pageControlView.delegate = self
        self.pageControlViewWidthConstraint.constant = CGFloat(pageControlView.buttonData.count * pageControlView.buttonWidth)
        
        self.headerLabel.setTitle(self.searchText, forState: UIControlState.Normal)
        
        addLeftPanelViewController()
        addBottomDrawerViewController()
        
        switch Config.appState {
        case .Historic:
            Log("CenterViewController viewDidLoad in historic mode")
            searchButton.hidden = false
            liveButton.hidden = true
        case .Live:
            Log("CenterViewController viewDidLoad in live mode")
            searchButton.hidden = true
            liveButton.hidden = false
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(animated: Bool) {
        self.resetViewController()
    }
    
    override func viewDidAppear(animated: Bool) {
        if firstLoad
        {
            self.setupWebViews()
        }
        firstLoad = false
    }
    
    override func viewDidDisappear(animated: Bool) {
        stopNetworkTimer()
    }
    
    func applicationWillResignActive(application: UIApplication) {
        stopNetworkTimer()
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        switch Config.appState {
        case .Live:
            startNetworkTimer()
        default:
            break
        }
        
    }
    
    func addLeftPanelViewController() {
        leftViewController = UIStoryboard.leftViewController()
        leftViewController.delegate = self
        view.addSubview(leftViewController.view)
        addChildViewController(leftViewController)
        leftViewController.didMoveToParentViewController(self)
        
        let views = [
            "leftViewControllerView": leftViewController.view
        ]
        leftViewController.view.translatesAutoresizingMaskIntoConstraints = false
        let viewConst_W = NSLayoutConstraint.constraintsWithVisualFormat("H:|-(-350@990)-[leftViewControllerView(354)]", options: NSLayoutFormatOptions.DirectionLeadingToTrailing, metrics: nil, views: views)
        let viewConst_H = NSLayoutConstraint.constraintsWithVisualFormat("V:|[leftViewControllerView]|", options: NSLayoutFormatOptions.DirectionLeadingToTrailing, metrics: nil, views: views)
        view.addConstraints(viewConst_W)
        view.addConstraints(viewConst_H)
    }
    
    func addBottomDrawerViewController() {
        bottomDrawerViewController = UIStoryboard.bottomDrawerViewController()
        bottomDrawerHolder.addSubview(bottomDrawerViewController.view)
        addChildViewController(bottomDrawerViewController)
        bottomDrawerViewController.didMoveToParentViewController(self)
        
        // Set contraints
        let views = [
            "bottomDrawerControllerView": bottomDrawerViewController.view
        ]
        bottomDrawerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        let viewConst_W = NSLayoutConstraint.constraintsWithVisualFormat("H:|-0-[bottomDrawerControllerView]-0-|", options: NSLayoutFormatOptions.DirectionLeadingToTrailing, metrics: nil, views: views)
        let viewConst_H = NSLayoutConstraint.constraintsWithVisualFormat("V:|-2-[bottomDrawerControllerView]-0-|", options: NSLayoutFormatOptions.DirectionLeadingToTrailing, metrics: nil, views: views)
        bottomDrawerHolder.addConstraints(viewConst_W)
        bottomDrawerHolder.addConstraints(viewConst_H)
        
        bottomDrawerViewController.edgeConstraint = bottomDrawerHolderBottomEdge
        bottomDrawerViewController.state = BottomDrawerState.ClosedFully
        
        rangeSliderViewController = UIStoryboard.rangeSliderViewController()
        bottomDrawerViewController.addControl(rangeSliderViewController!)
        rangeSliderViewController!.rangeSlider.addTarget(self, action: "rangeSliderValueChanged:", forControlEvents: .ValueChanged)
        
        playBarViewController = UIStoryboard.playBarViewController()
        bottomDrawerViewController.addControl(playBarViewController!)
        playBarViewController.delegate = self
    }
    
    @IBAction func toggleFeedButtonClicked(sender: UIButton) {
        toggleLeftPanel()
    }
    
    @IBAction func showInfoView(sender: UIButton) {
        let controller = UIStoryboard.infoViewController()
        controller?.modalPresentationStyle = UIModalPresentationStyle.Popover
        
        let popover = controller?.popoverPresentationController
        popover?.sourceView = sender
        popover?.sourceRect = sender.bounds
        popover?.permittedArrowDirections = UIPopoverArrowDirection.Any
        
        self.presentViewController(controller!, animated: true, completion: nil)
    }

    @IBAction func showFeedbackView(sender: UIButton) {
        let mailComposeViewController = feedbackMailComposeViewController()
        if MFMailComposeViewController.canSendMail() {
            self.presentViewController(mailComposeViewController, animated: true, completion: nil)
        } else {
            self.showSendMailErrorAlert()
        }
    }
    
    // MARK: - PlayBarViewControllerDelegate
    
    func playPauseClicked() { //stop and start the timemap
        if let vis = visualizationsByType[VisTypes.TimeMap] as! VisNativeViewController? {
            if(vis.timemapIsPlaying){
                vis.stopTimemap()
                playBarViewController.state = PlayBarState.Paused
            }
            else{
                vis.startTimemap()
                playBarViewController.state = PlayBarState.Playing
            }
        }
    }
    
    func scrubberScrubbed(progress: Float) { //move the timemap scrubber
        if let vis = visualizationsByType[VisTypes.TimeMap] as! VisNativeViewController? {
            vis.setTimemapDateBasedOnPercentageProgressOfBarUsingGuess(Double(progress))
        }
    }
    
    // MARK: - LeftViewControllerDelegate
    
    func toggleLeftPanel() {
        
        if (leftPanelInConstraint == nil) {
            let views = [
                "leftViewControllerView": leftViewController.view
            ]
            leftPanelInConstraint = NSLayoutConstraint.constraintsWithVisualFormat("H:|[leftViewControllerView(354)]", options: NSLayoutFormatOptions.DirectionLeadingToTrailing, metrics: nil, views: views)
        }
        
        if (CenterViewController.leftViewOpen) { //get bigger
            // animate out
            view.removeConstraints(leftPanelInConstraint!)
            self.animateLeftPanelXPosition(targetPosition: -350)
            CenterViewController.leftViewOpen = false
        } else { //get smaller
            // animate in
            view.addConstraints(leftPanelInConstraint!)
            self.animateLeftPanelXPosition(targetPosition: 0)
            CenterViewController.leftViewOpen = true
        }
    }
    
    func animateLeftPanelXPosition(targetPosition targetPosition: CGFloat, completion: ((Bool) -> Void)! = nil) {
        leftViewController.onAnimationStart()
        self.scrollView.viewWillResize()
        self.hideAllVisualisations()
        self.footerViewLeadingEdge.constant = targetPosition + 350
        self.bottomDrawerHolderLeadingEdge.constant = targetPosition + 350
        UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .CurveEaseInOut, animations: {
            self.leftViewController.view.layoutIfNeeded()
            self.footerView.layoutIfNeeded()
            self.bottomDrawerHolder.layoutIfNeeded()
            }, completion: { finished in
                self.dummyViewLeadingEdge.constant = targetPosition + 350
                self.leftViewController.onAnimationComplete()
                
                // Force scrollView to layout and update its frame
                self.scrollView.setNeedsLayout()
                self.scrollView.layoutIfNeeded()
                
                self.scrollView.viewDidResize()
                if !Network.waitingForResponse {
                    self.reloadVisualisations()
                    if (self.rangeSliderViewController != nil) { self.rangeSliderViewController.resetViewController() }
                }
        })
    }
    
    // MARK: - Reset UI
    
    func resetViewController() {
        // Use this function to reset the view controller's UI to a clean state
        Log("Resetting \(__FILE__)")
        
        if (rangeSliderViewController != nil) { rangeSliderViewController.resetViewController() }
        if (scrollView != nil) { scrollView.setContentOffset(CGPoint(x: 0,y: 0), animated: false) }
    }
    
    func setupWebViews()
    {
        for visType in Config.visualizationTypes {
            let vis = VisFactory.visualizationControllerForType(visType)!
            vis.willMoveToParentViewController(self)
            scrollView.addVisualisation(vis.view)
            addChildViewController(vis)
            
            visualizationsByIndex.append(vis)
            visualizationsByType[visType] = vis
            
            switch visType {
            case .TimeMap:
                vis.playBarController = playBarViewController
            default:
                break
            }
            
            if (networkError != nil) {
                vis.errorDescription = networkError!.localizedDescription
            }
        }
    }
    
    func rangeSliderValueChanged(rangeSlider: RangeSliderUIControl) {
        
        if let vis = visualizationsByType[VisTypes.StackedBar] as! VisWebViewController? {
            let maxDate = Double(vis.chartData.count) - 1
            
            //Transform range from 0-1 to 0-count
            let lowerIndex: Int = Int(round(maxDate * rangeSlider.lowerValue))
            let upperIndex: Int = Int(round(rangeSlider.upperValue * maxDate))
            
            vis.redrawStackedBarWithNewRange(lowerIndex, upperIndex: upperIndex)
        }
    }
    
    // MARK: - UIScrollViewDelegate
    
    //detect when the page was changed
    func scrollViewDidScroll(scrollView: UIScrollView) {
        let scrollView = scrollView as! ResizingScrollView
        let pageWidth = scrollView.frame.size.width
        let fractionalPage = Float(scrollView.contentOffset.x / pageWidth)
        var page : Int = Int(round(fractionalPage))
        
        if (page >= Config.getNumberOfVisualizations()) {
            page = Config.getNumberOfVisualizations()-1
        }
        if (currentPage != page && scrollView.endedRelayout) { //page was changed
            pageChanged = true
            previousPage = currentPage
            currentPage = page
            pageControlView.selectedIndex = page

            let currentVis = visualizationsByIndex[page]
            currentVis.onFocus()
            
            bottomDrawerViewController.animateToState(Config.visualizationDrawerStates[currentVis.type]!, complete: {
                switch currentVis.type! {
                case .StackedBar:
                    self.rangeSliderViewController.view.hidden = false
                    self.playBarViewController.view.hidden = true
                case .TimeMap:
                    self.rangeSliderViewController.view.hidden = true
                    self.playBarViewController.view.hidden = false
                default:
                    self.rangeSliderViewController.view.hidden = true
                    self.playBarViewController.view.hidden = true
                }
            })
        }
    }
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        resetZoomOnLastPage()
    }
    
    func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
        resetZoomOnLastPage()
    }
    
    // MARK: UIScrollViewDelegate helpers
    
    func resetZoomOnLastPage() {
        if (pageChanged) {
            pageChanged = false
            
            visualizationsByIndex[previousPage].onBlur()
        }
    }
    
    // MARK: - PageControlDelegate
    
    func pageChanged(index: Int) {
        let offset = scrollView.frame.size.width * CGFloat(index)
        scrollView.setContentOffset(CGPointMake(offset, 0), animated: true)
    }
    
    @IBAction func searchClicked(sender: UIButton) {
        delegate?.toggleRightPanel?(false)
    }
    
    // MARK - Actions
    
    @IBAction func shareButtonClicked(sender: UIButton) {
        
        let mailComposeViewController = configuredMailComposeViewController()
        if MFMailComposeViewController.canSendMail() {
            self.presentViewController(mailComposeViewController, animated: true, completion: nil)
        } else {
            self.showSendMailErrorAlert()
        }
    }
    
    @IBAction func headerTitleClicked(sender: AnyObject) {
        CenterViewController.leftViewOpen = false
        delegate?.displaySearchViewController?()
    }
    
    func cleanViews()
    {
        if leftViewController != nil && leftViewController.tweetsTableViewController != nil
        {
            leftViewController.tweetsTableViewController.emptySearchResult = false
            leftViewController.tweetsTableViewController.errorMessage = nil
            leftViewController.tweetsTableViewController.tweets = []
            leftViewController.tweetsTableViewController.tableView.reloadData()
        }
        
        if leftViewController != nil
        {
            if leftViewController.searchedTweetsNumberLabel != nil
            {
                leftViewController.searchedTweetsNumberLabel.text = ""
            }
            if leftViewController.foundUsersNumberLabel != nil
            {
                leftViewController.foundUsersNumberLabel.text = ""
            }
            if leftViewController.foundTweetsNumberLabel != nil
            {
                leftViewController.foundTweetsNumberLabel.text = ""
            }
        }
        
        if self.headerLabel != nil
        {
            self.headerLabel.setTitle(self.searchText, forState: UIControlState.Normal)
        }
        self.cleanVisualisations()
        self.resetViewController()
    }
    
    // MARK: - Network
    
    func loadDataFromServer()
    {
        if (Config.useDummyData) {
            let delay = Config.dummyDataDelay * Double(NSEC_PER_SEC)
            let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
            dispatch_after(time, dispatch_get_main_queue()) {
                self.onDummyRequestSuccess(nil)
            }
        } else {
            let networkConnection = Network.sharedInstance
            networkConnection.delegate = self
            networkConnection.searchRequest(self.searchText!)
        }
    }
    
    // MARK: - Network Delegate
    
    func displayRequestTime(time: String) {
        let alertController = UIAlertController(title: "Request Time", message:
            time, preferredStyle: UIAlertControllerStyle.Alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default,handler: nil))
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func responseProcessed() {
        
    }
    
    func handleTweetsCallBack(json: JSON?, error: NSError?) {
        if ((error) != nil) {
            leftViewController.tweetsTableViewController.errorMessage = error!.localizedDescription
        }
        else if json != nil
        {
            //select the json content according to appropriate request
            var tweetsContent = json!
            if Config.serverMakeSingleRequest
            {
                tweetsContent = json!["toptweets"]
            }
            
            if tweetsContent != nil
            {
                if tweetsContent["tweets"].count == 0
                {
                    leftViewController.tweetsTableViewController.emptySearchResult = true
                }
                leftViewController.tweetsTableViewController.tweets = tweetsContent["tweets"]
            }
            else
            {
                leftViewController.tweetsTableViewController.errorMessage = Config.serverErrorMessage
            }
        }
        else
        {
            leftViewController.tweetsTableViewController.errorMessage = Config.serverErrorMessage
        }
        leftViewController.tweetsTableViewController.tableView.reloadData()
    }
    
    func handleLocationCallBack(json: JSON?, error: NSError?) {
        setJsonForVisType(json, error: error, type: .TimeMap)
    }

    func handleSentimentsCallBack(json: JSON?, error: NSError?) {
        setJsonForVisType(json, error: error, type: .StackedBar)
    }
    
    func handleWordDistanceCallBack(json: JSON?, error: NSError?) {
        setJsonForVisType(json, error: error, type: .ForceGraph)
    }
    
    func handleWordClusterCallBack(json: JSON?, error: NSError?) {
        setJsonForVisType(json, error: error, type: .CirclePacking)
    }
    
    func handleProfessionCallBack(json: JSON?, error: NSError?) {
        setJsonForVisType(json, error: error, type: .TreeMap)
    }
    
    func setJsonForVisType(json: JSON?, error: NSError?, type: VisTypes) {
        if let vis = visualizationsByType[type] {
            if error != nil {
                vis.errorDescription = error?.localizedDescription
                return
            }
            vis.searchText = self.searchText!
            vis.json = json
        } else {
            Log("Unable to load data into visualization. VisType: \(type) not found.")
            
        }
        
        if (error != nil) {
            self.networkError = error
        } else {
            self.networkError = nil
        }
    }
    
    
    func handleTopMetrics(json: JSON?, error: NSError?) {
        if (error != nil) {
            leftViewController.searchedTweetsNumberLabel.text = "Error"
            leftViewController.foundTweetsNumberLabel.text = "Error"
            leftViewController.foundUsersNumberLabel.text = "Error"
            return
        }
        else
        {
            switch Config.appState {
            case .Historic:
                self.setCountLabelWithJSONKey(json, key: "totaltweets", label: leftViewController.searchedTweetsNumberLabel)
                self.setCountLabelWithJSONKey(json, key: "totalusers", label: leftViewController.foundUsersNumberLabel)
                self.setCountLabelWithJSONKey(json, key: "totalfilteredtweets", label: leftViewController.foundTweetsNumberLabel)
            case .Live:
                self.setCountLabelWithJSONKey(json, key: "totalfilteredtweets", label: leftViewController.searchedTweetsNumberLabel)
                self.setCountLabelWithJSONKey(json, key: "totalusers", label: leftViewController.foundUsersNumberLabel)
                self.setCountLabelWithJSONKey(json, key: "totalretweets", label: leftViewController.foundTweetsNumberLabel)
            }
        }
    }
    
    //MARK: Jury-Rigged Websocket
    
    // idempotent function that makes requests every X seconds
    // X is a number in config

    func startNetworkTimer(){
        invalidateNetworkTimer()
        periodicPowertrackWordcountRequest()
        
        // make a request every X seconds
        self.networkTimer = NSTimer.scheduledTimerWithTimeInterval(Config.networkTimerInterval, target: self, selector: Selector("periodicPowertrackWordcountRequest"), userInfo: nil, repeats: true)
    }
    
    // idempotent function that stops the networktimer from making any further requests
    func stopNetworkTimer(){
        invalidateNetworkTimer()
    }
    
    func invalidateNetworkTimer(){
        if networkTimer != nil {
            networkTimer.invalidate()
            networkTimer = nil;
        }
    }
    
    func periodicPowertrackWordcountRequest(){
        Network.sharedInstance.powertrackWordcountRequest(searchText!) { (json, error) -> () in
            self.handleTopMetrics(json, error: error)
            self.handleTweetsCallBack(json, error: error)
            self.populateLiveVisualizations(json)
        }
    }
    
    func populateLiveVisualizations(json: JSON?){
        guard json != nil else {
            return
        }
        for vis in visualizationsByIndex {
            vis.json = json
        }
    }
    
    //MARK: Dummy Data
    
    func onDummyRequestSuccess(json: JSON) {
        Log(__FUNCTION__)
        
        if (Config.serverMakeSingleRequest) {
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                
                let fileName = "response_spark"
                let filePath = NSBundle.mainBundle().pathForResource("response_spark", ofType:"json")
                guard filePath != nil else {
                    Log("Error: Dummy Data file \"\(fileName).json\" not found")
                    return
                }
                
                var readError:NSError?
                do {
                    let fileData = try NSData(contentsOfFile:filePath!,
                        options: NSDataReadingOptions.DataReadingUncached)
                    // Read success
                    var parseError: NSError?
                    do {
                        let JSONObject: AnyObject? = try NSJSONSerialization.JSONObjectWithData(fileData, options: NSJSONReadingOptions.AllowFragments)
                        // Parse success
                        let json = JSON(JSONObject!)
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            self.populateUI(json)
                        })
                    } catch let error as NSError {
                        parseError = error
                        // Parse error
                        Log("Error Parsing demo data: \(parseError?.localizedDescription)")
                    }
                } catch let error as NSError {
                    readError = error
                    // Read error
                    Log("Error Reading demo data: \(readError?.localizedDescription)")
                } catch {
                    fatalError()
                }
                
            })
            
        } else {
            populateUI(json)
        }
    }

    func populateUI(json: JSON){ // This is only used for dummy data
        self.handleTweetsCallBack(json, error: nil)
        self.handleTopMetrics(json, error: nil)
        
        self.handleLocationCallBack(json, error: nil )

        self.handleProfessionCallBack(json, error: nil)
        
        self.handleSentimentsCallBack(json, error: nil)
        
        self.handleWordDistanceCallBack(json, error: nil)
        
        self.handleWordClusterCallBack(json, error: nil)
    }
    
    // MARK: - UI Utils
    
    func createUILabelForError(origin: CGFloat, center: CGPoint) -> UILabel
    {
        let label = UILabel()
        label.frame = CGRectMake(origin, 0, 300, 300);
        label.numberOfLines = 3
        label.center = center
        label.textColor = Config.darkBlueColor
        label.text = Config.noDataMessage
        label.font = UIFont.init(name: "HelveticaNeue-Medium", size: 19)
        label.textAlignment = NSTextAlignment.Center
        label.hidden = true
        return label
    }
    
    func createUILabel(text: String, origin: CGFloat) -> UILabel
    {
        let titleLabel = UILabel()
        titleLabel.frame = CGRectMake(origin, 0, self.scrollView.frame.size.width, 40);
        titleLabel.numberOfLines = 1
        titleLabel.font = UIFont.init(name: "HelveticaNeue-Medium", size: 16)
        titleLabel.textColor = Config.darkGrayTextColor
        titleLabel.text = text
        titleLabel.textAlignment = NSTextAlignment.Center
        titleLabel.backgroundColor = Config.lightWhiteIce
        return titleLabel
    }
    
    // MARK: - Visualisation Utils
    
    func cleanVisualisations() {
        for v in visualizationsByIndex {
            v.clean()
        }
    }
    
    func reloadVisualisations() {
        for v in visualizationsByIndex {
            v.onDataSet()
        }
    }
    
    func hideAllVisualisations() {
        for v in visualizationsByIndex {
            v.onHiddenState()
        }
    }
    
    // MARK: - Utils
    
    func configuredMailComposeViewController() -> MFMailComposeViewController {
        let mailComposerVC = MFMailComposeViewController()
        mailComposerVC.mailComposeDelegate = self
        mailComposerVC.setSubject("IBM RedRock")
        mailComposerVC.addAttachmentData(UIImageJPEGRepresentation(getScreenShot(), 1)!, mimeType: "image/jpeg", fileName: "IBMSparkInsightScreenShot.jpeg")
        return mailComposerVC
    }
    
    func feedbackMailComposeViewController() -> MFMailComposeViewController {
        let mailComposerVC = MFMailComposeViewController()
        mailComposerVC.mailComposeDelegate = self
        mailComposerVC.setSubject("IBM RedRock Feedback")
        mailComposerVC.setToRecipients(["redrock@us.ibm.com"])
        
        return mailComposerVC
    }

    
    func getScreenShot() -> UIImage {
        let layer = UIApplication.sharedApplication().keyWindow!.layer
        let scale = UIScreen.mainScreen().scale
        UIGraphicsBeginImageContextWithOptions(layer.frame.size, false, scale);
        UIApplication.sharedApplication().keyWindow?.drawViewHierarchyInRect(layer.frame, afterScreenUpdates: true)
        
        let screenshot = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        UIImageWriteToSavedPhotosAlbum(screenshot, nil, nil, nil)
        
        return screenshot
    }
    
    func showSendMailErrorAlert() {
        let sendMailErrorAlert = UIAlertView(title: "Could Not Send Email", message: "Your device could not send e-mail.  Please check e-mail configuration and try again.", delegate: self, cancelButtonTitle: "OK")
        sendMailErrorAlert.show()
    }
    
    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        controller.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func formatNumberToDisplay(number: Int64) -> String {
        let billion = Int64(999999999)
        let million = Int64(999999)
        let thousand = Int64(999)
        var div = 0.0
        var letter = ""
        if number > billion
        {
            div = Double(number)/Double((billion+1))
            letter = "B"
        }
        else if number > million
        {
            div = Double(number)/Double((million+1))
            letter = "M"
        }
        else if number > thousand
        {
            div = Double(number)/Double((thousand+1))
            letter = "K"
        }
        else
        {
            return String(number)
        }
        
        return String(format: "%.1f", div) + String(letter)
    }
    
    func setCountLabelWithJSONKey(json: JSON?, key: String, label: UILabel) {
        if json![key] != nil {
            label.text = self.formatNumberToDisplay(Int64(json![key].int64Value))
        } else {
            label.text = ""
        }
    }
}

