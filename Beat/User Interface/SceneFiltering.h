//
//  SceneFiltering.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 30.12.2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FountainAnalysis.h"
#import "OutlineScene.h"

NS_ASSUME_NONNULL_BEGIN

@interface SceneFiltering : NSObject

@property (nonatomic) NSString* text;
@property (nonatomic) NSString* character;
@property (nonatomic) NSMutableArray* colors;
@property (weak) NSMutableArray* lines;
@property (weak) NSMutableArray* scenes;
@property (nonatomic) FountainAnalysis* analysis;
@property (nonatomic) NSMutableArray* filteredScenes;

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
