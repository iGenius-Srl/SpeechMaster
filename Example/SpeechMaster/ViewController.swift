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
       requestSpeechAuthorization()
    }
    
}

// MARK - SpeechMasterDelegate

extension ViewController: SpeechMasterDelegate {
    
    func speechResult(withText text: String?, isFinal: Bool) {
        if isFinal {
            if let speechText = text {
                textLabel.text = speechText
                SpeechMaster.shared.speak(speechText, after: 1)
            }
        }
    }
    
    func speechWasCancelled() {
        print("Speech was cancelled")
    }
    
    func speechDidFail(withError error: Error) {
        print("Speech did fail")
    }
    
    func speech(didFinishSpeaking text: String) {
        print("Speech did finish speaking")
    }
    
}
