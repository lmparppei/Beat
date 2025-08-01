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

#import <BeatCore/BeatCompatibility.h>
#import __OS_KIT

#import <TargetConditionals.h>
#import <BeatCore/BeatEditorMode.h>
#import <BeatCore/BeatDocumentDelegate.h>
#import <BeatParsing/BeatParsing.h>

#if TARGET_OS_OSX
@class BeatPreviewController;
#else
@class BeatUITextView;
#endif

typedef void (^BeatChangeListener)(NSRange);

@class NSLayoutManager;
@class NSTextStorage;
@class UITextRange;
@class BeatStylesheet;
@class BeatTextIO;
@class BeatEditorFormatting;
@class BeatPluginAgent;
@class BeatFontSet;
@class BeatTagging;
@class BeatPaginationManager;
@class BeatRevisions;
@class BeatReview;
@class BeatPlugin;

/**
 Protocol for editor views which need to be updated in some cases
*/
@protocol BeatEditorView
- (void)reloadInBackground;
- (void)reloadView;
- (bool)visible;
@end

/**
 Protocol for any views/objects that need to be updated when selection changes
*/
@protocol BeatSelectionObserver
- (void)selectionDidChange:(NSRange)selectedRange;
@end

/**
 TODO: Make the text editor conform to this protocol to avoid tons of editor view calls in the delegate
 */
@protocol BeatTextEditor
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
//- (void)didMoveToScene:(OutlineScene*)scene;
- (void)didMoveToSceneIndex:(NSInteger)index;
@end
 
@protocol BeatEditorDelegate <NSObject, NSCopying, BeatDocumentDelegate>

/// Reverts the editor to given text, including __settings block__.
- (void)revertToText:(NSString*)text;

#pragma mark - Core functionality

@property (nonatomic, readonly) bool documentIsLoading;
@property (atomic, readonly) NSAttributedString *attrTextCache;
@property (nonatomic, readonly) NSUndoManager *undoManager;
@property (nonatomic, readonly) bool disableFormatting;

/// Returns the actual text view for either macOS or iOS.
- (BXTextView*)getTextView;
- (CGFloat)editorLineHeight;

#if TARGET_OS_OSX
@property (weak, readonly) BXWindow* documentWindow;
#endif

- (id)themeManager;
- (void)updateUIColors;

/// Updates theme and reformats necessary lines.
/// @param types A list of types. These are predefined string values, not necessarily actual line type names, so for example `note` and `omit` are used.
- (void)updateThemeAndReformat:(NSArray*)types;


#pragma mark - Application data and file access

- (NSString*)fileNameString;
- (bool)isDark;
- (void)showLockStatus;
- (bool)contentLocked;


#pragma mark - Getters for parser data

@property (nonatomic, readonly, weak) OutlineScene* currentScene;
@property (nonatomic, readonly) Line* currentLine;

- (NSAttributedString*)attributedString;
- (NSAttributedString*)getAttributedText;


#pragma mark - Revisions

@property (nonatomic) NSInteger revisionLevel;
@property (nonatomic) BeatRevisions* revisionTracking;
/// Bakes current revisions into lines
- (void)bakeRevisions;


#pragma mark - Reviews

@property (nonatomic) BeatReview* review;



#pragma mark - Editing the text content

@property (nonatomic, readonly) BeatTextIO* textActions;

@property (nonatomic, readonly) NSRange lastEditedRange;

- (void)removeAttribute:(NSString*)key range:(NSRange)range;
- (void)addAttribute:(NSString*)key value:(id)value range:(NSRange)range;
- (void)addAttributes:(NSDictionary*)attributes range:(NSRange)range;

/// Determines if the text has changed since last query
- (bool)hasChanged;

/// Forces text reformat and editor view updates
- (void)textDidChange:(NSNotification *)notification;

/// Ensures layout of the text view
- (void)ensureLayout;
- (void)updateLayout;

- (void)setAutomaticTextCompletionEnabled:(BOOL)value;


#pragma mark - Editor item visibility

