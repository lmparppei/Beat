//
//  BeatDocumentViewController.m
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 18.2.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatDocumentViewController.h"
#import <BeatPagination2/BeatPagination2.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatPlugins/BeatPlugins.h>

#import "BeatEditorFormatting.h"
#import "BeatPreview.h"

#import "Beat-Swift.h"
#import <OSLog/OSLog.h>

@interface BeatDocumentViewController () <KeyboardManagerDelegate, iOSDocumentDelegate, NSTextStorageDelegate, BeatTextIODelegate, BeatPaginationManagerDelegate, BeatPreviewDelegate, BeatExportSettingDelegate, BeatTextEditorDelegate, UINavigationItemRenameDelegate, BeatPluginDelegate>

@property (nonatomic) NSUUID* uuid;
@property (nonatomic, weak) IBOutlet BeatUITextView* textView;
@property (nonatomic, weak) IBOutlet BeatPageView* pageView;
@property (nonatomic) NSString* bufferedText;

@property (nonatomic) bool documentIsLoading;

@property (nonatomic) BeatPreview* preview;
@property (nonatomic) BeatPreviewView* previewView;
@property (nonatomic) bool previewUpdated;
@property (nonatomic) NSTimer* previewTimer;

@property (nonatomic, readonly) bool typewriterMode;
@property (nonatomic, readonly) bool disableFormatting;

@property (nonatomic) NSMutableDictionary* runningPlugins;

@property (nonatomic) BeatPaginationManager *pagination;

@property (atomic) NSAttributedString *attrTextCache;
@property (atomic) NSString *cachedText;
@property (nonatomic) NSString* contentBuffer;

/// The range which was *actually* changed
@property (nonatomic) NSRange lastChangedRange;

/// The range where the *edit* happened
@property (nonatomic) NSRange lastEditedRange;
 
@property (nonatomic) NSMutableSet<id<BeatEditorView>>* registeredViews;
@property (nonatomic) NSMutableSet<id<BeatSceneOutlineView>>* registeredOutlineViews;
@property (nonatomic) NSMutableSet<id<BeatPluginContainer>>* registeredPluginContainers;

@property (nonatomic) bool sidebarVisible;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint* sidebarConstraint;

@property (nonatomic) bool matchParentheses;

@property (strong, nonatomic) BXFont *sectionFont;
@property (strong, nonatomic) NSMutableDictionary *sectionFonts;
@property (strong, nonatomic) BXFont *synopsisFont;

@property (nonatomic) IBOutlet BeatEditorFormatting* formatting;
@property (nonatomic) IBOutlet BeatRevisions* revisionTracking;

@property (nonatomic) IBOutlet BeatReview* review;

@property (nonatomic) Line* previouslySelectedLine;
@property (nonatomic) OutlineScene* currentScene;
@property (nonatomic) NSArray *outline;

@property (nonatomic) BeatTextIO* textActions;

@property (nonatomic) KeyboardManager* keyboardManager;

@property (nonatomic, weak) IBOutlet BeatScrollView* scrollView;
@property (nonatomic, weak) IBOutlet BeatiOSOutlineView* outlineView;
@property (nonatomic, weak) IBOutlet UIView* sidebar;
@property (nonatomic, weak) IBOutlet UINavigationItem* titleBar;

@property (nonatomic) BeatOutlineDataProvider* outlineProvider;

@property (nonatomic) bool hideFountainMarkup;

@property (nonatomic) NSMutableAttributedString* formattedTextBuffer;

@property (nonatomic, weak) IBOutlet UIBarButtonItem* screenplayButton;

@property (nonatomic, weak) NSDictionary* typingAttributes;

//@objc var hideFountainMarkup: Bool = false
@property (nonatomic) bool closing;
@end

@implementation BeatDocumentViewController 

-(instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	if (self) {
		_documentIsLoading = true;
	}
	
	return self;
}

- (BXWindow*)documentWindow {
	return self.view.window;
}

/// Creates the text view and replaces placeholder text view
- (void)createTextView {
	BeatUITextView* textView = [BeatUITextView createTextViewWithEditorDelegate:self frame:CGRectMake(0, 0, self.pageView.frame.size.width, self.pageView.frame.size.height) pageView:self.pageView scrollView:self.scrollView];
	
	textView.inputAccessoryView.translatesAutoresizingMaskIntoConstraints = true;
	
	[self.textView removeFromSuperview];
	self.textView = textView;
	[self.pageView addSubview:self.textView];
		
	self.textView.delegate = self;
	self.textView.editorDelegate = self;
	self.textView.enclosingScrollView = self.scrollView;
	self.textView.scrollEnabled = false;
	
	self.textView.font = self.courier;
	
	[self.textView.textStorage setAttributedString:self.formattedTextBuffer];
}

- (NSUndoManager *)undoManager {
	return self.textView.undoManager;
}

- (void)viewDidLoad {
	/// NOTE: You need to use `loadDocument` before actually presenting the view
	
	[super viewDidLoad];
	
	if (!self.documentIsLoading) return;
	
	// Create text view
	[self createTextView];
	
	// Setup document title menu
	[self setupTitleMenu];
	[self setupScreenplayMenuWithButton:self.screenplayButton];
	
	// Setup navigation item delegate
	self.navigationItem.renameDelegate = self;
	
	// Hide text from view until loaded
	// self.textView.pageView.layer.opacity = 0.0;
	
	// Hide sidebar
	self.sidebarConstraint.constant = 0.0;
	
	self.scrollView.backgroundColor = ThemeManager.sharedManager.marginColor;
	self.textView.backgroundColor = ThemeManager.sharedManager.backgroundColor;
	
	self.formattingActions = [BeatEditorFormattingActions.alloc initWithDelegate:self];
	
	[self setupDocument];
}

-(IBAction)dismissViewController:(id)sender {
	[self unloadViews];
}

- (void)loadDocumentWithCallback:(void (^)(void))callback
{
	[self.document openWithCompletionHandler:^(BOOL success) {
		if (!success) {
			// Do something
			return;
		}
		
		self.parser = [ContinuousFountainParser.alloc initWithString:self.document.rawText delegate:self];
		self.formattedTextBuffer = [NSMutableAttributedString.alloc initWithString:self.document.rawText];
		
		// Load fonts
		[self loadSerifFonts];
		
		BeatEditorFormatting* formatting = [BeatEditorFormatting.alloc initWithTextStorage:self.formattedTextBuffer];
		formatting.delegate = self;
		
		for (Line* line in self.parser.lines) { @autoreleasepool {
			[formatting formatLine:line firstTime:true];
		} }
		[self.parser.changedIndices removeAllIndexes];
				
		callback();
	}];
}

