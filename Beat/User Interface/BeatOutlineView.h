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


@protocol BeatOutlineViewEditorDelegate <NSObject>
@property (readonly, nonatomic) OutlineScene *currentScene;
@property (nonatomic) bool outlineEdit;
@property (readonly, nonatomic) NSMutableArray *outline;
@property (nonatomic, strong, readonly) ContinuousFountainParser *parser;
- (NSMutableArray<Line*>*)lines;
- (NSMutableArray*)getOutlineItems;
- (void)moveScene:(OutlineScene*)sceneToMove from:(NSInteger)from to:(NSInteger)to;
- (void)scrollToScene:(OutlineScene*)scene;
- (void)moveStringFrom:(NSRange)range to:(NSInteger)position actualString:(NSString*)string;
@end

@interface BeatOutlineView : NSOutlineView <NSOutlineViewDelegate, NSOutlineViewDataSource>
@property (nonatomic, weak) IBOutlet id<BeatOutlineViewEditorDelegate, BeatEditorDelegate> editorDelegate;
@property (weak) IBOutlet NSTouchBar *touchBar;
@property (nonatomic) bool editing;
@property (nonatomic) bool dragging;

@property (nonatomic) NSMutableArray *filteredOutline;
@property (nonatomic) SceneFiltering *filters;

-(void)reloadOutline;
-(void)reloadOutline:(NSArray*)changesInOutline;
- (void)scrollToScene:(OutlineScene*)scene;
- (NSArray*)outline;
@end
