//
//  AppStatsAPI.swift
//  AppStats
//
//  Created by Meilbn on 2023/9/26.
//

import Moya
import SwiftyJSON

struct AppAPIUser: Codable {
    
    var id: Int
    var appId: Int
    var uuid: String
    var platform: String
    var systemVersion: String
    var deviceModel: String
    var appVersion: String
    var appBuild: String
    var region: String
    
}

//struct AppAPIStat: Codable {
//    
//    var t: Int
//    var c: Int
//    var d: String
//    
//}
//
//struct AppAPIEvent: Codable {
//    
//    var e: String
//    var a: String
//    var t: String
//    
//}

public struct AppStatsAPISign {
    
    public static func generateCurrentTimestampSign() -> (sign: String, ts: String) {
        let ts = String(format: "%.0lf", Date().timeIntervalSince1970)
        let rts = String(ts.reversed())
        let ori = "Meilbn_AppStats_" + rts
        return (ori.app_stats_sha256(), ts)
    }
    
}

//

enum AppStatsAPI {
    // 获取 app id
    case getAppId(appKey: String, bundleId: String)
    // 更新统计用户信息
    case updateAppUser(appUserId: Int?, appId: Int)
    // 统计数据
    case clcAppStatsAndEvents(appUserId: Int, appId: Int, stats: [AppStat], events: [AppEvent])
    
}

extension AppStatsAPI: TargetType {
    
    var baseURL: URL {
        return URL(string: AppStats.shared.endpoint + "/api/v1/stats")!
    }
    
    var headers: [String : String]? {
        var dict: [String : String] = ["Content-type" : "application/x-www-form-urlencoded;charset=UTF-8"]
        
        switch self {
        case .clcAppStatsAndEvents(let appUserId, _, _, _):
            dict["app_user_id"] = "\(appUserId)"
        default: break
        }
        
//        let ts = String(format: "%.0lf", Date().timeIntervalSince1970)
//        let rts = String(ts.reversed())
//        let ori = "Meilbn_AppStats_" + rts
        let signs = AppStatsAPISign.generateCurrentTimestampSign()
        dict["sign"] = signs.sign // ori.app_stats_sha256()
        dict["ts"] = signs.ts
        
        return dict
    }
    
    var method: Moya.Method {
        switch self {
        case .getAppId:
            return .get
        default: break
        }
        
        return .post
    }
    
    var path: String {
        switch self {
        case .getAppId:
            return "/app/id"
        case .updateAppUser:
            return "/app/user"
        case .clcAppStatsAndEvents(_, let appId, _, _):
            return "/clc/\(appId)"
        }
    }
    
    var task: Task {
        switch self {
        case .getAppId(let appKey, let bundleId):
            return .requestParameters(parameters: ["key" : appKey, "bundleId" : bundleId], encoding: URLEncoding.default)
        case .updateAppUser(let appUserId, let appId):
            var params: [String : Any] = ["appId" : appId, "uuid" : AppStats.shared.appUUID, "platform" : UIDevice.current.systemName, "systemVersion" : UIDevice.current.systemVersion,
                                          "deviceModel" : AppStatsHelper.deviceModel, "appVersion" : AppStatsHelper.appVersion, "appBuild" : AppStatsHelper.appBuild, "region" : AppStatsHelper.currentRegion]
            if let uid = appUserId, uid > 0 { params["id"] = uid }
            return .requestParameters(parameters: params, encoding: JSONEncoding.default)
        case .clcAppStatsAndEvents(_, _, let stats, let events):
            var body = [String : Any]()
            
            var statList = [[String : Any]]()
            for stat in stats {
                statList.append(["t" : stat.type.rawValue, "c" : stat.count, "d" : stat.date])
            }
            body["stats"] = statList
            
            var eventList = [[String : Any]]()
            for event in events {
                eventList.append(["e" : event.event, "a" : event.attrs ?? "", "t" : AppStatsHelper.longDateFormatter.string(from: event.time)])
            }
            body["events"] = eventList
            return .requestParameters(parameters: body, encoding: JSONEncoding.default)
        }
    }
    
}


enum AppStatsAPIReturnCode: Int {
    case failed = -1
    case success = 200 // 成功
}


struct AppStatsAPIManager {
    
    static let returnCodeKey = "code"
    static let messageKey = "msg"
    static let dataKey = "data"
    
    typealias BoolResultBlock = ((AppStatsAPIReturnCode, Bool, String?) -> Void)
    typealias IntegerResultBlock = ((AppStatsAPIReturnCode, Bool, Int, String?) -> Void)
    typealias OptionalIntegerResultBlock = ((AppStatsAPIReturnCode, Bool, Int?, String?) -> Void)
    typealias DoubleResultBlock = ((AppStatsAPIReturnCode, Bool, Double, String?) -> Void)
    typealias StringResultBlock = ((AppStatsAPIReturnCode, Bool, String?, String?) -> Void)
    typealias ObjectResultBlock<T: Codable> = ((AppStatsAPIReturnCode, Bool, T?, String?) -> Void)
    typealias ArrayResultBlock<T: Codable> = ((AppStatsAPIReturnCode, Bool, [T]?, String?) -> Void)
    typealias ArrayWithCountResultBlock<T: Codable> = ((AppStatsAPIReturnCode, Bool, [T]?, Int, String?) -> Void)
    typealias DictionaryResultBlock<K: Hashable & Codable, T: Codable> = ((AppStatsAPIReturnCode, Bool, [K : T]?, String?) -> Void)
    typealias FailureBlock = ((MoyaError) -> Void)
    