- (void)setupDocument
{
	// Setup revision tracking and reviews
	self.revisionTracking = [BeatRevisions.alloc initWithDelegate:self];
	self.review = [BeatReview.alloc initWithDelegate:self];
	
	self.titleBar.title = self.fileNameString;
	
	self.document.delegate = self;
	//self.contentBuffer = self.document.rawText;
	
	self.formatting = BeatEditorFormatting.new;
	self.formatting.delegate = self;
	
	self.pagination = [BeatPaginationManager.alloc initWithSettings:self.exportSettings delegate:self renderer:nil livePagination:true];
	
	// Init preview
	self.previewView = [self.storyboard instantiateViewControllerWithIdentifier:@"Preview"];
	[self.previewView loadViewIfNeeded];
	self.preview = [BeatPreview.alloc initWithDelegate:self];
	
	// Fit to view here
	self.scrollView.zoomScale = 1.4;
	
	// Keyboard manager
	self.keyboardManager = KeyboardManager.new;
	self.keyboardManager.delegate = self;
	
	// Text I/O
	self.textActions = [BeatTextIO.alloc initWithDelegate:self];
	
	// Text view settings
	self.textView.textStorage.delegate = self;
	[self.textView setFindInteractionEnabled:true];
	
	// Data source
	_outlineProvider = [BeatOutlineDataProvider.alloc initWithDelegate:self tableView:self.outlineView];

	// Restore caret position
	NSInteger position = [self.documentSettings getInt:DocSettingCaretPosition];
	if (position < self.text.length) {
		[self.textView setSelectedRange:NSMakeRange(position, 0)];
		[self.textView scrollToRange:self.textView.selectedRange];
	}
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	
	if (_documentIsLoading) {
		// Loading is complete, show page view
		[_textView layoutIfNeeded];
		
		[_textView.layoutManager invalidateDisplayForCharacterRange:NSMakeRange(0, _textView.text.length)];
		[_textView.layoutManager invalidateLayoutForCharacterRange:NSMakeRange(0, _textView.text.length) actualCharacterRange:nil];
		
		[_textView resize];
		[_textView firstResize];
		[_textView resize];
		
		_documentIsLoading = false;
	}
}

- (IBAction)dismissDocumentViewController:(id)sender
{
	[self unloadViews];
}

- (void)unloadViews
{
	[self.previewView.webview removeFromSuperview];
	self.previewView.webview = nil;
	
	[self.previewView.nibBundle unload];
	self.previewView = nil;
	
	for (id<BeatPluginContainer> container in self.registeredPluginContainers) {
		[container unload];
	}
	[self.registeredPluginContainers removeAllObjects];
	
	[self dismissViewControllerAnimated:true completion:^{
		[self.document closeWithCompletionHandler:nil];
	}];
}


#pragma mark - Text view

- (BXTextView*)getTextView {
	return self.textView;
}
- (CGFloat)editorLineHeight {
	return BeatPagination.lineHeight;
}


#pragma mark - Application data and file access

- (NSString*)fileNameString {
	return _document.fileURL.lastPathComponent.stringByDeletingPathExtension;
}
- (bool)isDark {
	return false;
}
- (void)showLockStatus {
	
}
- (bool)contentLocked {
	return [self.documentSettings getBool:DocSettingLocked];
}

- (BeatDocumentSettings*)documentSettings {
	return self.document.settings;
}


- (NSString*)contentForSaving {
	return [self createDocumentFile];
}
- (NSString*)createDocumentFile {
	return [self createDocumentFileWithAdditionalSettings:nil];
}
- (NSString*)createDocumentFileWithAdditionalSettings:(NSDictionary*)additionalSettings {
	// This puts together string content & settings block. It is returned to dataOfType:
	
	// Save tagged ranges
	// [self saveTags];
	
	// For async saving & thread safety, make a copy of the lines array
	NSAttributedString *attrStr = self.getAttributedText;
	NSString *content = self.parser.screenplayForSaving;
	if (content == nil) {
		NSLog(@"ERROR: Something went horribly wrong, trying to crash the app to avoid data loss.");
		@throw NSInternalInconsistencyException;
	}
	
	// Resort to content buffer if needed
	// if (content == nil) content = self.contentCache;
	
	// Save added/removed ranges
	// This saves the revised ranges into Document Settings
	NSDictionary *revisions = [BeatRevisions rangesForSaving:attrStr];
	[self.documentSettings set:DocSettingRevisions as:(revisions != nil) ? revisions : @{}];
	
	// Save current revision color
	[self.documentSettings setString:DocSettingRevisionColor as:self.revisionColor];
	
	// Save changed indices (why do we need this? asking for myself. -these are lines that had something removed rather than added, a later response)
	[self.documentSettings set:DocSettingChangedIndices as:[BeatRevisions changedLinesForSaving:self.lines]];
	
	// [_documentSettings set:@"Running Plugins" as:self.runningPlugins.allKeys];
	
	// Save reviewed ranges
	NSArray *reviews = [_review rangesForSavingWithString:attrStr];
	[self.documentSettings set:DocSettingReviews as:(reviews != nil) ? reviews : @[]];
	
	// Save caret position
	[self.documentSettings setInt:DocSettingCaretPosition as:self.textView.selectedRange.location];
	
	//[self unblockUserInteraction];
	
	NSString * settingsString = [self.documentSettings getSettingsStringWithAdditionalSettings:additionalSettings];
	NSString * result = [NSString stringWithFormat:@"%@%@", content, (settingsString) ? settingsString : @""];
	
	/*
	 if (_runningPlugins.count) {
	 for (NSString *pluginName in _runningPlugins.allKeys) {
	 BeatPlugin *plugin = _runningPlugins[pluginName];
	 [plugin documentWasSaved];
	 }
	 }
	 */
	
	return result;
}


#pragma mark - Getters for parser data

- (OutlineScene*)currentScene {
	// If we are not on the main thread, return the latest known scene
	if (!NSThread.isMainThread) return _currentScene;
	
	// Check if the cached scene is OK
	NSInteger position = self.selectedRange.location;
	if (_currentScene && NSLocationInRange(position, _currentScene.range)) {
		return _currentScene;
	}
	
	OutlineScene* scene = [self.parser sceneAtPosition:position];
	_currentScene = scene;
	return _currentScene;
}

- (NSArray*)getOutlineItems {
	// Make a copy of the outline to avoid threading issues
	_outline = self.parser.outline.copy;
	return _outline;
}
- (NSArray*)getOutline {
	return [self getOutlineItems];
}

- (NSMutableArray<Line*>*)lines {
	return self.parser.lines;
}

