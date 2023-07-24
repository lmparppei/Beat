//
//  BeatSpeak.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 10.3.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatSpeak.h"


@implementation BeatSpeak {
	id synthesizer;
}

+ (instancetype)new {
	BeatSpeak *speak = [super new];
	speak.rate = 0.3f;
	speak.volume = 0.9f;
	speak.pitchMultiplier = 1.0f;
	
	return speak;
}

- (void)speak:(NSString*)string {
	if (@available(macOS 10.14, *)) {
		AVSpeechSynthesizer *synth = synthesizer;
		if (synth) [synth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
		else synthesizer = AVSpeechSynthesizer.new;
				
		AVSpeechUtterance *utt = [AVSpeechUtterance.alloc initWithString:string];
		
		utt.rate = self.rate;
		utt.pitchMultiplier = self.pitchMultiplier;
		utt.volume = self.volume;
		
		// Set language if specified
		if (self.language.length) {
			utt.voice = [AVSpeechSynthesisVoice voiceWithLanguage:self.language];
		}
		
	
		[(AVSpeechSynthesizer*)synthesizer speakUtterance:utt];
	}
}

- (void)stopSpeaking {
	if (@available(macOS 10.14, *)) {
		[(AVSpeechSynthesizer*)synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryWord];
	}
}

- (void)continueSpeaking {
	if (@available(macOS 10.14, *)) {
		[(AVSpeechSynthesizer*)synthesizer continueSpeaking];
	}
}

@end