    private(set) static var sharedProvider = MoyaProvider<AppStatsAPI>(plugins: [NetworkLoggerPlugin(configuration: NetworkLoggerPlugin.Configuration(logOptions: .verbose))])
    
}


extension AppStatsAPIManager {
    
    static func getAppId(withAppKey appKey: String, bundleId: String, completion: IntegerResultBlock?, failure: FailureBlock?) {
        sharedProvider.request(.getAppId(appKey: appKey, bundleId: bundleId)) { result in
            commonIntegerProcessing(withResult: result, innerData: nil, completion: completion, failure: failure)
        }
    }
    
    static func updateAppUser(withAppUserId appUserId: Int?, appId: Int, completion: ObjectResultBlock<AppAPIUser>?, failure: FailureBlock?) {
        sharedProvider.request(.updateAppUser(appUserId: appUserId, appId: appId)) { result in
            commonObjectProcessing(withResult: result, withClass: AppAPIUser.self, completion: completion, failure: failure)
        }
    }
    
    static func collectAppStatsAndEvents(_ stats: [AppStat], events: [AppEvent], appId: Int, appUserId: Int, completion: BoolResultBlock?, failure: FailureBlock?) {
        sharedProvider.request(.clcAppStatsAndEvents(appUserId: appUserId, appId: appId, stats: stats, events: events)) { result in
            commonBoolProcessing(withResult: result, completion: completion, failure: failure)
        }
    }
    
}


extension AppStatsAPIManager {
    
    static func processingErrorMessageForToken(withJSON json:JSON) -> String? {
        let msg = json[messageKey].string
        return msg
    }
    
    static func commonBoolProcessing(withResult result: Result<Moya.Response, MoyaError>, completion: BoolResultBlock?, failure: FailureBlock?) {
        switch result {
        case let .success(response):
            var retCode: AppStatsAPIReturnCode = .failed
            var isSuccess = false
            var msg: String?
            
            do {
                let json = try JSON(data: response.data)
                if json[returnCodeKey].intValue == AppStatsAPIReturnCode.success.rawValue {
                    retCode = .success
                    isSuccess = true
                    msg = json[messageKey].string
                } else {
                    retCode = AppStatsAPIReturnCode(rawValue: json[returnCodeKey].intValue) ?? .failed
                    msg = processingErrorMessageForToken(withJSON: json)
                }
            } catch {
//                debugPrint("\(#function) - error: \(error)")
//                msg = error.localizedDescription
                msg = "返回数据解析出错"
            }
            
            completion?(retCode, isSuccess, msg)
        case let .failure(error):
            failure?(error)
        }
    }
    
    static func commonIntegerProcessing(withResult result: Result<Moya.Response, MoyaError>, innerData: String?, completion: IntegerResultBlock?, failure: FailureBlock?) {
        switch result {
        case let .success(response):
            var retCode: AppStatsAPIReturnCode = .failed
            var isSuccess = false
            var intValue = 0
            var msg: String?
            
            do {
                let json = try JSON(data: response.data)
                if json[returnCodeKey].intValue == AppStatsAPIReturnCode.success.rawValue {
                    retCode = .success
                    isSuccess = true
                    if let inner = innerData {
                        intValue = json[dataKey][inner].intValue
                    } else {
                        intValue = json[dataKey].intValue
                    }
                    msg = json[messageKey].string
                } else {
                    retCode = AppStatsAPIReturnCode(rawValue: json[returnCodeKey].intValue) ?? .failed
                    msg = processingErrorMessageForToken(withJSON: json)
                }
            } catch {
//                debugPrint("\(#function) - error: \(error)")
//                msg = error.localizedDescription
                msg = "返回数据解析出错"
            }
            
            completion?(retCode, isSuccess, intValue, msg)
        case let .failure(error):
            failure?(error)
        }
    }
    
    static func commonObjectProcessing<T: Codable>(withResult result: Result<Moya.Response, MoyaError>, innerData: String? = nil, withClass: T.Type, completion: ObjectResultBlock<T>?, failure: FailureBlock?) {
        switch result {
        case let .success(response):
            var retCode: AppStatsAPIReturnCode = .failed
            var isSuccess = false
            var obj: T?
            var msg: String?
            do {
                let json = try JSON(data: response.data)
                if json[returnCodeKey].intValue == AppStatsAPIReturnCode.success.rawValue {
                    retCode = .success
                    isSuccess = true
                } else {
                    retCode = AppStatsAPIReturnCode(rawValue: json[returnCodeKey].intValue) ?? .failed
                    msg = processingErrorMessageForToken(withJSON: json)
                }
                
                do {
                    var data = json[dataKey]
                    if nil != data.dictionary {
                        if let inner = innerData {
                            data = data[inner]
                        }
                        let jsonDecoder = JSONDecoder()
                        obj = try jsonDecoder.decode(T.self, from: try data.rawData())
                    }
                    msg = json[messageKey].string
                } catch {
                    debugPrint("\(#function) - error: \(error)")
                    isSuccess = false
                    msg = "返回数据解析失败" // error.localizedDescription
                }
            } catch {
//                debugPrint("\(#function) - error: \(error)")
//                msg = error.localizedDescription
                msg = "返回数据解析出错"
            }
            
            completion?(retCode, isSuccess, obj, msg)
        case let .failure(error):
            failure?(error)
        }
    }
    
}
