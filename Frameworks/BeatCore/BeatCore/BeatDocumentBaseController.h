//
//  BeatDocumentController.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 7.11.2023.
//
/**
 
 This class aims to be a cross-platform base class for both `Document` (macOS) and `BeatDocumentViewController` (iOS).
 Move **any** overlapping code here when possible, and leave only UI- and OS-specific stuff in the main implementations.
 
 */

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <BeatCore/BeatCompatibility.h>
#import "BeatEditorDelegate.h"

@class BeatStylesheet;
@class BeatTextIO;
@class BeatRevisions;
@class BeatReview;
@class BeatPlugin;
@class BeatEditorFormatting;
@class BeatTagging;
@class BeatPluginAgent;
@class BeatFonts;

@class BeatPaginationManager;
@class BeatPagination;

typedef NS_ENUM(NSInteger, BeatFontType);

@protocol DocumentExports <JSExport>
@property (nonatomic, readonly) ContinuousFountainParser* _Nullable parser;
@property (nonatomic) BeatDocumentSettings * _Nonnull documentSettings;
- (NSMutableArray<Line*>* _Nonnull)lines;
- (NSArray<OutlineScene*>* _Nonnull)outline;
- (NSString* _Nullable)displayName;
@end

@protocol BeatPluginInstance
@property (nonatomic) bool restorable;
@property (nonatomic) NSString* _Nonnull pluginName;
- (void)previewDidFinish:(BeatPagination* _Nullable)operation indices:(NSIndexSet* _Nullable)indices;
@end

/// This is a protocol for the generic preview controller. Because of cross-framework mess, we can't use the actual controller here.
@protocol BeatPreviewControllerInstance
- (id _Nullable)getPagination;
- (void)resetPreview;
- (void)createPreviewWithChangedRange:(NSRange)range sync:(bool)sync;
- (void)invalidatePreviewAt:(NSRange)range;
- (void)renderOnScreen;
@end

#if TARGET_OS_OSX
// macOS
@interface BeatDocumentBaseController:NSDocument <DocumentExports, BeatExportSettingDelegate>
#else
// iOS
@interface BeatDocumentBaseController:UIViewController
#endif


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


#pragma mark - Basic document settings

@property (nonatomic) BeatPaperSize pageSize;
@property (nonatomic) bool printSceneNumbers;
@property (nonatomic) bool showSceneNumberLabels;


#pragma mark - Creating the actual document file

- (NSString* _Nonnull)createDocumentFile;
- (NSString* _Nonnull)createDocumentFileWithAdditionalSettings:(NSDictionary* _Nullable)additionalSettings;


#pragma mark - Parser convenience methods

- (NSMutableArray<Line*>* _Nonnull)lines;


#pragma mark - Identity

/// Returns a unique identifier for this document
@property (nonatomic) NSUUID* _Nonnull uuid;


#pragma mark - Setting getters

- (bool)showRevisedTextColor;


#pragma mark - Registering views

@property (nonatomic) NSMutableSet<id<BeatEditorView>>*  _Nullable registeredViews;
@property (nonatomic) NSMutableSet<id<BeatSceneOutlineView>>*  _Nullable registeredOutlineViews;
@property (nonatomic) NSMutableSet<id<BeatSelectionObserver>>*  _Nullable registeredSelectionObservers;
- (void)registerEditorView:(id<BeatEditorView> _Nonnull)view;
- (void)registerSceneOutlineView:(id<BeatSceneOutlineView> _Nonnull)view;

- (void)registerSelectionObserver:(id<BeatSelectionObserver> _Nonnull)observer;
- (void)unregisterSelectionObserver:(id<BeatSelectionObserver> _Nonnull)observer;

- (void)updateEditorViewsInBackground;
- (void)updateSelectionObservers;
- (void)updateOutlineViewsWithChanges:(OutlineChanges* _Nullable)changes;



#pragma mark - Line lookup

@property (nonatomic) Line* _Nullable previouslySelectedLine;
@property (nonatomic) Line* _Nullable currentLine;
@property (nonatomic, weak) OutlineScene* _Nullable currentScene;
- (OutlineScene* _Nullable)getCurrentSceneWithPosition:(NSInteger)position;


#pragma mark - Text view

/// - note: Override this property in OS class.
@property (nonatomic, weak) IBOutlet BXTextView* _Nullable textView;

/// Skips selection change events when needed. Remember to reset after selection change.
@property (nonatomic) bool skipSelectionChangeEvent;

- (BXTextView* _Nonnull)getTextView;
- (NSTextStorage* _Nonnull)textStorage;
- (NSLayoutManager* _Nonnull)layoutManager;

- (NSRange)selectedRange;
- (void)setSelectedRange:(NSRange)range;
- (void)setSelectedRange:(NSRange)range withoutTriggeringChangedEvent:(bool)triggerChangedEvent;
- (bool)caretAtEnd;
- (void)refreshTextView;


#pragma mark - Text getters and caches

/// Content buffer keeps the text until the text view is initialized
@property (strong, nonatomic) NSString* _Nullable contentBuffer;

- (NSString* _Nullable)text;
- (void)setText:(NSString * _Nonnull)text;

- (NSAttributedString * _Nonnull)getAttributedText;
- (NSAttributedString * _Nonnull)attributedString;
@property (nonatomic) NSString* _Nullable contentCache;
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

@property (nonatomic) BeatFonts* _Nonnull fonts;
@property (nonatomic) bool useSansSerif;
/// Loads the current fonts defined by stylesheet.
- (void)loadFonts;
/// Reloads fonts and performs reformatting if needed.
- (void)reloadFonts;

@property (nonatomic) BeatEditorFormatting* _Nullable formatting;
/// When something was changed, this method takes care of reformatting every line
- (void)applyFormatChanges;
/// Forces reformatting of a range
- (void)forceFormatChangesInRange:(NSRange)range;
/// Redraws backgrounds in given range
- (void)renderBackgroundForRange:(NSRange)range;
/// Renders background for this line range
- (void)renderBackgroundForLine:(Line* _Nonnull)line clearFirst:(bool)clear;
/// Forces a type on a line and formats it accordingly. Can be abused for doing strange and esoteric stuff.
- (void)setTypeAndFormat:(Line* _Nonnull)line type:(LineType)type;
/// A convenience method which reformats lines in given indices
- (void)reformatLinesAtIndices:(NSMutableIndexSet * _Nonnull)indices;
/// Refreshes the backgrounds and foreground revision colors in all lines. The method name is a bit confusing because of legacy reasons.
- (void)renderBackgroundForLines;
/// Returns current default font point size
- (CGFloat)fontSize;


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
@property (nonatomic) NSString* _Nullable revisionColor;

- (void)bakeRevisions;
- (NSDictionary* _Nonnull)revisedRanges;
- (NSArray* _Nonnull)shownRevisions;


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


#pragma mark - Styles

@property (nonatomic) BeatStylesheet* _Nonnull styles;
@property (nonatomic) BeatStylesheet* _Nonnull editorStyles;

- (void)reloadStyles;
- (CGFloat)editorLineHeight;
- (CGFloat)lineHeight;

@end

