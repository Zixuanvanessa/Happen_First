//
//  Happen_FirstApp.swift
//  Happen_First
//
//  Created by Vanessaw on 30/1/2026.
//
import SwiftUI //导入 SwiftUI 框架，提供声明式 UI

@main //— 声明应用入口点
struct Happen_FirstApp: App { //应用结构体，符合 SwiftUI 的 App 协议
    // 1. 全局共享状态对象，供 UI 与后台（AudioMonitor）使用
    @StateObject private var appState = AppState() //在应用生命周期中创建并持有一个 AppState 的单例状态对象（用于 UI 与后台通信）
    
    var body: some Scene { //定义应用的场景（窗口）
        WindowGroup {
            // 2. 主启动页，绑定到共享状态
            ContentView()
                .environmentObject(appState) //主窗口组，注入 appState 到 ContentView 里作为环境对象（environmentObject）
        }
    }
}