- (NSArray *)scenes {
	return [self getOutlineItems];
}

- (NSArray*)linesForScene:(OutlineScene*)scene {
	return [self.parser linesForScene:scene];
}

- (Line*)lineAt:(NSInteger)index {
	return [self.parser lineAtPosition:index];
}

- (LineType)lineTypeAt:(NSInteger)index {
	return [self.parser lineTypeAt:index];
}

- (Line*)currentLine {
	_previouslySelectedLine = _currentLine;
	
	NSInteger location = self.selectedRange.location;
	if (location >= self.text.length) return self.parser.lines.lastObject;
	
	// Don't fetch the line if we already know it
	if (NSLocationInRange(location, _currentLine.range) && [self.parser.lines containsObject:_currentLine]) return _currentLine;
	else {
		Line *line = [_parser lineAtPosition:location];
		_currentLine = line;
		return _currentLine;
	}
}

- (NSArray*)markers {
	// This could be inquired from the text view, too.
	// Also, rename the method, because this doesn't return actually markers, but marker+scene positions and colors
	NSMutableArray * markers = NSMutableArray.new;
	
	for (Line* line in self.parser.lines) { @autoreleasepool {
		if (line.marker.length == 0 && line.color.length == 0) continue;
		
		NSRange glyphRange = [self.textView.layoutManager glyphRangeForCharacterRange:line.textRange actualCharacterRange:nil];
		CGFloat yPosition = [self.textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textView.textContainer].origin.y;
		CGFloat relativeY = yPosition / [self.textView.layoutManager usedRectForTextContainer:_textView.textContainer].size.height;
		
		if (line.isOutlineElement) [markers addObject:@{ @"color": line.color, @"y": @(relativeY), @"scene": @(true) }];
		else [markers addObject:@{ @"color": line.marker, @"y": @(relativeY) }];
	} }
	
	return markers;
}

- (OutlineScene*)getCurrentSceneWithPosition:(NSInteger)position {
	// If the position is inside the stored current scene, just return that.
	if (_currentScene && NSLocationInRange(position, _currentScene.range)) {
		return _currentScene;
	}
	
	// At the end, return last scene
	if (position >= self.text.length) return self.parser.outline.lastObject;
	
	OutlineScene *prevScene;
	for (OutlineScene *scene in self.outline) {
		if (NSLocationInRange(position, scene.range))  {
			return scene;
		}
		else if (position >= NSMaxRange(prevScene.range) && position < scene.position && prevScene) {
			return prevScene;
		}
		
		prevScene = scene;
	}
	
	return nil;
}

- (OutlineScene*)getPreviousScene {
	NSArray *outline = [self getOutlineItems];
	if (outline.count == 0) return nil;
	
	Line * currentLine = self.currentLine;
	NSInteger lineIndex = [self.parser indexOfLine:currentLine] ;
	if (lineIndex == NSNotFound || lineIndex >= self.parser.lines.count - 1) return nil;
	
	for (NSInteger i = lineIndex - 1; i >= 0; i--) {
		Line* line = self.parser.lines[i];
		
		if (line.type == heading || line.type == section) {
			for (OutlineScene *scene in outline) {
				if (scene.line == line) return scene;
			}
		}
	}
	
	return nil;
}
- (OutlineScene*)getNextScene {
	NSArray *outline = [self getOutlineItems];
	if (outline.count == 0) return nil;
	
	Line * currentLine = self.currentLine;
	NSInteger lineIndex = [self.parser indexOfLine:currentLine] ;
	if (lineIndex == NSNotFound || lineIndex >= self.parser.lines.count - 1) return nil;
	
	for (NSInteger i = lineIndex + 1; i < self.parser.lines.count; i++) {
		Line* line = self.parser.lines[i];
		
		if (line.type == heading || line.type == section) {
			for (OutlineScene *scene in outline) {
				if (scene.line == line) return scene;
			}
		}
	}
	
	return nil;
}


#pragma mark - Sidebar

- (IBAction)toggleSidebar:(id)sender {
	self.sidebarVisible = !self.sidebarVisible;
	
	if (self.sidebarVisible) [self.outlineProvider update];
	
	CGFloat sidebarWidth = (_sidebarVisible) ? 230.0 : 0.0;
	
	[UIView animateWithDuration:0.25 animations:^{
		self.sidebarConstraint.constant = sidebarWidth;
	} completion:^(BOOL finished) {
		[self.textView resize];
	}];
}

#pragma mark - Preview / Pagination

/**
 __N.B.__ / note to self:
 This doesn't really make any sense. This should follow the design pattern of macOS, though written better:
 There, pagination is just a byproduct of previews. This way, once any changes were made (including just attribute changes etc.),
 we can just invalidate the previes at given range and get both for free. Now we're telling this controller to invalidate
 preview, but we're *actually* invalidating pagination.
 
 Correct pattern should be:
 - change made
 - invalidate preview in preview controller
 ... build new pagination
 ... build new preview
 ... BOTH of them are now up to date
 
 We should also allow the pagination to receive a CHANGED RANGE instead of just an index.
 It would allow larger changes to be made, while still supporting caching previous results etc.
 
 */

static bool buildPreviewImmediately = false;
- (IBAction)togglePreview:(id)sender
{
	if (!_previewUpdated) {
		buildPreviewImmediately = true;
		[self paginate];
	} else {
		[self.preview displayPreview];
	}
	
	[self presentViewController:self.previewView animated:true completion:nil];
}

- (void)previewDidFinish
{
	//
}

- (void)paginate
{
	[self paginateWithChangeAt:NSMakeRange(0, 0) sync:true];
}

- (void)paginateWithChangeAt:(NSRange)range sync:(bool)sync
{
	[self.previewTimer invalidate];
	self.preview.previewUpdated = false;
	
	if (sync) {
		NSLog(@"%@", self.pagination);
		[BeatRevisions bakeRevisionsIntoLines:self.parser.lines text:self.getAttributedText];
		[self.pagination newPaginationWithScreenplay:self.parser.forPrinting settings:self.exportSettings forEditor:true changeAt:range.location];
	} else {
		self.previewTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:false block:^(NSTimer * _Nonnull timer) {
			dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 ), ^(void) {
				[BeatRevisions bakeRevisionsIntoLines:self.parser.lines text:self.getAttributedText];
				[self.pagination newPaginationWithScreenplay:self.parser.forPrinting settings:self.exportSettings forEditor:true changeAt:range.location];
			});
		}];
	}
}

- (void)invalidatePreview
{
	// Mark the current preview as invalid
	[self paginateWithChangeAt:NSMakeRange(0, 0) sync:false];
	self.preview.previewUpdated = NO;
}

