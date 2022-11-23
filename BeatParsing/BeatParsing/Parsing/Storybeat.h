//
//  Storybeat.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 14.2.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

@class Line;
@class OutlineScene;
@protocol StorybeatExports <JSExport>
@property (nonatomic) NSString *beat;
@property (nonatomic) NSString *storyline;
+ (NSString*)stringWithBeats:(NSArray*)beats;
+ (NSString*)stringWithStorylineNames:(NSArray<NSString*>*)storylineNames;
@end

@interface Storybeat : NSObject <StorybeatExports>
+ (Storybeat*)line:(Line*)line scene:(OutlineScene*)scene storyline:(NSString*)storyline beat:(NSString*)beat range:(NSRange)range;
+ (Storybeat*)line:(Line*)line scene:(OutlineScene*)scene string:(NSString*)string range:(NSRange)range;
+ (NSString*)stringWithBeats:(NSArray<Storybeat*>*)beats;
+ (NSString*)stringWithStorylineNames:(NSArray<NSString*>*)storylineNames;
@property (nonatomic) NSString *beat;
@property (nonatomic) NSString *storyline;
@property (nonatomic, weak) Line *line;
@property (nonatomic, weak) OutlineScene *scene;
@property (nonatomic) NSRange rangeInLine;
- (NSString*)stringified;
- (NSDictionary*)forSerialization;
@end
