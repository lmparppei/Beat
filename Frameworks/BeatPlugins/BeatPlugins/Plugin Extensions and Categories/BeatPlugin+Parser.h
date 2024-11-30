//
//  BeatPlugin+Parser.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 25.11.2024.
//

#import <BeatPlugins/BeatPlugins.h>
#import <JavaScriptCore/JavaScriptCore.h>

@class Line;

@protocol BeatPluginParserExports <JSExport>

/// List of Beat line types
@property (nonatomic, readonly) NSDictionary *type;
/// Returns the actual parser object in the document
@property (readonly) ContinuousFountainParser *currentParser;


#pragma mark - Contextual line and scene info
/// Currently edited line
@property (readonly) Line* currentLine;
/// Currently edited scene
@property (readonly) OutlineScene* currentScene;


#pragma mark - Parser access

/// Create a new parser with given raw string (__NOTE__: Doesn't support document settings, revisions, etc.)
- (ContinuousFountainParser*)parser:(NSString*)string;

/// Creates a new line element
JSExportAs(line, - (Line*)lineWithString:(NSString*)string type:(LineType)type);

/// Returns all parsed lines
- (NSArray*)lines;
/// Returns the current outline
- (NSArray*)outline;
/// Returns the current outline excluding any structural elements (namely `sections`)
- (NSArray*)scenes;

/// Returns the full outline as a JSON string
- (NSString*)outlineAsJSON;
/// Returns all scenes as a JSON string
- (NSString*)scenesAsJSON;
/// Returns all lines as a JSON string
- (NSString*)linesAsJSON;
/// Returns the line at given position in document
- (Line*)lineAtPosition:(NSInteger)index;
/// Returns the scene at given position in document
- (Line*)sceneAtPosition:(NSInteger)index;
/// Returns lines in given scene.
- (NSArray*)linesForScene:(OutlineScene*)scene;
/// Creates the outline from scratch
- (void)createOutline;


@end

@interface BeatPlugin (Parser) <BeatPluginParserExports>

/// Currently edited line
@property (readonly) Line* currentLine;
/// Currently edited scene
@property (readonly) OutlineScene* currentScene;

- (Line*)lineWithString:(NSString*)string type:(LineType)type;


@end

