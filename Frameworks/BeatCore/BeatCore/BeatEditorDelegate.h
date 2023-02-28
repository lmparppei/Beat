//
//  BeatEditorDelegate.h
//  
//
//  Created by Lauri-Matti Parppei on 8.4.2021.
//
/*
 
 BeatEditorDelegate is a protocol which provides the basic stuff for interfacing
 with the editor (and document) for other classes.
 
 */

#import <TargetConditionals.h>
#import "BeatEditorMode.h"

#if TARGET_OS_IOS
    #import <UIKit/UIKit.h>
    #define BXFont UIFont
    #define BXChangeType UIDocumentChangeKind
    #define BXTextView UITextView
    #define BXWindow UIWindow
    #define BXPrintInfo UIPrintInfo
#else
    #import <Cocoa/Cocoa.h>
    #define BXFont NSFont
    #define BXChangeType NSDocumentChangeType
    #define BXTextView NSTextView
    #define BXWindow NSWindow
    #define BXPrintInfo NSPrintInfo
#endif

#import <BeatParsing/BeatParsing.h>

#if !TARGET_OS_IOS
@class BeatPrintView;
#else
@class BeatUITextView;
#endif

@class ContinuousFountainParser;
@class Line;
@class OutlineScene;
@class BeatDocumentSettings;
@class NSLayoutManager;
@class NSTextStorage;
@class UITextRange;
@class BeatPaginator;

@protocol BeatEditorView
- (void)reloadInBackground;
- (void)reloadView;
- (bool)visible;
@end
 
@protocol BeatEditorDelegate <NSObject>

@property (nonatomic, readonly) bool documentIsLoading;
- (BXTextView*)getTextView;
- (CGFloat)editorLineHeight;

#if !TARGET_OS_IOS
@property (weak, readonly) BXWindow* documentWindow;
@property (nonatomic, readonly) bool typewriterMode;
@property (nonatomic, readonly) bool disableFormatting;

// TODO: Remove this when native export is implemented
@property (nonatomic) bool nativeRendering;
#endif


#pragma mark - Core functionality

/// Fountain parser associated with the document
@property (readonly) ContinuousFountainParser *parser;
/// Live pagination manager
@property (nonatomic, readonly) BeatPaginator *paginator;
@property (nonatomic, readonly) NSUndoManager *undoManager;

 
#pragma mark - Application data and file access

- (NSString*)fileNameString;
- (bool)isDark;
- (void)showLockStatus;
- (bool)contentLocked;



#pragma mark - Getters for parser data

@property (nonatomic, readonly, weak) OutlineScene *currentScene;
@property (atomic, readonly) NSAttributedString *attrTextCache;

- (NSArray<OutlineScene*>*)getOutlineItems;
- (NSMutableArray<Line*>*)lines;
- (NSString*)text;
- (NSAttributedString*)attributedString;
- (NSArray*)linesForScene:(OutlineScene*)scene;

- (Line*)currentLine;
- (LineType)lineTypeAt:(NSInteger)index;
- (NSArray*)getOutline; // What is this?
- (NSArray*)scenes;
- (NSArray*)markers;


#pragma mark - Screenplay document data

@property (nonatomic) NSDictionary<NSString*, NSString*>* characterGenders;
@property (nonatomic) NSString *revisionColor;
@property (nonatomic) BeatDocumentSettings *documentSettings;

@property (nonatomic) bool printSceneNumbers;

- (void)setPrintSceneNumbers:(bool)value;
- (void)setAutomaticTextCompletionEnabled:(BOOL)value;

- (void)addStoryline:(NSString*)storyline to:(OutlineScene*)scene;
- (void)removeStoryline:(NSString*)storyline from:(OutlineScene*)scene;


#pragma mark - Editing the text content

- (void)addString:(NSString*)string atIndex:(NSUInteger)index;
- (void)removeString:(NSString*)string atIndex:(NSUInteger)index;
- (void)replaceRange:(NSRange)range withString:(NSString*)newString;
- (void)replaceString:(NSString*)string withString:(NSString*)newString atIndex:(NSUInteger)index;
- (void)moveScene:(OutlineScene*)sceneToMove from:(NSInteger)from to:(NSInteger)to;
- (void)setColor:(NSString *) color forScene:(OutlineScene *) scene;

/// Determines if the text has changed since last query
- (bool)hasChanged;

