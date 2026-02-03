//
//  FloatingView.swift
//  Happen_First
//
//  Created by Vanessaw on 30/1/2026.
//

import SwiftUI
struct FloatingView: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        ZStack {
            // 半透明黑色背景
            Color.black.opacity(0.5)
                .cornerRadius(12)
            VStack(alignment: .leading, spacing: 8) {
                // 这里仅为占位文本，未来会显示逐字转写与 AI 回复
                // 如果 endParagraph 为 true，显示段落结束（占位）
                 if appState.endParagraph {
                     Text("— 段落结束（占位） —")
                         .font(.callout)
                         .foregroundColor(Color.white.opacity(0.7))
                         .padding(.horizontal)
                         .padding(.top, 8)
                 } else {
                     // 显示正在转写 / 等待提示（占位）
                     Text(appState.isSpeaking ? "Transcribing…" : "Awaiting speech...")
                         .foregroundColor(Color.white.opacity(0.9))
                         .padding(.horizontal)
                         .padding(.top, 8)
                 }
                 Spacer()
            }
        }
        .frame(minWidth: 300, minHeight: 120)
        .padding()
    }
}
