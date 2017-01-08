/*
 This file is part of Appirater.
 
 Copyright (c) 2012, Arash Payan
 All rights reserved.
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 */
//
//  Appirater.swift
//
//  Rewritten in swift language by SeokWon Cheul on 2016. 1. 9..
//  Copyright © 2016년 won cheulseok. All rights reserved.
//
//  The original implementation is here
//  https://github.com/arashpayan/appirater
//

//////////////////////////////////
//                              //
//  Begin Test Code Examples    //
//                              //
//////////////////////////////////
//
//
// this code lets the alert view to be presented always
// if user choose "rate later" button, aler view will be presented with next foreground event
//        Appirater.setDaysUntilPrompt(0)
//        Appirater.setUsesUntilPrompt(0)
//        Appirater.setSignificantEventsUntilPrompt(0)
//        Appirater.setTimeBeforeReminding(0)
//
//test setDaysUntilPrompt
//        // this code lets alert view to be presented after 1 day
//        Appirater.setDaysUntilPrompt(1)
//        Appirater.setUsesUntilPrompt(0)
//        Appirater.setSignificantEventsUntilPrompt(0)
//        Appirater.setTimeBeforeReminding(0)
//
//
//test setUsesUntilPrompt
//this code prevents alert view to be presented after 2 times of uses
//        Appirater.setDaysUntilPrompt(0)
//        Appirater.setUsesUntilPrompt(2)
//        Appirater.setSignificantEventsUntilPrompt(0)
//        Appirater.setTimeBeforeReminding(0)
//
//test setSignificantEventsUntilPrompt
//this code lets the alert view to be presented after 2 times of significant events
//        Appirater.setDaysUntilPrompt(0)
//        Appirater.setUsesUntilPrompt(0)
//        Appirater.setSignificantEventsUntilPrompt(2)
//        Appirater.setTimeBeforeReminding(0)
//
//test setSignificantEventsUntilPrompt
//this code lets the alert view to be presented after 1 day
//        Appirater.setDaysUntilPrompt(0)
//        Appirater.setUsesUntilPrompt(0)
//        Appirater.setSignificantEventsUntilPrompt(0)
//        Appirater.setTimeBeforeReminding(1)
//
//////////////////////////////////
//                              //
//  End Test Code Examples      //
//                              //
//////////////////////////////////
//


import Foundation
import SystemConfiguration
import StoreKit

@objc
protocol AppiraterDelegate : class {
    @objc optional func appiraterShouldDisplayAlert(_ appirater : Appirater) -> Bool
    @objc optional func appiraterDidDisplayAlert(_ appirater : Appirater)
    @objc optional func appiraterDidDeclineToRate(_ appirater : Appirater)
    @objc optional func appiraterDidOptToRate(_ appirater : Appirater)
    @objc optional func appiraterDidOptToRemindLater(_ appirater : Appirater)
    @objc optional func appiraterWillPresentModalView(_ appirater : Appirater, animated:Bool)
    @objc optional func appiraterDidDismissModalView(_ appirater : Appirater, animated:Bool)
}

class Appirater: NSObject, UIAlertViewDelegate, SKStoreProductViewControllerDelegate, AppiraterDelegate {
    
