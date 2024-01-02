//
//  BeatEditorDelegate.h
//  
//
//  Created by Lauri-Matti Parppei on 8.4.2021.
//
/**
 
 BeatEditorDelegate is a protocol which provides the basic stuff for interfacing with the editor.
 It's an expansion of `BeatDocumentDelegate` which  should be used when no actual editor
 interaction is needed.
 
 
 */

#import <TargetConditionals.h>
#import <BeatCore/BeatEditorMode.h>
#import <BeatCore/BeatDocumentDelegate.h>

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
#else
@class BeatUITextView;
#endif

@class NSLayoutManager;
@class NSTextStorage;
@class UITextRange;
@class BeatStylesheet;
@class BeatTextIO;
@class BeatEditorFormatting;
@class BeatPluginAgent;
@class BeatFonts;

/// Protocol for editor views which need to be updated in some cases
@protocol BeatEditorView
- (void)reloadInBackground;
- (void)reloadView;
- (bool)visible;
@end

/// Protocol for any views/objects that need to be updated when selection changes
@protocol BeatSelectionObserver
- (void)selectionDidChange:(NSRange)selectedRange;
@end

/**
 TODO: Make the text editor conform to this protocol to avoid tons of editor view calls in the delegate
 */
@protocol BeatTextEditor
//NSLayoutManager* layoutManager;
//NSTextStorage* textStorage;
@property (nonatomic) NSString* text;
@property (nonatomic) NSDictionary<NSAttributedStringKey,id>* typingAttributes;

- (void)scrollToLine:(Line*)line;
- (void)scrollToRange:(NSRange)range;
- (void)scrollToRange:(NSRange)range callback:(void (^)(void))callbackBlock;
- (void)scrollToScene:(OutlineScene*)scene;

@end

/**
 Every view which uses the outline structure to show stuff should adhere to this protocol.
 */
@protocol BeatSceneOutlineView<BeatEditorView>
/// Reloads the view with given changes. Changes can be `nil` in which case the view should do a complete reload.
- (void)reloadWithChanges:(OutlineChanges*)changes;
@end
 
@protocol BeatEditorDelegate <NSObject, NSCopying, BeatDocumentDelegate>


#pragma mark - Core functionality

@property (nonatomic, readonly) bool documentIsLoading;
@property (atomic, readonly) NSAttributedString *attrTextCache;
@property (nonatomic, readonly) NSUndoManager *undoManager;

/// Returns the actual text view for either macOS or iOS.
- (BXTextView*)getTextView;
- (CGFloat)editorLineHeight;

#if !TARGET_OS_IOS
@property (weak, readonly) BXWindow* documentWindow;
@property (nonatomic, readonly) bool disableFormatting;
#endif


#pragma mark - Application data and file access

- (NSUUID*)uuid;
- (NSString*)fileNameString;
- (bool)isDark;
- (void)showLockStatus;
- (bool)contentLocked;


#pragma mark - Getters for parser data

// NO idea why currentScene is a property and currentLine a method.
// TODO: Harmonize these

@property (nonatomic, readonly, weak) OutlineScene *currentScene;
- (Line*)currentLine;

- (NSAttributedString*)attributedString;
- (NSArray*)markers;



#pragma mark - Screenplay document data

@property (nonatomic) NSDictionary<NSString*, NSString*>* characterGenders;
@property (nonatomic) NSString *revisionColor;

@property (nonatomic) bool printSceneNumbers;

- (void)setAutomaticTextCompletionEnabled:(BOOL)value;

- (void)bakeRevisions;


#pragma mark - Editing the text content

@property (nonatomic, readonly) BeatTextIO* textActions;

@property (nonatomic, readonly) NSRange lastEditedRange;

// TODO: Remove these and access the text methods only through BeatTextIO

- (void)addString:(NSString*)string atIndex:(NSUInteger)index;
- (void)addString:(NSString*)string atIndex:(NSUInteger)index skipAutomaticLineBreaks:(bool)skipLineBreaks;
- (void)replaceRange:(NSRange)range withString:(NSString*)newString;
- (void)replaceString:(NSString*)string withString:(NSString*)newString atIndex:(NSUInteger)index;
- (void)moveScene:(OutlineScene*)sceneToMove from:(NSInteger)from to:(NSInteger)to;

// TODO: Remove these and only add attributes through the text storage

- (void)removeAttribute:(NSString*)key range:(NSRange)range;
- (void)addAttribute:(NSString*)key value:(id)value range:(NSRange)range;
- (void)addAttributes:(NSDictionary*)attributes range:(NSRange)range;


/// Determines if the text has changed since last query
- (bool)hasChanged;