- (void)removeAttribute:(NSString*)key range:(NSRange)range;
- (void)addAttribute:(NSString*)key value:(id)value range:(NSRange)range;
- (void)addAttributes:(NSDictionary*)attributes range:(NSRange)range;

/// Forces text reformat and editor view updates
- (void)textDidChange:(NSNotification *)notification;


#pragma mark - Editor item visibility

@property (nonatomic) bool showSceneNumberLabels;
@property (nonatomic) bool showPageNumbers;
@property (nonatomic, readonly) bool showRevisions;
@property (nonatomic, readonly) bool showTags;



#pragma mark - Export options

@property (nonatomic) BeatPaperSize pageSize;
@property (nonatomic, readonly) BeatExportSettings* exportSettings;



#pragma mark - Editor text view values

/// Sets and gets the selected range in editor text view
@property (nonatomic, readwrite) NSRange selectedRange;

@property (nonatomic, readonly) CGFloat documentWidth;
@property (nonatomic, readonly) CGFloat magnification;

#pragma mark Editor text view helpers

- (void)updateChangeCount:(BXChangeType)change;
- (bool)caretAtEnd;
- (void)scrollToLine:(Line*)line;
- (void)scrollToRange:(NSRange)range;
- (void)scrollToRange:(NSRange)range callback:(void (^)(void))callbackBlock;
- (void)setTypingAttributes:(NSDictionary*)attrs;
- (void)refreshTextViewLayoutElements;
- (void)refreshTextViewLayoutElementsFrom:(NSInteger)location;



#pragma mark - Fonts

@property (readonly, nonatomic) BXFont *courier;
@property (readonly, nonatomic) BXFont *boldCourier;
@property (readonly, nonatomic) BXFont *boldItalicCourier;
@property (readonly, nonatomic) BXFont *italicCourier;

@property (strong, nonatomic, readonly) BXFont *sectionFont;
@property (strong, nonatomic, readonly) NSMutableDictionary *sectionFonts;
@property (strong, nonatomic, readonly) BXFont *synopsisFont;

- (BXFont*)sectionFontWithSize:(CGFloat)size;
#if TARGET_OS_IOS
    - (CGFloat)fontSize;
#endif



#pragma mark - Style getters

@property (nonatomic, readonly) bool headingStyleBold;
@property (nonatomic, readonly) bool headingStyleUnderline;


#pragma mark - Editor flags

@property (nonatomic) bool revisionMode;
@property (nonatomic, readonly) bool characterInput;
@property (nonatomic) Line* characterInputForLine;
@property (nonatomic) BeatEditorMode mode;
@property (nonatomic, readonly) bool hideFountainMarkup;

/// Check if the editor tab is visible on macOS
@optional - (bool)editorTabVisible;


#pragma mark - Formatting

- (void)formatAllLines;
- (void)forceFormatChangesInRange:(NSRange)range;
- (void)renderBackgroundForLine:(Line*)line clearFirst:(bool)clear;
- (void)renderBackgroundForLines;
- (void)renderBackgroundForRange:(NSRange)range;



#pragma mark - Printing stuff for macOS

#if !TARGET_OS_IOS
@property (strong, nonatomic) NSMutableArray<BeatPrintView*>* printViews;
- (CGFloat)sidebarWidth;

- (NSPrintInfo*)printInfo;
- (id)document;
- (void)releasePrintDialog;
- (NSAttributedString*)getAttributedText;
#endif


#pragma mark - Printing stuff for iOS

#if TARGET_OS_IOS
- (id)documentForDelegation;
- (UIPrintInfo*)printInfo;
#endif

- (NSString*)contdString;
- (NSString*)moreString;


#if TARGET_OS_IOS
- (UITextRange*)selectedTextRange;
- (void)setSelectedTextRange:(UITextRange*)textRange;
#endif


#pragma mark - General editor stuff

- (void)updateQuickSettings;
- (void)updatePreview;

- (void)handleTabPress;
- (void)registerEditorView:(id)view;

- (void)toggleMode:(BeatEditorMode)mode;

// A hack to provide text storage interface to both iOS and macOS ports
- (NSTextStorage*)textStorage;
- (NSLayoutManager*)layoutManager;

@optional - (void)returnToEditor;
@optional - (void)focusEditor;
@optional - (IBAction)toggleCards:(id)sender;
@optional - (NSDictionary*)runningPlugins;



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
