//
//  AKReverb.swift
//  AudioKit
//
//  Created by Aurelius Prochazka on 10/4/15.
//  Copyright © 2015 AudioKit. All rights reserved.
//

import Foundation
import AVFoundation

/** AudioKit version of Apple's Reverb Audio Unit */
public struct AKReverb: AKNode {
    private let reverbAU = AVAudioUnitReverb()
    public var avAudioNode: AVAudioNode
    
    /** Dry/Wet Mix (Default 50) */
    public var dryWetMix: Float = 50.0 {
        didSet {
            if dryWetMix < 0 {
                dryWetMix = 0
            }
            if dryWetMix > 100 {
                dryWetMix = 100
            }
            reverbAU.wetDryMix = dryWetMix
        }
    }
    
    /** Initialize the reverb node */
    public init(_ input: AKNode, dryWetMix: Float = 50) {
        self.dryWetMix = dryWetMix
        
        self.avAudioNode = reverbAU
        AKManager.sharedInstance.engine.attachNode(self.avAudioNode)
        AKManager.sharedInstance.engine.connect(input.avAudioNode, to: self.avAudioNode, format: AKManager.format)
        
        reverbAU.wetDryMix = dryWetMix
    }
    
    /** Load an Apple Factory Preset */
    public func loadFactoryPreset(preset: AVAudioUnitReverbPreset) {
        reverbAU.loadFactoryPreset(preset)
    }
}
