//
//  BeatSceneTree.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.1.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatSceneTree.h"

@implementation BeatSceneTreeItem

- (instancetype)initWithScene:(OutlineScene*)scene parent:(BeatSceneTreeItem*)parent {
	self = [super init];
	self.scene = scene;
	self.parent = parent.scene;
	self.parentNode = parent;
	self.children = NSMutableArray.new;
	
	return self;
}

- (NSInteger)sectionDepth {
	return self.scene.sectionDepth;
}

- (NSInteger)childrenCount {
	NSInteger count = self.children.count;
	
	for (BeatSceneTreeItem *child in self.children) {
		if (child.children.count) count += [child childrenCount];
	}
	
	return count;
}

- (OutlineScene*)lastScene {
	BeatSceneTreeItem *item = self.children.lastObject;
	return item.scene;
}

@end

@interface BeatSceneTree ()
@property (nonatomic) NSMutableArray<OutlineScene*>* outline;
@end

@implementation BeatSceneTree

+ (BeatSceneTree*)fromOutline:(NSArray<OutlineScene*>*)outline {
	BeatSceneTree *tree = BeatSceneTree.new;
	tree.outline = outline.mutableCopy;
	tree.items = [tree childrenOf:nil parent:nil];
		
	return tree;
}

- (NSMutableArray*)childrenOf:(OutlineScene*)topSection parent:(BeatSceneTreeItem*)parent {
	NSMutableArray *items = NSMutableArray.new;
	
	NSInteger idx = (topSection) ? [self.outline indexOfObject:parent.scene] + 1 : 0;
	if (idx == NSNotFound) return items;
		
	for (NSInteger i=idx; i<self.outline.count; i++) {
		OutlineScene *scene = self.outline[i];
		if (!scene) continue;
		
		BeatSceneTreeItem *item = [BeatSceneTreeItem.alloc initWithScene:scene parent:parent];
		
		if (scene.type == section) {
			// Break the loop when we encounter a higher level section
			if (scene.sectionDepth <= parent.sectionDepth) break;
			else {
				item.children = [self childrenOf:scene parent:item];
				i += [item childrenCount];
			}
		}
		
		[items addObject:item];
	}
	
	return items;
}

- (id)itemWithScene:(OutlineScene*)scene {
	return [self find:scene parent:nil];
}

- (id)find:(OutlineScene*)scene parent:(BeatSceneTreeItem*)parent {
	NSArray *items;
	
	if (!parent) items = self.items;
	else items = parent.children;
	
	for (BeatSceneTreeItem* item in items) {
		if (item.scene == scene) return item;
		if (item.children.count) {
			BeatSceneTreeItem *match = [self find:scene parent:item];
			if (match) return match;
		}
	}
	
	return nil;
}

- (OutlineScene*)sceneInSection:(OutlineScene*)section index:(NSInteger)index {
	BeatSceneTreeItem *sectionItem = [self itemWithScene:section];
	if (index < sectionItem.children.count) {
		BeatSceneTreeItem *child = sectionItem.children[index];
		return child.scene;
	} else {
		return nil;
	}
}

@end
