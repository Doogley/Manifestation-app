//
//  AlreadyMineWidgetBundle.swift
//  AlreadyMineWidget extension
//
//  Entry point for the widget extension. Xcode's Widget Extension template
//  generates a file like this — replace the template's bundle with this one
//  (there must be exactly one @main in the extension target).
//
//  TARGET MEMBERSHIP: widget extension target only.
//

import WidgetKit
import SwiftUI

@main
struct AlreadyMineWidgetBundle: WidgetBundle {
    var body: some Widget {
        AlreadyMineWidget()
        AlreadyMineAffirmationWidget()
    }
}
