//
//  AKBandRejectButterworthFilter.swift
//  AudioKit
//
//  Autogenerated by scripts by Aurelius Prochazka. Do not edit directly.
//  Copyright (c) 2015 Aurelius Prochazka. All rights reserved.
//

import AVFoundation

/** These filters are Butterworth second-order IIR filters. They offer an almost
 flat passband and very good precision and stopband attenuation. */
public struct AKBandRejectButterworthFilter: AKNode {

    // MARK: - Properties
    public var avAudioNode: AVAudioNode
    private var internalAU: AKBandRejectButterworthFilterAudioUnit?
    private var token: AUParameterObserverToken?

    private var centerFrequencyParameter: AUParameter?
    private var bandwidthParameter: AUParameter?

    /** Center frequency. (in Hertz) */
    public var centerFrequency: Double = 3000 {
        didSet {
            centerFrequencyParameter?.setValue(Float(centerFrequency), originator: token!)
        }
    }
    /** Bandwidth. (in Hertz) */
    public var bandwidth: Double = 2000 {
        didSet {
            bandwidthParameter?.setValue(Float(bandwidth), originator: token!)
        }
    }

    // MARK: - Initializers

    /** Initialize this filter node */
    public init(
        _ input: AKNode,
        centerFrequency: Double = 3000,
        bandwidth: Double = 2000) {

        self.centerFrequency = centerFrequency
        self.bandwidth = bandwidth

        var description = AudioComponentDescription()
        description.componentType         = kAudioUnitType_Effect
        description.componentSubType      = 0x62746272 /*'btbr'*/
        description.componentManufacturer = 0x41754b74 /*'AuKt'*/
        description.componentFlags        = 0
        description.componentFlagsMask    = 0

        AUAudioUnit.registerSubclass(
            AKBandRejectButterworthFilterAudioUnit.self,
            asComponentDescription: description,
            name: "Local AKBandRejectButterworthFilter",
            version: UInt32.max)

        self.avAudioNode = AVAudioNode()
        AVAudioUnit.instantiateWithComponentDescription(description, options: []) {
            avAudioUnit, error in

            guard let avAudioUnitEffect = avAudioUnit else { return }

            self.avAudioNode = avAudioUnitEffect
            self.internalAU = avAudioUnitEffect.AUAudioUnit as? AKBandRejectButterworthFilterAudioUnit

            AKManager.sharedInstance.engine.attachNode(self.avAudioNode)
            AKManager.sharedInstance.engine.connect(input.avAudioNode, to: self.avAudioNode, format: AKManager.format)
        }

        guard let tree = internalAU?.parameterTree else { return }

        centerFrequencyParameter = tree.valueForKey("centerFrequency") as? AUParameter
        bandwidthParameter       = tree.valueForKey("bandwidth")       as? AUParameter

        token = tree.tokenByAddingParameterObserver {
            address, value in

            dispatch_async(dispatch_get_main_queue()) {
                if address == self.centerFrequencyParameter!.address {
                    self.centerFrequency = Double(value)
                } else if address == self.bandwidthParameter!.address {
                    self.bandwidth = Double(value)
                }
            }
        }
        centerFrequencyParameter?.setValue(Float(centerFrequency), originator: token!)
        bandwidthParameter?.setValue(Float(bandwidth), originator: token!)
    }
}
