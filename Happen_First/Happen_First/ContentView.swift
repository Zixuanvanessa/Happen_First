//
//  ContentView.swift
//  Happen_First
//
//  Created by Vanessaw on 30/1/2026.
//

import SwiftUI
import AppKit
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    private var audioMonitor = AudioMonitor.shared
    // MARK: - timers (DispatchWorkItem) for Day4 rules
    // Work items are used so we can cancel them cleanly
    @State private var fiveSecondWorkItem: DispatchWorkItem? = nil
    @State private var thirtySecondWorkItem: DispatchWorkItem? = nil
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
            // 显示主状态（Idle / Ready / Listening）
            Text(statusText())
                .font(.footnote)
                .padding(.bottom, 20)
        }
        .frame(minWidth: 420, minHeight: 300)
        // 当 isActive 切换时启动/停止音频监控（Start 后并不直接显示悬浮窗）
        .onReceive(appState.$isActive) { newValue in
            if newValue {
                // 激活：开始监控（AudioMonitor 内部会做权限请求）
                audioMonitor.startMonitoring { speaking in
                    // AudioMonitor 回调保证在主线程（但这里再 dispatch 保险）
                    DispatchQueue.main.async {
                        appState.isSpeaking = speaking
                    }
                }
                // 当激活时，清理任何遗留的段落信号 / 定时器
                cancelFiveSecondTimer()
                cancelThirtySecondTimer()
                appState.endParagraph = false
            } else {
                // 取消监控并清理所有 UI 计时器
                audioMonitor.stopMonitoring()
                DispatchQueue.main.async {
                    appState.isSpeaking = false
                }
                // hide immediately when user stops the app
                hideFloating()
                cancelFiveSecondTimer()
                cancelThirtySecondTimer()
                appState.endParagraph = false
            }
        }
        // 当 isSpeaking 改变时负责 Day3 + Day4 的计时器逻辑
        .onReceive(appState.$isSpeaking) { speaking in
            if speaking {
                // 讲话：立即取消所有静默计时器（重置 5s/30s 规则）
                cancelFiveSecondTimer()
                cancelThirtySecondTimer()
                // 讲话时清除 endParagraph（开始新段）
                appState.endParagraph = false
                // 显示悬浮带（设计要求：只有在检测到讲话时才显示）
                showFloating()
            } else {
                // 检测到静默：只在 app 仍处于 active 时开始计时
                if appState.isActive {
                    // 安排 5 秒计时器：触发段落结束标记
                    scheduleFiveSecondTimer()
                    // 安排 30 秒计时器：触发悬浮带淡出
                    scheduleThirtySecondTimer()
                } else {
                    // 如果不是 active 就确保隐藏并清理
                    cancelFiveSecondTimer()
                    cancelThirtySecondTimer()
                    appState.endParagraph = false
                    hideFloating()
                }
            }
        }
        .onAppear {
            // 恢复 last window frame 如果有（可选）
        }
    }
    // MARK: - status text helper
    private func statusText() -> String {
        if !appState.isActive { return "Idle" }
        return appState.isSpeaking ? "Listening..." : "Ready — say something"
    }
    private func toggleActive() {
        appState.isActive.toggle()
    }
    // MARK: - Five second logic (endParagraph)
    private func scheduleFiveSecondTimer() {
        // cancel existing
        cancelFiveSecondTimer()
        // create new work item
        let work = DispatchWorkItem { [weak appState] in
            guard let appState = appState else { return }
            // Set the endParagraph flag on main queue
            DispatchQueue.main.async {
                appState.endParagraph = true
            }
        }
        fiveSecondWorkItem = work
        // schedule after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)
    }
    private func cancelFiveSecondTimer() {
        fiveSecondWorkItem?.cancel()
        fiveSecondWorkItem = nil
    }
    // MARK: - Thirty second logic (fade out floating)
    private func scheduleThirtySecondTimer() {
        cancelThirtySecondTimer()
        // capture only appState weakly (AppState is a class). Do NOT attempt to weak-capture `self` (ContentView is a struct).
        let work = DispatchWorkItem { [weak appState] in
            // Ensure we run UI changes on main queue
            DispatchQueue.main.async {
                guard let appState = appState else { return }
                // Defensive check: only hide if still active and not speaking
                if appState.isActive && !appState.isSpeaking {
                    FloatingWindowController.shared.hideFloatingView()
                }
            }
        }
        thirtySecondWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0, execute: work)
    }
    private func cancelThirtySecondTimer() {
        thirtySecondWorkItem?.cancel()
        thirtySecondWorkItem = nil
    }
    
    // MARK: - Floating window helpers
    private func showFloating() {
        DispatchQueue.main.async {
            // 将 FloatingView 包装为 AnyView，然后放入 ResizableHostingView
            let floatingSwiftUIView = FloatingView().environmentObject(appState)
            let hosting = ResizableHostingView(rootView: AnyView(floatingSwiftUIView))
            // center on main screen to avoid creating off-screen windows
            if let screenFrame = NSScreen.main?.visibleFrame {
                let w: CGFloat = 600
                let h: CGFloat = 200
                let x = screenFrame.midX - w/2
                let y = screenFrame.midY - h/2
                hosting.frame = NSRect(x: x, y: y, width: w, height: h)
            } else {
                hosting.frame = NSRect(x: 100, y: 100, width: 600, height: 200)
            }
            hosting.autoresizingMask = [.width, .height]
            // pass the hosting view to the floating controller
            FloatingWindowController.shared.showFloatingView(with: hosting, frame: hosting.frame)
        }
    }
    
    private func hideFloating() {
        DispatchQueue.main.async {
            FloatingWindowController.shared.hideFloatingView()
        }
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(AppState())
    }
}


