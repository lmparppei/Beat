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
@property (nonatomic) NSString *script;
@property (weak) NSArray *lines;
@property (weak) NSArray *scenes;
@property (nonatomic) JSVirtualMachine *vm;
@property (nonatomic) JSContext *context;
@end

@implementation BeatScriptParser

- (id)performDefaultImplementation {
    NSString *sTitle = [self directParameter];
	NSLog(@"param %@", sTitle);
    return sTitle;
}


- (id)initWithScript:(NSString*)script lines:(NSArray*)lines scenes:(NSArray*)scenes
{
	if ((self = [super init]) == nil) { return nil; }
	
	_script = script;
	_lines = lines;
	_scenes = scenes;
	
	_vm = [[JSVirtualMachine alloc] init];
	_context = [[JSContext alloc] initWithVirtualMachine:_vm];
	
	NSString *js = @"return 'hello';";
	NSLog(@"result: %@", [_context evaluateScript:js]);
	
	return self;
}

/*
 
 // Beat functions available for scripting
 beat.newPanel(htmlContent);
 beat.newWindow(htmlContent);
 beat.scrollTo(location);	
 beat.scrollToLine(line);
 beat.scrollToScene(scene);
 beat.setContent(content);
 
 // Helper functions to be implemented in JS
 beat.sceneAt(location);
 beat.lineAt(location);
 
 // Read-only values
 beat.lines;
 beat.scenes;
 beat.cursorLocation;
 beat.scriptAsString;
 
 
 Example plugin for finding the longest scene:
 
 let longestScene = { length: 0, scene: null };
 let sceneIndex = -1;
 for (const scene of beat.scenes) {
	sceneIndex++;
	if (scene.length > longestScene.length) {
		longestScene.scene = scene;
		length: scene.length;
	}
 }
 if (longestScene.scene) {
	beat.scrollToScene(scene);
 }
 
 */

- (void)runScript {

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
}

@end
