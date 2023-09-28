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
    
    private var isUploading = false
    private var latestUploadedTime: TimeInterval = 0
    
    //
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidFinishLaunching(_:)), name: UIApplication.didFinishLaunchingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    // MARK: Register App Key
    
    /// 注册 App key
    public func register(withAppKey appkey: String, endpoint: String) {
        assert(appkey.count > 0, "App key can not be empty!")
        debugPrint("AppStats - register app key")
        _appUUID = AppStatsRealm.shared.getUUID(withAppKey: appkey)
        
        self.endpoint = endpoint
        
        if _appUUID.appId > 0 {
            AppStats.shared.updateAppUserIfNeeded()
        } else {
            AppStatsAPIManager.getAppId(withAppKey: appkey, bundleId: AppStatsHelper.bundleID) { _, success, data, msg in
                if success && data > 0 {
                    AppStatsRealm.shared.updateAppId(data, forUUID: AppStats.shared._appUUID)
                    AppStats.shared.updateAppUserIfNeeded()
                } else {
                    debugPrint("AppStats - register app key failed, error: \(msg ?? "nil"), with return data: \(data)")
                }
            } failure: { error in
                debugPrint("AppStats - register app key failed, error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: Private Methods
    
    /// 更新 App user 信息
    private func updateAppUserIfNeeded() {
        if !_appUUID.isUpdateNeeded { return }
        
        AppStatsAPIManager.updateAppUser(withAppUserId: _appUUID.appUserId, appId: _appUUID.appId) { _, success, data, msg in
            if success, let user = data {
                AppStatsRealm.shared.updateUserInfos(withUser: user, forUUID: AppStats.shared._appUUID)
            } else {
                debugPrint("AppStats - update app user failed, error: \(msg ?? "nil")")
            }
        } failure: { error in
            debugPrint("AppStats - update app user failed, error: \(error.localizedDescription)")
        }
    }
    
    private func checkUploadAppCollects() {
        guard !_appUUID.appKey.isEmpty && _appUUID.appId > 0 && _appUUID.appUserId > 0 else { return }
        
        if isUploading { return }
        
        if latestUploadedTime > 0 && Date().timeIntervalSince1970 - latestUploadedTime < 30.0 * 60 {
            debugPrint("AppStats - 距离上次提交不到 1 小时，先不提交...")
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
                    debugPrint("AppStats - upload app stats failed, error: \(msg ?? "nil")")
                }
                self?.isUploading = false
            } failure: { [weak self] error in
                debugPrint("AppStats - upload app stats failed, error: \(error.localizedDescription)")
                self?.isUploading = false
            }
        }
    }
    
    // MARK: Notifications
    
    @objc private func applicationDidFinishLaunching(_ ntf: Notification) {
        debugPrint("AppStats - \(#function)")
        AppStatsRealm.shared.addAppLaunchingStat()
    }
    
    @objc private func applicationDidEnterBackground(_ ntf: Notification) {
        debugPrint("AppStats - \(#function)")
    }
    
    @objc private func applicationDidBecomeActive(_ ntf: Notification) {
        debugPrint("AppStats - \(#function)")
        AppStatsRealm.shared.addAppBecomeActiveStat()
        checkUploadAppCollects()
    }
    
    // MARK: Add App Event
    
    public func addAppEvent(_ event: String, attrs: [String : Codable]?) {
        AppStatsRealm.shared.addAppEvent(event, attrs: attrs)
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


