//
//  AppStatsRealm.swift
//  AppStats
//
//  Created by Meilbn on 2023/9/26.
//

import RealmSwift

// MARK: Objects

class AppStatsUUID: Object {
    
    @Persisted(primaryKey: true) var id: Int64 = 0
    @Persisted var appKey: String = ""
    @Persisted var appUserId: Int = 0
    @Persisted var appId: Int = 0
    @Persisted var uuid: String = ""
    @Persisted var systemVersion: String = ""
    @Persisted var deviceModel: String = ""
    @Persisted var appVersion: String = ""
    @Persisted var appBuild: String = ""
    @Persisted var region: String = ""
    
    var isUpdateNeeded: Bool {
        return 0 == appUserId || systemVersion != UIDevice.current.systemVersion || deviceModel != AppStatsHelper.deviceModel || appVersion != AppStatsHelper.appVersion || region != AppStatsHelper.currentRegion || appBuild != AppStatsHelper.appBuild
    }
    
}

enum AppStatType: Int, PersistableEnum {
    
    case download = 0, launching = 1, active = 2
    
}

class AppStat: Object {
    
    @Persisted(primaryKey: true) var id: Int64 = 0
    @Persisted var appKey: String = ""
    @Persisted var appId: Int = 0
    @Persisted var type: AppStatType = .download
    @Persisted var count: Int = 1
    @Persisted var date: String = ""
    @Persisted var isUploaded: Bool = false
    
}

class AppEvent: Object {
    
    @Persisted(primaryKey: true) var id: Int64 = 0
    @Persisted var appKey: String = ""
    @Persisted var appId: Int = 0
    @Persisted var event: String = ""
    @Persisted var attrs: String?
    @Persisted var time = Date()
    @Persisted var isUploaded: Bool = false
    
}

// MARK: AppStatsRealm

class AppStatsRealm {
    
    private init() { }
    
    static let shared = AppStatsRealm()
    
    //
    
    private(set) lazy var realm = AppStatsRealm.getRealm()
    
    //
    
    static func getRealm() -> Realm {
        let libraryDirectoryURL = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!)
        let appStatsDirectoryURL = libraryDirectoryURL.appendingPathComponent("AppStats", isDirectory: true)
        if !FileManager.default.fileExists(atPath: appStatsDirectoryURL.path) {
            do {
                try FileManager.default.createDirectory(at: appStatsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                AppStats.debugLog("AppStats - create folder failed, error = \(error.localizedDescription)")
            }
        }
        
        var config = Realm.Configuration.defaultConfiguration
        config.fileURL = appStatsDirectoryURL.appendingPathComponent("default.realm", isDirectory: false)
        let realm = try! Realm(configuration: config)
        return realm
    }
    
    func maxIdOf<Element: Object>(_ type: Element.Type) -> Int64 {
        if let max = realm.objects(type).max(ofProperty: "id") as Int64? {
            return max + 1
        } else {
            return 1
        }
    }
    
}

// MARK: AppStatsUUID

extension AppStatsRealm {
    
    func getUUID(withAppKey key: String) -> AppStatsUUID {
        if let uuid = realm.objects(AppStatsUUID.self).where({
            $0.appKey == key
        }).first { // 如果有找到则说明不是第一次打开
            return uuid
        }
        
        let uuid = AppStatsUUID()
        uuid.id = maxIdOf(AppStatsUUID.self)
        uuid.appKey = key
        uuid.uuid = UUID().uuidString
        uuid.systemVersion = UIDevice.current.systemVersion
        uuid.deviceModel = AppStatsHelper.deviceModel
        uuid.appVersion = AppStatsHelper.appVersion
        
        // 没有则添加一条下载的记录
        let stat = AppStat()
        stat.id = maxIdOf(AppStat.self)
        stat.appKey = key
        stat.type = .download
        stat.date = AppStatsHelper.shortDateFormatter.string(from: Date())
        
        try! realm.write {
            realm.add(uuid)
            realm.add(stat)
        }
        
        return uuid
    }
    
    func updateAppId(_ appId: Int, forUUID uuid: AppStatsUUID) {
        try! realm.write {
            uuid.appId = appId
            
            // 查询是否有 app id 为 0 的 stat 记录
            let zeroAppIdStats = realm.objects(AppStat.self).where {
                $0.appKey == uuid.appKey && $0.appId == 0
            }
            for stat in zeroAppIdStats {
                stat.appId = appId
            }
            // 查询是否有 app id 为 0 的 event 记录
            let zeroAppIdEvents = realm.objects(AppEvent.self).where {
                $0.appKey == uuid.appKey && $0.appId == 0
            }
            for event in zeroAppIdEvents {
                event.appId = appId
            }
        }
    }
    
