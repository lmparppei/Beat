//
//  FountainReport.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 28/09/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContinousFountainParser.h"
#import "Line.h"

@interface FountainAnalysis : NSObject
{
}
@property NSMutableArray * characters;
@property NSMutableArray * lines;
@property NSMutableArray * scenes;
@property NSDictionary * genders;
@property NSMutableDictionary<NSString *, NSNumber *>* characterLines;

@property NSInteger interiorScenes;
@property NSInteger exteriorScenes;
@property NSInteger otherScenes;

- (NSString*) getJSON;
- (void) setupScript:(NSMutableArray*)lines scenes:(NSMutableArray*)scenes;
- (void) setupScript:(NSMutableArray*)lines scenes:(NSMutableArray*)scenes characterGenders:(NSDictionary*)genders;
- (NSMutableArray*) scenesWithCharacter:(NSString*)character onlyDialogue:(bool)onlyDialogue;
@end
