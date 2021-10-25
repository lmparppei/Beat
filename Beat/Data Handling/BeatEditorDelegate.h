//
//  BeatEditorDelegate.h
//  
//
//  Created by Lauri-Matti Parppei on 8.4.2021.
//

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#if TARGET_OS_IOS
    #import <UIKit/UIKit.h>
#endif

@class ContinuousFountainParser;
@class Line;
@class OutlineScene;
@class BeatDocumentSettings;

@protocol BeatEditorDelegate <NSObject>

@property (nonatomic, readonly, weak) OutlineScene *currentScene;
@property (nonatomic, readonly) bool printSceneNumbers;
@property (nonatomic, readonly) bool showSceneNumberLabels;
@property (nonatomic, readonly) bool typewriterMode;
@property ContinuousFountainParser *parser;

@property (nonatomic, readonly) CGFloat magnification;
@property (nonatomic) CGFloat inset;
@property (nonatomic, readonly) NSUInteger documentWidth;

@property (nonatomic) NSMutableDictionary *characterGenders;
@property (atomic) BeatDocumentSettings *documentSettings;

- (NSMutableArray*)scenes;
- (NSMutableArray*)getOutlineItems;
- (NSMutableArray*)lines;
- (NSString*)getText;
- (NSArray*)linesForScene:(OutlineScene*)scene;

- (NSInteger)lineTypeAt:(NSInteger)index;

- (void)setSelectedRange:(NSRange)range;
- (NSRange)selectedRange;
- (NSArray*)getOutline; // ???
- (OutlineScene*)getCurrentScene;

- (void)addStoryline:(NSString*)storyline to:(OutlineScene*)scene;
- (void)removeStoryline:(NSString*)storyline from:(OutlineScene*)scene;
- (void)setColor:(NSString *) color forScene:(OutlineScene *) scene;
- (bool)caretAtEnd;

- (bool)isDark;

- (void)showLockStatus;
- (bool)contentLocked;

// This determines if the text has changed since last query
- (bool)hasChanged;
- (NSArray*)markers;

- (void)showTitleBar;
- (void)hideTitleBar;

- (void)scrollToLine:(Line*)line;


#if TARGET_OS_IOS
    - (CGFloat)fontSize;
#endif

@end
/*
 
 tää viesti on varoitus
 tää viesti on
 varoitus
 
 tästä hetkestä
 ikuisuuteen
 tästä hetkestä
 ikuisuuteen
 
 ja se vaara
 on yhä läsnä
 vaikka me oomme lähteneet
 se vaara on
 yhä läsnä
 
 */

