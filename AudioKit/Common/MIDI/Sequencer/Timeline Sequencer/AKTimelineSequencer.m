//
//  AKSamplerSequencer.m
//  SuperSequencer
//
//  Created by Aurelius Prochazka on 8/11/18.
//  Copyright © 2018 AudioKit. All rights reserved.
//

#import "AKTimelineSequencer.h"
#import <AudioKit/AudioKit-Swift.h>
#import "AKTimelineTap.h"
#import <mach/mach_time.h>

#define NOTEON 0x90
#define NOTEOFF 0x80

struct Note {
    double sampleTime;
    uint8_t noteNumber;
    uint8_t velocity;
    double beat;
};

@implementation AKTimelineSequencer {
    AKTimelineTap *tap;
    struct Note _notes[32];
    int _noteCount;
    double _lastTriggerTime;
    double _beatsPerSample;
    double _sampleRate;
    int _beatCount;
    int _playCount;
    int _maximumPlays;
    BOOL _hasSound;
    AudioUnit _audioUnit;
    double _startOffset;
}

@synthesize maximumPlayCount = _maximumPlays;

-(instancetype)init {
    return [self initWithNode:nil];
}

- (instancetype)initWithNode:(AKNode *)node {
    self = [super init];
    if (self) {
        _sampleRate = 44100;
        _audioUnit = [[node avAudioUnit] audioUnit];
        _playCount = 0;
        _maximumPlays = 0;
        _noteCount = 0;

        tap = [[AKTimelineTap alloc]initWithNode:node.avAudioNode timelineBlock:[self timelineBlock]];
        tap.preRender = true;
        _beatCount = 4;
        [self setTempo:120];
    }
    return self;
}

-(AKTimelineBlock)timelineBlock {
    AudioUnit instrument = _audioUnit;
    struct Note *notes = _notes;
    int *playCount = &_playCount;
    int *maximumPlays = &_maximumPlays;
    int *noteCount = &_noteCount;
    double *lastTriggerTime = &_lastTriggerTime;

    return ^(AKTimeline         *timeline,
             AudioTimeStamp     *timeStamp,
             UInt32             offset,
             UInt32             inNumberFrames,
             AudioBufferList    *ioData) {

        if (timeStamp->mSampleTime > *lastTriggerTime) { //Hack
            *playCount += 1;
        }

        if (*maximumPlays != 0 && *playCount >= *maximumPlays) {
            [self stop];
            return;
        }

        Float64 startSample = timeStamp->mSampleTime;
        Float64 endSample = startSample + inNumberFrames;

        for (int i = 0; i < *noteCount; i++) {
            double triggerTime = notes[i].sampleTime;

            if((startSample <= triggerTime && triggerTime < endSample)) {

                MusicDeviceMIDIEvent(instrument,
                                     notes[i].velocity == 0 ? NOTEOFF : NOTEON,
                                     notes[i].noteNumber,
                                     notes[i].velocity,
                                     triggerTime - startSample + offset);
            }
        }
    };
}

-(void)setTempo:(double)bpm andBeats:(int)beats atTime:(AudioTimeStamp)timeStamp{

    //Store the last beatsPerSample before updating, needed to maintain current beat is running.
    double lastBeatsPerSample = _beatsPerSample;

    //Update new tempo, stored as beatsPerSample.
    double beatsPerSecond = bpm / 60.0;
    _beatsPerSample = beatsPerSecond / _sampleRate;
    _beatCount = beats;

    Float64 newLoopEnd = _beatCount / _beatsPerSample;

    // Get the current sampleTime in the timeline.
    Float64 lastSampleTime = AKTimelineTimeAtTime(tap.timeline, timeStamp);

    //Manually roll loop if beat change puts us past loop end.
    if (lastSampleTime > newLoopEnd) {
        lastSampleTime -= newLoopEnd;
    }

    // Calculate the beat of sample time at the last tempo.
    double lastBeat = lastSampleTime * lastBeatsPerSample;

    // Calculate the new sample time for last beat.
    double newSampleTime = lastBeat / _beatsPerSample;

    // This data will be read from the render thread, so there is a posibility of
    // misfires because we are not writing to it on the main thread.
    for (int i = 0; i < _noteCount; i++) {
        _notes[i].sampleTime = (double)_notes[i].beat / _beatsPerSample;
    }

    // If timeline is stopped, no need to synchronize with previous timing.
    if (!AKTimelineIsStarted(tap.timeline)) {
        AKTimelineSetTime(tap.timeline, newSampleTime);
        AKTimelineSetLoop(tap.timeline, 0, newLoopEnd);
        return;
    }

    // Timeline is running so we need to get use the reference time to make
    // sure we pick up where we left off.
    AKTimelineSetState(tap.timeline, newSampleTime, 0, newLoopEnd, timeStamp);
}