- (void)invalidatePreviewAt:(NSInteger)index
{
	[self paginateWithChangeAt:NSMakeRange(index, 0) sync:false];
	self.preview.previewUpdated = NO;
}

/// Backwards compatibility
- (void)resetPreview {
	[self invalidatePreviewAt:0];
}

- (void)createPreviewAt:(NSRange)range {
	[self paginateWithChangeAt:range sync:true];
}

- (void)createPreviewAt:(NSRange)range sync:(BOOL)sync {
	[self paginateWithChangeAt:range sync:sync];
}



#pragma mark - Text I/O

- (NSString *)text {
	if (self.textView == nil) return self.formattedTextBuffer.string;
	
	if (NSThread.mainThread) return self.textView.text;
	else return self.attrTextCache.string;
}
- (NSAttributedString*)attributedString {
	return [self getAttributedText];
}
- (NSAttributedString *)getAttributedText
{
	if (NSThread.isMainThread) {
		_attrTextCache = [[NSAttributedString alloc] initWithAttributedString:self.textView.textStorage];
		return _attrTextCache;
	} else {
		return _attrTextCache;
	}
}

// TODO: (Some day) Expose text i/o class to delegate and edit the existing calls to these methods, rather than using this clunky macro.
FORWARD_TO(self.textActions, void, replaceCharactersInRange:(NSRange)range withString:(NSString*)string);
FORWARD_TO(self.textActions, void, addString:(NSString*)string atIndex:(NSUInteger)index);
FORWARD_TO(self.textActions, void, addString:(NSString*)string atIndex:(NSUInteger)index skipAutomaticLineBreaks:(bool)skipLineBreaks);
FORWARD_TO(self.textActions, void, replaceRange:(NSRange)range withString:(NSString*)newString);
FORWARD_TO(self.textActions, void, replaceString:(NSString*)string withString:(NSString*)newString atIndex:(NSUInteger)index);
FORWARD_TO(self.textActions, void, removeRange:(NSRange)range);
FORWARD_TO(self.textActions, void, moveStringFrom:(NSRange)range to:(NSInteger)position actualString:(NSString*)string);
FORWARD_TO(self.textActions, void, moveStringFrom:(NSRange)range to:(NSInteger)position);
FORWARD_TO(self.textActions, void, moveScene:(OutlineScene*)sceneToMove from:(NSInteger)from to:(NSInteger)to);
FORWARD_TO(self.textActions, void, removeTextOnLine:(Line*)line inLocalIndexSet:(NSIndexSet*)indexSet);

- (void)removeAttribute:(NSString*)key range:(NSRange)range {
	if (key == nil) return;
	[self.textView.textStorage removeAttribute:key range:range];
}
- (void)addAttribute:(NSString*)key value:(id)value range:(NSRange)range {
	if (value == nil) return;
	[self.textView.textStorage addAttribute:key value:value range:range];
}
- (void)setAttributes:(NSDictionary*)attributes range:(NSRange)range {
	if (attributes == nil) return;
	[self.textView.textStorage setAttributes:attributes range:range];
}
- (void)setTypingAttributes:(NSDictionary*)attrs {
	_typingAttributes = attrs;
	//self.textView.typingAttributes = attrs;
}



#pragma mark - Screenplay document data shorthands

- (NSString*)revisionColor
{
	NSString* revisionColor = [self.documentSettings getString:DocSettingRevisionColor];
	if (revisionColor == nil) revisionColor = BeatRevisions.defaultRevisionColor;
	return revisionColor;
}
- (void)setRevisionColor:(NSString *)revisionColor
{
	if (revisionColor == nil) return;
	[self.documentSettings setString:DocSettingRevisionColor as:revisionColor];
}

- (NSDictionary<NSString*, NSString*>*)characterGenders {
	return [self.documentSettings get:DocSettingCharacterGenders];
}

- (void)setPrintSceneNumbers:(bool)value {
	[BeatUserDefaults.sharedDefaults saveBool:value forKey:BeatSettingPrintSceneNumbers];
}

- (void)setAutomaticTextCompletionEnabled:(BOOL)value {
	// ?
}



#pragma mark - Colors, storylines etc.

- (void)setColor:(NSString *)color forLine:(Line *)line {
	if (line == nil) return;
	
	// First replace the existing color range (if it exists)
	if (line.colorRange.length > 0) {
		NSRange localRange = line.colorRange;
		NSRange globalRange = [line globalRangeFromLocal:localRange];
		[self removeRange:globalRange];
	}
	
	// Do nothing else if color is set to none
	if ([color.lowercaseString isEqualToString:@"none"]) return;
	
	// Create color string and add a space at the end of heading if needed
	NSString *colorStr = [NSString stringWithFormat:@"[[%@]]", color.lowercaseString];
	if ([line.string characterAtIndex:line.string.length - 1] != ' ') {
		colorStr = [NSString stringWithFormat:@" %@", colorStr];
	}
	
	[self addString:colorStr atIndex:NSMaxRange(line.textRange)];
}

- (void)setColor:(NSString *)color forScene:(OutlineScene *) scene {
	if (scene == nil) return;
	[self setColor:color forLine:scene.line];
}

- (void)addStoryline:(NSString*)storyline to:(OutlineScene*)scene {
	NSMutableArray *storylines = scene.storylines.copy;
	
	// Do nothing if the storyline is already there
	if ([storylines containsObject:storyline]) return;
	
	if (storylines.count > 0) {
		// If the scene already has any storylines, we'll have to add the beat somewhere.
		// Check if scene heading has note ranges, and if not, add it. Otherwise stack into that range.
		if (!scene.line.beatRanges.count) {
			// No beat note in heading yet
			NSString *beatStr = [Storybeat stringWithStorylineNames:@[storyline]];
			beatStr = [@" " stringByAppendingString:beatStr];
			[self addString:beatStr atIndex:NSMaxRange(scene.line.textRange)];
		} else {
			NSMutableArray <Storybeat*>*beats = scene.line.beats.mutableCopy;
			NSRange replaceRange = beats.firstObject.rangeInLine;
			
			// This is fake storybeat object to handle the string creation correctly.
			[beats addObject:[Storybeat line:scene.line scene:scene string:storyline range:replaceRange]];
			NSString *beatStr = [Storybeat stringWithBeats:beats];
			
			[self replaceRange:[scene.line globalRangeFromLocal:replaceRange] withString:beatStr];
		}
		
	} else {
		// There are no storylines yet. Create a beat note and add it at the end of scene heading.
		NSString *beatStr = [Storybeat stringWithStorylineNames:@[storyline]];
		beatStr = [@" " stringByAppendingString:beatStr];
		[self addString:beatStr atIndex:NSMaxRange(scene.line.textRange)];
	}
}

