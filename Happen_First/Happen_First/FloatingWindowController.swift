//
//  FloatingWindowController.swift
//  Happen_First
//
//  Created by Vanessaw on 30/1/2026.
//

import Cocoa
import SwiftUI

/// 管理悬浮窗口展示与淡入淡出（主线程异步 + 防重入）
final class FloatingWindowController {
    static let shared = FloatingWindowController()

    private var window: NSWindow?
    private var isShowing = false

    private init() {}

    /// 显示悬浮视图（thread-safe：总是切回主线程异步执行）
    /// - Parameters:
    ///   - view: 要放入 window 的 NSView（通常是 NSHostingView）
    ///   - frame: 可选初始 frame
    func showFloatingView(with view: NSView, frame: CGRect? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 防重入：如果已经在显示中就不再创建新窗口
            if self.isShowing {
                // 如果 window 存在但被隐藏，确保前置它
                if let w = self.window {
                    w.orderFrontRegardless()
                }
                return
            }

            self.isShowing = true

            let contentRect = frame ?? CGRect(x: 100, y: 100, width: 600, height: 200)
            let style: NSWindow.StyleMask = [.borderless]
            let w = NSWindow(contentRect: contentRect,
                             styleMask: style,
                             backing: .buffered,
                             defer: false)
            w.isOpaque = false
            w.backgroundColor = NSColor.clear
            w.level = .floating
            w.hasShadow = true
            w.ignoresMouseEvents = false
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            w.contentView = view
            w.alphaValue = 0.0
            self.window = w

            // 展示并淡入动画
            w.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                w.animator().alphaValue = 1.0
            }
        }
    }

    /// 隐藏悬浮视图（同样在主线程）
    func hideFloatingView() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let w = self.window else {
                // 仍然把状态清干净
                self.isShowing = false
                return
            }

            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                w.animator().alphaValue = 0.0
            }, completionHandler: {
                w.orderOut(nil)
                // 清理
                self.window = nil
                self.isShowing = false
            })
        }
    }
}

