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
            // compute content rect: use passed frame or center on main screen
            let contentRect: CGRect
            if let frame = frame {
                contentRect = frame
            } else if let screenFrame = NSScreen.main?.visibleFrame {
                let w: CGFloat = 600
                let h: CGFloat = 200
                let x = screenFrame.midX - w/2
                let y = screenFrame.midY - h/2
                contentRect = CGRect(x: x, y: y, width: w, height: h)
            } else {
                contentRect = CGRect(x: 100, y: 100, width: 600, height: 200)
            }
            let style: NSWindow.StyleMask = [.borderless]
            let w = NSWindow(contentRect: contentRect,
                             styleMask: style,
                             backing: .buffered,
                             defer: false)
            // allow semi-transparent content
            w.isOpaque = false
            w.backgroundColor = NSColor.clear
            // vanessaw Feb 1st added (optional but recommanded): do not let AppKit auto-move the window by background
            w.isMovableByWindowBackground = false
            // adjust level if needed; .statusBar usually places above app windows
            w.level = .statusBar
            w.hasShadow = true
            w.ignoresMouseEvents = false
            // allow showing on all spaces including full screen
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            // set contentView and ensure sizing
            w.contentView = view
            view.frame = w.contentView?.bounds ?? contentRect
            view.autoresizingMask = [.width, .height]
            w.alphaValue = 0.0
            self.window = w
            w.makeKeyAndOrderFront(nil)
            // fade in with animation
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                w.animator().alphaValue = 1.0
            } completionHandler: {
                // completion if needed
            }
        }
    }
    /// 隐藏悬浮视图（同样在主线程）
    func hideFloatingView() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let w = self.window else {
                // 清理显示状态
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