- (void)removeStoryline:(NSString*)storyline from:(OutlineScene*)scene {
	// This is unnecessarily complicated.
	
	NSMutableArray *storylines = scene.storylines.copy;
	
	if (storylines.count > 0) {
		if ([storylines containsObject:storyline]) 		// Is the storyline really there?
		{
			if (storylines.count - 1 <= 0) {
				// No storylines left. Clear ALL storyline notes.
				for (Line *line in [self.parser linesForScene:scene]) {
					[self removeTextOnLine:line inLocalIndexSet:line.beatRanges];
				}
			}
			else {
				// Find the specified beat note
				Line *lineWithBeat;
				for (Line *line in [self.parser linesForScene:scene]) {
					if ([line hasBeatForStoryline:storyline]) {
						lineWithBeat = line;
						break;
					}
				}
				if (!lineWithBeat) return;
				
				NSMutableArray *beats = lineWithBeat.beats.mutableCopy;
				Storybeat *beatToRemove = [lineWithBeat storyBeatWithStoryline:storyline];
				[beats removeObject:beatToRemove];
				
				// Multiple beats can be tucked into a single note. Store the other beats.
				NSMutableArray *stackedBeats = NSMutableArray.new;
				for (Storybeat *beat in beats) {
					if (NSEqualRanges(beat.rangeInLine, beatToRemove.rangeInLine)) [stackedBeats addObject:beat];
				}
				
				// If any beats were left, recreate the beat note with the leftovers.
				// Otherwise, just remove it.
				NSString *beatStr = @"";
				if (stackedBeats.count) beatStr = [Storybeat stringWithBeats:stackedBeats];
				
				NSRange removalRange = beatToRemove.rangeInLine;
				[self replaceRange:[lineWithBeat globalRangeFromLocal:removalRange] withString:beatStr];
			}
		}
	}
}

- (void)addAttributes:(NSDictionary*)attributes range:(NSRange)range {
	if (attributes == nil) return;
	[self.textView.textStorage addAttributes:attributes range:range];
}


#pragma mark - Text view delegation

/// The main method where changes are parsed
- (void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta
{
	if (self.documentIsLoading) return;
	else if (self.formatting.didProcessForcedCharacterCue) return;
	
	// Don't parse anything when editing attributes
	if (editedMask == NSTextStorageEditedAttributes) {
		return;
	}
	else if (editedMask & NSTextStorageEditedCharacters) {
		// First store the edited range and register possible changes to the text
		self.lastEditedRange = NSMakeRange(editedRange.location, delta);
		
		// Register changes
		if (_revisionMode && _lastChangedRange.location != NSNotFound) {
			[self.revisionTracking registerChangesWithLocation:editedRange.location length:_lastChangedRange.length delta:delta];
		}
	}
	
	NSRange affectedRange = NSMakeRange(NSNotFound, 0);
	NSString* string = @"";
	
	if (editedRange.length == 0 && delta < 0) {
		// Single removal. Note that delta is NEGATIVE.
		NSRange removedRange = NSMakeRange(editedRange.location, labs(delta));
		affectedRange = removedRange;
	}
	else if (editedRange.length > 0 && labs(delta) >= 0) {
		// Something was replaced.
		NSRange addedRange = editedRange;
		NSRange replacedRange;
		
		// Handle negative and positive delta
		if (delta <= 0) replacedRange = NSMakeRange(editedRange.location, editedRange.length + labs(delta));
		else replacedRange =  NSMakeRange(editedRange.location, editedRange.length - labs(delta));
		
		affectedRange = replacedRange;
		string = [self.text substringWithRange:addedRange];
	}
	else {
		// Something was added.
		if (delta > 1) {
			// Longer addition
			NSRange addedRange = editedRange;
			NSRange replacedRange = NSMakeRange(editedRange.location, editedRange.length - labs(delta));
			affectedRange = replacedRange;
			
			string = [self.text substringWithRange:addedRange];
		}
		else {
			// Single addition
			NSRange addedRange = NSMakeRange(editedRange.location, delta);
			affectedRange = NSMakeRange(editedRange.location, 0);
			string = [self.text substringWithRange:addedRange];
		}
	}
	
	if (affectedRange.length == 0 && self.currentLine == self.characterInputForLine && self.characterInput) {
		string = string.uppercaseString;
	}
	
	[self.parser parseChangeInRange:affectedRange withString:string];
	
}

-(void)textViewDidChangeSelection:(UITextView *)textView {
	if (self.characterInputForLine != nil && self.currentLine != self.characterInputForLine) {
		NSLog(@"Current line: %@", self.currentLine);
		self.characterInput = false;
		self.characterInputForLine = nil;
	}
	
	[self.textView updateAssistingViews];
	
	if (self.outlineView.visible) [self.outlineView update];
	
	[self.textView scrollRangeToVisible:textView.selectedRange];
	
	// Show review if needed
	// Review items
	if (self.textView.text.length > 0 && self.selectedRange.location < self.text.length && self.selectedRange.location != NSNotFound) {
		NSInteger pos = self.selectedRange.location;
		BeatReviewItem *reviewItem = [self.textStorage attribute:BeatReview.attributeKey atIndex:pos effectiveRange:nil];
		if (reviewItem && !reviewItem.emptyReview) {
			[_review showReviewIfNeededWithRange:NSMakeRange(pos, 0) forEditing:NO];
			//[self.textView.window makeFirstResponder:self.textView];
		} else {
			[_review closePopover];
		}
	}
}

/// Forces text reformat and editor view updates
- (void)textDidChange:(NSNotification *)notification {
	// Faux method for protocol compatibility
	[self textViewDidChange:self.textView];
}

-(void)textViewDidChange:(UITextView *)textView {
	if (_lastChangedRange.location == NSNotFound) _lastChangedRange = NSMakeRange(0, 0);
	_attrTextCache = textView.attributedText;
	
	// If we are just opening the document, do nothing
	if (_documentIsLoading) return;
	
	// Register changes
	//if (_revisionMode) [self.revisionTracking registerChangesInRange:_lastChangedRange];
	
	// Save
	[self.document updateChangeCount:UIDocumentChangeDone];
	
	// Update formatting
	[self applyFormatChanges];
	
	// NOTE: calling this method removes the outline changes from parser
	OutlineChanges* changesInOutline = self.parser.changesInOutline;
	
	if (changesInOutline.hasChanges) {
		// Update any outline views
		if (self.sidebarVisible) [self.outlineProvider update];
	}
	
	// Editor views can register themselves and have to conform to BeatEditorView protocol,
	// which includes methods for reloading both in sync and async
	for (id<BeatEditorView> view in _registeredViews.allObjects) {
		if (view.visible) [view reloadInBackground];
	}
	
	// Paginate
	[self paginateWithChangeAt:_lastChangedRange sync:false];
	
	// If this was an undo operation, scroll to where the alteration was made
	if (self.undoManager.isUndoing) {
		[self.textView scrollRangeToVisible:_lastChangedRange];
	}
	
	// Reset last changed range
	_lastChangedRange = NSMakeRange(NSNotFound, 0);
	
	[self.textView resize];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
	// We won't allow tabs to be inserted
	if ([text isEqualToString:@"\t"]) {
		[self handleTabPress];
		return false;
	}
	
	Line* currentLine = self.currentLine;
	
	// Handle backspaces with forced cues
	if (range.length == 1 && [text isEqualToString:@""] && self.characterInput && !self.undoManager.isUndoing && !self.undoManager.isRedoing) {
		[self.textView cancelCharacterInput];
		return NO;
	}
	
	if ([text isEqualToString:@"\n"]) {
		// Process line break after a forced character input
		if (_characterInput && _characterInputForLine) {
			// If the cue is empty, reset it
			if (_characterInputForLine.string.length == 0) {
				_characterInputForLine.type = empty;
				[_formatting formatLine:_characterInputForLine];
			} else {
				_characterInputForLine.forcedCharacterCue = YES;
			}
		}
	}
	
	if (!self.undoManager.isUndoing && !self.undoManager.isRedoing && self.selectedRange.length == 0 && currentLine != nil) {
		// Test if we'll add extra line breaks and exit the method
		if (range.length == 0 && [text isEqualToString:@"\n"]) {
			bool shouldAddLineBreak = [self.textActions shouldAddLineBreaks:currentLine range:range];
			if (shouldAddLineBreak) return false;
		}
	}
	else if (self.matchParentheses) {
		// If something is being inserted, check whether it is a "(" or a "[[" and auto close it
		[self.textActions matchParenthesesIn:range string:text];
	}
	else if ([self.textActions shouldJumpOverParentheses:text range:range]) {
		// Jump over already-typed parentheses and other closures
		return false;
	}
	
	_lastChangedRange = (NSRange){ range.location, text.length };
	
	return true;
}


#pragma mark - User default shorthands

- (bool)matchParentheses {
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingMatchParentheses];
}
- (void)setMatchParentheses:(bool)matchParentheses {
	[BeatUserDefaults.sharedDefaults saveBool:matchParentheses forKey:BeatSettingMatchParentheses];
}

