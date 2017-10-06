//
//  ViewController.swift
//  SpeechMaster
//

import UIKit
import SpeechMaster
import Speech

class ViewController: UIViewController {
    
    @IBOutlet weak var textLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func startAction(_ sender: Any) {
       requestSpeechAuthorization()
    }
    
    @IBAction func stopAction(_ sender: Any) {
        SpeechMaster.sharedInstance.stopRecognition()
        
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        SpeechMaster.sharedInstance.cancelRecognition()
    }
}

extension ViewController: SpeechRequestDelegate {
    
    func speechAuthorized() {
      SpeechMaster.sharedInstance.resultDelegate = self
      SpeechMaster.sharedInstance.requestDelegate = self
      SpeechMaster.sharedInstance.microphoneSoundOn = Bundle.main.url(forResource: "start", withExtension: "wav")
      SpeechMaster.sharedInstance.microphoneSoundOff = Bundle.main.url(forResource: "end", withExtension: "wav")
      SpeechMaster.sharedInstance.microphoneSoundCancel = Bundle.main.url(forResource: "error", withExtension: "wav")
      SpeechMaster.sharedInstance.startRecognition()
    }
    
    func speechNotAuthorized(_ authStatus: SFSpeechRecognizerAuthorizationStatus) {
      print("not authorized")
    }
    
}

extension ViewController: SpeechResultDelegate {
    
    func speechResult(withText text: String?, isFinal: Bool) {
        textLabel.text = text
    }
    
    func speechWasCancelled() {
        
    }
    
    func speechDidFail() {
        
    }
}
