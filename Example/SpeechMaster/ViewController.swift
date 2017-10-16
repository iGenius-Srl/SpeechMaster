//
//  ViewController.swift
//  SpeechMaster
//

import UIKit
import SpeechMaster
import Speech

class ViewController: UIViewController {
    
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    
    lazy var speechMaster: SpeechMaster = {
        let speechMaster = SpeechMaster.shared
        speechMaster.microphoneSoundStart = Bundle.main.url(forResource: "start", withExtension: "wav")
        speechMaster.microphoneSoundStop = Bundle.main.url(forResource: "end", withExtension: "wav")
        speechMaster.microphoneSoundCancel = Bundle.main.url(forResource: "error", withExtension: "wav")
        speechMaster.microphoneSoundError = Bundle.main.url(forResource: "error", withExtension: "wav")
        return speechMaster
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
                    let microphoneViewController = Storyboard.Main.instantiate(SecondaryViewController.self) as SecondaryViewController
                    microphoneViewController.delegate = self
                    self?.present(microphoneViewController,animated: true)
                }
            }
        }
    }
    
    // MARK: - tapOnStart
    
    @IBAction func startAction(_ sender: Any) {
       print("tap on Start")
       startButton.isUserInteractionEnabled = false
       requestSpeechAuthorization()
    }
    
}

// MARK - SpeechMasterDelegate

extension ViewController: SpeechMasterDelegate {
    
    func speechResult(_ speechMaster: SpeechMaster, withText text: String?, isFinal: Bool) {
        if isFinal {
            if let speechText = text {
                textLabel.text = speechText
                speechMaster.speak(speechText, after: 1)
            }
            startButton.isUserInteractionEnabled = true
        }
    }
    
    func speechWasCancelled(_ speechMaster: SpeechMaster) {
        print("Speech was cancelled")
        startButton.isUserInteractionEnabled = true
    }
    
    func speechDidFail(_ speechMaster: SpeechMaster, withError error: Error) {
        print("Speech did fail")
        startButton.isUserInteractionEnabled = true
    }
    
    func speech(_ speechMaster: SpeechMaster, didFinishSpeaking text: String) {
        print("Speech did finish speaking")
        startButton.isUserInteractionEnabled = true
    }
    
}
