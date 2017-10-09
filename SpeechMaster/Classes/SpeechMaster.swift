//
//  SpeechMaster.swift
//  SpeechKit Example
//

import Foundation
import UIKit
import Speech

// MARK: - SpeechResultDelegate

public protocol SpeechMasterDelegate: class {
    func speechResult(_ speechMaster: SpeechMaster, withText text: String?, isFinal: Bool)
    func speechWasCancelled(_ speechMaster: SpeechMaster)
    func speechDidFail(_ speechMaster: SpeechMaster, withError error: Error)
}

// MARK: - Speech

public class SpeechMaster: NSObject {
    
    public var microphoneSoundStart: URL?
    public var microphoneSoundStop: URL?
    public var microphoneSoundCancel: URL?
    public var locale: Locale = Locale.current // CHECK SPEECH LOCALE AVAILABLE
    public var idleTimeout: TimeInterval = 1.5 // OPTIONAL
    
    public weak var delegate: SpeechMasterDelegate?
    
    // Speech
    lazy private var speechRecognizer: SFSpeechRecognizer? = {
        return SFSpeechRecognizer(locale: locale)
    }()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // AVFoundation
    let audioEngine = AVAudioEngine()
    
    // Idle Timer
    private let defaultTimeoutSeconds: TimeInterval = 1.5
    private var idleTimer: Timer?
    
    // Flag 🚩
    var 🗣: Bool = false
    
    // Player
    lazy var startPlayer: AVAudioPlayer? = {
        guard let microphoneSoundStart = microphoneSoundStart else {
            return nil
        }
        let startPlayer = try? AVAudioPlayer(contentsOf: microphoneSoundStart)
        return startPlayer
    }()
    
    lazy var stopPlayer: AVAudioPlayer? = {
        guard let microphoneSoundStop = microphoneSoundStop else {
            return nil
        }
        return try? AVAudioPlayer(contentsOf: microphoneSoundStop)
    }()
    
    lazy var cancelPlayer: AVAudioPlayer? = {
        guard let microphoneSoundCancel = microphoneSoundCancel else {
            return nil
        }
        return try? AVAudioPlayer(contentsOf: microphoneSoundCancel)
    }()
    
    // MARK: - AVAudioSession
    
    private func setRecordingAudioSession(active: Bool) throws {
        let audioSession = AVAudioSession.sharedInstance()
        let avopts:AVAudioSessionCategoryOptions  = [
            .mixWithOthers,
            .duckOthers,
            .interruptSpokenAudioAndMixWithOthers,
            .defaultToSpeaker
        ]
        
        try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: avopts)
        try audioSession.setMode(AVAudioSessionModeSpokenAudio)
        try audioSession.overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
        try audioSession.setActive(active, with: .notifyOthersOnDeactivation)
    }
    
    // MARK: - Methods
    
    public func startRecognition() {
        
        guard let speechRecognizer = speechRecognizer else {
            self.delegate?.speechDidFail(self, withError: SpeechMasterError.localeNotSupported)
            return
        }
        
        guard !audioEngine.isRunning else {
            print("SpeechMaster is already running")
            return
        }
        
        guard speechRecognizer.isAvailable else {
            self.delegate?.speechDidFail(self, withError: SpeechMasterError.notAvailable)
            return
        }
        
        do {
            try setRecordingAudioSession(active: true)
        } catch (let error) {
            self.delegate?.speechDidFail(self, withError: error)
        }
        
        request = SFSpeechAudioBufferRecognitionRequest()
        
        recognitionTask = speechRecognizer.recognitionTask(
            with: request!,
            delegate: self
        )
        
        startAudioEngine()
        
    }
    
    public func stopRecognition() {
        if audioEngine.isRunning {
            play(stopPlayer)
        }
        request?.endAudio()
        recognitionTask?.finish()
        stopAudioEngine()
    }
    
    public func cancelRecognition() {
        if audioEngine.isRunning {
            play(cancelPlayer)
        }
        request?.endAudio()
        recognitionTask?.cancel()
        stopAudioEngine()
    }
    
    // MARK: - AVAudioEngine
    
    private func startAudioEngine() {
        
        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            // It's invoked on any thread (also in the main thread).
            self.request?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            
            try audioEngine.start()
            play(startPlayer)
            startPlayer?.delegate = self
        }
        catch (let error) {
            print("Errors on AVAudioEngine start - \(error.localizedDescription)")
            
        }
    }
    
    private func stopAudioEngine() {
        audioEngine.inputNode.removeTap(onBus: 0)
        guard audioEngine.isRunning else { return }
        self.audioEngine.stop()
        self.audioEngine.reset()
    }
    
    // MARK: - AVAudioPlayer
    
    private func play(_ player: AVAudioPlayer?) {
        player?.currentTime = 0
        player?.play()
    }
    
    // MARK: - Timer
    
    private func initializeIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: defaultTimeoutSeconds, repeats: false) { _ in
            print("🔔")
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

extension SpeechMaster: SFSpeechRecognitionTaskDelegate {
    
    // Called when the task first detects speech in the source audio
    public func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
        self.initializeIdleTimer()
        🗣 = true
    }
    
    // Called for all recognitions, including non-final hypothesis
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        self.initializeIdleTimer()
        self.delegate?.speechResult(self, withText: transcription.formattedString, isFinal: false)
    }
    
    // Called when the task is no longer accepting new audio but may be finishing final processing
    public func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
       
    }
    
    // Called when the task has been cancelled, either by client app, the user, or the system
    public func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        print("Task cancelled")
        self.destroyIdleTimer()
        self.delegate?.speechWasCancelled(self)
    }
    
    // Called when recognition of all requested utterances is finished.
    // If successfully is false, the error property of the task will contain error information
    //
    // **ATTENTION**
    // This method is called with successfully false also when the recognition is stopped without speaking.
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        print("Task finisched")
        print("successfully: \(successfully)")
        self.destroyIdleTimer()
        guard let error = task.error else { return }
        !🗣 ? self.delegate?.speechResult(self, withText: nil, isFinal: true) : self.delegate?.speechDidFail(self, withError: error)
    }
    
    // Called only for final recognitions of utterances. No more about the utterance will be reported
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        print("Final result")
        self.destroyIdleTimer()
        self.delegate?.speechResult(self, withText: recognitionResult.bestTranscription.formattedString, isFinal: true)
    }
    
}

// MARK: - AVAudioPlayerDelegate

extension SpeechMaster: AVAudioPlayerDelegate {
   
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if let startPlayer = startPlayer, startPlayer == player {
            self.initializeIdleTimer()
        }
    }
}
