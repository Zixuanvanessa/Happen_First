//
//  AppState.swift
//  Happen_First
//
//  Created by Vanessaw on 30/1/2026.
//

import Foundation //基础库
import Combine //用于 ObservableObject / Published

final class AppState: ObservableObject { //定义可被 SwiftUI 观察的共享状态类
    // 1. 是否处于 active (Start) 状态
    @Published var isActive: Bool = false //发布 Start/Stop 状态变化，UI 会响应
    // 2. VAD（是否检测到语音活动）
    @Published var isSpeaking: Bool = false //发布 VAD 结果：当前是否被判为讲话
    // 3. 其它可扩展字段（例如 lastPosition、lastSize）
    @Published var floatingWindowFrame: CGRect? = nil //可选：记录悬浮窗口位置/大小以便恢复
}
