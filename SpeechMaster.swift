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
    func speechResult(withText text: String?, isFinal: Bool)
    func speechWasCancelled()
    func speechDidFail()
}

// MARK: - Speech

public class SpeechMaster: NSObject {
    
    public static var sharedInstance = SpeechMaster()
    internal override init() { }
    
    public var microphoneSoundOn: URL?
    public var microphoneSoundOff: URL?
    public var microphoneSoundCancel: URL?
    public var locale: Locale = Locale.current // CHECK SPEECH LOCALE AVAILABLE
    public var idleTimeout: TimeInterval = 1 // OPTIONAL
    
    public weak var requestDelegate: SpeechRequestDelegate?
    public weak var resultDelegate: SpeechResultDelegate?
    
    // Speech
    lazy private var speechRecognizer: SFSpeechRecognizer = {
        return SFSpeechRecognizer() ?? SFSpeechRecognizer(locale: locale)!
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
    var startPlayer: AVAudioPlayerNode!
    var stopPlayer: AVAudioPlayerNode!
    
    lazy var startAudioFile: AVAudioFile? = {
        guard microphoneSoundOn != nil else {
            return nil
        }
        return try? AVAudioFile(forReading: microphoneSoundOn!)
    }()
    
    lazy var stopAudioFile: AVAudioFile? = {
        guard microphoneSoundOff != nil else {
            return nil
        }
        return try! AVAudioFile(forReading: microphoneSoundOff!)
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
        
        guard speechRecognizer.isAvailable else {
            self.requestDelegate?.speechNotAvailable?()
            return
        }
        
        do {
            try setRecordingAudioSession(active: true)
        } catch {
            self.resultDelegate?.speechDidFail()
        }
        
        request = SFSpeechAudioBufferRecognitionRequest()
        
        recognitionTask = speechRecognizer.recognitionTask(
            with: request!,
            delegate: self
        )
        
        startAudioEngine()
        
    }
    
    public func stopRecognition() {
        stopAudioEngine()
        request?.endAudio()
        recognitionTask?.finish()
    }
    
    public func cancelRecognition() {
        stopAudioEngine()
        request?.endAudio()
        recognitionTask?.cancel()
    }
    
    // MARK: - AVAudioEngine
    
    private func startAudioEngine() {
        
        setupAudioPlayerNode()
        
        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            // It's invoked on any thread (also in the main thread).
            self.request?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            if startAudioFile != nil {
                startPlayer?.scheduleFile(startAudioFile!, at: nil)
            }
            try audioEngine.start()
            startPlayer?.play()
            
            self.initializeIdleTimer()
        }
        catch (let error) {
            print("Errors on AVAudioEngine start - \(error.localizedDescription)")
            
        }
    }
    
    private func stopAudioEngine() {
        stopPlayer?.scheduleFile(stopAudioFile!, at: nil) {
            self.startPlayer = nil
            self.stopPlayer = nil
            self.audioEngine.stop()
            self.audioEngine.reset()
        }
        stopPlayer?.play()
        
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    // MARK: - AVAudioPlayerNode
    
    private func setupAudioPlayerNode() {
       
        if microphoneSoundOn != nil {
            startPlayer = AVAudioPlayerNode()
            self.connect(playerNode: startPlayer, for: microphoneSoundOn!, format: startAudioFile!.processingFormat)
        }
        
        if microphoneSoundOff != nil {
            stopPlayer = AVAudioPlayerNode()
            self.connect(playerNode: stopPlayer, for: microphoneSoundOff!, format: stopAudioFile!.processingFormat)
        }
    }
    
    private func connect(playerNode node: AVAudioPlayerNode, for url: URL, format: AVAudioFormat) {
        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
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
        🗣 = true
    }
    
    // Called for all recognitions, including non-final hypothesis
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        self.initializeIdleTimer()
        self.resultDelegate?.speechResult(withText: transcription.formattedString, isFinal: false)
    }
    
    // Called when the task is no longer accepting new audio but may be finishing final processing
    public func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
       // Maybe play stop audio sound
    }
    
    // Called when the task has been cancelled, either by client app, the user, or the system
    public func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        print("Task cancelled")
        self.destroyIdleTimer()
        self.resultDelegate?.speechWasCancelled()
    }
    
    // Called when recognition of all requested utterances is finished.
    // If successfully is false, the error property of the task will contain error information
    //
    // **ATTENTION**
    // This method is called with successfully false also when the recognition is stopped without speaking.
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        print("Task finisched")
        print("successfully: \(successfully)")
        
        guard task.error != nil else { return }
        
        self.destroyIdleTimer()
        !🗣 ? self.resultDelegate?.speechResult(withText: nil, isFinal: true) : self.resultDelegate?.speechDidFail()
    }
    
    // Called only for final recognitions of utterances. No more about the utterance will be reported
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        print("Final result")
        self.destroyIdleTimer()
        self.resultDelegate?.speechResult(withText: recognitionResult.bestTranscription.formattedString, isFinal: true)
    }
    
}
