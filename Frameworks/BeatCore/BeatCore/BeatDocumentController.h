//
//  BeatDocumentController.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 7.11.2023.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <BeatCore/BeatCompatibility.h>

@class BeatStylesheet;
@class BeatTextIO;
@class BeatRevisions;
@class BeatReview;
@class BeatPlugin;
@class BeatEditorFormatting;

@protocol DocumentExports <JSExport>
@property (nonatomic, readonly) ContinuousFountainParser* _Nullable parser;
@property (nonatomic) BeatDocumentSettings * _Nullable documentSettings;
- (NSMutableArray<Line*>* _Nonnull)lines;
- (NSArray<OutlineScene*>* _Nonnull)outline;
- (NSString* _Nullable)displayName;
@end

#if TARGET_OS_OSX
// macOS
@interface BeatDocumentController:NSDocument <DocumentExports, BeatExportSettingDelegate>
#else
// iOS
@interface BeatDocumentController:UIViewController
#endif

// Document settings
@property (nonatomic) BeatDocumentSettings* _Nullable documentSettings;
@property (nonatomic) BeatExportSettings* _Nonnull exportSettings;

// Parser
@property (strong, nonatomic) ContinuousFountainParser* _Nullable parser;
/// Returns a copy of the outline
@property (nonatomic) NSArray* _Nonnull outline;


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
- (NSString* _Nonnull)fileNameString;


#pragma mark - Setting getters

- (bool)showRevisedTextColor;


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

@property (nonatomic) BeatEditorFormatting* _Nullable formatting;
/// Formats a single line (might cause a crash if it's not actually part of the screenplay)
- (void)formatLine:(Line* _Nonnull)line;
/// Formats all lines in screenplay
- (void)formatAllLines;
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

#pragma mark - Revisions

@property (nonatomic) IBOutlet BeatRevisions* _Nonnull revisionTracking;
@property (nonatomic) NSString* _Nullable revisionColor;

- (void)bakeRevisions;
- (NSDictionary* _Nonnull)revisedRanges;
- (NSArray* _Nonnull)shownRevisions;


#pragma mark - Reviews

@property (nonatomic) IBOutlet BeatReview* _Nullable review;


#pragma mark - Plugins
// Most of these are just placeholders for OS-specific code.

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

