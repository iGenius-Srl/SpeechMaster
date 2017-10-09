//
//  ViewController.swift
//  SpeechMaster
//

import UIKit
import SpeechMaster
import Speech

class ViewController: UIViewController {
    
    @IBOutlet weak var textLabel: UILabel!
    
    lazy var speechMaster: SpeechMaster = {
        let speechMaster = SpeechMaster()
        speechMaster.resultDelegate = self
        speechMaster.requestDelegate = self
        speechMaster.microphoneSoundStart = Bundle.main.url(forResource: "start", withExtension: "wav")
        speechMaster.microphoneSoundStop = Bundle.main.url(forResource: "end", withExtension: "wav")
        speechMaster.microphoneSoundCancel = Bundle.main.url(forResource: "error", withExtension: "wav")
        return speechMaster
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func startAction(_ sender: Any) {
       requestSpeechAuthorization()
    }
    
    @IBAction func stopAction(_ sender: Any) {
        speechMaster.stopRecognition()
        
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        speechMaster.cancelRecognition()
    }
}

extension ViewController: SpeechRequestDelegate {
    
    func speechAuthorized() {
      speechMaster.startRecognition()
    }
    
    func speechNotAvailable() {
        print("Speech not available")
    }
    
    func speechNotAuthorized(_ authStatus: SFSpeechRecognizerAuthorizationStatus) {
      print("not authorized")
    }
    
}

extension ViewController: SpeechResultDelegate {
    
    func speechResult(_ speechMaster: SpeechMaster, withText text: String?, isFinal: Bool) {
        textLabel.text = text
    }
    
    func speechWasCancelled(_ speechMaster: SpeechMaster) {
        print("Speech was cancelled")
    }
    
    func speechDidFail(_ speechMaster: SpeechMaster, withError error: Error) {
        print("Speech did fail")
    }
    
}
