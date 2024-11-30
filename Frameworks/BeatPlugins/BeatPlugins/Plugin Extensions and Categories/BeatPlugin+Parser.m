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
    // Catch document settings
    NSRange settingsRange = [[[BeatDocumentSettings alloc] init] readSettingsAndReturnRange:string];
    if (settingsRange.length > 0) {
        string = [self removeRange:settingsRange from:string];
    }
    
    ContinuousFountainParser *parser = [[ContinuousFountainParser alloc] initWithString:string];
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
        
    /*
    // This is very efficient, but I can't figure out how to fix memory management issues. Would probably require a full copy of the parser.
    NSMutableDictionary<NSNumber*, NSDictionary*>* items = NSMutableDictionary.new;
    @synchronized (self.delegate.parser.lines) {
        // Multi-threaded JSON process
        dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
        dispatch_apply((size_t)outline.count, queue, ^(size_t index) {
            if (outline[index] == nil) return;
            NSDictionary* json = outline[index].forSerialization;
            @synchronized (self.delegate.parser.outline) {
                items[@(index)] = json;
            }
        });
    }
        
    // Turn the dictionary into a normal array
    for (NSInteger i=0; i<items.count; i++) {
        NSNumber* idx = @(i);
        if (items[idx] != nil) [scenesToSerialize addObject:items[@(i)]];
    }
     */

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

- (NSString*)removeRange:(NSRange)range from:(NSString*)string {
    NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] initWithIndexesInRange:(NSRange){0, string.length}];
    [indexSet removeIndexesInRange:range];
    
    NSMutableString *result = [NSMutableString string];
    [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        [result appendString:[string substringWithRange:range]];
    }];
    
    return result;
}

@end
