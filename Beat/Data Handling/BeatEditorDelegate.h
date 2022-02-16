//
//  BeatEditorDelegate.h
//  
//
//  Created by Lauri-Matti Parppei on 8.4.2021.
//

#import <Cocoa/Cocoa.h>
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
@property (readonly) ContinuousFountainParser *parser;

@property (nonatomic, readonly) CGFloat magnification;
@property (nonatomic) CGFloat inset;
@property (nonatomic, readonly) NSUInteger documentWidth;

@property (nonatomic) NSMutableDictionary *characterGenders;
@property (nonatomic) NSString *revisionColor;
@property (nonatomic) bool revisionMode;
@property (atomic) BeatDocumentSettings *documentSettings;
@property (nonatomic, weak, readonly) NSTextView *textView;

@property (nonatomic, readonly) NSUndoManager *undoManager;

@property (readonly, nonatomic) NSFont *courier;
@property (readonly, nonatomic) NSFont *boldCourier;
@property (readonly, nonatomic) NSFont *boldItalicCourier;
@property (readonly, nonatomic) NSFont *italicCourier;

@property (nonatomic, readonly) bool disableFormatting;

@property (nonatomic, readonly) bool characterInput;
@property (nonatomic, readonly) Line* characterInputForLine;

@property (nonatomic, readonly) bool headingStyleBold;
@property (nonatomic, readonly) bool headingStyleUnderline;

@property (nonatomic, readonly) bool showRevisions;
@property (nonatomic, readonly) bool showTags;

@property (strong, nonatomic, readonly) NSFont *sectionFont;
@property (strong, nonatomic, readonly) NSMutableDictionary *sectionFonts;
@property (strong, nonatomic, readonly) NSFont *synopsisFont;


- (NSMutableArray*)scenes;
- (NSMutableArray*)getOutlineItems;
- (NSMutableArray*)lines;
- (NSString*)text;
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

- (void)updateQuickSettings;

- (void)scrollToLine:(Line*)line;
- (void)scrollToRange:(NSRange)range;

// Document compatibility
-(void)updateChangeCount:(NSDocumentChangeType)change;
-(void)updatePreview;
-(void)forceFormatChangesInRange:(NSRange)range;
- (void)refreshTextViewLayoutElements;
- (void)refreshTextViewLayoutElementsFrom:(NSInteger)location;
- (void)renderBackgroundForLine:(Line*)line clearFirst:(bool)clear;
- (void)renderBackgroundForLines;
- (void)renderBackgroundForRange:(NSRange)range;
- (NSFont*)sectionFontWithSize:(CGFloat)size;

- (void)replaceRange:(NSRange)range withString:(NSString*)newString;

- (void)formatAllLines;

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
 
 se vaara
 on yhä läsnä
 vaikka me oomme lähteneet
 se vaara on
 yhä läsnä
 
 */

