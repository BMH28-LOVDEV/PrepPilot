//
//  PrepPilotWidgetsBundle.swift
//  PrepPilotWidgets
//
//  Created by Benjamin M. Hale on 6/7/26.
//

import WidgetKit
import SwiftUI

@main
struct PrepPilotWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PrepPilotWidgets()
        PrepPilotWidgetsControl()
        PrepPilotWidgetsLiveActivity()
    }
}
