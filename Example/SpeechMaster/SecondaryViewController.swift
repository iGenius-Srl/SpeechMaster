//
//  SecondaryViewController.swift
//  SpeechMaster_Example
//
//  Created by Kristiyan Petrov on 10/10/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import UIKit
import Pulsator
import SpeechMaster
import Speech

class SecondaryViewController: UIViewController {
    
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var micButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    public var delegate: SpeechMasterDelegate? = nil
    
    lazy var pulsator: Pulsator = {
        let pulsator = Pulsator()
        pulsator.backgroundColor = UIColor.red.cgColor
        pulsator.animationDuration = 1.5
        pulsator.radius = 100
        pulsator.numPulse = 3
        return pulsator
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        micButton.layer.superlayer?.insertSublayer(pulsator, below: micButton.layer)
        
        SpeechMaster.shared.microphoneSoundStart = Bundle.main.url(forResource: "start", withExtension: "wav")
        SpeechMaster.shared.microphoneSoundStop = Bundle.main.url(forResource: "end", withExtension: "wav")
        SpeechMaster.shared.microphoneSoundCancel = Bundle.main.url(forResource: "error", withExtension: "wav")
        SpeechMaster.shared.microphoneSoundError = Bundle.main.url(forResource: "error", withExtension: "wav")
        SpeechMaster.shared.delegate = self
        SpeechMaster.shared.startRecognition()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        pulsator.start()
        pulsator.position = micButton.layer.position
        micButton.layoutIfNeeded()
        micButton.setNeedsLayout()
    }
    
    @IBAction func tapOnMic(_ sender: Any) {
        print("tap on Stop")
        SpeechMaster.shared.stopRecognition()
    }
    
    @IBAction func tapOnCancel(_ sender: Any) {
        SpeechMaster.shared.cancelRecognition()
    }
    
}

extension SecondaryViewController: SpeechMasterDelegate {
    
    func speechResult(withText text: String?, isFinal: Bool) {
        textLabel.text = text
        if isFinal {
            print("FINALLY !!! \(String(describing: text))")
            dismiss(animated: true, completion: {
                self.delegate?.speechResult(withText: text, isFinal: true)
            })
        }
    }
    
    func speechWasCancelled() {
        print("Speech was cancelled")
        dismiss(animated: true){
             self.delegate?.speechWasCancelled()
        }
    }
    
    func speechDidFail(withError error: Error) {
        print("Speech did fail")
        dismiss(animated: true){
             self.delegate?.speechDidFail(withError: error)
        }
    }
    
}
