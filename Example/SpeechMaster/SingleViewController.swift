//
//  SingleViewController.swift
//  SpeechMaster_Example
//

import UIKit
import SpeechMaster
import Speech

class SingleViewController: UIViewController {

    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var startButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        SpeechMaster.shared.microphoneSoundStart = Bundle.main.url(forResource: "start", withExtension: "wav")
        SpeechMaster.shared.microphoneSoundStop = Bundle.main.url(forResource: "end", withExtension: "wav")
        SpeechMaster.shared.microphoneSoundCancel = Bundle.main.url(forResource: "error", withExtension: "wav")
        SpeechMaster.shared.microphoneSoundError = Bundle.main.url(forResource: "error", withExtension: "wav")
        SpeechMaster.shared.delegate = self
        enableStartButton(true)
    }

    @IBAction func tapOnCancel(_ sender: Any) {
        SpeechMaster.shared.cancelRecognition()
        enableStartButton(true)
    }
    
    @IBAction func tapOnStop(_ sender: Any) {
        SpeechMaster.shared.stopRecognition()
        enableStartButton(true)
    }
    
    @IBAction func tapOnStart(_ sender: Any) {
         requestSpeechAuthorization()
    }
    
    // MARK: - Request Speech Authorization
    
    func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation { [weak self] in
                switch authStatus {
                    
                case .notDetermined: fallthrough
                case .denied: fallthrough
                case .restricted:
                    self?.startButton.isUserInteractionEnabled = true
                    print("Speech Recognition not Authorized. Please check on Settings")
                case .authorized:
                    self?.enableStartButton(false)
                    SpeechMaster.shared.startRecognition()
                }
            }
        }
    }
    
    func enableStartButton(_ enable: Bool) {
        startButton.isUserInteractionEnabled = enable
        stopButton.isUserInteractionEnabled = !enable
        cancelButton.isUserInteractionEnabled = !enable
        
        startButton.alpha = enable ? 1.0 : 0.4
        stopButton.alpha = !enable ? 1.0 : 0.4
        cancelButton.alpha = !enable ? 1.0 : 0.4
    }

}

extension SingleViewController: SpeechMasterDelegate {
    
    func speechResult(withText text: String?, isFinal: Bool) {
        textLabel.text = text
        if isFinal {
            if let speechText = text {
                SpeechMaster.shared.speak(speechText, after: 1)
                enableStartButton(true)
            }
        }
    }
    
    func speechWasCancelled() {
        print("Speech was cancelled")
         enableStartButton(true)
    }
    
    func speechDidFail(withError error: Error) {
        print("Speech did fail")
        enableStartButton(true)
    }
    
}
