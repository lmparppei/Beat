//
//  BeatDocumentController.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 7.11.2023.
//
/**
 
 This class aims to be a cross-platform base class for both `Document` (macOS) and `BeatDocumentViewController` (iOS).
 Move **any** overlapping code here when possible, and leave only UI- and OS-specific stuff in the main implementations.
 
 Because of legacy code, macOS uses `Document` directly, rather than `NSViewController`, resulting in a silly target conditional below.
 I'll fix this one day. That day isn't today.
 
 */

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <BeatCore/BeatCompatibility.h>
#import <BeatCore/BeatEditorDelegate.h>

@class BeatStylesheet;
@class BeatTextIO;
@class BeatRevisions;
@class BeatReview;
@class BeatPlugin;
@class BeatEditorFormatting;
@class BeatTagging;
@class BeatPluginAgent;
//@class BeatFonts;
@class BeatFontSet;

@class BeatPaginationManager;
@class BeatPagination;

typedef NS_ENUM(NSInteger, BeatFontType);

@protocol DocumentExports <JSExport>
@property (nonatomic, readonly) ContinuousFountainParser* _Nullable parser;
@property (nonatomic) BeatDocumentSettings * _Nonnull documentSettings;
- (NSArray<OutlineScene*>* _Nonnull)outline;
- (NSString* _Nullable)displayName;

NS_ASSUME_NONNULL_BEGIN
JSExportAs(addAttribute, - (void)addAttribute:(NSString* _Nonnull)key value:(id _Nonnull)value range:(NSRange)range);
JSExportAs(removeAttribute, - (void)removeAttribute:(NSString* _Nonnull)key range:(NSRange)range);
NS_ASSUME_NONNULL_END
@end

@protocol BeatPluginInstance
@property (nonatomic) bool restorable;
@property (nonatomic) NSString* _Nonnull pluginName;
- (void)previewDidFinish:(BeatPagination* _Nullable)operation indices:(NSIndexSet* _Nullable)indices;
@end

@protocol BeatPluginAgentInstance
- (void)updatePlugins:(NSRange)range;
- (void)updatePluginsWithOutline:(NSArray* _Nonnull)outline changes:(OutlineChanges* _Nullable)changes;
@end

/// This is a protocol for the generic preview controller. Because of cross-framework mess, we can't use the actual controller here.
@protocol BeatPreviewControllerInstance
- (id _Nullable)getPagination;
- (void)resetPreview;
- (void)createPreviewWithChangedRange:(NSRange)range sync:(bool)sync;
- (void)invalidatePreviewAt:(NSRange)range;
- (void)renderOnScreen;
@end

/// A placeholder protocol for cross-platform containers
@protocol BeatPluginContainerInstance
@end


#if TARGET_OS_OSX
// macOS
@interface BeatDocumentBaseController:NSDocument <DocumentExports, BeatExportSettingDelegate, BeatDocumentSettingDelegate>
#else
// iOS
@interface BeatDocumentBaseController:UIViewController
#endif

#pragma mark - Loading text

/// Loads the given Beat document string by reading the settings block and returning content. Also sets the content buffer.
- (NSString* _Nullable)readBeatDocumentString:(NSString* _Nullable)text;
/// Reverts the editor to given text
- (void)revertToText:(NSString* _Nullable)text;


#pragma mark - Document settings
@property (nonatomic) BeatDocumentSettings* _Nonnull documentSettings;
@property (nonatomic) BeatExportSettings* _Nonnull exportSettings;

/// macOS only – `true` when loading and initial formatting is still in process
@property (nonatomic) bool documentIsLoading;


#pragma mark - Parser
@property (strong, nonatomic) ContinuousFountainParser* _Nullable parser;
/// Returns a copy of the outline
@property (nonatomic) NSArray* _Nonnull outline;
/// Flag for if character cue input is on/off
@property (nonatomic) bool characterInput;
/// Line on which the input is happening. This is not the best approach, but whatever.
@property (nonatomic) Line* _Nullable characterInputForLine;
@property (nonatomic) NSIndexSet* _Nullable disabledTypes;

- (void)lineWasRemoved:(Line * _Nonnull)line;


#pragma mark - Basic document settings

@property (nonatomic) BeatPaperSize pageSize;
@property (nonatomic) bool printSceneNumbers;
@property (nonatomic) bool showSceneNumberLabels;
@property (nonatomic) bool showPageNumbers;
@property (nonatomic) bool hidePageNumbers;

@property (nonatomic) bool autocomplete;
@property (nonatomic) bool autoLineBreaks;
@property (nonatomic) bool automaticContd;

@property (nonatomic) bool matchParentheses;

- (id _Nonnull)themeManager;


#pragma mark - Creating the actual document file

