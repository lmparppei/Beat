//
//  BeatPlugin+Parser.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 25.11.2024.
//

#import "BeatPlugin+Parser.h"

@implementation BeatPlugin (Parser)

#pragma mark - Parser data delegation

/// Parses string and return a new parser object
- (ContinuousFountainParser*)parser:(NSString*)string
{
    BeatDocumentSettings* settings = BeatDocumentSettings.new;
    ContinuousFountainParser *parser = [[ContinuousFountainParser alloc] initStaticParsingWithString:string settings:settings];
    return parser;
}

/// Creates a new `Line` object with given string and type.
- (Line*)lineWithString:(NSString*)string type:(LineType)type
{
    return [Line withString:string type:type];
}

/// Returns parsed `Line` objects for current document.
- (NSArray*)lines { return self.delegate.parser.lines; }
- (NSArray*)linesForScene:(id)sceneId { return [self.delegate.parser linesForScene:(OutlineScene*)sceneId]; }

- (NSArray*)scenes { return self.delegate.parser.scenes; }

- (NSArray*)outline { return (self.delegate.parser.outline) ? self.delegate.parser.outline : @[]; }

- (Line*)lineAtPosition:(NSInteger)index { return [self.delegate.parser lineAtPosition:index]; }

- (OutlineScene*)sceneAtPosition:(NSInteger)index { return [self.delegate.parser sceneAtPosition:index]; }

- (NSDictionary*)type
{
    static NSDictionary* type;
    
    static dispatch_once_t once;
    dispatch_once(&once, ^{ type = Line.typeDictionary; });
    
    return type;
}

- (NSString*)scenesAsJSON
{
    NSMutableArray *scenesToSerialize = NSMutableArray.new;
    NSArray* scenes = self.delegate.parser.scenes.copy;
    
    for (OutlineScene* scene in scenes) {
        [scenesToSerialize addObject:scene.forSerialization];
    }
    
    return scenesToSerialize.json;
}

- (NSString*)outlineAsJSON
{
    NSArray<OutlineScene*>* outline = self.delegate.parser.outline.copy;
    NSMutableArray *scenesToSerialize = [NSMutableArray arrayWithCapacity:outline.count];
        
    for (OutlineScene* scene in outline) {
        [scenesToSerialize addObject:scene.forSerialization];
    }
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:scenesToSerialize options:0 error:&error];
    NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    return json;
}

/// Returns all lines as JSON
- (NSString*)linesAsJSON {
    NSMutableArray *linesToSerialize = NSMutableArray.new;
    NSArray* lines = self.delegate.parser.safeLines.copy;
    
    for (Line* line in lines) {
        Line* l = line;
        if (!NSThread.mainThread) l = line.clone; // Clone the line for background operations
        
        [linesToSerialize addObject:l.forSerialization];
    }
    
    return linesToSerialize.json;
}

- (OutlineScene*)getCurrentScene
{
    return self.delegate.currentScene;
}

- (OutlineScene*)getSceneAt:(NSInteger)position
{
    return [self.delegate.parser sceneAtPosition:position];
}

- (void)createOutline
{
    [self.delegate.parser updateOutline];
}

- (Line*)currentLine
{
    return self.delegate.currentLine;
}

- (OutlineScene*)currentScene
{
    return self.delegate.currentScene;
}

- (ContinuousFountainParser*)currentParser
{
    return self.delegate.parser;
}


@end
