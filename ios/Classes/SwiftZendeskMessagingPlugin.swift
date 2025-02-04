import Flutter
import UIKit
import ZendeskSDKMessaging

public class SwiftZendeskMessagingPlugin: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate {
    let TAG = "[SwiftZendeskMessagingPlugin]"
    private var channel: FlutterMethodChannel
    private var zendeskMessaging: ZendeskMessaging?
    var isInitialized = false
    var isLoggedIn = false
    var pushNotificationsDisabled = false
    
    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init();
        self.zendeskMessaging = ZendeskMessaging(flutterPlugin: self, channel: channel)
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "zendesk_messaging", binaryMessenger: registrar.messenger())
        let instance = SwiftZendeskMessagingPlugin(channel: channel)
        let center = UNUserNotificationCenter.current()
        center.delegate = instance
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }
    
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        let shouldBeDisplayed = PushNotifications.shouldBeDisplayed(userInfo)
        
        let displayNotification = {
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .sound, .badge])
            } else {
                completionHandler([.alert, .sound, .badge])
            }
        }
        
        switch shouldBeDisplayed {
        case .messagingShouldDisplay:
            // Only display the notification if the app is active.
            if !pushNotificationsDisabled {
                displayNotification()
            }
        case .messagingShouldNotDisplay:
            // This push belongs to ZendeskMessaging but the interaction should not be handled by the SDK
            break
        case .notFromMessaging:
            // // This push does not belong to ZendeskMessaging
            displayNotification()
        @unknown default:
            break
        }
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let shouldBeDisplayed = PushNotifications.shouldBeDisplayed(userInfo)
        
        switch shouldBeDisplayed {
        case .messagingShouldDisplay:
            // This push belongs to ZendeskMessaging and the SDK is able to handle when the end user interacts with it
            PushNotifications.handleTap(userInfo) { viewController in
                if let topViewController = UIApplication.shared.delegate?.window??.rootViewController {
                    if let viewController {
                        topViewController.present(viewController, animated: false)
                    }
                }
            }
        case .messagingShouldNotDisplay:
            // This push belongs to ZendeskMessaging but the interaction should not be handled by the SDK
            break
        case .notFromMessaging:
            break
        @unknown default: break
        }
        
        completionHandler()
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            self.processMethodCall(call, result: result)
        }
    }
    
    private func processMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = call.method
        let arguments = call.arguments as? Dictionary<String, Any>
        
        
        switch(method){
        case "initialize":
            let channelKey: String = (arguments?["channelKey"] ?? "") as! String
            zendeskMessaging?.initialize(channelKey: channelKey, flutterResult: result)
        case "show":
            if (!isInitialized) {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            zendeskMessaging?.show(rootViewController: UIApplication.shared.delegate?.window??.rootViewController, flutterResult: result)
        case "loginUser":
            if (!isInitialized) {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            let jwt: String = arguments?["jwt"] as? String ?? ""
            zendeskMessaging?.loginUser(jwt: jwt, flutterResult: result)
        case "logoutUser":
            if (!isInitialized) {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            zendeskMessaging?.logoutUser(flutterResult: result)
        case "getUnreadMessageCount":
            if (!isInitialized) {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            result(handleMessageCount())
        case "listenUnreadMessages":
            if (!isInitialized) {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            zendeskMessaging?.listenMessageCountChanged()
            result(nil)
        case "isInitialized":
            result(handleInitializedStatus())
        case "isLoggedIn":
            result(handleLoggedInStatus())
        case "setConversationTags":
            if (!isInitialized) {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            let tags: [String] = arguments?["tags"] as! [String]
            zendeskMessaging?.setConversationTags(tags:tags)
            result(nil)
        case "clearConversationTags":
            if (!isInitialized) {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            zendeskMessaging?.clearConversationTags()
            result(nil)
        case "setConversationFields":
            if (!isInitialized) {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            let fields: [String: String] = arguments?["fields"] as! [String: String]
            zendeskMessaging?.setConversationFields(fields:fields)
            result(nil)
        case "clearConversationFields":
            if (!isInitialized) {
                print("\(TAG) - Messaging needs to be initialized first.\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            zendeskMessaging?.clearConversationFields()
            result(nil)
        case "updatePushNotificationToken":
            let token: String = arguments?["token"] as! String
            zendeskMessaging?.updatePushNotificationToken(token:token)
            result(nil)
        case "checkAndDisplayFirebaseNotification":
            // iOS does not support Firebase push notifications
            //They are sent via APNs directly and handled by the UNUserNotificationCenterDelegate
            result(false)
        case "setLoggable":
            let isLoggable: Bool = arguments?["isLoggable"] as! Bool
            zendeskMessaging?.setLoggable(isLoggable:isLoggable)
            result(nil)
        case "disablePushNotifications":
            pushNotificationsDisabled = arguments?["pushNotificationsDisabled"] as? Bool ?? false
            result(nil)
        case "invalidate":
            if (!isInitialized) {
                print("\(TAG) - Messaging is already on an invalid state\n")
                reportNotInitializedFlutterError(result: result)
                return
            }
            zendeskMessaging?.invalidate()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleMessageCount() -> Int {
        return zendeskMessaging?.getUnreadMessageCount() ?? 0
    }
    
    private func handleInitializedStatus() -> Bool {
        return isInitialized
    }
    
    private func handleLoggedInStatus() -> Bool {
        return isLoggedIn
    }
    
    private func reportNotInitializedFlutterError(result: FlutterResult) {
        result(FlutterError(
            code: "not_initialized",
            message: "Zendesk SDK needs to be initialized first",
            details: nil)
        )
    }
}
