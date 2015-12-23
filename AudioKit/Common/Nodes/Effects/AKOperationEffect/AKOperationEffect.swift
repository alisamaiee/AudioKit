//
//  AKOperationEffect.swift
//  AudioKit
//
//  Autogenerated by scripts by Aurelius Prochazka. Do not edit directly.
//  Copyright (c) 2015 Aurelius Prochazka. All rights reserved.
//

import AVFoundation

/** This is was built using the JC reverb implentation found in FAUST. According to
 the source code, the specifications for this implementation were found on an old
 SAIL DART backup tape.
 This class is derived from the CLM JCRev function, which is based on the use of
 networks of simple allpass and comb delay filters.  This class implements three
 series allpass units, followed by four parallel comb filters, and two
 decorrelation delay lines in parallel at the output. */
public struct AKOperationEffect: AKNode {

    // MARK: - Properties

    private var internalAU: AKOperationEffectAudioUnit?
    public var avAudioNode: AVAudioNode

    // MARK: - Initializers

    /** Initialize this effect node */
    
    public init(_ input: AKNode, operation: AKOperation) {
        // add "dup" to copy the left channel output to the right channel output
        self.init(input, sporth:"\(operation) dup")
    }
    public init(_ input: AKNode, stereoOperation: AKStereoOperation) {
        self.init(input, sporth:"\(stereoOperation) swap")
    }
    
    public init(_ input: AKNode, left: AKOperation, right: AKOperation) {
        self.init(input, sporth:"\(left) swap \(right) swap")
    }
    
    public init(_ input: AKNode, sporth: String) {

        var description = AudioComponentDescription()
        description.componentType         = kAudioUnitType_Effect
        description.componentSubType      = 0x6373746d /*'cstm'*/
        description.componentManufacturer = 0x41754b74 /*'AuKt'*/
        description.componentFlags        = 0
        description.componentFlagsMask    = 0

        AUAudioUnit.registerSubclass(
            AKOperationEffectAudioUnit.self,
            asComponentDescription: description,
            name: "Local AKOperationEffect",
            version: UInt32.max)

        self.avAudioNode = AVAudioNode()
        AVAudioUnit.instantiateWithComponentDescription(description, options: []) {
            avAudioUnit, error in

            guard let avAudioUnitEffect = avAudioUnit else { return }

            self.avAudioNode = avAudioUnitEffect
            self.internalAU = avAudioUnitEffect.AUAudioUnit as? AKOperationEffectAudioUnit
            AKManager.sharedInstance.engine.attachNode(self.avAudioNode)
            AKManager.sharedInstance.engine.connect(input.avAudioNode, to: self.avAudioNode, format: AKManager.format)
            self.internalAU?.setSporth(sporth)
        }

    }
}
