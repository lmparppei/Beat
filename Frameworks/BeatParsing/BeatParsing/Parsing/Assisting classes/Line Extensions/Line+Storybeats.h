//
//  Line+Storybeats.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 29.12.2024.
//

#import <BeatParsing/BeatParsing.h>
#import <JavaScriptCore/JavaScriptCore.h>

//@class Storybeat;
@protocol LineStorybeatExports <JSExport>
- (bool)hasBeat;
- (bool)hasBeatForStoryline:(NSString*)storyline;
- (Storybeat*)storyBeatWithStoryline:(NSString*)storyline;
- (NSRange)firstBeatRange;
@end

@interface Line (Storybeats)

#pragma mark - Story beats

/// The line contains a story beat
- (bool)hasBeat;
/// Returns `true` if the line contains a story beat for the given storyline.
- (bool)hasBeatForStoryline:(NSString*)storyline;
/// Returns the story beat item for given storyline name.
- (Storybeat*)storyBeatWithStoryline:(NSString*)storyline;
/// Returns the range for first story beat on this line.
- (NSRange)firstBeatRange;

@end
