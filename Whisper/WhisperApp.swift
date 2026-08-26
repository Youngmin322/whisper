//
//  WhisperApp.swift
//  Whisper
//
//  Created by Youngmin Cho on 8/11/26.
//

import SwiftUI

@main
struct WhisperApp: App {
    @UIApplicationDelegateAdaptor(WhisperAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
