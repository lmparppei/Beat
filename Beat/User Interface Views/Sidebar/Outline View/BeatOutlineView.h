//
//  BeatOutlineView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 07/10/2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatEditorDelegate.h>
#import "SceneFiltering.h"
@class BeatAutocomplete;

@protocol BeatOutlineViewEditorDelegate <NSObject>
@property (readonly, nonatomic) OutlineScene *currentScene;
@property (nonatomic) bool outlineEdit;
@property (readonly, nonatomic) NSArray *outline;
@property (readonly, weak, nonatomic) BeatAutocomplete* autocompletion;
@property (nonatomic, strong, readonly) ContinuousFountainParser *parser;
- (NSMutableArray<Line*>*)lines;
- (void)scrollToScene:(OutlineScene*)scene;
@end

@interface BeatOutlineView : NSOutlineView <NSOutlineViewDelegate, NSOutlineViewDataSource>
@property (nonatomic, weak) IBOutlet id<BeatOutlineViewEditorDelegate, BeatEditorDelegate> editorDelegate;
@property (nonatomic, weak) IBOutlet NSTabViewItem* enclosingTabView;
@property (weak) IBOutlet NSTouchBar *touchBar;
@property (nonatomic) bool editing;
@property (nonatomic) bool dragging;

@property (nonatomic) NSArray<NSTableCellView*>* visibleSnapshots;

@property (nonatomic) NSMutableArray *filteredOutline;
@property (nonatomic) SceneFiltering *filters;

-(void)setup;

-(void)reloadOutline;
-(void)reloadWithChanges:(OutlineChanges*)changes;
- (void)scrollToScene:(OutlineScene*)scene;
- (NSArray*)outline;

- (void)closeSnapshots;
- (void)addSnapshot:(NSTableCellView*)view;

@end