/// Forces text reformat and editor view updates
- (void)textDidChange:(NSNotification *)notification;

/// Ensures layout of the text view
- (void)ensureLayout;


#pragma mark - Editor item visibility

@property (nonatomic) bool showSceneNumberLabels;
@property (nonatomic) bool showPageNumbers;
@property (nonatomic, readonly) bool showRevisions;
@property (nonatomic, readonly) bool showRevisedTextColor;
@property (nonatomic, readonly) bool showTags;


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
- (void)scrollToScene:(OutlineScene*)scene;
- (void)setTypingAttributes:(NSDictionary*)attrs;


#pragma mark - Plugin access

@property (nonatomic, readonly) NSMutableDictionary* runningPlugins;
@property (nonatomic) BeatPluginAgent* pluginAgent;

#pragma mark - Fonts

@property (nonatomic) BeatFonts* fonts;
/*
@property (readonly, nonatomic) BXFont *courier;
@property (readonly, nonatomic) BXFont *boldCourier;
@property (readonly, nonatomic) BXFont *boldItalicCourier;
@property (readonly, nonatomic) BXFont *italicCourier;
 @property (strong, nonatomic, readonly) BXFont *sectionFont;
 @property (strong, nonatomic, readonly) NSMutableDictionary *sectionFonts;
 @property (strong, nonatomic, readonly) BXFont *synopsisFont;

 */
#if TARGET_OS_IOS
    - (CGFloat)fontSize;
#endif


#pragma mark - Editor flags

@property (nonatomic) bool revisionMode;
@property (nonatomic) bool characterInput;
@property (nonatomic) Line* characterInputForLine;
@property (nonatomic) BeatEditorMode mode;
@property (nonatomic, readonly) bool hideFountainMarkup;

/// Check if the editor tab is visible on macOS
#if !TARGET_OS_IOS
- (bool)editorTabVisible;
#endif


#pragma mark - Pagination

/// Returns the current pagination in preview controller. Typecast this to `BeatPaginationManager`.
- (id)pagination;


#pragma mark - Formatting

@property (nonatomic, readonly) BeatStylesheet* editorStyles;
@property (nonatomic, readonly) BeatStylesheet* styles;
@property (nonatomic, readonly) BeatEditorFormatting* formatting;
- (void)reloadStyles;

- (void)forceFormatChangesInRange:(NSRange)range;
- (void)renderBackgroundForLine:(Line*)line clearFirst:(bool)clear;
- (void)renderBackgroundForLines;
- (void)renderBackgroundForRange:(NSRange)range;

/// Forces line type and formats it. Use only if you know what you are doing.
- (void)setTypeAndFormat:(Line*)line type:(LineType)type;


#pragma mark - Printing stuff for macOS

- (NSAttributedString*)getAttributedText;

#if !TARGET_OS_IOS
- (CGFloat)sidebarWidth;
- (NSPrintInfo*)printInfo;
- (id)document;
- (void)releasePrintDialog;
#endif


#pragma mark - Printing stuff for iOS

#if TARGET_OS_IOS
- (id)documentForDelegation;
- (UIPrintInfo*)printInfo;
- (void)refreshLayoutByExportSettings;
#endif

#if TARGET_OS_IOS
/*
- (UITextRange*)selectedTextRange;
- (void)setSelectedTextRange:(UITextRange*)textRange;
 */
#endif


#pragma mark - Preview

//- (void)updatePreview;
#if !TARGET_OS_IOS
- (id)previewController;
#endif
- (void)invalidatePreview;
- (void)invalidatePreviewAt:(NSInteger)index;


#pragma mark - General editor stuff

- (void)handleTabPress;
- (void)registerEditorView:(id<BeatEditorView>)view;
- (void)registerSceneOutlineView:(id<BeatSceneOutlineView>)view;

- (void)registerSelectionObserver:(id<BeatSelectionObserver>)observer;
- (void)unregisterSelectionObserver:(id<BeatSelectionObserver>)observer;

- (void)toggleMode:(BeatEditorMode)mode;
- (IBAction)toggleSidebar:(id)sender;

// A hack to provide text storage interface to both iOS and macOS ports
- (NSTextStorage*)textStorage;
- (NSLayoutManager*)layoutManager;

- (void)refreshTextView;

@optional

- (void)returnToEditor;
- (void)focusEditor;
- (IBAction)toggleCards:(id)sender;

- (IBAction)nextScene:(id)sender;
- (IBAction)previousScene:(id)sender;

- (void)renameDocumentTo:(NSString *)newName completion:(void (^)(NSError *))completion;

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
