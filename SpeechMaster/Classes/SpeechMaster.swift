//
//  SpeechMaster.swift
//  SpeechKit Example
//

import Foundation
import UIKit
import Speech

// MARK: - SpeechMasterDelegate

@available(iOS 10, *)
@objc public protocol SpeechMasterDelegate: class {
    func speechResult(withText text: String?, isFinal: Bool)
    func speechWasCancelled()
    func speechDidFail(withError error: Error)
    @objc optional func speech(didFinishSpeaking text: String)
}

// MARK: - SpeechMaster

@available(iOS 10, *)
public class SpeechMaster: NSObject {
    
    // -------------------------
    // MARK: - Public Properties
    // -------------------------
    
    public static let shared = SpeechMaster()
    
    public var microphoneSoundStart: URL?
    public var microphoneSoundStop: URL?
    public var microphoneSoundCancel: URL?
    public var microphoneSoundError: URL?
    public var locale: Locale = Locale.current {
        didSet {
            speechRecognizer = SFSpeechRecognizer(locale: locale)
        }
    }
    
    public weak var delegate: SpeechMasterDelegate?
    
    // -------------------------
    // MARK: - Private Properties
    // -------------------------
    
    // Speech Recognition
    private lazy var speechRecognizer: SFSpeechRecognizer? = {
        return SFSpeechRecognizer(locale: locale)
    }()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Text To Speech (TTS)
    private lazy var speechSynthesizer: AVSpeechSynthesizer? = {
        let speechSynthesizer = AVSpeechSynthesizer()
        return speechSynthesizer
    }()
    
    // AVFoundation
    private var audioEngine: AVAudioEngine?
    
    // Idle Timer
    private let defaultTimeoutSeconds: TimeInterval = 1.5
    private var idleTimer: Timer?
    
    // Flag 🚩
    private var 🗣: Bool = false
    private var shouldRestartRecongnition: Bool = false
    
    // Players
    private lazy var startPlayer: AVAudioPlayer? = {
        guard let microphoneSoundStart = microphoneSoundStart else {
            return nil
        }
        return try? AVAudioPlayer(contentsOf: microphoneSoundStart)
    }()
    
    private lazy var stopPlayer: AVAudioPlayer? = {
        guard let microphoneSoundStop = microphoneSoundStop else {
            return nil
        }
        return try? AVAudioPlayer(contentsOf: microphoneSoundStop)
    }()
    
    private lazy var cancelPlayer: AVAudioPlayer? = {
        guard let microphoneSoundCancel = microphoneSoundCancel else {
            return nil
        }
        return try? AVAudioPlayer(contentsOf: microphoneSoundCancel)
    }()
    
    private lazy var errorPlayer: AVAudioPlayer? = {
        guard let microphoneSoundError = microphoneSoundError else {
            return nil
        }
        return try? AVAudioPlayer(contentsOf: microphoneSoundError)
    }()
    
    // MARK: - Initializer
    
    private override init() { }
    
    // MARK: - AVAudioSession
    
    public func setAudioSession(active: Bool) {
        if !active {
            DispatchQueue.main.async {
                self._setAudioSession(active: false)
            }
        }
        _setAudioSession(active: active)
    }
    
