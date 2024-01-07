//
//  PreviewViewController.m
//  BeatQuickLook
//
//  Created by Lauri-Matti Parppei on 27.5.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

#import "PreviewViewController.h"
#import <BeatCore/BeatCore.h>
#import <BeatParsing/BeatParsing.h>
#import <Quartz/Quartz.h>
#import "Beat-Swift.h"

@interface PreviewViewController () <QLPreviewingController, BeatPreviewManagerDelegate, BeatQuickLookDelegate, BeatExportSettingDelegate>
@property (nonatomic) IBOutlet BeatPreviewController* previewController;
@property (nonatomic) BeatDocumentSettings* settings;
@end

@implementation PreviewViewController

- (NSString *)nibName {
    return @"PreviewViewController";
}

- (void)loadView {
    [super loadView];
    // Do any additional setup after loading the view.
}

/*
 * Implement this method and set QLSupportsSearchableItems to YES in the Info.plist of the extension if you support CoreSpotlight.
 *
- (void)preparePreviewOfSearchableItemWithIdentifier:(NSString *)identifier queryString:(NSString *)queryString completionHandler:(void (^)(NSError * _Nullable))handler {
    
    // Perform any setup necessary in order to prepare the view.
    
    // Call the completion handler so Quick Look knows that the preview is fully loaded.
    // Quick Look will display a loading spinner while the completion handler is not called.

    handler(nil);
}
*/

- (void)preparePreviewOfFileAtURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable))handler
{
	self.document = [BeatDocument.alloc initWithURL:url];
	[self.previewController createPreviewWithChangedRange:NSMakeRange(0, self.text.length) sync:true];
	
    handler(nil);
}

- (ContinuousFountainParser*)parser {
	return self.document.parser;
}

- (BeatExportSettings*)exportSettings
{
	BeatExportSettings* settings = [BeatExportSettings operation:ForQuickLook delegate:self];
	return settings;
}

- (BOOL)previewVisible
{
	return true;
}

- (void)paginationFinished:(BeatPagination * _Nonnull)operation indices:(NSIndexSet * _Nonnull)indices
{
	[self.previewController.scrollView scrollPoint:NSMakePoint(0, 0)];
}

#pragma mark - Styles

- (BeatStylesheet *)editorStyles {
	return BeatStyles.shared.defaultEditorStyles;
}
- (BeatStylesheet *)styles {
	return BeatStyles.shared.defaultStyles;
}


#pragma mark - Delegate methods

// Lol. I should create a separate protocol called BeatDelegate or something, which only delivers the data part of the protocol,
// while BeatEditorDelegate inherits from that and returns the more interactive parts.

-(BeatPaperSize)pageSize {
	return (BeatPaperSize)[self.document.settings getInt:DocSettingPageSize];
}

- (nonnull NSString *)fileNameString {
	return self.document.url.lastPathComponent.stringByDeletingPathExtension;
}

- (void)addAttribute:(NSString *)key value:(id)value range:(NSRange)range {}
- (void)addAttributes:(NSDictionary *)attributes range:(NSRange)range {}
- (void)addStoryline:(NSString *)storyline to:(OutlineScene *)scene {}
- (void)addString:(NSString *)string atIndex:(NSUInteger)index {}
- (void)addString:(NSString *)string atIndex:(NSUInteger)index skipAutomaticLineBreaks:(bool)skipLineBreaks {}
- (NSAttributedString *)attributedString { return nil; }
- (void)bakeRevisions {}


