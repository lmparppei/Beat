//
//  BeatSpeak.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 10.3.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <AVKit/AVKit.h>

@protocol BeatSpeakExports <JSExport>
@property (nonatomic) NSString *string;
@property (nonatomic) NSString *language;
@property (nonatomic) CGFloat rate;
@property (nonatomic) CGFloat volume;
@property (nonatomic) CGFloat pitchMultiplier;
- (void)speak:(NSString*)string;
- (void)stopSpeaking;
- (void)continueSpeaking;
@end

@interface BeatSpeak : NSObject <BeatSpeakExports>
@property (nonatomic) NSString *string;
@property (nonatomic) NSString *language;
@property (nonatomic) CGFloat rate;
@property (nonatomic) CGFloat volume;
@property (nonatomic) CGFloat pitchMultiplier;
- (void)speak:(NSString*)string;
- (void)stopSpeaking;
- (void)continueSpeaking;
@end

