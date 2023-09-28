//
//  AppStats.swift
//  AppStats
//
//  Created by Meilbn on 2023/9/26.
//

import UIKit

public class AppStats {
    
    public static let shared = AppStats()
    
    //
    
    public var isDebugLogEnable = true
    
    var _appUUID: AppStatsUUID!
    
    public var appUUID: String {
        if nil != _appUUID {
            return _appUUID.uuid
        }
        
        return ""
    }
    
    public var appUserId: Int {
        if nil != _appUUID {
            return _appUUID.appUserId
        }
        
        return 0
    }
    
    var endpoint = ""
    
    // 加入重试机制，防止国行机子上第一次打开需要网络权限弹窗导致暂时无网络，接口调用失败
    private var retryMaxCount = 100
    private var currentRetryTimes = 0
    private var retryTimer: Timer?
    
    private var isUploading = false
    private var latestUploadedTime: TimeInterval = 0
    
    //
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidFinishLaunching(_:)), name: UIApplication.didFinishLaunchingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    static func debugLog(_ log: String) {
        if AppStats.shared.isDebugLogEnable {
            debugPrint("\(Date()) AppStats - \(log)")
        }
    }
    
    // MARK: Register App Key
    
    /// 注册 App key
    public func register(withAppKey appkey: String, endpoint: String) {
        assert(appkey.count > 0, "App key can not be empty!")
        AppStats.debugLog("AppStats - register app key")
        _appUUID = AppStatsRealm.shared.getUUID(withAppKey: appkey)
        self.endpoint = endpoint
        checkAppId()
    }
    
    // MARK: Private Methods
    
    private func checkAppId() {
        if _appUUID.appId > 0 {
            AppStats.shared.updateAppUserIfNeeded()
        } else {
            AppStatsAPIManager.getAppId(withAppKey: _appUUID.appKey, bundleId: AppStatsHelper.bundleID) { _, success, data, msg in
                if success && data > 0 {
                    AppStatsRealm.shared.updateAppId(data, forUUID: AppStats.shared._appUUID)
                    AppStats.shared.updateAppUserIfNeeded()
                } else {
                    AppStats.debugLog("AppStats - register app key failed, error: \(msg ?? "nil"), with return data: \(data)")
                }
            } failure: { error in
                AppStats.debugLog("AppStats - register app key failed, error: \(error.localizedDescription)")
                AppStats.shared.startRetryTimer()
            }
        }
    }
    
    /// 更新 App user 信息
    private func updateAppUserIfNeeded() {
        if !_appUUID.isUpdateNeeded {
            invalidateRetryTimer()
            return
        }
        
        AppStatsAPIManager.updateAppUser(withAppUserId: _appUUID.appUserId, appId: _appUUID.appId) { _, success, data, msg in
            if success, let user = data {
                AppStatsRealm.shared.updateUserInfos(withUser: user, forUUID: AppStats.shared._appUUID)
                AppStats.shared.invalidateRetryTimer()
                AppStats.shared.checkUploadAppCollects()
            } else {
                AppStats.debugLog("AppStats - update app user failed, error: \(msg ?? "nil")")
            }
        } failure: { error in
            AppStats.debugLog("AppStats - update app user failed, error: \(error.localizedDescription)")
            AppStats.shared.startRetryTimer()
        }
    }
    
    private func checkUploadAppCollects() {
        guard !_appUUID.appKey.isEmpty && _appUUID.appId > 0 && _appUUID.appUserId > 0 else { return }
        
        if isUploading { return }
        
        if latestUploadedTime > 0 && Date().timeIntervalSince1970 - latestUploadedTime < 30.0 * 60 {
            AppStats.debugLog("AppStats - 距离上次提交不到半小时，先不提交...")
            return
        }
        
        let stats = AppStatsRealm.shared.getNotUploadedAppStats().array
        let events = AppStatsRealm.shared.getNotUploadedAppEvents().array
        if stats.count > 0 || events.count > 0 {
            isUploading = true
            AppStatsAPIManager.collectAppStatsAndEvents(stats, events: events, appId: _appUUID.appId, appUserId: _appUUID.appUserId) { [weak self] _, success, msg in
                if success {
                    AppStatsRealm.shared.appStatsDidUpload(stats)
                    AppStatsRealm.shared.appEventsDidUpload(events)
                    self?.latestUploadedTime = Date().timeIntervalSince1970
                } else {
                    AppStats.debugLog("AppStats - upload app stats failed, error: \(msg ?? "nil")")
                }
                self?.isUploading = false
            } failure: { [weak self] error in
                AppStats.debugLog("AppStats - upload app stats failed, error: \(error.localizedDescription)")
                self?.isUploading = false
            }
        }
    }
    
    private func invalidateRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }
    
    private func startRetryTimer() {
        if let timer = retryTimer, timer.isValid { return }
        
        invalidateRetryTimer()
        
        let timer = Timer(timeInterval: 5.0, target: self, selector: #selector(retryRegiter), userInfo: nil, repeats: false)
        RunLoop.current.add(timer, forMode: .common)
        retryTimer = timer
    }
    
    @objc private func retryRegiter() {
        if currentRetryTimes >= retryMaxCount {
            invalidateRetryTimer()
            return
        }
        
        currentRetryTimes += 1
        checkAppId()
    }
    
    // MARK: Notifications
    
    @objc private func applicationDidFinishLaunching(_ ntf: Notification) {
        AppStats.debugLog("AppStats - \(#function)")
        AppStatsRealm.shared.addAppLaunchingStat()
    }
    
    @objc private func applicationDidEnterBackground(_ ntf: Notification) {
        AppStats.debugLog("AppStats - \(#function)")
    }
    
    @objc private func applicationDidBecomeActive(_ ntf: Notification) {
        AppStats.debugLog("AppStats - \(#function)")
        AppStatsRealm.shared.addAppBecomeActiveStat()
        checkUploadAppCollects()
    }
    
    // MARK: Add App Event
    
    public func addAppEvent(_ event: String, attrs: [String : Codable]?) {
        AppStatsRealm.shared.addAppEvent(event, attrs: attrs)
        checkUploadAppCollects()
    }
    
}

//

struct AppStatsHelper {
    
    static var bundleID: String {
        if let bundleID = Bundle.main.infoDictionary?[kCFBundleIdentifierKey as String] {
            return "\(bundleID)"
        } else {
            return ""
        }
    }
    
    static var appVersion: String {
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] {
            return "\(appVersion)"
        } else {
            return ""
        }
    }
    
    static var appBuild: String {
        if let buildVersion = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] {
            return "\(buildVersion)"
        } else {
            return ""
        }
    }
    
    static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    static var currentRegion: String {
        if #available(iOS 16, *) {
            return Locale.current.region?.identifier ?? "Unknown"
        } else {
            // Fallback on earlier versions
            return Locale.current.regionCode ?? "Unknown"
        }
    }
    
    // MARK: Time
    
    static var longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    static var shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
}

//


