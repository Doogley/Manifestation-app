//
//  WidgetBridgePlugin.swift
//  App (main iOS app target — NOT the widget extension)
//
//  Local Capacitor plugin that receives widget data from JavaScript
//  (window.AMWidget.sync in capacitor-init.js), writes it to the shared
//  App Group UserDefaults suite, and asks WidgetKit to refresh.
//
//  Registration (Capacitor 6+): local plugins are no longer auto-discovered.
//  MainViewController.swift registers an instance in capacitorDidLoad() —
//  see that file and the setup guide.
//
//  TARGET MEMBERSHIP: app target only. Requires Models.swift (WidgetKeys)
//  to also be a member of the app target.
//

import Foundation
import Capacitor
import WidgetKit

@objc(WidgetBridgePlugin)
public class WidgetBridgePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "WidgetBridgePlugin"
    public let jsName = "WidgetBridge"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "setWidgetData", returnType: CAPPluginReturnPromise)
    ]

    @objc func setWidgetData(_ call: CAPPluginCall) {
        guard let defaults = UserDefaults(suiteName: WidgetKeys.appGroup) else {
            call.reject("App Group \(WidgetKeys.appGroup) is not enabled on the app target")
            return
        }

        defaults.set(call.getString("todayAffirmation") ?? "", forKey: WidgetKeys.todayAffirmation)
        defaults.set(call.getString("todayCategory") ?? "", forKey: WidgetKeys.todayCategory)
        defaults.set(call.getInt("streakCount") ?? 0, forKey: WidgetKeys.streakCount)
        defaults.set(call.getString("currentRank") ?? "", forKey: WidgetKeys.currentRank)
        defaults.set(call.getInt("unlockedCount") ?? 0, forKey: WidgetKeys.unlockedCount)
        defaults.set(Date().timeIntervalSince1970, forKey: WidgetKeys.lastSync)

        // Ask iOS to re-run every widget timeline so the new affirmation /
        // streak shows up immediately instead of at the next 2-hour refresh.
        DispatchQueue.main.async {
            WidgetCenter.shared.reloadAllTimelines()
        }

        call.resolve()
    }
}