- (bool)caretAtEnd { return false; }
- (bool)contentLocked { return true; }
- (Line *)currentLine { return self.parser.lines.firstObject; }
- (CGFloat)editorLineHeight { return 12.0; }
- (NSTextView *)getTextView { return nil; }
- (bool)hasChanged { return false; }
- (bool)isDark { return false; }
- (NSMutableArray<Line *> *)lines { return self.parser.lines; }
- (NSArray *)linesForScene:(OutlineScene *)scene { return [self.parser linesForScene:scene]; }
- (NSArray *)markers { return @[]; }
- (void)moveScene:(OutlineScene *)sceneToMove from:(NSInteger)from to:(NSInteger)to { }
- (void)removeAttribute:(NSString *)key range:(NSRange)range {}
- (void)removeStoryline:(NSString *)storyline from:(OutlineScene *)scene {}
- (void)replaceRange:(NSRange)range withString:(NSString *)newString {}
- (void)replaceString:(NSString *)string withString:(NSString *)newString atIndex:(NSUInteger)index {}
- (NSArray *)scenes { return self.parser.scenes; }
- (void)scrollToLine:(Line *)line {}
- (void)scrollToRange:(NSRange)range {}
- (void)scrollToRange:(NSRange)range callback:(void (^)(void))callbackBlock {}
- (void)setAutomaticTextCompletionEnabled:(BOOL)value {}
- (void)setColor:(NSString *)color forScene:(OutlineScene *)scene {}
- (void)setTypingAttributes:(NSDictionary *)attrs {}
- (void)showLockStatus {}
- (NSString *)text { return self.parser.rawText; }
- (void)textDidChange:(NSNotification *)notification {}
- (void)updateChangeCount:(NSDocumentChangeType)change {}

- (bool)editorTabVisible { return true; }
- (void)forceFormatChangesInRange:(NSRange)range {}
- (NSAttributedString *)getAttributedText { return self.attributedString; }
- (void)handleTabPress {}
- (void)invalidatePreview {}
- (void)invalidatePreviewAt:(NSInteger)index {}
- (NSLayoutManager *)layoutManager { return nil; }
- (id)pagination { return self.previewController.pagination; }
- (NSPrintInfo *)printInfo { return NSPrintInfo.sharedPrintInfo; }
- (void)registerEditorView:(id<BeatEditorView>)view {}
- (void)registerSceneOutlineView:(id<BeatSceneOutlineView>)view {}
- (void)releasePrintDialog {}
- (void)renderBackgroundForLine:(Line *)line clearFirst:(bool)clear {}
- (void)renderBackgroundForLines {}
- (void)renderBackgroundForRange:(NSRange)range {}
- (void)setTypeAndFormat:(Line *)line type:(LineType)type {}
- (CGFloat)sidebarWidth { return 0.0; }
- (NSTextStorage *)textStorage { return nil; }
- (void)toggleMode:(BeatEditorMode)mode {}
- (NSUUID *)uuid { return NSUUID.new; }

- (void)toggleSidebar:(id)sender {}


- (nonnull NSArray<NSString *> *)shownRevisions {
	return BeatRevisions.revisionColors;
}

-(bool)printSceneNumbers {
	return true;
}

- (NSAttributedString*)attrTextCache {
	return NSAttributedString.new;
}

- (BeatFonts*)fonts { return BeatFonts.sharedFonts; }
- (NSDictionary*)characterGenders { return @{}; }
- (bool)characterInput { return false; }
- (Line*)characterInputForLine { return nil; }
- (OutlineScene*)currentScene { return nil; }
- (NSRange)selectedRange { return NSMakeRange(0, 0); }

@synthesize undoManager;
@synthesize characterGenders;
@synthesize characterInput;
@synthesize characterInputForLine;
@synthesize disableFormatting;
@synthesize documentIsLoading;
@synthesize documentSettings;
@synthesize documentWidth;
@synthesize documentWindow;
@synthesize headingStyleBold;
@synthesize headingStyleUnderline;
@synthesize hideFountainMarkup;
@synthesize lastEditedRange;
@synthesize magnification;
@synthesize mode;
@synthesize pageSize;
@synthesize printSceneNumbers;
@synthesize revisionColor;
@synthesize revisionMode;
@synthesize showPageNumbers;
@synthesize showRevisedTextColor;
@synthesize showRevisions;
@synthesize showSceneNumberLabels;
@synthesize showTags;
@synthesize styles;

@end