- (bool)showRevisions {
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowRevisions];
}
- (void)setShowRevisions:(bool)showRevisions {
	[BeatUserDefaults.sharedDefaults saveBool:showRevisions forKey:BeatSettingShowRevisions];
	[self refreshTextViewLayoutElements];
}

- (bool)showPageNumbers {
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowPageNumbers];
}
- (void)setShowPageNumbers:(bool)showPageNumbers {
	[BeatUserDefaults.sharedDefaults saveBool:showPageNumbers forKey:BeatSettingShowPageNumbers];
	[self refreshTextViewLayoutElements];
}

- (bool)showSceneNumberLabels {
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowSceneNumbers];
}
-(void)setShowSceneNumberLabels:(bool)showSceneNumberLabels {
	[BeatUserDefaults.sharedDefaults saveBool:showSceneNumberLabels forKey:BeatSettingShowSceneNumbers];
	[self refreshTextViewLayoutElements];
}

- (NSInteger)spaceBeforeHeading {
	return [BeatUserDefaults.sharedDefaults getInteger:BeatSettingSceneHeadingSpacing];
}

- (bool)printSceneNumbers {
	return self.showSceneNumberLabels;
}

- (bool)showRevisedTextColor {
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowRevisedTextColor];
}


#pragma mark - Document setting shorthands

- (BeatPaperSize)pageSize {
	BeatPaperSize pageSize = [self.documentSettings getInt:DocSettingPageSize];
	return pageSize;
}
- (void)setPageSize:(BeatPaperSize)pageSize {
	[self.documentSettings setInt:DocSettingPageSize as:pageSize];
	[self.textView resize];
}

- (NSInteger)sceneNumberingStartsFrom {
	return [self.documentSettings getInt:DocSettingSceneNumberStart];
}

- (void)setSceneNumberingStartsFrom:(NSInteger)number {
	[self.documentSettings setInt:DocSettingSceneNumberStart as:number];
}



#pragma mark - Export options

- (BeatExportSettings*)exportSettings  {
	BeatExportSettings* settings = [BeatExportSettings operation:ForPreview delegate:self];
	
	return settings;
}


#pragma mark - Editor text view values

- (CGFloat)documentWidth { return self.textView.documentWidth; }
- (CGFloat)magnification { return _textView.enclosingScrollView.zoomScale; }

- (NSRange)selectedRange { return self.textView.selectedRange; }
- (void)setSelectedRange:(NSRange)range { [self setSelectedRange:range withoutTriggeringChangedEvent:NO]; }
- (UITextRange*)selectedTextRange { return self.textView.selectedTextRange; }
- (void)setSelectedTextRange:(UITextRange*)textRange { self.textView.selectedTextRange = textRange; }

/// Set selected range but with the option to opt out of  the didChangeSelection: event
- (void)setSelectedRange:(NSRange)range withoutTriggeringChangedEvent:(bool)triggerChangedEvent {
	_skipSelectionChangeEvent = triggerChangedEvent;
	
	@try {
		[self.textView setSelectedRange:range];
	}
	@catch (NSException *e) {
		NSLog(@"Selection out of range: %lu, %lu", range.location, range.length);
	}
}


#pragma mark Editor text view helpers

- (void)updateChangeCount:(BXChangeType)change {
	[self.document updateChangeCount:change];
}

- (bool)caretAtEnd {
	return (self.textView.selectedRange.location == self.text.length);
}

- (void)refreshTextViewLayoutElements {
	[self.textView setNeedsDisplay];
}
- (void)refreshTextViewLayoutElementsFrom:(NSInteger)location {
	
}


#pragma mark - Scrolling

- (void)scrollToSceneNumber:(NSString*)sceneNumber {
	// Note: scene numbers are STRINGS, because they can be anything (2B, EXTRA, etc.)
	OutlineScene *scene = [self.parser sceneWithNumber:sceneNumber];
	if (scene != nil) [self scrollToScene:scene];
}
- (void)scrollToScene:(OutlineScene*)scene {
	[self selectAndScrollTo:scene.line.textRange];
}
/// Legacy method. Use selectAndScrollToRange
- (void)scrollToRange:(NSRange)range {
	[self selectAndScrollTo:range];
}