    private static var __once: () = { () in
        Appirater._appirater = Appirater()
        Appirater._appirater!.delegate = Appirater._appirater!
        NotificationCenter.default.addObserver(Appirater._appirater!, selector: #selector(Appirater.appWillResignActive), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
    }()
    
    private static let kFirstUseDate            = "kFirstUseDate"
    private static let kUseCount				= "kUseCount"
    private static let kSignificantEventCount	= "kSignificantEventCount"
    private static let kCurrentVersion			= "kCurrentVersion"
    private static let kRatedCurrentVersion		= "kRatedCurrentVersion"
    private static let kDeclinedToRate			= "kDeclinedToRate"
    private static let kReminderRequestDate		= "kReminderRequestDate"
    
    private static var templateReviewURL = "itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=APP_ID"
    private static var templateReviewURLiOS7 = "itms-apps://itunes.apple.com/app/idAPP_ID"
    private static var templateReviewURLiOS8 = "itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=APP_ID&onlyLatestVersion=true&pageNumber=0&sortOrdering=1&type=Purple+Software"
    
    /*!
     Your localized app's name.
     */
    static var LOCALIZED_APP_NAME : String? {
        get {
            return Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String
        }
    }
    
    /*!
     Your app's name.
     */
    static var APP_NAME : String {
        get {
            if let localizedAppName = self.LOCALIZED_APP_NAME
            {
                return localizedAppName
                
            }else if let displayName = Bundle.main.infoDictionary?["CFBundleDisplayName"]
            {
                return displayName as! String
            }else
            {
                return Bundle.main.infoDictionary!["CFBundleName"] as! String
            }
        }
    }
    /*!
     This is the message your users will see once they've passed the day+launches
     threshold.
     */
    static var LOCALIZED_MESSAGE : String {
        
        get {
            return NSLocalizedString("If you enjoy using %@, would you mind taking a moment to rate it? It won't take more than a minute. Thanks for your support!", tableName: "AppiraterLocalizable", bundle: Appirater.bundle(), comment: "")
        }
    }
    private static var APPIRATER_MESSAGE : String {
        get {
            return String(format: self.LOCALIZED_MESSAGE, self.APP_NAME)
        }
    }
    
    /*!
     This is the title of the message alert that users will see.
     */
    static var LOCALIZED_MESSAGE_TITLE : String {
        get {
            return NSLocalizedString("Rate %", tableName: "AppiraterLocalizable", bundle: Appirater.bundle(), comment: "")
        }
    }
    private static var APPIRATER_MESSAGE_TITLE : String {
        get {
            return String(format: self.LOCALIZED_MESSAGE_TITLE, self.APP_NAME)
        }
    }
    
    /*!
     The text of the button that rejects reviewing the app.
     */
    static var CANCEL_BUTTON : String {
        get {
            return NSLocalizedString("No, Thanks", tableName: "AppiraterLocalizable", bundle: Appirater.bundle(), comment: "")
        }
    }
    
    /*!
     Text of button that will send user to app review page.
     */
    static var LOCALIZED_RATE_BUTTON : String {
        get {
            return NSLocalizedString("Rate %@", tableName: "AppiraterLocalizable", bundle: Appirater.bundle(), comment: "")
        }
    }
    private static var RATE_BUTTON : String {
        get {
            return String(format: self.LOCALIZED_RATE_BUTTON, self.APP_NAME)
        }
    }
    
    /*!
     Text for button to remind the user to review later.
     */
    static var RATE_LATER : String {
        get {
            return NSLocalizedString("Remind me later", tableName: "AppiraterLocalizable", bundle: Appirater.bundle(), comment: "")
        }
    }
    private class func bundle() -> Bundle
    {
        var bundle : Bundle
        
        if self._alwaysUseMainBundle
        {
            
            bundle = Bundle.main
        } else if let appiraterBundleURL = Bundle.main.url(forResource: "Appirater", withExtension: "bundle")
        {
            // Appirater.bundle will likely only exist when used via CocoaPods
            bundle = Bundle(url:appiraterBundleURL)!
        } else
        {
            bundle = Bundle.main
        }
        
        return bundle
    }
    
    // Shared Instance
    private static var _appirater : Appirater? = nil
    private static var onceToken : Int = 0
    static var sharedInstance : Appirater {
        
        get {
            
            if (self._appirater == nil)
            {
                
                _ = Appirater.__once
            }
            
            return self._appirater!
        }
    }
    class func setPresentCancelButton(_ present:Bool) {
        self.sharedInstance.presentCancelButton = present
    }
    /*!
     Set customized title for alert view.
     */
    class func setCustomAlertTitle(_ title:String) {
        self.sharedInstance.alertTitle = title
    }
    
    /*!
     Set customized message for alert view.
     */
    class func setCustomAlertMessage(_ message : String) {
        self.sharedInstance.alertMessage = message
    }
    
    /*!
     Set customized cancel button title for alert view.
     */
    class func setCustomAlertCancelButtonTitle(_ title : String) {
        self.sharedInstance.alertCancelTitle = title
    }
    
    /*!
     Set customized rate button title for alert view.
     */
    class func setCustomAlertRateButtonTitle(_ title : String) {
        self.sharedInstance.alertRateLaterTitle = title
    }
    /*!
     Set customized rate later button title for alert view.
     */
    class func setCustomAlertRateLaterButtonTitle(_ title : String) {
        self.sharedInstance.alertRateLaterTitle = title
    }
    
    /*!
     If set to YES, Appirater will open App Store link (instead of SKStoreProductViewController on iOS 6). Default YES.
     */
    class func setOpenInAppStore(_ openInStore : Bool) {
        self.sharedInstance.openInAppStore = openInStore
    }
    
    private static var _appId : String?
    /*!
     Set your Apple generated software id here.
     */
    class func setAppId(_ appId : String) {
        self._appId = appId
    }
    
    private static var _daysUntilPrompt : Double = 30
    /*!
     Users will need to have the same version of your app installed for this many
     days before they will be prompted to rate it.
     */
    class func setDaysUntilPrompt(_ days:Double) {
        self._daysUntilPrompt = days
    }
    
    
    private static var _usesUntilPrompt : Int = 20
    /*!
     An example of a 'use' would be if the user launched the app. Bringing the app
     into the foreground (on devices that support it) would also be considered
     a 'use'. You tell Appirater about these events using the two methods:
     [Appirater appLaunched:]
     [Appirater appEnteredForeground:]
     
     Users need to 'use' the same version of the app this many times before
     before they will be prompted to rate it.
     */
    class func setUsesUntilPrompt(_ count : Int) {
        self._usesUntilPrompt = count
    }
    
    private static var _significantEventsUntilPrompt : Int = -1
    /*!
     A significant event can be anything you want to be in your app. In a
     telephone app, a significant event might be placing or receiving a call.
     In a game, it might be beating a level or a boss. This is just another
     layer of filtering that can be used to make sure that only the most
     loyal of your users are being prompted to rate you on the app store.
     If you leave this at a value of -1, then this won't be a criterion
     used for rating. To tell Appirater that the user has performed
     a significant event, call the method:
     [Appirater userDidSignificantEvent:]
     */
    class func setSignificantEventsUntilPrompt(_ count : Int) {
        self._significantEventsUntilPrompt = count
    }
    
    private static var _timeBeforeReminding : Double = 1
    /*!
     Once the rating alert is presented to the user, they might select
     'Remind me later'. This value specifies how long (in days) Appirater
     will wait before reminding them.
     */
    class func setTimeBeforeReminding(_ count : Double) {
        self._timeBeforeReminding = count
    }
    
    private static var _debug : Bool = false
    /*!
     'YES' will show the Appirater alert everytime. Useful for testing how your message
     looks and making sure the link to your app's review page works.
     */
    class func setDebug(_ debug : Bool) {
        self._debug = debug
    }
    
    private static weak var _delegate : AppiraterDelegate?
    /*!
     Set the delegate if you want to know when Appirater does something
     */
    class func setDelegate(_ delegate : AppiraterDelegate) {
        self._delegate = delegate
    }
    
    private static var _usesAnimation : Bool = true
    /*!
     Set whether or not Appirater uses animation (currently respected when pushing modal StoreKit rating VCs).
     */
    class func setUsesAnimation(_ animate : Bool) {
        self._usesAnimation = animate
    }
    
    private static var _statusBarStyle : UIStatusBarStyle = .default
    private class func setStatusBarStyle(_ style : UIStatusBarStyle) {
        self._statusBarStyle = style
    }
    
    private static var _modalOpen : Bool = false
    private class func setModalOpen(_ modalOpen : Bool) {
        self._modalOpen = modalOpen
    }
    
    private static var _alwaysUseMainBundle : Bool = false
    /*!
     If set to YES, the main bundle will always be used to load localized strings.
     Set this to YES if you have provided your own custom localizations in AppiraterLocalizable.strings
     in your main bundle.  Default is NO.
     */
    class func setAlwaysUseMainBundle(_ alwaysUseMainBundle : Bool) {
        self._alwaysUseMainBundle = alwaysUseMainBundle
    }
    
    private var presentCancelButton : Bool = true
    var ratingAlert : UIAlertView?
    var openInAppStore : Bool
    weak var delegate : AppiraterDelegate?
    
    // TODO: Obj-C implements has these properties with copy attribute but swift doesn't
    private var _alertTitle : String?
    private var alertTitle : String {
        get
        {
            return "이번 업데이트 만족도는?\n간단히 별점만 매겨주세요"
        }
        set {
            self._alertTitle = newValue
        }
    }
    
    // TODO: Obj-C implements has these properties with copy attribute but swift doesn't
    private var _alertMessage : String?
    private var alertMessage : String {
        get
        {
            var message:String!
            var version:String!
            do {
                let jsonData = try Data(contentsOf: NSURL(string:"http://itunes.apple.com/lookup?id=991670217") as! URL)
                let jsonObject:[String:Any] = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as! [String:Any]
                let appInfos = (jsonObject["results"] as! [[String:Any]])[0]
                message = appInfos["releaseNotes"]! as! String
                version = appInfos["version"]! as! String
            }catch {
                
            }
            return "\n이번 개선사항\n\n\(message!)\n"
        }
        set
        {
            self._alertMessage = newValue
        }
    }
    
    // TODO: Obj-C implements has these properties with copy attribute but swift doesn't
    private var _alertCancelTitle : String?
    private var alertCancelTitle : String {
        get
        {
            return self._alertCancelTitle != nil ? self._alertCancelTitle! : Appirater.CANCEL_BUTTON
        }
        set
        {
            self._alertCancelTitle = newValue
        }
    }
    
    // TODO: Obj-C implements has these properties with copy attribute but swift doesn't
    private var _alertRateTitle : String?
    private var alertRateTitle : String {
        get
        {
            return "리뷰 작성하기"
        }
        set
        {
            self._alertRateTitle = newValue
        }
    }
    // TODO: Obj-C implements has these properties with copy attribute but swift doesn't
    private var _alertRateLaterTitle : String?
    private var alertRateLaterTitle : String {
        get
        {
            return "더 사용 후 결정"
        }
        set
        {
            self._alertRateLaterTitle = newValue
        }
    }
    
    override init() {
        let systemVersion = UIDevice.current.systemVersion as NSString
        if systemVersion.floatValue >= 7.0 {
            self.openInAppStore = true
        } else {
            self.openInAppStore = false
        }
        
        super.init()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func connectedToNetwork() -> Bool {
        
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        
        return (isReachable && !needsConnection)
    }
    
    private func showRatingAlert(_ displayRateLaterButton: Bool)
    {
        var alertView: UIAlertView?
        let delegate = self.delegate
        if delegate?.appiraterShouldDisplayAlert?(self) == false {
            return
        }
        
        if displayRateLaterButton {
            alertView = UIAlertView(title:self.alertTitle,
                                    message:self.alertMessage,
                                    delegate:self,
                                    cancelButtonTitle:self.presentCancelButton ? self.alertCancelTitle : nil,
                                    otherButtonTitles:self.alertRateTitle, self.alertRateLaterTitle)
        } else {
            alertView = UIAlertView(title:self.alertTitle,
                                    message:self.alertMessage,
                                    delegate:self,
                                    cancelButtonTitle:self.presentCancelButton ? self.alertCancelTitle : nil,
                                    otherButtonTitles:self.alertRateTitle)
        }
        
        self.ratingAlert = alertView!
        alertView!.show()
        PMTracker.trackEvent("Rate - Alert is presented")
        delegate?.appiraterDidDisplayAlert?(self)
    }
    
    private func showRatingAlert()
    {
        self.showRatingAlert(true)
    }
    
    // is this an ok time to show the alert? (regardless of whether the rating conditions have been met)
    //
    // things checked here:
    // * connectivity with network
    // * whether user has rated before
    // * whether user has declined to rate
    // * whether rating alert is currently showing visibly
    // things NOT checked here:
    // * time since first launch
    // * number of uses of app
    // * number of significant events
    // * time since last reminder
    private func ratingAlertIsAppropriate() -> Bool
    {
        return self.connectedToNetwork()
            && !self.userHasDeclinedToRate()
            && (self.ratingAlert == nil || !self.ratingAlert!.isVisible)
            && !self.userHasRatedCurrentVersion()
    }
    
    // have the rating conditions been met/earned? (regardless of whether this would be a moment when it's appropriate to show a new rating alert)
    //
    // things checked here:
    // * time since first launch
    // * number of uses of app
    // * number of significant events
    // * time since last reminder
    // things NOT checked here:
    // * connectivity with network
    // * whether user has rated before
    // * whether user has declined to rate
    // * whether rating alert is currently showing visibly
    private func ratingConditionsHaveBeenMet() -> Bool
    {
        if (!connectedToNetwork()) { return false }
        
        var latestVersion:String!
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        do {
            let jsonData = try Data(contentsOf: NSURL(string:"http://itunes.apple.com/lookup?id=991670217") as! URL)
            let jsonObject:[String:Any] = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as! [String:Any]
            latestVersion = (jsonObject["results"] as! [[String:Any]])[0]["version"]! as! String
        }catch {
            
        }
        if (nil == latestVersion || latestVersion! != currentVersion) {
            return false
        }
        
        if Appirater._debug {
            return true
        }
        if UIAccessibilityIsVoiceOverRunning() {
            return false
        }
        let userDefaults = UserDefaults.standard
        
        let dateOfFirstLaunch = Date(timeIntervalSince1970:userDefaults.double(forKey: Appirater.kFirstUseDate))
        let timeSinceFirstLaunch = Date().timeIntervalSince(dateOfFirstLaunch)
        let timeUntilRate = 60 * 60 * 24 * Appirater._daysUntilPrompt
        if timeSinceFirstLaunch < timeUntilRate {return false}
        
        // check if the app has been used enough
        let useCount = userDefaults.integer(forKey: Appirater.kUseCount)
        if useCount < Appirater._usesUntilPrompt { return false }
        
        // check if the user has done enough significant events
        let sigEventCount = userDefaults.integer(forKey: Appirater.kSignificantEventCount)
        if (sigEventCount < Appirater._significantEventsUntilPrompt) { return false }
        
        // if the user wanted to be reminded later, has enough time passed?
        let reminderRequestDate = Date(timeIntervalSince1970:userDefaults.double(forKey: Appirater.kReminderRequestDate))
        let timeSinceReminderRequest = Date().timeIntervalSince(reminderRequestDate)
        let timeUntilReminder = 60 * 60 * 24 * Appirater._timeBeforeReminding
        if timeSinceReminderRequest < timeUntilReminder {return false}
        
        
        
        
        return true
    }
    
    private func incrementUseCount() {
        // get the app's version
        let version = Bundle.main.infoDictionary![kCFBundleVersionKey as String]! as! String
        
        // get the version number that we've been tracking
        let userDefaults = UserDefaults.standard
        var trackingVersion = userDefaults.string(forKey: Appirater.kCurrentVersion)
        if trackingVersion == nil
        {
            trackingVersion = version
            userDefaults.set(version, forKey:Appirater.kCurrentVersion)
        }
        
        if Appirater._debug
        {
            //print("APPIRATER Tracking version: \(trackingVersion)")
        }
        
        if trackingVersion == version
        {
            // check if the first use date has been set. if not, set it.
            var timeInterval = userDefaults.double(forKey: Appirater.kFirstUseDate)
            if timeInterval == 0
            {
                timeInterval = Date().timeIntervalSince1970
                userDefaults.set(timeInterval, forKey:Appirater.kFirstUseDate)
            }
            
            // increment the use count
            var useCount = userDefaults.integer(forKey: Appirater.kUseCount)
            useCount += 1
            userDefaults.set(useCount, forKey:Appirater.kUseCount)
            if Appirater._debug
            {
                //print("APPIRATER Use count: \(useCount)")
            }
        }
        else
        {
            // it's a new version of the app, so restart tracking
            userDefaults.set(version, forKey:Appirater.kCurrentVersion)
            userDefaults.set(Date().timeIntervalSince1970, forKey:Appirater.kFirstUseDate)
            userDefaults.set(1, forKey:Appirater.kUseCount)
            userDefaults.set(0, forKey:Appirater.kSignificantEventCount)
            userDefaults.set(false, forKey:Appirater.kRatedCurrentVersion)
            userDefaults.set(false, forKey:Appirater.kDeclinedToRate)
            userDefaults.set(0, forKey:Appirater.kReminderRequestDate)
        }
        
        userDefaults.synchronize()
    }
    
    private func incrementSignificantEventCount() {
        // get the app's version
        let version = Bundle.main.infoDictionary![kCFBundleVersionKey as String] as! String
        
        // get the version number that we've been tracking
        let userDefaults = UserDefaults.standard
        var trackingVersion = userDefaults.string(forKey: Appirater.kCurrentVersion)
        if trackingVersion == nil
        {
            trackingVersion = version
            userDefaults.set(version, forKey:Appirater.kCurrentVersion)
        }
        
        if Appirater._debug
        {
            //            NSLog("APPIRATER Tracking version: \(trackingVersion)")
        }
        if trackingVersion == version
        {
            // check if the first use date has been set. if not, set it.
            var timeInterval = userDefaults.double(forKey: Appirater.kFirstUseDate)
            if timeInterval == 0
            {
                timeInterval = Date().timeIntervalSince1970
                userDefaults.set(timeInterval, forKey:Appirater.kFirstUseDate)
            }
            
            // increment the significant event count
            var sigEventCount = userDefaults.integer(forKey: Appirater.kSignificantEventCount)
            sigEventCount += 1
            userDefaults.set(sigEventCount, forKey:Appirater.kSignificantEventCount)
            if Appirater._debug
            {
                //print("APPIRATER Significant event count: \(sigEventCount)")
            }
        }
        else
        {
            // it's a new version of the app, so restart tracking
            userDefaults.set(version, forKey:Appirater.kCurrentVersion)
            userDefaults.set(0, forKey:Appirater.kFirstUseDate)
            userDefaults.set(0, forKey:Appirater.kUseCount)
            userDefaults.set(1, forKey:Appirater.kSignificantEventCount)
            userDefaults.set(false, forKey:Appirater.kRatedCurrentVersion)
            userDefaults.set(false, forKey:Appirater.kDeclinedToRate)
            userDefaults.set(0, forKey:Appirater.kReminderRequestDate)
        }
        
        userDefaults.synchronize()
    }
    
    private func incrementAndRate(_ canPromptForRating : Bool)
    {
        self.incrementUseCount()
        
        if canPromptForRating &&
            self.ratingConditionsHaveBeenMet() &&
            self.ratingAlertIsAppropriate()
        {
            
            DispatchQueue.main.async(execute: { () in
                self.showRatingAlert()
            })
        }
    }
    
    private func incrementSignificantEventAndRate(_ canPromptForRating:Bool)
    {
        self.incrementSignificantEventCount()
        
        if canPromptForRating &&
            self.ratingConditionsHaveBeenMet() &&
            self.ratingAlertIsAppropriate()
        {
            DispatchQueue.main.async(execute: { () in
                self.showRatingAlert()
            })
        }
    }
    /*!
     Asks Appirater if the user has declined to rate
     */
    
    func userHasDeclinedToRate() -> Bool
    {
        return UserDefaults.standard.bool(forKey: Appirater.kDeclinedToRate)
    }
    /*!
     Asks Appirater if the user has rated the current version.
     Note that this is not a guarantee that the user has actually rated the app in the
     app store, but they've just clicked the rate button on the Appirater dialog.
     */
    func userHasRatedCurrentVersion() -> Bool
    {
        return UserDefaults.standard.bool(forKey: Appirater.kRatedCurrentVersion)
    }
    
    
    /*!
     Tells Appirater that the app has launched, and on devices that do NOT
     support multitasking, the 'uses' count will be incremented. You should
     call this method at the end of your application delegate's
     application:didFinishLaunchingWithOptions: method.
     
     If the app has been used enough to be rated (and enough significant events),
     you can suppress the rating alert
     by passing NO for canPromptForRating. The rating alert will simply be postponed
     until it is called again with YES for canPromptForRating. The rating alert
     can also be triggered by appEnteredForeground: and userDidSignificantEvent:
     (as long as you pass YES for canPromptForRating in those methods).
     */
    
    class func appLaunched(_ canPromptForRating : Bool)
    {
        DispatchQueue.global(qos: .default).async {
            let a = Appirater.sharedInstance
            if Appirater._debug
            {
                DispatchQueue.main.async(execute: {
                    a.showRatingAlert()
                })
            } else {
                a.incrementAndRate(canPromptForRating)
            }
        }
    }
    private func hideRatingAlert()
    {
        if nil != self.ratingAlert?.isVisible {
            if Appirater._debug
            {
                //print("APPIRATER Hiding Alert")
            }
            self.ratingAlert!.dismiss(withClickedButtonIndex: -1, animated:false)
        }
    }
    
    func appWillResignActive()
    {
        if Appirater._debug
        {
            //print("APPIRATER appWillResignActive")
        }
        Appirater.sharedInstance.hideRatingAlert()
    }
    /*!
     Tells Appirater that the app was brought to the foreground on multitasking
     devices. You should call this method from the application delegate's
     applicationWillEnterForeground: method.
     
     If the app has been used enough to be rated (and enough significant events),
     you can suppress the rating alert
     by passing NO for canPromptForRating. The rating alert will simply be postponed
     until it is called again with YES for canPromptForRating. The rating alert
     can also be triggered by appLaunched: and userDidSignificantEvent:
     (as long as you pass YES for canPromptForRating in those methods).
     */
    
    class func appEnteredForeground(_ canPromptForRating:Bool)
    {
        DispatchQueue.global(qos: .default).async {
            Appirater.sharedInstance.incrementAndRate(canPromptForRating)
        }
    }
    
    /*!
     Tells Appirater that the user performed a significant event. A significant
     event is whatever you want it to be. If you're app is used to make VoIP
     calls, then you might want to call this method whenever the user places
     a call. If it's a game, you might want to call this whenever the user
     beats a level boss.
     
     If the user has performed enough significant events and used the app enough,
     you can suppress the rating alert by passing NO for canPromptForRating. The
     rating alert will simply be postponed until it is called again with YES for
     canPromptForRating. The rating alert can also be triggered by appLaunched:
     and appEnteredForeground: (as long as you pass YES for canPromptForRating
     in those methods).
     */
    
    class func userDidSignificantEvent(_ canPromptForRating : Bool)
    {
        DispatchQueue.global(qos: .default).async {
            Appirater.sharedInstance.incrementSignificantEventAndRate(canPromptForRating)
        }
    }
    
    
    /*!
     Tells Appirater to try and show the prompt (a rating alert). The prompt will be showed
     if there is connection available, the user hasn't declined to rate
     or hasn't rated current version.
     
     You could call to show the prompt regardless Appirater settings,
     e.g., in case of some special event in your app.
     */
    class func tryToShowPrompt()
    {
        Appirater.sharedInstance.showPromptWithChecks(true,
                                                      displayRateLaterButton:true)
    }
    /*!
     Tells Appirater to show the prompt (a rating alert).
     Similar to tryToShowPrompt, but without checks (the prompt is always displayed).
     Passing false will hide the rate later button on the prompt.
     
     The only case where you should call this is if your app has an
     explicit "Rate this app" command somewhere. This is similar to rateApp,
     but instead of jumping to the review directly, an intermediary prompt is displayed.
     */
    
    class func forceShowPrompt(_ displayRateLaterButton:Bool)
    {
        Appirater.sharedInstance.showPromptWithChecks(false,
                                                      displayRateLaterButton:displayRateLaterButton)
    }
    private class func showPrompt()
    {
        Appirater.tryToShowPrompt()
    }
    private func showPromptWithChecks(_ withChecks:Bool, displayRateLaterButton:Bool) {
        if (withChecks == false) || self.ratingAlertIsAppropriate() {
            self.showRatingAlert(displayRateLaterButton)
        }
    }
    
    private class func getRootViewController() -> AnyObject?
    {
        let window = UIApplication.shared.keyWindow
        if window!.windowLevel != UIWindowLevelNormal {
            let windows = UIApplication.shared.windows
            for window in windows {
                if window.windowLevel == UIWindowLevelNormal {
                    break
                }
            }
        }
        
        return Appirater.iterateSubViewsForViewController(window!) // iOS 8+ deep traverse
    }
    
    private class func iterateSubViewsForViewController(_ parentView:UIView) -> AnyObject?
    {
        for subView in parentView.subviews
        {
            let responder = subView.next! as NSObject
            if responder is UIViewController {
                return self.topMostViewController(responder as! UIViewController)
            }
            
            if let found = Appirater.iterateSubViewsForViewController(subView) {
                return found
            }
        }
        return nil
    }
    
    private class func topMostViewController( _ controller : UIViewController) -> UIViewController {
        var currentController = controller
        var isPresenting = false
        repeat {
            // this path is called only on iOS 6+, so -presentedViewController is fine here.
            let presented = currentController.presentedViewController
            isPresenting = presented != nil
            if(presented != nil) {
                currentController = presented!
            }
            
        } while (isPresenting)
        
        return currentController
    }
    /*!
     Tells Appirater to open the App Store page where the user can specify a
     rating for the app. Also records the fact that this has happened, so the
     user won't be prompted again to rate the app.
     
     The only case where you should call this directly is if your app has an
     explicit "Rate this app" command somewhere.  In all other cases, don't worry
     about calling this -- instead, just call the other functions listed above,
     and let Appirater handle the bookkeeping of deciding when to ask the user
     whether to rate the app.
     */
    
    class func rateApp()
    {
        
        let userDefaults = UserDefaults.standard
        userDefaults.set(true, forKey:kRatedCurrentVersion)
        userDefaults.synchronize()
        
        //Use the in-app StoreKit view if available (iOS 6) and imported. This works in the simulator.
        
        if !Appirater.sharedInstance.openInAppStore
        {
            
            let storeViewController = SKStoreProductViewController()
            let appId = NSNumber(value:(Appirater._appId! as NSString).integerValue)
            storeViewController.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier:appId], completionBlock:nil)
            storeViewController.delegate = self.sharedInstance
            
            let delegate = self.sharedInstance.delegate
            delegate?.appiraterWillPresentModalView?(self.sharedInstance, animated: Appirater._usesAnimation)
            
            
            self.getRootViewController()!.present(storeViewController, animated:Appirater._usesAnimation, completion:{ () in
                
                self.setModalOpen(true)
                
                //Temporarily use a black status bar to match the StoreKit view.
                self.setStatusBarStyle(UIApplication.shared.statusBarStyle)
                UIApplication.shared.setStatusBarStyle(UIStatusBarStyle.lightContent,  animated:Appirater._usesAnimation)
            })
            
            //Use the standard openUrl method if StoreKit is unavailable.
        }
        else
        {
            
            #if (arch(i386) || arch(x86_64)) && os(iOS)
                //print("APPIRATER NOTE: iTunes App Store is not supported on the iOS simulator. Unable to open App Store page.")
            #else
                var reviewURL = Appirater.templateReviewURL.replacingOccurrences(of: "APP_ID", with: String(format:"%@", Appirater._appId!))
                //                var reviewURL = Appirater.templateReviewURL.stringByReplacingOccurrencesOfString("APP_ID", withString:String(format:"%@", Appirater._appId!))
                
                // iOS 7 needs a different templateReviewURL @see https://github.com/arashpayan/appirater/issues/131
                // Fixes condition @see https://github.com/arashpayan/appirater/issues/205
                let version = (UIDevice.current.systemVersion as NSString).floatValue
                if version >= 7.0 && version < 8.0 {
                    reviewURL = Appirater.templateReviewURLiOS7.replacingOccurrences(of: "APP_ID", with: String(format:"%@", Appirater._appId!))
                    //                    reviewURL = Appirater.templateReviewURLiOS7.stringByReplacingOccurrencesOfString("APP_ID", withString:String(format:"%@", Appirater._appId!))
                }
                    // iOS 8 needs a different templateReviewURL also @see https://github.com/arashpayan/appirater/issues/182
                else if version >= 8.0
                {
                    reviewURL = Appirater.templateReviewURLiOS8.replacingOccurrences(of: "APP_ID", with: String(format:"%@", Appirater._appId!))
                    //                    reviewURL = Appirater.templateReviewURLiOS8.stringByReplacingOccurrencesOfString("APP_ID", withString:String(format:"%@", Appirater._appId!))
                }
                
                UIApplication.shared.openURL(NSURL(string:reviewURL)! as URL)
            #endif
        }
    }
    internal func alertView(_ alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int)
    {
        if self.presentCancelButton
        {
            self.processRatingEvent(buttonIndex)
        }
        else {
            self.processRatingEventWithoutCancelButton(buttonIndex)
        }
    }
    private func processRatingEvent(_ alertButtonIndex:Int) {
        let delegate = Appirater._delegate
        let userDefaults = UserDefaults.standard
        
        switch (alertButtonIndex)
        {
        case 0:
            // they don't want to rate it
            PMTracker.trackEvent("Rate - Decline")
            userDefaults.set(true, forKey:Appirater.kDeclinedToRate)
            userDefaults.synchronize()
            delegate?.appiraterDidDeclineToRate?(self)
            
        case 1:
            // they want to rate it
            PMTracker.trackEvent("Rate - Rate This App")
            Appirater.rateApp()
            delegate?.appiraterDidOptToRate?(self)
        case 2:
            // remind them later
            PMTracker.trackEvent("Rate - Remind Me Later")
            userDefaults.set(Date().timeIntervalSince1970, forKey:Appirater.kReminderRequestDate)
            userDefaults.synchronize()
            delegate?.appiraterDidOptToRemindLater?(self)
        default:
            break
        }
    }
    private func processRatingEventWithoutCancelButton(_ alertButtonIndex:Int) {
        let delegate = Appirater._delegate
        let userDefaults = UserDefaults.standard
        
        switch (alertButtonIndex)
        {
        case 0:
            // they want to rate it
            PMTracker.trackEvent("Rate - Rate This App")
            Appirater.rateApp()
            delegate?.appiraterDidOptToRate?(self)
        case 1:
            // remind them later
            PMTracker.trackEvent("Rate - Remind Me Later")
            userDefaults.set(Date().timeIntervalSince1970, forKey:Appirater.kReminderRequestDate)
            userDefaults.synchronize()
            delegate?.appiraterDidOptToRemindLater?(self)
        default:
            break
        }
    }
    internal func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        Appirater.closeModal()
    }
    
    /*!
     Tells Appirater to immediately close any open rating modals (e.g. StoreKit rating VCs).
     */
    //Close the in-app rating (StoreKit) view and restore the previous status bar style.
    class func closeModal()
    {
        if Appirater._modalOpen
        {
            UIApplication.shared.setStatusBarStyle(Appirater._statusBarStyle, animated:Appirater._usesAnimation)
            let usedAnimation = Appirater._usesAnimation
            self.setModalOpen(false)
            
            // get the top most controller (= the StoreKit Controller) and dismiss it
            var presentingController = UIApplication.shared.keyWindow!.rootViewController
            presentingController = self.topMostViewController(presentingController!)
            presentingController!.dismiss(animated: Appirater._usesAnimation, completion:{ () in
                let delegate = self.sharedInstance.delegate
                delegate?.appiraterDidDismissModalView?(self.sharedInstance, animated: usedAnimation)
            })
            Appirater.setStatusBarStyle(UIStatusBarStyle.default)
        }
    }
    @available(*, deprecated:0.1)
    class func appLaunched()
    {
        Appirater.appLaunched(true)
    }
}
