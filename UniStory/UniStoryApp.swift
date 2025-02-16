//
//  UniStoryApp.swift
//  UniStory
//
//  Created by Rae Hou on 2024/12/2.
//

import SwiftUI

@main
struct UniStoryApp: App {
    @StateObject private var localization = LocalizationManager.shared
    
    init() {
        // 禁用暗黑模式
        if #available(iOS 13.0, *) {
            UIWindow.appearance().overrideUserInterfaceStyle = .light
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(localization)  // 注入 LocalizationManager
        }
    }
}
