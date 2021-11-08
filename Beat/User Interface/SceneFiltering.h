//
//  SceneFiltering.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 30.12.2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FountainAnalysis.h"
#import "OutlineScene.h"
#import "BeatEditorDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface SceneFiltering : NSObject

@property (nonatomic) NSString* text;
@property (nonatomic) NSString* character;
@property (nonatomic) NSMutableArray* colors;
@property (weak) NSMutableArray* lines; // This is a reference to the parser
@property (nonatomic) NSMutableArray* scenes; // This is a real array of scenes
@property (nonatomic) FountainAnalysis* analysis;
@property (nonatomic) NSMutableArray* filteredScenes;

@property (weak) IBOutlet id<BeatEditorDelegate> editorDelegate;

- (void)setScript:(NSMutableArray *)lines scenes:(NSMutableArray *)scenes;
- (bool)activeFilters;
- (bool)filterText;
- (bool)filterColor;
- (bool)filterCharacter;
- (void)byText:(NSString*)string;
- (void)byScenes:(NSMutableArray*)scenes;
- (void)byCharacter:(NSString*)character;
- (void)byColor:(NSString*)color;
- (bool)match:(OutlineScene*)scene;
- (void)addColorFilter:(NSString*)color;
- (void)removeColorFilter:(NSString*)color;
- (void)resetScenes;
- (NSString*)listFilters;

@end

NS_ASSUME_NONNULL_END
