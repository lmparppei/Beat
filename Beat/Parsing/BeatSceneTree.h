//
//  BeatSceneTree.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.1.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Line.h"
#import "OutlineScene.h"

@interface BeatSceneTreeItem : NSObject
@property (nonatomic, weak) OutlineScene *scene;
@property (nonatomic, weak) OutlineScene *parent;
@property (nonatomic, weak) BeatSceneTreeItem *parentNode;
@property (nonatomic) NSMutableArray<BeatSceneTreeItem*>* children;
- (NSInteger)sectionDepth;
- (OutlineScene*)lastScene;
@end

@interface BeatSceneTree : NSObject
@property (nonatomic) NSArray* items;
+ (BeatSceneTree*)fromOutline:(NSArray<OutlineScene*>*)outline;
- (id)itemWithScene:(OutlineScene*)scene;
- (OutlineScene*)sceneInSection:(OutlineScene*)section index:(NSInteger)index;

@end
