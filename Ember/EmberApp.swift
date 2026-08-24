//
//  EmberApp.swift
//  Ember
//
//  Created by Youngmin Cho on 8/11/26.
//

import SwiftUI

@main
struct EmberApp: App {
    @UIApplicationDelegateAdaptor(EmberAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
