//
//  AudioMonitor.swift
//  Happen_First
//
//  Created by Vanessaw on 30/1/2026.
//

import Foundation
import AVFoundation
import Cocoa
/// AudioMonitor for macOS
/// - Uses AVAudioEngine inputNode to compute RMS and detect voice activity.
/// - Debounce logic: schedule speak debounce only once on transition to `rawSpeaking == true`,
///   and schedule silence debounce only once on transition to `rawSpeaking == false`.
final class AudioMonitor {
    static let shared = AudioMonitor()
    // MARK: - Public API
    /// Callback invoked on main queue with current speaking boolean.
    private var callback: ((Bool) -> Void)?
    func startMonitoring(_ onVoiceActivity: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            self._startMonitoring(onVoiceActivity)
        }
    }
    func stopMonitoring() {
        DispatchQueue.main.async {
            self._stopMonitoring()
        }
    }
    // MARK: - Private
    private let engine = AVAudioEngine()
    private var isMonitoring = false
    private var lastPublishedSpeaking: Bool = false
    // Tunable parameters
    private var levelThreshold: Float = 0.005    // RMS threshold (adjust for environment)
    private var smoothing: Float = 0.18          // exponential smoothing [0..1]
    private var smoothedLevel: Float = 0.0
    // Debounce intervals
    private var speakDebounceSeconds: TimeInterval = 0.25
    private var silenceDebounceSeconds: TimeInterval = 0.20
    private var speakDebounceWorkItem: DispatchWorkItem?
    private var silenceDebounceWorkItem: DispatchWorkItem?
    private init() {}
    // MARK: - start/stop internals (main thread)
    private func _startMonitoring(_ onVoiceActivity: @escaping (Bool) -> Void) {
        guard !isMonitoring else {
            // already monitoring: update callback only
            self.callback = onVoiceActivity
            return
        }
        self.callback = onVoiceActivity
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            prepareAndStartEngine()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.prepareAndStartEngine()
                    } else {
                        self.publishSpeaking(false)
                    }
                }
            }
        default:
            // denied or restricted
            publishSpeaking(false)
        }
    }
    private func _stopMonitoring() {
        guard isMonitoring else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isMonitoring = false
        speakDebounceWorkItem?.cancel()
        silenceDebounceWorkItem?.cancel()
        speakDebounceWorkItem = nil
        silenceDebounceWorkItem = nil
        publishSpeaking(false)
    }
    // MARK: - engine setup
    private func prepareAndStartEngine() {
        let inputNode = engine.inputNode
        if engine.isRunning {
            isMonitoring = true
            return
        }
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let bufferSize: AVAudioFrameCount = 1024
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            let rmsValue = self.rms(from: buffer)
            self.smoothedLevel = self.smoothing * rmsValue + (1.0 - self.smoothing) * self.smoothedLevel
            let rawSpeaking = self.smoothedLevel > self.levelThreshold
            self.handleDebouncedSpeaking(rawSpeaking)
        }
        do {
            try engine.start()
            isMonitoring = true
        } catch {
            publishSpeaking(false)
        }
    }
    // Compute RMS for first channel
    private func rms(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        if frameLength == 0 { return 0 }
        var sum: Float = 0
        for i in 0..<frameLength {
            let s = channelData[i]
            sum += s * s
        }
        let mean = sum / Float(frameLength)
        return sqrt(mean)
    }
    // MARK: - Debounce logic
    private func handleDebouncedSpeaking(_ rawSpeaking: Bool) {
        if rawSpeaking {
            // cancel pending silence debounce
            silenceDebounceWorkItem?.cancel()
            silenceDebounceWorkItem = nil
            // if already published true, nothing to do
            if lastPublishedSpeaking { return }
            // only schedule speak debounce if not already scheduled
            if speakDebounceWorkItem == nil {
                let work = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    self.publishSpeaking(true)
                    self.speakDebounceWorkItem = nil
                }
                speakDebounceWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + speakDebounceSeconds, execute: work)
            }
        } else {
            // cancel pending speak debounce
            speakDebounceWorkItem?.cancel()
            speakDebounceWorkItem = nil
            // if already published false, nothing to do
            if !lastPublishedSpeaking { return }
            // only schedule silence debounce if not already scheduled
            if silenceDebounceWorkItem == nil {
                let work = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    self.publishSpeaking(false)
                    self.silenceDebounceWorkItem = nil
                }
                silenceDebounceWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + silenceDebounceSeconds, execute: work)
            }
        }
    }
    // Publish changes only when state flips
    private func publishSpeaking(_ speaking: Bool) {
        if speaking == lastPublishedSpeaking { return }
        lastPublishedSpeaking = speaking
        DispatchQueue.main.async {
            self.callback?(speaking)
        }
    }
}