-(BOOL)isPlaying {
    return AKTimelineIsStarted(tap.timeline);
}

-(void)setBeatCount:(int)beatCount {
    [self setBeatCount:beatCount atTime:nil];
}

-(int)beatCount {
    return _beatCount;
}

-(void)setTempo:(double)bpm {
    [self setTempo:bpm atTime:nil];
}

-(double)tempo {
    double beatsPerSecond = _beatsPerSample * _sampleRate;
    return beatsPerSecond * 60.0;
}

-(int)addNote:(uint8_t)noteNumber velocity:(uint8_t)velocity at:(double)beat {
    _notes[_noteCount].noteNumber = noteNumber;
    _notes[_noteCount].velocity = velocity;
    _notes[_noteCount].beat = beat;
    _notes[_noteCount].sampleTime = beat / _beatsPerSample;

    _noteCount += 1;

    _lastTriggerTime = 0.0;
    for (int i = 0; i < _noteCount; i++) {
        if (_notes[i].sampleTime > _lastTriggerTime) _lastTriggerTime = _notes[i].sampleTime;
    }
    return _noteCount - 1;
}

-(void)changeNoteAtIndex:(int)index note:(uint8_t)noteNumber velocity:(uint8_t)velocity at:(double)beat {
    _notes[index].noteNumber = noteNumber;
    _notes[index].velocity = velocity;
    _notes[index].beat = beat;
    _notes[index].sampleTime = beat / _beatsPerSample;
}

- (void)clear {
    _noteCount = 0;
    _playCount = 0;
}
-(void)play {
    //_startOffset = something;
    _playCount = 0;
    [self playAt: nil];
}

-(void)playAt:(AVAudioTime *)audioTime {
    _playCount = 0;
    if (audioTime) {
        AKTimelineStartAtTime(tap.timeline, audioTime.audioTimeStamp);
    } else {
        AKTimelineStart(tap.timeline);
    }
}

-(double)beatTime {
    return [self beatTimeAtTime:nil];
}

-(void)setBeatTime:(double)beatTime {
    [self setBeatTime:beatTime atTime:nil];
}

-(void)setBeatTime:(double)beatTime atTime:(AVAudioTime *)audioTime {
    _playCount = 0;

    if (audioTime) {
        AKTimelineSetTimeAtTime(tap.timeline, beatTime / _beatsPerSample, audioTime.audioTimeStamp);
    } else {
        AKTimelineSetTime(tap.timeline, beatTime / _beatsPerSample);
    }
}

-(double)beatTimeAtTime:(AVAudioTime *)audioTime {
//    AudioTimeStamp timestamp = audioTime ? audioTime.audioTimeStamp : AudioTimeNow(); HACK
    return AKTimelineTimeAtTime(tap.timeline, AudioTimeNow()) * _beatsPerSample; // HACK
}

-(void)setTempo:(double)tempo atTime:(AVAudioTime *)audioTime{
    AudioTimeStamp timestamp = audioTime ? audioTime.audioTimeStamp : AudioTimeNow();
    [self setTempo:tempo andBeats:_beatCount atTime:timestamp];
}

-(void)setBeatCount:(int)beatCount atTime:(AVAudioTime *)audioTime{
    if (beatCount > 32) {
        NSLog(@"Beats must be <= 32");
        return;
    }
    AudioTimeStamp timestamp = audioTime ? audioTime.audioTimeStamp : AudioTimeNow();
    [self setTempo:self.tempo andBeats:beatCount atTime:timestamp];
}

-(void)stop {
    // Attempt to do midi panic
//    MusicDeviceMIDIEvent(self.audioUnit, 0xB0, 0, 0,0.0);

    _playCount = 0;
    AKTimelineStop(tap.timeline);
}


static AudioTimeStamp AudioTimeNow(void) {
    return (AudioTimeStamp) {
        .mHostTime = mach_absolute_time(),
        .mFlags = kAudioTimeStampHostTimeValid
    };
}
@end
