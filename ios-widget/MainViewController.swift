//
//  MainViewController.swift
//  App (main iOS app target)
//
//  Capacitor 6+ requires local (in-app) plugins to be registered manually.
//  This subclass registers WidgetBridgePlugin when the bridge loads.
//
//  After adding this file to the app target, open App/Main.storyboard,
//  select the view controller, and set its Custom Class from
//  CAPBridgeViewController to MainViewController (see the setup guide).
//
//  TARGET MEMBERSHIP: app target only.
//

import UIKit
import Capacitor

class MainViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(WidgetBridgePlugin())
    }
}
