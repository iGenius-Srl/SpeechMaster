//
//  SpeechMaster.swift
//  SpeechKit Example
//

import Foundation
import UIKit
import Speech

// MARK: - SpeechRequestDelegate

@objc public protocol SpeechRequestDelegate: class {
    func speechAuthorized()
    func speechNotAuthorized(_ authStatus: SFSpeechRecognizerAuthorizationStatus)
    @objc optional func speechNotAvailable()
}

extension SpeechRequestDelegate where Self: UIViewController {
    
    public func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            switch authStatus {
                
            case .notDetermined: fallthrough
            case .denied: fallthrough
            case .restricted:
                OperationQueue.main.addOperation { [weak self] in
                    self?.speechNotAuthorized(authStatus)
                }
            case .authorized:
                OperationQueue.main.addOperation { [weak self] in
                    self?.speechAuthorized()
                }
            }
            
        }
    }
}

// MARK: - SpeechResultDelegate

public protocol SpeechResultDelegate: class {
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
    
    public weak var requestDelegate: SpeechRequestDelegate?
    public weak var resultDelegate: SpeechResultDelegate?
    
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
        startPlayer?.delegate = self
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
        try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(active, with: .notifyOthersOnDeactivation)
    }
    
    // MARK: - Methods
    
    public func startRecognition() {
        
        guard let speechRecognizer = speechRecognizer else {
            self.resultDelegate?.speechDidFail(self, withError: SpeechMasterError.localeNotSupported)
            return
        }
        
        guard !audioEngine.isRunning else {
            print("SpeechMaster is already running")
            return
        }
        
        guard speechRecognizer.isAvailable else {
            self.requestDelegate?.speechNotAvailable?()
            return
        }
        
        do {
            try setRecordingAudioSession(active: true)
        } catch (let error) {
            self.resultDelegate?.speechDidFail(self, withError: error)
        }
        
        request = SFSpeechAudioBufferRecognitionRequest()
        
        recognitionTask = speechRecognizer.recognitionTask(
            with: request!,
            delegate: self
        )
        
        startAudioEngine()
        
    }
    
    public func stopRecognition() {
        guard audioEngine.isRunning else { return }
        request?.endAudio()
        play(stopPlayer)
        stopAudioEngine()
        recognitionTask?.finish()
    }
    
    public func cancelRecognition() {
        guard audioEngine.isRunning else { return }
        request?.endAudio()
        play(cancelPlayer)
        stopAudioEngine()
        recognitionTask?.cancel()
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
        }
        catch (let error) {
            print("Errors on AVAudioEngine start - \(error.localizedDescription)")
            
        }
    }
    
    private func stopAudioEngine() {
        self.audioEngine.stop()
        self.audioEngine.reset()
        audioEngine.inputNode.removeTap(onBus: 0)
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
        self.resultDelegate?.speechResult(self, withText: transcription.formattedString, isFinal: false)
    }
    
    // Called when the task is no longer accepting new audio but may be finishing final processing
    public func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
       
    }
    
    // Called when the task has been cancelled, either by client app, the user, or the system
    public func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        print("Task cancelled")
        self.destroyIdleTimer()
        self.resultDelegate?.speechWasCancelled(self)
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
        !🗣 ? self.resultDelegate?.speechResult(self, withText: nil, isFinal: true) : self.resultDelegate?.speechDidFail(self, withError: error)
    }
    
    // Called only for final recognitions of utterances. No more about the utterance will be reported
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        print("Final result")
        self.destroyIdleTimer()
        self.resultDelegate?.speechResult(self, withText: recognitionResult.bestTranscription.formattedString, isFinal: true)
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