- (void)scrollToRange:(NSRange)range callback:(nullable void (^)(void))callbackBlock {
	// BeatTextView *textView = (BeatTextView*)self.textView;
	// [textView scrollToRange:range callback:callbackBlock];
}

/// Scrolls the given position into view
- (void)scrollTo:(NSInteger)location {
	NSRange range = NSMakeRange(location, 0);
	[self selectAndScrollTo:range];
}
/// Selects the given line and scrolls it into view
- (void)scrollToLine:(Line*)line {
	if (line != nil) [self selectAndScrollTo:line.textRange];
}
/// Selects the line at given index and scrolls it into view
- (void)scrollToLineIndex:(NSInteger)index {
	Line *line = [self.parser.lines objectAtIndex:index];
	if (line != nil) [self selectAndScrollTo:line.textRange];
}
/// Selects the scene at given index and scrolls it into view
- (void)scrollToSceneIndex:(NSInteger)index {
	OutlineScene *scene = [[self getOutlineItems] objectAtIndex:index];
	if (!scene) return;
	
	NSRange range = NSMakeRange(scene.line.position, scene.string.length);
	[self selectAndScrollTo:range];
}

/// Selects the given range and scrolls it into view
- (void)selectAndScrollTo:(NSRange)range {
	[self focusEditor];
	
	self.textView.selectedRange = range;
	[self.textView scrollToRange:range];
}


#pragma mark - Fonts

- (void)loadSerifFonts {
	_courier = BeatFonts.sharedFonts.courier;
	[self loadFont];
}
- (void)loadSansSerifFonts {
	_courier = BeatFonts.sharedSansSerifFonts.courier;
	[self loadFont];
}
- (void)loadFont {
	_boldCourier = BeatFonts.sharedFonts.boldCourier;
	_italicCourier = BeatFonts.sharedFonts.italicCourier;
	_boldItalicCourier = BeatFonts.sharedFonts.boldItalicCourier;
	self.textView.font = _courier;
}

- (BXFont*)sectionFont
{
	if (!_sectionFont) {
		_sectionFont = [BXFont boldSystemFontOfSize:17.0];
	}
	return _sectionFont;
}

- (BXFont*)sectionFontWithSize:(CGFloat)size
{
	// Init dictionary if it's unset
	if (!_sectionFonts) _sectionFonts = NSMutableDictionary.new;
	
	// We'll store fonts of varying sizes on the go, because why not?
	// No, really, why shouldn't we?
	NSString *sizeKey = [NSString stringWithFormat:@"%f", size];
	if (!_sectionFonts[sizeKey]) {
		[_sectionFonts setValue:[BXFont boldSystemFontOfSize:size] forKey:sizeKey];
	}
	
	return (BXFont*)_sectionFonts[sizeKey];
}

- (BXFont*)synopsisFont
{
	if (!_synopsisFont) {
		_synopsisFont = [BXFont systemFontOfSize:11.0];
		
		//NSFontManager *fontManager = [[NSFontManager alloc] init];
		//_synopsisFont = [fontManager convertFont:_synopsisFont toHaveTrait:NSFontItalicTrait];
	}
	return _synopsisFont;
}


#pragma mark - Style getters

- (bool)headingStyleBold {
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingHeadingStyleBold];
}
- (bool)headingStyleUnderline {
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingHeadingStyleUnderlined];
}



#pragma mark - Formatting

- (void)formatAllLines {
	for (Line* line in self.parser.lines) {
		[_formatting formatLine:line];
	}
	[self.parser.changedIndices removeAllIndexes];
}

- (void)formatLine:(Line *)line {
	[self.formatting formatLine:line];
}

- (void)forceFormatChangesInRange:(NSRange)range {
	NSArray* lines = [self.parser linesInRange:range];
	for (Line* line in lines) {
		[_formatting formatLine:line];
	}
}

/// When something was changed, this method takes care of reformatting every line
- (void)applyFormatChanges
{
	//[self.textStorage beginEditing];
	[self.parser.changedIndices enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
		if (idx >= self.parser.lines.count) return;
		[_formatting formatLine:self.parser.lines[idx]];
	}];
	//[self.textStorage endEditing];
	
	[self.parser.changedIndices removeAllIndexes];
	[self.textView setTypingAttributes:self.typingAttributes];
}

- (void)reformatLinesAtIndices:(NSMutableIndexSet *)indices {
	[indices enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
		if (idx < self.parser.lines.count) {
			[self.formatting formatLine:self.parser.lines[idx]];
		}
	}];
}


- (void)renderBackgroundForLine:(Line*)line clearFirst:(bool)clear {
	[self.layoutManager invalidateDisplayForCharacterRange:line.textRange];
}

- (void)renderBackgroundForLines {
}

- (void)renderBackgroundForRange:(NSRange)range {
	[self.layoutManager invalidateDisplayForCharacterRange:range];
}

/// Forces a type on a line and formats it accordingly. Can be abused for doing strange and esoteric stuff.
- (void)setTypeAndFormat:(Line*)line type:(LineType)type {
	line.type = type;
	[_formatting formatLine:line];
}


#pragma mark - Shown revisions

- (NSArray*)shownRevisions {
	NSArray<NSString*>* hiddenRevisions = [self.documentSettings get:@"HiddenRevisions"];
	NSMutableArray* shownRevisions = [NSMutableArray.alloc initWithArray:BeatRevisions.revisionColors];
	if (hiddenRevisions.count > 0) {
		[shownRevisions removeObjectsInArray:hiddenRevisions];
	}
	
	return shownRevisions;
}


#pragma mark - Printing stuff for iOS

- (IBAction)openExportPanel:(id)sender {
	BeatExportViewController* vc = [self.storyboard instantiateViewControllerWithIdentifier:@"ExportPanel"];
	vc.modalPresentationStyle = UIModalPresentationPopover;
	vc.popoverPresentationController.barButtonItem = sender;
	vc.senderButton = sender;
	vc.senderVC = self;
	vc.editorDelegate = self;
	
	[self presentViewController:vc animated:false completion:^{
		
	}];
}

- (id)documentForDelegation {
	return self.document;
}

- (UIPrintInfo*)printInfo {
	return UIPrintInfo.new;
}

#pragma mark - General editor stuff

- (void)handleTabPress {
	if (self.textView.assistantView.numberOfSuggestions > 0) {
		//Select the first one
		[self.textView.assistantView selectItemAt:0];
		return;
	}
	
	[self.formattingActions addCue];
	[self.formatting forceEmptyCharacterCue];
}

