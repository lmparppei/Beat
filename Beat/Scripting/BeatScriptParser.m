//
//  BeatScriptParser.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.7.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

/*
 
 A fantasy side-project for creating a JavaScript scripting possibility for Beat.
 The idea is to expose the lines & scenes to JavaScript (via JSON) and let the user
 make what they want with them. The trouble is, though, that easily manipulating the
 screenplay via JS would require resetting the whole text content after it' done.
 
 Also, I want to make it possible to open a window/panel with custom HTML content to
 make it easier to build some weird analytics / statistics tools.
 
 */

#import <Cocoa/Cocoa.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "BeatScriptParser.h"
#import "Line.h"
#import "OutlineScene.h"

@interface BeatScriptParser ()
@property (nonatomic) JSVirtualMachine *vm;
@property (nonatomic) JSContext *context;
@end

@implementation BeatScriptParser


- (id)init
{
	if ((self = [super init]) == nil) { return nil; }
		
	_vm = [[JSVirtualMachine alloc] init];
	_context = [[JSContext alloc] initWithVirtualMachine:_vm];

	[_context setObject:[Line class] forKeyedSubscript:@"Line"];
	[_context setObject:[OutlineScene class] forKeyedSubscript:@"OutlineScene"];
	[_context setObject:self forKeyedSubscript:@"Beat"];
	
	return self;
}

- (void)log:(NSString*)string {
	// If there is a delegate, log into that, but not yet
	NSLog(@"# %@", string);
}


/*
 
 // Beat functions which should be available for scripting
 Beat.scrollTo(location);
 Beat.scrollToLine(line);
 Beat.scrollToScene(scene);
 Beat.setContent(content);
 Beat.addString(string, position)
 Beat.removeRange(start, end)
 
 // Some UI stuff we might need:
 Beat.inputValue("Input Prompt", "Further Info", completionHandler)
 Beat.newPanel(htmlContent);
 ... with a completion handler?


 // Helper functions to be implemented in JS
 Beat.sceneAt(location);
 Beat.lineAt(location);
 
 // Read-only values
 Lines
 Scenes
 
 
 Example plugin for finding the longest scene:
 
 let longestScene = { length: 0, scene: null };
 
 for (const scene of Scenes) {
	if (scene.sceneLength > longestScene.length) {
		longestScene.scene = scene;
		longestScene.length = scene.sceneLength;
	}
 }
 
 if (longestScene.scene) Beat.scrollToScene(scene);
 
 */

- (NSMutableArray*)scenes {
	[self.delegate.parser createOutline];
	NSArray *scenes = self.delegate.parser.outline;
	
	NSMutableArray *result = [NSMutableArray array];
	
	for (OutlineScene *scene in scenes) {
		[result addObject:@{
			@"type": scene.line.typeAsString,
			@"string": (scene.string.length) ? scene.string : @"",
			@"position": [NSNumber numberWithInteger:scene.sceneStart],
			@"length": [NSNumber numberWithInteger:scene.sceneLength],
			@"omitted": [NSNumber numberWithBool:scene.omited],
			@"color": (scene.color.length) ? scene.color : @"",
			@"sceneNumber": (scene.sceneNumber.length) ? scene.sceneNumber : @""
		}];
	}
	
	return result;
}

- (void)runScriptWithString:(NSString*)string {
	if (_lines) {
		[_context setObject:_lines forKeyedSubscript:@"Lines"];
	}
	
	JSValue *value = [_context evaluateScript:string];
	NSLog(@"value %@", value);
}

- (void)runScript {

	/*
	// We need to make a copy of lines available to JS
	NSMutableArray *jsonLines = [NSMutableArray array];
	
	for (Line* line in _lines) {
		NSError *error;
		
		NSDictionary *lineData = @{
			@"string": line.string,
			@"position": [NSNumber numberWithUnsignedInteger:line.position],
			@"color": line.color,
			@"sceneNumber": line.sceneNumber,
			@"type": line.typeAsString,
			@"omited": line.omited ? @"true" : @"false",
			@"centered": line.centered ? @"true" : @"false"
		};
		
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:lineData options:NSJSONWritingPrettyPrinted error:&error];
		if (!jsonData) NSLog(@"Error with JSON serialization: %@", error);
		else {
			[jsonLines addObject:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]];
		}
	}
	 */
}

@end
