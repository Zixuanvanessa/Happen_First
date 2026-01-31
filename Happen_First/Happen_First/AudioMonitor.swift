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
/// - Uses AVAudioEngine inputNode to read microphone buffers.
/// - Requests microphone permission via AVCaptureDevice.requestAccess(for: .audio).
/// - Computes RMS from PCM buffer and uses exponential smoothing + a small debounce
///   to decide "speaking" (voice activity). Calls back only on state changes.
/// - No AVAudioSession usage (iOS-only) — suitable for macOS App.
final class AudioMonitor {
    static let shared = AudioMonitor()
    
    // MARK: - Public API
    /// Callback will be invoked on the main queue with the current "isSpeaking" boolean.
    private var callback: ((Bool) -> Void)?
    
    // Start/stop monitoring
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
    
    // RMS / smoothing parameters (tune in real env)
    private let levelThreshold: Float = 0.01    // RMS threshold for voice (example — tune per environment)
    private let smoothing: Float = 0.2          // exponential smoothing factor [0..1]
    private var smoothedLevel: Float = 0.0
    
    // Debounce: require detected speaking state to be stable for this many seconds before flipping
    private let speakDebounceSeconds: TimeInterval = 0.15
    private let silenceDebounceSeconds: TimeInterval = 0.15
    private var speakDebounceWorkItem: DispatchWorkItem?
    private var silenceDebounceWorkItem: DispatchWorkItem?
    
    // Private initializer (singleton)
    private init() {}
    
    // Internal start (must be called on main queue)
    private func _startMonitoring(_ onVoiceActivity: @escaping (Bool) -> Void) {
        guard !isMonitoring else {
            // already monitoring; update callback reference
            self.callback = onVoiceActivity
            return
        }
        self.callback = onVoiceActivity
        
        // 1) Check mic authorization status for .audio (AVCaptureDevice)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            // already authorized → set up engine
            prepareAndStartEngine()
        case .notDetermined:
            // ask permission then start if granted
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.prepareAndStartEngine()
                    } else {
                        // permission denied -> publish false
                        self.publishSpeaking(false)
                    }
                }
            }
        default:
            // .denied or .restricted
            // publish false so UI can handle "no permission" state
            publishSpeaking(false)
        }
    }
    
    // Internal stop (must be called on main queue)
    private func _stopMonitoring() {
        guard isMonitoring else { return }
        // remove tap and stop engine
        engine.inputNode.removeTap(onBus: 0)

        engine.stop()
        isMonitoring = false
        // cancel pending debounce work
        speakDebounceWorkItem?.cancel()
        silenceDebounceWorkItem?.cancel()
        speakDebounceWorkItem = nil
        silenceDebounceWorkItem = nil
        // Notify UI that speaking is false
        publishSpeaking(false)
    }
    
    // Setup AVAudioEngine taps and start
    private func prepareAndStartEngine() {
        let inputNode = engine.inputNode   // ✅ macOS 正确写法

        if engine.isRunning {
            isMonitoring = true
            return
        }

        let inputFormat = inputNode.outputFormat(forBus: 0)
        let bufferSize: AVAudioFrameCount = 1024

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(
            onBus: 0,
            bufferSize: bufferSize,
            format: inputFormat
        ) { [weak self] buffer, _ in
            guard let self = self else { return }
            let rmsValue = self.rms(from: buffer)
            self.smoothedLevel =
                self.smoothing * rmsValue +
                (1 - self.smoothing) * self.smoothedLevel
            let rawSpeaking = self.smoothedLevel > self.levelThreshold
            self.handleDebouncedSpeaking(rawSpeaking)
        }

        do {
            try engine.start()
            isMonitoring = true
        } catch {
            print("AudioMonitor: AVAudioEngine start error: \(error)")
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
    
    // Debounce logic: require stable state for a short interval before publishing
    private func handleDebouncedSpeaking(_ rawSpeaking: Bool) {
        if rawSpeaking {
            // cancel silence debounce
            silenceDebounceWorkItem?.cancel()
            silenceDebounceWorkItem = nil
            // if already published speaking == true, nothing to do
            if lastPublishedSpeaking { return }
            // schedule speak debounce
            speakDebounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.publishSpeaking(true)
            }
            speakDebounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + speakDebounceSeconds, execute: work)
        } else {
            // cancel speak debounce
            speakDebounceWorkItem?.cancel()
            speakDebounceWorkItem = nil
            if !lastPublishedSpeaking { return }
            // schedule silence debounce -> set speaking = false after short quiet
            silenceDebounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.publishSpeaking(false)
            }
            silenceDebounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + silenceDebounceSeconds, execute: work)
        }
    }
    
    // Publish callback only when state changes
    private func publishSpeaking(_ speaking: Bool) {
        if speaking == lastPublishedSpeaking { return }
        lastPublishedSpeaking = speaking
        // call callback on main queue
        DispatchQueue.main.async {
            self.callback?(speaking)
        }
    }
}