-(void)focusEditor {
	[self.textView becomeFirstResponder];
}

- (void)registerEditorView:(id)view {
	if (_registeredViews == nil) _registeredViews = NSMutableSet.new;
	[_registeredViews addObject:view];
}
-(void)registerSceneOutlineView:(id<BeatSceneOutlineView>)view {
	if (_registeredOutlineViews == nil) _registeredOutlineViews = NSMutableSet.new;
	[_registeredViews addObject:view];
}
- (void)registerPluginContainer:(id<BeatPluginContainer>)view {
	if (_registeredPluginContainers == nil) _registeredPluginContainers = NSMutableSet.new;
}

- (void)toggleMode:(BeatEditorMode)mode {
	NSLog(@"• Do additional checks for mode change");
	self.mode = mode;
}

// A hack to provide text storage interface to both iOS and macOS ports
- (NSTextStorage*)textStorage {
	return self.textView.textStorage;
}
- (NSLayoutManager*)layoutManager {
	return self.textView.layoutManager;
}

// @optional - (IBAction)toggleCards:(id)sender;



#pragma mark - For avoiding throttling

- (bool)hasChanged {
	if ([self.text isEqualToString:_bufferedText]) {
		return NO;
	} else {
		_bufferedText = self.text.copy;
		return YES;
	}
}

- (CGFloat)fontSize {
	return 12.0;
}

- (void)bakeRevisions {
	[BeatRevisions bakeRevisionsIntoLines:self.parser.lines text:self.attributedString];
}




#pragma mark - Keyboard manager delegate

// TODO: Move this to the text view

-(void)keyboardWillShowWith:(CGSize)size animationTime:(double)animationTime {
	UIEdgeInsets insets = UIEdgeInsetsMake(0, 0, size.height + 200.0, 0);
	
	[UIView animateWithDuration:0.0 animations:^{
		self.scrollView.contentInset = insets;
		self.outlineView.contentInset = insets;
	} completion:^(BOOL finished) {
		[self.textView resize];
		
		if (self.selectedRange.location == NSNotFound) return;
		
		CGRect rect = [self.textView rectForRangeWithRange:self.selectedRange];
		// Make sure we never hide the selection
		rect.origin.y += 100.0;
		rect.size.height += 24.0;
		CGRect visible = [self.textView convertRect:rect toView:self.scrollView];
		[self.scrollView scrollRectToVisible:visible animated:true];
	}];
}

-(void)keyboardWillHide {
	self.outlineView.contentInset = UIEdgeInsetsZero;
	self.scrollView.contentInset = UIEdgeInsetsZero;
}


#pragma mark - Rename document

-(void)navigationItem:(UINavigationItem *)navigationItem didEndRenamingWithTitle:(NSString *)title
{
	[self.documentBrowser renameDocumentAtURL:self.document.fileURL proposedName:title completionHandler:^(NSURL * _Nullable finalURL, NSError * _Nullable error) {
		if (error) {
			self.titleBar.title = self.document.fileURL.lastPathComponent.stringByDeletingPathExtension;
			return;
		}
		
		[self.document presentedItemDidMoveToURL:finalURL];
	}];
}


#pragma mark - Title menu provider



#pragma mark - Pagination

- (void)paginationDidFinish:(BeatPagination * _Nonnull)operation {
	// Update preview in main thread
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		self.preview.previewUpdated = false;
		
		if (buildPreviewImmediately) {
			[self.preview displayPreview];
		} else {
			// Send back to background thread
			[self.preview updatePreviewAsync];
		}
	});
}


#pragma mark - Minimal plugin support

- (NSUUID *)uuid {
	if (_uuid == nil) _uuid = NSUUID.new;
	return _uuid;
}

- (IBAction)runPlugin:(id)sender
{
	// Get plugin filename from menu item
	//BeatPluginMenuItem *menuItem = (BeatPluginMenuItem*)sender;
	//NSString *pluginName = menuItem.pluginName;
	
	//[self runPluginWithName:pluginName];
}

- (void)runPluginWithName:(NSString*)pluginName {
	os_log(OS_LOG_DEFAULT, "# Run plugin: %@", pluginName);
	
	// See if the plugin is running and disable it if needed
	if (self.runningPlugins[pluginName]) {
		[(BeatPlugin*)self.runningPlugins[pluginName] forceEnd];
		[self.runningPlugins removeObjectForKey:pluginName];
		return;
	}
	
	// Run a new plugin
	BeatPlugin *plugin = [BeatPlugin withName:pluginName delegate:self];
	
	// Null the local variable just in case.
	// If the plugin wishes to stay in memory, it should call registerPlugin:
	plugin = nil;
}

/// Loads and registers a plugin with given code. This is used for injecting plugins into memory, including the console plugin.
- (BeatPlugin*)loadPluginWithName:(NSString*)pluginName script:(NSString*)script
{
	if (self.runningPlugins[pluginName] != nil) return self.runningPlugins[pluginName];
	
	BeatPlugin* plugin = [BeatPlugin withName:pluginName script:script delegate:self];
	return plugin;
}

- (void)call:(NSString*)script context:(NSString*)pluginName {
	BeatPlugin* plugin = [self pluginContextWithName:pluginName];
	[plugin call:script];
}

- (BeatPlugin*)pluginContextWithName:(NSString*)pluginName {
	return self.runningPlugins[pluginName];
}

- (void)runGenericPlugin:(NSString*)script
{
	
}

- (void)registerPlugin:(id)plugin
{
	BeatPlugin *parser = (BeatPlugin*)plugin;
	if (!self.runningPlugins) self.runningPlugins = NSMutableDictionary.new;
	
	self.runningPlugins[parser.pluginName] = parser;
}
- (void)deregisterPlugin:(id)plugin
{
	BeatPlugin *parser = (BeatPlugin*)plugin;
	[self.runningPlugins removeObjectForKey:parser.pluginName];
	parser = nil;
}


- (NSDictionary *)revisedRanges {
	NSDictionary *revisions = [BeatRevisions rangesForSaving:self.getAttributedText];
	return revisions;
}

- (id)getPropertyValue:(NSString *)key {
	return [self valueForKey:key];
}

- (void)setPropertyValue:(NSString *)key value:(id)value {
	[self setValue:value forKey:key];
}


#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([segue.identifier isEqualToString:@"Cards"]) {
		BeatPluginContainerViewController* vc = segue.destinationViewController;
		
		vc.delegate = self;
		vc.pluginName = @"Index Card View";
	}
}


@end
