//
//  SpeechMasterError.swift
//  SpeechMaster
//
//  Created by Andrea Antonioni on 06/10/17.
//

import Foundation
@available(iOS 10, *)
enum SpeechMasterError: Error {
    case localeNotSupported
    case notAvailable
}
