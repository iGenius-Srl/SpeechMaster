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
    
    lazy var speechMaster: SpeechMaster = {
        let speechMaster = SpeechMaster.shared
        speechMaster.delegate = self
        speechMaster.microphoneSoundStart = Bundle.main.url(forResource: "start", withExtension: "wav")
        speechMaster.microphoneSoundStop = Bundle.main.url(forResource: "end", withExtension: "wav")
        speechMaster.microphoneSoundCancel = Bundle.main.url(forResource: "error", withExtension: "wav")
        speechMaster.microphoneSoundError = Bundle.main.url(forResource: "error", withExtension: "wav")
        return speechMaster
    }()
    
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
        self.speechMaster.startRecognition()
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
        speechMaster.stopRecognition()
    }
    
    @IBAction func tapOnCancel(_ sender: Any) {
        speechMaster.cancelRecognition()
    }
    
}

extension SecondaryViewController: SpeechMasterDelegate {
    
    func speechResult(_ speechMaster: SpeechMaster, withText text: String?, isFinal: Bool) {
        textLabel.text = text
        if isFinal {
            print("FINALLY !!! \(String(describing: text))")
            dismiss(animated: true, completion: {
                self.delegate?.speechResult(speechMaster, withText: text, isFinal: true)
            })
        }
    }
    
    func speechWasCancelled(_ speechMaster: SpeechMaster) {
        print("Speech was cancelled")
        dismiss(animated: true){
             self.delegate?.speechWasCancelled(speechMaster)
        }
    }
    
    func speechDidFail(_ speechMaster: SpeechMaster, withError error: Error) {
        print("Speech did fail")
        dismiss(animated: true){
             self.delegate?.speechDidFail(speechMaster, withError: error)
        }
    }
    
}