@property (nonatomic) bool showSceneNumberLabels;
@property (nonatomic) bool showPageNumbers;
@property (nonatomic, readonly) bool showRevisions;
@property (nonatomic, readonly) bool showRevisedTextColor;
@property (nonatomic, readonly) bool showTags;

@property (nonatomic) bool printSceneNumbers;


#pragma mark - Tagging

@property (nonatomic, readonly) BeatTagging* tagging;


#pragma mark - Editor text view values

/// Sets and gets the selected range in editor text view
@property (nonatomic, readwrite) NSRange selectedRange;
@property (nonatomic, readonly) CGFloat documentWidth;
@property (nonatomic, readonly) CGFloat magnification;

#pragma mark Editor text view helpers

- (void)updateChangeCount:(BXChangeType)change;
- (void)addToChangeCount;
- (void)scrollToLine:(Line*)line;
- (void)scrollToRange:(NSRange)range;
- (void)scrollToRange:(NSRange)range callback:(void (^)(void))callbackBlock;
- (void)scrollToScene:(OutlineScene*)scene;


#pragma mark - Plugin access

@property (nonatomic, readonly) NSMutableDictionary<NSString*, BeatPlugin*>* runningPlugins;
@property (nonatomic, readonly) NSMutableArray* registeredPluginContainers;
@property (nonatomic) BeatPluginAgent* pluginAgent;

#pragma mark - Fonts

@property (nonatomic) BeatFontSet* fonts;
- (CGFloat)fontScale;
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


#if TARGET_OS_OSX
/// Check if the editor tab is visible on macOS
- (bool)editorTabVisible;
#else
@property (nonatomic) UIKeyModifierFlags inputModifierFlags;
#endif


#pragma mark - Pagination

/// Returns the current pagination in preview controller
- (BeatPaginationManager*)pagination;


#pragma mark - Formatting

@property (nonatomic, readonly) BeatStylesheet* editorStyles;
@property (nonatomic, readonly) BeatStylesheet* styles;
@property (nonatomic, readonly) BeatEditorFormatting* formatting;

/// Forces full reload of editor styles and invalidates preview.
- (void)reloadStyles;
/// Sets the stylesheet and forces full reformatting in editor (and invalidates preview)
- (void)setStylesheetAndReformat:(NSString*)name;
/// Resets all styles
- (void)resetStyles;

/// Forces line type and formats it. Use only if you know what you are doing.
- (void)setTypeAndFormat:(Line*)line type:(LineType)type;


#pragma mark - Printing stuff for macOS

#if TARGET_OS_OSX
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

#if TARGET_OS_OSX
@property (nonatomic, readonly) BeatPreviewController* previewController;
#endif

- (void)invalidatePreview;
- (void)invalidatePreviewAt:(NSInteger)index;
- (void)resetPreview;


#pragma mark - General editor stuff

- (void)registerEditorView:(id<BeatEditorView>)view;
- (void)registerSceneOutlineView:(id<BeatSceneOutlineView>)view;
/// Updates editor views asynchronously (where applicable)
- (void)updateEditorViewsInBackground;

- (void)registerSelectionObserver:(id<BeatSelectionObserver>)observer;
- (void)unregisterSelectionObserver:(id<BeatSelectionObserver>)observer;

- (void)toggleMode:(BeatEditorMode)mode;
- (IBAction)toggleSidebar:(id)sender;

// A hack to provide text storage interface to both iOS and macOS ports
- (NSTextStorage*)textStorage;
- (NSLayoutManager*)layoutManager;

- (void)refreshTextView;

- (bool)sidebarVisible;


#pragma mark - Listeners

- (void)addChangeListener:(void(^)(NSRange))listener owner:(id)owner;
- (void)removeChangeListenersFor:(id)owner;


@optional

/// Switches to main editor view
- (void)returnToEditor;
/// Focuses the text editor
- (void)focusEditor;
/// Displays index cards
- (IBAction)toggleCards:(id)sender;

/// Jump to next scene
- (IBAction)nextScene:(id)sender;
/// Jump to previous scene
- (IBAction)previousScene:(id)sender;

/// iOS method for renaming the document
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
