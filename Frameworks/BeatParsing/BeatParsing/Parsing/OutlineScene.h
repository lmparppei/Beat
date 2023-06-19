//
//  OutlineScene.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.2.2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContinuousFountainParser.h"
#import "Line.h"
#import <JavaScriptCore/JavaScriptCore.h>

@class OutlineScene;

// JavaScript interface
@protocol OutlineSceneExports <JSExport>
@property (nonatomic, readonly) NSString * sceneNumber;
@property (nonatomic, readonly) NSString * color;

@property (nonatomic, readonly) Line * line;
@property (nonatomic, readonly) OutlineScene * parent;
@property (nonatomic, readonly) LineType type;

@property (strong, nonatomic, readonly) NSString * string;
@property (nonatomic, readonly) NSString * stringForDisplay;
@property (nonatomic, readonly) NSArray * storylines;
@property (nonatomic, readonly) NSUInteger sceneStart;

@property (nonatomic, readonly) NSMutableArray<Line*>* synopsis;

@property (nonatomic, readonly) NSUInteger position;
@property (nonatomic, readonly) NSUInteger length;
@property (nonatomic, readonly) NSUInteger sceneLength; // backwards compatibility
@property (nonatomic, readonly) NSInteger sectionDepth; // backwards compatibility

@property (nonatomic, readonly) NSMutableSet *markerColors;

@property (nonatomic, readonly) bool omitted;
@property (nonatomic, readonly) bool omited; // Legacy compatibility
@property (nonatomic, readonly) NSUInteger omissionStartsAt;
@property (nonatomic, readonly) NSUInteger omissionEndsAt;

@property (nonatomic, readonly) NSMutableArray * characters;

- (NSString*)typeAsString;
- (NSInteger)timeLength;
- (NSDictionary*)forSerialization;
- (NSDictionary*)json;
@end

@interface OutlineScene : NSObject <OutlineSceneExports>
+ (OutlineScene*)withLine:(Line*)line;
+ (OutlineScene*)withLine:(Line*)line delegate:(id)delegate;

@property (nonatomic, weak) id<LineDelegate> delegate;

@property (nonatomic, weak) Line* line; /// The heading line of this scene
@property (nonatomic, weak) OutlineScene* parent; /// Either a SECTION (for scenes) or a HEADING for synopsis lines
@property (nonatomic) NSMutableArray <OutlineScene*>* children; /// Children of this scene (if a section, or if it contains synopsis lines)

@property (nonatomic) NSMutableArray<Line*>* synopsis;
@property (nonatomic) NSMutableArray<Line*>* lines;

@property (strong, nonatomic) NSString * string; /// Clean string representation of the line
@property (nonatomic) LineType type;
@property (nonatomic) NSString * sceneNumber;
@property (nonatomic, readonly) NSString * color;
@property (nonatomic) NSArray * storylines;
@property (nonatomic) NSMutableArray * beats;

@property (nonatomic) NSMutableSet *markerColors;

@property (nonatomic, readonly) NSUInteger position;
@property (nonatomic) NSUInteger length;
@property (nonatomic, readonly) NSUInteger sceneStart;  // backwards compatibility
@property (nonatomic, readonly) NSUInteger sceneLength;  // backwards compatibility

@property (nonatomic) NSUInteger omissionStartsAt;
@property (nonatomic) NSUInteger omissionEndsAt;

@property (nonatomic) NSInteger sectionDepth;
@property (nonatomic) NSMutableArray * characters;

@property (nonatomic) bool omitted;

- (NSString*)stringForDisplay;
- (NSRange)range;
- (NSInteger)timeLength;
- (NSString*)typeAsString;
- (NSDictionary*)forSerialization;
@end