    private func _setAudioSession(active: Bool) {
        do {
            
            if shouldRestartSpeechRecognition() {
                return
            }
            
            let audioSession = AVAudioSession.sharedInstance()
            
            let avopts:AVAudioSessionCategoryOptions = [
                .defaultToSpeaker
            ]
            
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: avopts)
            try audioSession.setMode(AVAudioSessionModeDefault)
            try audioSession.setActive(active, with: .notifyOthersOnDeactivation)
        } catch {
            print("IGNORE!! - error while setting audioSession status")
        }
    }
    
    // MARK: - Recognition
    
    public func startRecognition() {
        
        guard !(audioEngine?.isRunning ?? false) else {
            print("SpeechMaster is already running")
            return
        }
        
        self.destroyIdleTimer()
        _stopAllAudio()
        if shouldRestartSpeechRecognition() {
            return
        }
        
        audioEngine = AVAudioEngine()

        self.setAudioSession(active: true)

        guard let speechRecognizer = speechRecognizer else {
            play(errorPlayer)
            self.delegate?.speechDidFail(withError: SpeechMasterError.localeNotSupported)
            return
        }
        
        guard speechRecognizer.isAvailable else {
            play(errorPlayer)
            self.delegate?.speechDidFail(withError: SpeechMasterError.notAvailable)
            return
        }
       
        request = SFSpeechAudioBufferRecognitionRequest()
        
        recognitionTask = speechRecognizer.recognitionTask(
            with: request!,
            delegate: self
        )
        
        startAudioEngine()
    }
    
    public func stopRecognition() {
        self.destroyIdleTimer()
        play(stopPlayer)
        request?.endAudio()
        recognitionTask?.finish()
        stopAudioEngine()
    }
    
    public func cancelRecognition() {
        self.destroyIdleTimer()
        play(cancelPlayer)
        request?.endAudio()
        recognitionTask?.cancel()
        stopAudioEngine()
    }
    
    private func shouldRestartSpeechRecognition() -> Bool {
        shouldRestartRecongnition = speechSynthesizer?.isSpeaking ?? false
        if shouldRestartRecongnition {
            initializeIdleTimer()
            return true
        }
        return false
    }
    
    // MARK: - Text to Speech
    
    public func speak(_ text: String?, after: Double = 0) {
        guard let text = text, !text.isEmpty else {
            return
        }
        
        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: locale.languageCode)
        speechSynthesizer?.delegate = self
        self.speechSynthesizer?.speak(speechUtterance)
    }
    
    public func stopSpeaking(at boundary: AVSpeechBoundary) {
        speechSynthesizer?.stopSpeaking(at: boundary)
    }
    
    // MARK: - AVAudioEngine
    
    private func startAudioEngine() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        let recordingFormat = audioEngine?.inputNode.outputFormat(forBus: 0)
        audioEngine?.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            // It's invoked on any thread (also in the main thread).
            self.request?.append(buffer)
        }
        
        audioEngine?.prepare()
        do {
            try audioEngine?.start()
            play(startPlayer)
            startPlayer?.delegate = self
        } catch (let error) {
            print("Errors on AVAudioEngine start - \(error.localizedDescription)")
        }
    }
    
    private func stopAudioEngine() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        guard audioEngine?.isRunning ?? false else { return }
        self.audioEngine?.stop()
        self.audioEngine?.reset()
    }
    
    // MARK: - AVAudioPlayer
    
    private func play(_ player: AVAudioPlayer?) {
        guard audioEngine?.isRunning ?? false else { return }
        player?.currentTime = 0
        player?.play()
    }
    
    private func _stopAllAudio() {
        if let speechSynthesizer = self.speechSynthesizer, speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        if let stopPlayer = self.stopPlayer, stopPlayer.isPlaying {
            stopPlayer.stop()
        }
        if let startPlayer = self.startPlayer, startPlayer.isPlaying {
            startPlayer.stop()
        }
        if let cancelPlayer = self.cancelPlayer, cancelPlayer.isPlaying {
            cancelPlayer.stop()
        }
        if let errorPlayer = self.errorPlayer, errorPlayer.isPlaying {
            errorPlayer.stop()
        }
    }
    
    // MARK: - Timer
    
    private func initializeIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: defaultTimeoutSeconds, repeats: false) { _ in
            self.stopRecognition()
        }
    }
    
    private func destroyIdleTimer() {
        // invalidate timer and remove it
        idleTimer?.invalidate()
        idleTimer = nil
    }
    
}

// MARK: - SFSpeechRecognitionTaskDelegate

@available(iOS 10, *)
extension SpeechMaster: SFSpeechRecognitionTaskDelegate {
    
    // Called when the task first detects speech in the source audio
    public func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
        self.initializeIdleTimer()
        🗣 = true
    }
    
    // Called for all recognitions, including non-final hypothesis
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        self.initializeIdleTimer()
        self.delegate?.speechResult(withText: transcription.formattedString, isFinal: false)
    }
    
    // Called when the task is no longer accepting new audio but may be finishing final processing
    public func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
        
    }
    
    // Called when the task has been cancelled, either by client app, the user, or the system
    public func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        self.destroyIdleTimer()
        self.delegate?.speechWasCancelled()
    }
    
    // Called when recognition of all requested utterances is finished.
    // If successfully is false, the error property of the task will contain error information
    //
    // **ATTENTION**
    // This method is called with successfully false also when the recognition is stopped without speaking.
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        self.destroyIdleTimer()
        guard let error = task.error else { return }
        if !🗣 {
            self.delegate?.speechResult(withText: nil, isFinal: true)
        } else {
            play(errorPlayer)
            self.delegate?.speechDidFail(withError: error)
        }
    }
    
    // Called only for final recognitions of utterances. No more about the utterance will be reported
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        print("Final result")
        self.destroyIdleTimer()
        self.delegate?.speechResult(withText: recognitionResult.bestTranscription.formattedString, isFinal: true)
    }
    
}

// MARK: - AVAudioPlayerDelegate

@available(iOS 10, *)
extension SpeechMaster: AVAudioPlayerDelegate {
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        
        if let startPlayer = startPlayer, startPlayer == player {
            self.initializeIdleTimer()
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

@available(iOS 10, *)
extension SpeechMaster: AVSpeechSynthesizerDelegate {
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        restartSpeechRecognition()
        self.delegate?.speech?(didFinishSpeaking: utterance.speechString)
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        restartSpeechRecognition()
    }
    
    private func restartSpeechRecognition() {
        if shouldRestartRecongnition {
            initializeIdleTimer()
            shouldRestartRecongnition = false
            startRecognition()
        } else {
            self.setAudioSession(active: false)
        }
    }
}
