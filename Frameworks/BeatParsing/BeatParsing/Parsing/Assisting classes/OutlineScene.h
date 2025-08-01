//
//  OutlineScene.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.2.2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/Line.h>
#import <JavaScriptCore/JavaScriptCore.h>

@class OutlineScene;
@class BeatNoteData;
@class Line;

@protocol OutlineSceneExports <JSExport>
@property (nonatomic, readonly) NSString * sceneNumber;
@property (nonatomic, readonly) NSString * color;

@property (nonatomic, readonly) Line * line;

@property (nonatomic, readonly) OutlineScene * parent;
@property (nonatomic, readonly) NSArray<OutlineScene*>* siblings;
@property (nonatomic, readonly) NSMutableArray <OutlineScene*>* children;

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

@property (nonatomic, readonly) NSMutableArray<BeatNoteData*>* notes;

@property (nonatomic, readonly) NSMutableSet *markerColors;

@property (nonatomic, readonly) bool omitted;
@property (nonatomic, readonly) bool omited; // Legacy compatibility
@property (nonatomic, readonly) NSUInteger omissionStartsAt;
@property (nonatomic, readonly) NSUInteger omissionEndsAt;

@property (nonatomic, readonly) NSMutableArray * characters;


- (NSArray<Line*>*)lines;
- (NSString*)typeAsString;
- (NSInteger)timeLength;
- (NSDictionary*)forSerialization;
- (NSDictionary*)json;
@end

@interface OutlineScene : NSObject <OutlineSceneExports>
+ (OutlineScene*)withLine:(Line*)line;
+ (OutlineScene*)withLine:(Line*)line delegate:(id)delegate;

@property (nonatomic, weak) id<LineDelegate> delegate;

/// The heading line of this scene
@property (nonatomic, weak) Line* line;
/// The `section` which contains this scene
@property (nonatomic, weak) OutlineScene* parent;
/// Convenience method for `.parent.children`
@property (nonatomic, readonly) NSArray<OutlineScene*>* siblings;
/// How deep in the hierarchy is this outline element (`0` is top-level)
@property (nonatomic) NSInteger sectionDepth;
/// `true` if this scene is wrapped in `/* */`
@property (nonatomic) bool omitted;

/// Children of this `section`
@property (nonatomic) NSMutableArray <OutlineScene*>* children;
/// A getter for the lines in this scene. Requires a `LineDelegate`.
@property (nonatomic) NSMutableArray<Line*>* lines;

/// An array of synopsis lines in this scene
@property (nonatomic) NSMutableArray<Line*>* synopsis;
/// An array of all notes contained by this scene (including markers and heading colors etc.)
@property (nonatomic) NSMutableArray<BeatNoteData*>* notes;
/// Story beats contained by this scene
@property (nonatomic) NSMutableArray * beats;
/// Returns the storyline **NAMES**  in this scene
@property (nonatomic) NSArray<NSString*>* storylines;
/// An array of characters with dialogue in this scene
@property (nonatomic) NSMutableArray * characters;

/// Clean string representation of the line
@property (strong, nonatomic) NSString* string;
/// Outline element type (forwarded from the heading line)
@property (nonatomic) LineType type;
/// Scene number (forwarded from the heading line)
@property (nonatomic) NSString * sceneNumber;
/// Outline element color (forwarded from the heading line)
@property (nonatomic, readonly) NSString * color;

/// Colors of the markers in this scene
@property (nonatomic) NSMutableSet *markerColors;
/// All markers in this scene
@property (nonatomic) NSMutableArray* markers;

/// Starting position of the outline element (forwarded from the heading line)
@property (nonatomic, readonly) NSUInteger position;
/// Length of the scene (calculated property, works only with a `LineDelegate` connected)
@property (nonatomic) NSUInteger length;
/// The same as `.position`, here for backwards compatibility
@property (nonatomic, readonly) NSUInteger sceneStart;
/// The same as `.length`, here for backwards compatibility
@property (nonatomic, readonly) NSUInteger sceneLength;

@property (nonatomic) NSUInteger omissionStartsAt;
@property (nonatomic) NSUInteger omissionEndsAt;

@property (nonatomic) NSInteger oldSectionDepth;

/// Experimental property: page number
@property (nonatomic) NSInteger page;
/// Experimental property: printed length
@property (nonatomic) CGFloat printedLength;

- (NSArray<Line*>*)lines;
- (NSString*)stringForDisplay;
- (NSRange)range;
- (NSInteger)timeLength;
- (NSString*)typeAsString;
- (NSDictionary*)forSerialization;
- (NSDictionary*)json;
@end