    func updateUserInfos(withUser user: AppAPIUser, forUUID uuid: AppStatsUUID) {
        try! realm.write {
            uuid.appUserId = user.id
            uuid.systemVersion = user.systemVersion
            uuid.deviceModel = user.deviceModel
            uuid.appVersion = user.appVersion
            uuid.appBuild = user.appBuild
            uuid.region = user.region
        }
    }
    
}

// MARK: AppStat

extension AppStatsRealm {
    
    func addAppLaunchingStat() {
        let appKey = AppStats.shared._appUUID.appKey
        if appKey.isEmpty { return }
        
        // 先找到今日的
        if let stat = getTodayStat(withType: .launching) {
            try! realm.write {
                stat.count += 1
                stat.isUploaded = false
            }
            
            return
        }
        
        // 没有找到今日的就添加一条
        let stat = AppStat()
        stat.id = maxIdOf(AppStat.self)
        stat.appKey = appKey
        stat.appId = AppStats.shared._appUUID.appId
        stat.type = .launching
        stat.date = AppStatsHelper.shortDateFormatter.string(from: Date())
        
        try! realm.write {
            realm.add(stat)
        }
    }
    
    func getTodayStat(withType type: AppStatType) -> AppStat? {
        let today = AppStatsHelper.shortDateFormatter.string(from: Date())
        return realm.objects(AppStat.self).where {
            $0.appKey == AppStats.shared._appUUID.appKey && $0.type == type && $0.date == today
        }.first
    }
    
    //
    
    func addAppBecomeActiveStat() {
        let appKey = AppStats.shared._appUUID.appKey
        if appKey.isEmpty { return }
        
        // 先找到今日的
        if let stat = getTodayStat(withType: .active) {
            try! realm.write {
                stat.count += 1
                stat.isUploaded = false
            }
            
            return
        }
        
        // 没有找到今日的就添加一条
        let stat = AppStat()
        stat.id = maxIdOf(AppStat.self)
        stat.appKey = appKey
        stat.appId = AppStats.shared._appUUID.appId
        stat.type = .active
        stat.date = AppStatsHelper.shortDateFormatter.string(from: Date())
        
        try! realm.write {
            realm.add(stat)
        }
    }
    
    //
    
    func getNotUploadedAppStats() -> Results<AppStat> {
        return realm.objects(AppStat.self).where {
            $0.appKey == AppStats.shared._appUUID.appKey && $0.isUploaded == false
        }
    }
    
    func appStatsDidUpload(_ stats: [AppStat]) {
        if 0 == stats.count { return }
        
        try! realm.write {
            for stat in stats {
                stat.isUploaded = true
            }
        }
    }
    
}

// MARK: AppEvent

extension AppStatsRealm {
    
    func addAppEvent(_ event: String, attrs: [String : Codable]?) {
        if event.isEmpty { return }
        
        let appKey = AppStats.shared._appUUID.appKey
        if appKey.isEmpty { return }
        
        let obj = AppEvent()
        obj.id = maxIdOf(AppEvent.self)
        obj.appKey = appKey
        obj.appId = AppStats.shared._appUUID.appId
        obj.event = event
        
        if let ats = attrs, let data = try? JSONSerialization.data(withJSONObject: ats), let jsonString = String(data: data, encoding: .utf8) {
            obj.attrs = jsonString
        }
        
        try! realm.write {
            realm.add(obj)
        }
    }
    
    func getNotUploadedAppEvents() -> Results<AppEvent> {
        return realm.objects(AppEvent.self).where {
            $0.appKey == AppStats.shared._appUUID.appKey && $0.isUploaded == false
        }
    }
    
    func appEventsDidUpload(_ events: [AppEvent]) {
        if 0 == events.count { return }
        
        try! realm.write {
            for event in events {
                event.isUploaded = true
            }
        }
    }
    
}

// MARK: Results Extensions

extension Results {
    
    var array: [Element] {
        var list = [Element]()
        for item in self {
            list.append(item)
        }
        return list
    }
    
}


// MARK: List Extensions

extension List {
    
    var array: [Element] {
        var list = [Element]()
        for item in self {
            list.append(item)
        }
        return list
    }
    
}
