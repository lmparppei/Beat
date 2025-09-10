//
//  ContinousFountainParser.h
//  Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <BeatParsing/Line.h>
#import <BeatParsing/OutlineScene.h>
#import <BeatParsing/BeatDocumentSettings.h>
#import <BeatParsing/BeatExportSettings.h>
#import <BeatParsing/BeatScreenplay.h>
#import <BeatParsing/OutlineChanges.h>

@class OutlineScene;
@class BeatMacroParser;

@protocol ContinuousFountainParserDelegate <NSObject>
/// Document settings object
@property (nonatomic, readonly) BeatDocumentSettings *documentSettings;
/// This is a confusing property name, but it defines the line on which a character cue is being entered after a tab press
@property (nonatomic, readonly) Line* characterInputForLine;
/// Current selected range (ask for this only in main thead)
@property (nonatomic, readonly) NSRange selectedRange;
/// A list of disabled line types (`LineType` is an integer enum, so an index set is the fastest way to implement this)
@property (nonatomic, readonly) NSIndexSet* disabledTypes;

- (Line*)currentLine;

/// Forces reformatting at given line indices
- (void)reformatLinesAtIndices:(NSMutableIndexSet*)indices;
/// Forces any changes in parser to be reformatted in editor
- (void)applyFormatChanges;
/// Notify that the outline was changed
- (void)outlineDidUpdateWithChanges:(OutlineChanges*)changes;
/// Notify that a line was deleted
- (void)lineWasRemoved:(Line*)line;
@end

// Plugin compatibility
@protocol ContinuousFountainParserExports <JSExport>
@property (readonly) NSMutableArray<Line*>* lines;
@property (nonatomic, readonly) NSMutableArray <OutlineScene*>* outline;
@property (nonatomic, readonly) NSMutableArray <OutlineScene*>* scenes;
@property (nonatomic, readonly) NSMutableArray<NSMutableDictionary<NSString*,NSArray<Line*>*>*>* titlePage;
@property (nonatomic, readonly) NSMutableDictionary *storybeats;
@property (nonatomic, readonly) bool hasTitlePage;

@property (nonatomic, readonly) OutlineChanges* outlineChanges;
@property (nonatomic, readonly) NSMutableSet *changedOutlineElements;

- (NSString*)rawText;
- (NSString*)screenplayForSaving;
- (void)parseText:(NSString*)text;

- (NSInteger)numberOfScenes;

- (NSString*)titlePageAsString;
- (NSArray<Line*>*)titlePageLines;
- (NSArray<NSDictionary<NSString*,NSArray<Line*>*>*>*)parseTitlePage;

- (NSArray*)safeLines;

@property (nonatomic, weak) Line* boneyardAct;

@end

@interface ContinuousFountainParser : NSObject <ContinuousFountainParserExports>
/// Parser delegate. Basically it's the document.
@property (nonatomic, weak) id 	<ContinuousFountainParserDelegate> delegate;
/// Every line as object
@property (atomic) NSMutableArray<Line*>* lines;
/// Contains every line that needs to be formatted once changes have been parsed.
@property (nonatomic) NSMutableIndexSet* changedIndices;
/// Document outline structure (scenes and sections)
@property (nonatomic) NSMutableArray<OutlineScene*>* outline;
/// Title page elements as a complicated array
@property (nonatomic) NSMutableArray<NSMutableDictionary<NSString*,NSArray<Line*>*>*>* titlePage;
@property (nonatomic) NSMutableDictionary <NSString*, NSMutableArray<Storybeat*>*>*storybeats;
/// Calculated property, checks if title page lines are present
@property (nonatomic) bool hasTitlePage;
/// Set `true` when a first-time parse is in process
@property (nonatomic) bool firstTime;


/// Previous line at a looked up location
@property (nonatomic, weak) Line* prevLineAtLocation;
/// The line which was last edited. We're storing this when asking for a line at caret position.
@property (nonatomic, weak) Line *lastEditedLine;

/// For STATIC parsing without a document
@property (nonatomic) BeatDocumentSettings *staticDocumentSettings;
/// Set `true` when the parser is not continuous
@property (nonatomic) bool staticParser;

@property (nonatomic) OutlineChanges* outlineChanges;
@property (nonatomic) NSMutableSet *changedOutlineElements;

/// Returns the assigned document settings 
- (BeatDocumentSettings*)documentSettings;

//@property (nonatomic) NSDictionary<NSUUID*, Line*>* uuidsToLines;
@property (nonatomic) NSMapTable<NSUUID*, Line*>* uuidsToLines;

+ (NSArray*)titlePageForString:(NSString*)string;

// Initialization for both CONTINUOUS and STATIC parsing
- (ContinuousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate;
- (ContinuousFountainParser*)initWithString:(NSString*)string;
- (ContinuousFountainParser*)initStaticParsingWithString:(NSString*)string settings:(BeatDocumentSettings*)settings;
- (ContinuousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate nonContinuous:(bool)nonContinuous;


#pragma mark - Parsing methods
/// Parses the full text
- (void)parseText:(NSString*)text;
/// Parse a change in range with given replacement string.
- (void)parseChangeInRange:(NSRange)range withString:(NSString*)string;
/// Reparses the whole document.
- (void)resetParsing;
/// Returns parsed scenes, excluding structure elements
- (NSArray<OutlineScene*>*)scenes;
/// Reparses the given lines
- (void)correctParsesForLines:(NSArray*)lines;

/// Returns thread-safe lines
- (NSArray*)safeLines;
/// Returns thread-safe outline
- (NSArray*)safeOutline;



#pragma mark - Preprocess for printing & saving

/// Returns the raw string for the screenplay. Preprocesses some lines.
- (NSString*)screenplayForSaving;
/// Can be used for handling issues with orphaned dialogue.
- (void)ensureDialogueParsingFor:(Line*)line;


#pragma mark - Macro handling

@property (nonatomic) BeatMacroParser* macros;
@property (nonatomic) bool macrosNeedUpdate;


#pragma mark - Boneyard

@property (nonatomic, weak) Line* boneyardAct;


#pragma mark - Convenience Methods

/// Returns the number of scenes  in the file (excluding other structure elements)
- (NSInteger)numberOfScenes;

/// Returns `NSUUID` object for each line.
- (NSArray*)lineIdentifiers:(NSArray<NSUUID*>*)lines;

/// Set `NSUUID` identifiers for lines in corresponding indices.
- (void)setIdentifiers:(NSArray*)uuids;

@end
