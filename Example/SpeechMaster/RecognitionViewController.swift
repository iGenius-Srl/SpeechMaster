//
//  SecondaryViewController.swift
//  SpeechMaster_Example
//

import Foundation
import UIKit
import SpeechMaster
import Speech

class RecognitionViewController: UIViewController {
    
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var micButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    public weak var delegate: SpeechMasterDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        SpeechMaster.shared.microphoneSoundStart = Bundle.main.url(forResource: "start", withExtension: "wav")
        SpeechMaster.shared.microphoneSoundStop = Bundle.main.url(forResource: "end", withExtension: "wav")
        SpeechMaster.shared.microphoneSoundCancel = Bundle.main.url(forResource: "error", withExtension: "wav")
        SpeechMaster.shared.microphoneSoundError = Bundle.main.url(forResource: "error", withExtension: "wav")
        
        SpeechMaster.shared.delegate = self
        SpeechMaster.shared.startRecognition()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    @IBAction func tapOnMic(_ sender: Any) {
        print("tap on Stop")
        SpeechMaster.shared.stopRecognition()
    }
    
    @IBAction func tapOnCancel(_ sender: Any) {
        SpeechMaster.shared.cancelRecognition()
    }
    
}

// MARK: - SpeechMasterDelegate

extension RecognitionViewController: SpeechMasterDelegate {
    
    func speechResult(withText text: String?, isFinal: Bool) {
        textLabel.text = text
        if isFinal {
            print("\(String(describing: text))")
            dismiss(animated: true) {
                self.delegate?.speechResult(withText: text, isFinal: true)
            }
        }
    }
    
    func speechWasCancelled() {
        print("Speech was cancelled")
        dismiss(animated: true) {
             self.delegate?.speechWasCancelled()
        }
    }
    
    func speechDidFail(withError error: Error) {
        print("Speech did fail")
        dismiss(animated: true) {
             self.delegate?.speechDidFail(withError: error)
        }
    }
    
}
