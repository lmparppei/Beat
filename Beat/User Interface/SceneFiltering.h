//
//  SceneFiltering.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 30.12.2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>
#import "FountainAnalysis.h"
#import <BeatCore/BeatEditorDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@interface SceneFiltering : NSObject

@property (weak) IBOutlet id<BeatEditorDelegate> editorDelegate;

- (bool)activeFilters;

- (void)byText:(NSString*)string;
- (void)byScenes:(NSMutableArray*)scenes;
- (void)byCharacter:(NSString*)character;
- (void)byColor:(NSString*)color;
- (bool)match:(OutlineScene*)scene;
- (void)addColorFilter:(NSString*)color;
- (void)removeColorFilter:(NSString*)color;
- (void)resetScenes;

@end

NS_ASSUME_NONNULL_END
