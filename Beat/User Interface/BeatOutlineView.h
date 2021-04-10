//
//  BeatOutlineView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 07/10/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OutlineScene.h"
#import "SceneFiltering.h"
#import "Line.h"
#import "BeatEditorDelegate.h"

@protocol BeatOutlineViewEditorDelegate <NSObject>
@property (readonly, nonatomic) OutlineScene *currentScene;
@property (nonatomic) bool outlineEdit;
@property (readonly, nonatomic) NSMutableArray *outline;
- (NSMutableArray*)lines;
- (NSMutableArray*)getOutlineItems;
- (void)moveScene:(OutlineScene*)sceneToMove from:(NSInteger)from to:(NSInteger)to;
- (void)scrollToScene:(OutlineScene*)scene;
- (void)maskScenes;
@end

@interface BeatOutlineView : NSOutlineView <NSOutlineViewDelegate, NSOutlineViewDataSource>
@property (nonatomic, weak) IBOutlet id<BeatOutlineViewEditorDelegate, BeatEditorDelegate> editorDelegate;
@property (nonatomic) NSInteger currentScene;
@property (weak) IBOutlet NSTouchBar *touchBar;
@property (nonatomic) bool editing;

@property (nonatomic) NSMutableArray *filteredOutline;
@property (nonatomic) SceneFiltering *filters;

-(void)reloadOutline;
- (void)scrollToScene:(OutlineScene*)scene;
@end