/// Creates the actual file for saving, which contains the Beat JSON block at the end.
- (NSString* _Nonnull)createDocumentFile;
/// Creates the actual file for saving, which contains the Beat JSON block at the end. You can provide additional settings which are not actually present in the document.
- (NSString* _Nonnull)createDocumentFileWithAdditionalSettings:(NSDictionary* _Nullable)additionalSettings;
/// Returns the string to be stored as the document. After merging together content and settings, the string is returned to `dataOfType:`. If you want to add additional settings at save-time, you can provide them in a dictionary. You can also provide an array for excluded setting keys. This is used especially for version control.
- (NSString* _Nonnull)createDocumentFileWithAdditionalSettings:(NSDictionary* _Nullable)additionalSettings excludingSettings:(NSArray<NSString*>* _Nullable)excludedKeys;


#pragma mark - Identity

/// Returns a unique identifier for this document
@property (nonatomic) NSUUID* _Nonnull uuid;


#pragma mark - Setting getters

@property (nonatomic) bool showRevisions;
@property (nonatomic) bool showRevisedTextColor;


#pragma mark - Handoff

// - (void)setupHandoff;


#pragma mark - Registered views

/// Registered editor views, which might require update when document contents change
@property (nonatomic) NSMutableSet<id<BeatEditorView>>*  _Nullable registeredViews;
/// Registered outline views, which always require update when outline is changed. Invisible views shouldn't be updated.
@property (nonatomic) NSMutableSet<id<BeatSceneOutlineView>>*  _Nullable registeredOutlineViews;
/// Objects which observe changes to selection.
@property (nonatomic) NSMutableSet<id<BeatSelectionObserver>>*  _Nullable registeredSelectionObservers;
/// Views that host plugins
@property (nonatomic) NSMutableArray<id<BeatPluginContainerInstance>>* _Nullable registeredPluginContainers;


#pragma mark - Line lookup

@property (nonatomic) Line* _Nullable previouslySelectedLine;
@property (nonatomic, weak) Line* _Nullable currentLine;
@property (nonatomic, weak) OutlineScene* _Nullable currentScene;
- (OutlineScene* _Nullable)getCurrentSceneWithPosition:(NSInteger)position;


#pragma mark - Updating outline views

- (void)outlineDidUpdateWithChanges:(OutlineChanges* _Nullable)changes;


#pragma mark - Text view

/// - note: Override this property in OS class.
@property (nonatomic, weak) IBOutlet BXTextView* _Nullable textView;

/// Skips selection change events when needed. Remember to reset after selection change.
@property (nonatomic) bool skipSelectionChangeEvent;

- (BXTextView* _Nonnull)getTextView;
- (NSTextStorage* _Nonnull)textStorage;
- (NSLayoutManager* _Nonnull)layoutManager;

/// The last **change** range which was parsed, **not** the last edited range.
@property (nonatomic) NSRange lastChangedRange;

/// Call when editor text changed
- (void)textDidChange;

- (NSRange)selectedRange;
- (void)setSelectedRange:(NSRange)range;
- (void)setSelectedRange:(NSRange)range withoutTriggeringChangedEvent:(bool)triggerChangedEvent;
/// Redraw the text view (OS-agnosticly)
- (void)refreshTextView;

/// Focuses the editor window and text view
- (void)focusEditor;

/// Marks the document as changed
- (void)addToChangeCount;


#pragma mark - Text getters and caches

/// Content buffer keeps the text until the text view is initialized
@property (strong, nonatomic) NSString* _Nullable contentBuffer;

- (NSString* _Nullable)text;
- (void)setText:(NSString * _Nonnull)text;

- (NSAttributedString * _Nonnull)getAttributedText;
- (NSAttributedString * _Nonnull)attributedString;
@property (atomic) NSAttributedString*  _Nullable attrTextCache;


#pragma mark - Text actions

@property (nonatomic, readwrite) IBOutlet BeatTextIO* _Nullable textActions;
- (void)removeAttribute:(NSString* _Nonnull)key range:(NSRange)range;
- (void)addAttribute:(NSString* _Nonnull)key value:(id _Nonnull)value range:(NSRange)range;
- (void)addAttributes:(NSDictionary* _Nonnull)attributes range:(NSRange)range;

NS_ASSUME_NONNULL_BEGIN
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString*)string;
- (void)addString:(NSString*)string atIndex:(NSUInteger)index;
- (void)addString:(NSString*)string atIndex:(NSUInteger)index skipAutomaticLineBreaks:(bool)skipLineBreaks;
- (void)replaceRange:(NSRange)range withString:(NSString*)newString;
- (void)replaceString:(NSString*)string withString:(NSString*)newString atIndex:(NSUInteger)index;
- (void)removeRange:(NSRange)range;
- (void)moveStringFrom:(NSRange)range to:(NSInteger)position actualString:(NSString*)string;
- (void)moveStringFrom:(NSRange)range to:(NSInteger)position;
- (void)moveScene:(OutlineScene*)sceneToMove from:(NSInteger)from to:(NSInteger)to;
- (void)removeTextOnLine:(Line*)line inLocalIndexSet:(NSIndexSet*)indexSet;
NS_ASSUME_NONNULL_END


