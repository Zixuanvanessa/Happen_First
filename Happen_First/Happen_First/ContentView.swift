//
//  ContentView.swift
//  Happen_First
//
//  Created by Vanessaw on 30/1/2026.
//

import SwiftUI
import AppKit // 用到 NSHostingView，需要 macOS 的 AppKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState // 从 App 注入的全局状态
    private var audioMonitor = AudioMonitor.shared

    var body: some View {
        VStack {
            Spacer()
            Button(action: toggleActive) {
                Text(appState.isActive ? "Stop" : "Start")
                    .font(.system(size: 28, weight: .bold))
                    .frame(width: 200, height: 80)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
            Text(appState.isActive ? (appState.isSpeaking ? "Listening..." : "Ready — say something") : "Idle")
                .font(.footnote)
                .padding(.bottom, 20)
        }
        .frame(minWidth: 420, minHeight: 300)
        // 当 isActive 变化时启动/停止音频监控（你已有逻辑）
        // 在 isActive 变 true 时：启动音频监控（但不直接 showFloating）
        .onReceive(appState.$isActive) { newValue in
            if newValue {
                audioMonitor.startMonitoring { speaking in
                    DispatchQueue.main.async {
                        appState.isSpeaking = speaking
                    }
                }
            } else {
                audioMonitor.stopMonitoring()
                DispatchQueue.main.async {
                    appState.isSpeaking = false
                }
                hideFloating()
            }
        }

        // 当 isSpeaking 变为 true 时再显示（减少视图构建内重入）
        .onReceive(appState.$isSpeaking) { speaking in
            if speaking {
                showFloating()
            } else if !appState.isActive {
                hideFloating()
            }
        }

        .onAppear {
            // 如果你在 AppState 中存了上次位置/尺寸，可以在这里恢复并传进去
        }
    }

    private func toggleActive() {
        appState.isActive.toggle()
    }

    // MARK: - Floating window helpers

    private func showFloating() {
        // 把你的 SwiftUI FloatingView 包装成 NSView（NSHostingView），并把 appState 注入进去
        let floatingSwiftUIView = FloatingView().environmentObject(appState)
        let hosting = NSHostingView(rootView: floatingSwiftUIView)

        // 可选：为 hosting 设置一个初始 frame（FloatingWindowController 里也可能调整）
        hosting.frame = NSRect(x: 100, y: 100, width: 600, height: 200)

        // 调用你项目里已有的 FloatingWindowController 显示悬浮窗
        FloatingWindowController.shared.showFloatingView(with: hosting, frame: hosting.frame)
    }

    private func hideFloating() {
        FloatingWindowController.shared.hideFloatingView()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(AppState())
    }
}