#pragma mark - Formatting

//@property (nonatomic) BeatFonts* _Nonnull fonts;
@property (nonatomic) BeatFontSet* _Nonnull fonts;
@property (nonatomic) bool useSansSerif;
@property (nonatomic) bool hideFountainMarkup;

/// Loads the current fonts defined by stylesheet.
- (void)loadFonts;
/// Loads fonts with given scale
- (void)loadFontsWithScale:(CGFloat)scale;
/// Reloads fonts and performs reformatting if needed.
- (void)reloadFonts;

@property (nonatomic) BeatEditorFormatting* _Nullable formatting;
/// When something was changed, this method takes care of reformatting every line. Actually done in `BeatEditorFormatting`.
- (void)applyFormatChanges;

/// Forces a type on a line and formats it accordingly. Can be abused for doing strange and esoteric stuff.
- (void)setTypeAndFormat:(Line* _Nonnull)line type:(LineType)type;
/// A convenience method which reformats lines in given indices
- (void)reformatLinesAtIndices:(NSMutableIndexSet * _Nonnull)indices;
/// A convenience method for reformatting all lines. Please note that this does NOT use any sort of concurrency and can be slow on some computers.
- (void)reformatAllLines;
/// Returns current default font point size
- (CGFloat)fontSize;
- (CGFloat)fontScale;


- (void)updateThemeAndReformat:(NSArray* _Nullable)types;


#pragma mark - Preview

@property (nonatomic) id<BeatPreviewControllerInstance> _Nonnull previewController;
@property (nonatomic, readonly) BeatPaginationManager* _Nonnull paginator;
@property (nonatomic, readonly) BeatPaginationManager* _Nonnull pagination;

- (void)paginationFinished:(BeatPagination * _Nonnull)operation indices:(NSIndexSet * _Nonnull)indices pageBreaks:(NSDictionary<NSValue *,NSArray<NSNumber *> *> * _Nonnull)pageBreaks;

- (void)resetPreview;
- (void)invalidatePreview;
- (void)invalidatePreviewAt:(NSInteger)index;
- (void)createPreviewAt:(NSRange)range;
- (void)createPreviewAt:(NSRange)range sync:(BOOL)sync;


#pragma mark - Revisions

@property (nonatomic) IBOutlet BeatRevisions* _Nonnull revisionTracking;
//@property (nonatomic) NSString* _Nullable revisionColor;
/// Current revision level
@property (nonatomic) NSInteger revisionLevel;

- (void)bakeRevisions;
- (NSIndexSet* _Nonnull)shownRevisions;


#pragma mark - Reviews

@property (nonatomic) IBOutlet BeatReview* _Nullable review;


#pragma mark - Tagging

@property (nonatomic) IBOutlet BeatTagging* _Nullable tagging;


#pragma mark - Plugins
// Most of these are just placeholders for OS-specific code.
@property (nonatomic, readwrite) BeatPluginAgent* _Nullable pluginAgent;
@property (nonatomic, readwrite) NSMutableDictionary <NSString*, BeatPlugin*>* _Nullable runningPlugins;
- (NSArray<NSString*>* _Nullable)runningPluginsForSaving;
- (void)documentWasSaved;

/// Plugin method: Gets a property value from host document
- (id _Nullable)getPropertyValue:(NSString * _Nonnull)key;
/// Plugin method: If you really know what you are doing, you can overwrite a property value in host document
- (void)setPropertyValue:(NSString * _Nonnull)key value:(id _Nonnull)value;


#pragma mark - Listeners

@property (nonatomic) NSMutableDictionary<NSValue*, void(^)(NSRange)>* _Nullable changeListeners;
- (void)addChangeListener:(void(^_Nonnull)(NSRange))listener owner:(id _Nonnull)owner;
- (void)removeChangeListenersFor:(id _Nonnull)owner;


#pragma mark - Styles

@property (nonatomic) BeatStylesheet* _Nonnull styles;
@property (nonatomic) BeatStylesheet* _Nonnull editorStyles;

- (void)reloadStyles;
- (void)resetStyles;
- (CGFloat)editorLineHeight;
- (void)forgetStyles;

/// Only sets the stylesheet. Does NOT reload or reformat anything.
- (void)setStylesheet:(NSString* _Nonnull)name;
/// Set stylesheet and refresh everything.
- (void)setStylesheetAndReformat:(NSString * _Nonnull)name;


#pragma mark - Additional data storage

@property (nonatomic) NSMapTable<NSString*, id>* _Nullable additionalData;


@end

