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

#import "BeatiOSFormatting.h"
#import "BeatPreview.h"

#import "Beat_iOS-Swift.h"

@interface BeatDocumentViewController () <KeyboardManagerDelegate, iOSDocumentDelegate, NSTextStorageDelegate, BeatTextIODelegate, BeatPaginationManagerDelegate, BeatPreviewDelegate, BeatExportSettingDelegate, BeatTextEditorDelegate, UINavigationItemRenameDelegate>

@property (nonatomic, weak) IBOutlet BeatUITextView* textView;
@property (nonatomic, weak) IBOutlet BeatPageView* pageView;
@property (nonatomic) NSString* bufferedText;

@property (nonatomic) bool documentIsLoading;

@property (nonatomic) BeatPreview* preview;
@property (nonatomic) BeatPreviewView* previewView;
@property (nonatomic) bool previewUpdated;
@property (nonatomic) NSTimer* previewTimer;

@property (nonatomic) BeatEditorFormattingActions* formattingActions;

@property (weak, readonly) BXWindow* documentWindow;
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
 
@property (nonatomic) NSMutableArray<id<BeatEditorView>>* registeredViews;

@property (nonatomic) bool sidebarVisible;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint* sidebarConstraint;

@property (nonatomic) bool matchParentheses;

@property (strong, nonatomic) BXFont *sectionFont;
@property (strong, nonatomic) NSMutableDictionary *sectionFonts;
@property (strong, nonatomic) BXFont *synopsisFont;

@property (nonatomic) IBOutlet BeatiOSFormatting* formatting;
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

@property (nonatomic) bool hideFountainMarkup;
//@objc var hideFountainMarkup: Bool = false

@end

@implementation BeatDocumentViewController 

-(instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	if (self) {
		_documentIsLoading = true;
	}
	
	return self;
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
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	if (!self.documentIsLoading) return;
	
	
	// Load fonts
	[self loadSerifFonts];
	// Create text view
	[self createTextView];
	
	// Setup revision tracking
	_revisionTracking = BeatRevisions.new;
	_revisionTracking.delegate = self;
	[_revisionTracking setup];
	
	// Setup navigation item delegate
	self.navigationItem.renameDelegate = self;
		
	// Hide text from view until loaded
	self.textView.pageView.layer.opacity = 0.0;
	
	// Hide sidebar
	self.sidebarConstraint.constant = 0.0;
	
	self.scrollView.backgroundColor = ThemeManager.sharedManager.marginColor;
	self.textView.backgroundColor = ThemeManager.sharedManager.backgroundColor;
	
	self.formattingActions = [BeatEditorFormattingActions.alloc initWithDelegate:self];
	
	[self.document openWithCompletionHandler:^(BOOL success) {
		if (!success) {
			// Do something
			return;
		}
		
		[self setupDocument];
		[self renderDocument];
	}];
}

-(IBAction)dismissViewController:(id)sender {
	[self.previewView.webview removeFromSuperview];
	self.previewView.webview = nil;
	
	[self.previewView.nibBundle unload];
	self.previewView = nil;
	
	[self dismissViewControllerAnimated:true completion:^{
		[self.document closeWithCompletionHandler:nil];
	}];
}

- (void)setupDocument {
	self.titleBar.title = self.fileNameString;
	
	self.document.delegate = self;
	//self.contentBuffer = self.document.rawText;
	
	self.formatting = BeatiOSFormatting.new;
	self.formatting.delegate = self;
	
	self.pagination = [BeatPaginationManager.alloc initWithSettings:self.exportSettings delegate:self renderer:nil livePagination:true];
	
	// Load document into parser
	self.parser = [ContinuousFountainParser.alloc initWithString:self.document.rawText delegate:self];
	
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
	
	// Set text
	self.textView.text = self.document.rawText;
	//[self.revisionTracking loadRevisions];
	
}

- (void)renderDocument {
	[self formatAllLines];
	[self.outlineView reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	
	[_textView resize];
	
	if (_documentIsLoading) {
		// Loading is complete, show page view
		[self.textView.layoutManager invalidateGlyphsForCharacterRange:NSMakeRange(0, self.textView.text.length) changeInLength:0 actualCharacterRange:nil];
		
		[UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
			self.documentIsLoading = false;
			self.textView.pageView.layer.opacity = 1.0;
			
		} completion:^(BOOL finished) {
			
		}];
	}
}

- (IBAction)dismissDocumentViewController:(id)sender {
	[self.previewView.webview removeFromSuperview];
	self.previewView.webview = nil;
	
	[self.previewView.nibBundle unload];
	self.previewView = nil;
	
	[self dismissViewControllerAnimated:YES completion:^{
		[self.document closeWithCompletionHandler:nil];
	}];
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */


#pragma mark -

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

/*
 
 @IBAction func dismissDocumentViewController() {
 self.previewView?.webview?.removeFromSuperview()
 self.previewView?.webview = nil
 
 self.previewView?.nibBundle?.unload()
 self.previewView = nil
 
 dismiss(animated: true) {
 self.document?.close(completionHandler: nil)
 }
 }
 */

#pragma mark - Rename document

- (void)renameDocumentTo:(NSString *)newName completion:(void (^)(NSError *))completion {
	[self.document renameDocumentTo:newName];
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
	
	CGFloat sidebarWidth = (_sidebarVisible) ? 230.0 : 0.0;
	
	[UIView animateWithDuration:0.25 animations:^{
		self.sidebarConstraint.constant = sidebarWidth;
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
- (IBAction)togglePreview:(id)sender {
	if (!_previewUpdated) {
		buildPreviewImmediately = true;
		[self paginate];
	} else {
		[self.preview displayPreview];
	}
	[self presentViewController:self.previewView animated:true completion:nil];
}

- (void)previewDidFinish {
	//
}

- (void)paginate {
	[self paginateWithChangeAt:0 sync:true];
}

- (void)paginateWithChangeAt:(NSInteger)location sync:(bool)sync {
	[self.previewTimer invalidate];
	self.preview.previewUpdated = false;
	
	if (sync) {
		[BeatRevisions bakeRevisionsIntoLines:self.parser.lines text:self.getAttributedText];
		[self.pagination newPaginationWithScreenplay:self.parser.forPrinting settings:self.exportSettings forEditor:true changeAt:location];
	} else {
		self.previewTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:false block:^(NSTimer * _Nonnull timer) {
			dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 ), ^(void) {
				[BeatRevisions bakeRevisionsIntoLines:self.parser.lines text:self.getAttributedText];
				[self.pagination newPaginationWithScreenplay:self.parser.forPrinting settings:self.exportSettings forEditor:true changeAt:location];
			});
		}];
	}
}

- (void)paginationDidFinishWithPages:(NSArray<BeatPaginationPage *> *)pages {
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

- (void)invalidatePreview {
	// Mark the current preview as invalid
	[self paginateWithChangeAt:0 sync:false];
	self.preview.previewUpdated = NO;
}

- (void)invalidatePreviewAt:(NSInteger)index {
	[self paginateWithChangeAt:index sync:false];
	self.preview.previewUpdated = NO;
}


#pragma mark - Text I/O

- (NSString *)text {
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

// TODO: Just add text i/o class to delegate and edit the existing calls to these methods, rather than using this clunky macro.

FORWARD_TO(self.textActions, void, replaceCharactersInRange:(NSRange)range withString:(NSString*)string);
FORWARD_TO(self.textActions, void, addString:(NSString*)string atIndex:(NSUInteger)index);
FORWARD_TO(self.textActions, void, addString:(NSString*)string atIndex:(NSUInteger)index skipAutomaticLineBreaks:(bool)skipLineBreaks);
FORWARD_TO(self.textActions, void, replaceRange:(NSRange)range withString:(NSString*)newString);
FORWARD_TO(self.textActions, void, replaceString:(NSString*)string withString:(NSString*)newString atIndex:(NSUInteger)index);
FORWARD_TO(self.textActions, void, removeRange:(NSRange)range);
FORWARD_TO(self.textActions, void, moveStringFrom:(NSRange)range to:(NSInteger)position actualString:(NSString*)string);
FORWARD_TO(self.textActions, void, moveStringFrom:(NSRange)range to:(NSInteger)position);
FORWARD_TO(self.textActions, void, globalRangeFromLocalRange:(NSRange*)range inLineAtPosition:(NSUInteger)position);
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
	self.textView.typingAttributes = attrs;
}



#pragma mark - Editor actions

- (IBAction)addDialogue:(id)sender {
	
}

- (IBAction)addINT:(id)sender {
	[self.textActions addNewParagraph:@"INT. "];
}

- (IBAction)addEXT:(id)sender {
	[self.textActions addNewParagraph:@"EXT. "];
}

- (IBAction)addCharacterCue:(id)sender {
	[self.formattingActions addCue];
}



#pragma mark - Screenplay document data shorthands

- (NSString*)revisionColor {
	NSString* revisionColor = [self.documentSettings getString:DocSettingRevisionColor];
	if (revisionColor == nil) revisionColor = BeatRevisions.defaultRevisionColor;
	return revisionColor;
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
		NSRange globalRange = [self.textActions globalRangeFromLocalRange:&localRange inLineAtPosition:line.position];
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
			
			[self replaceRange:[self.textActions globalRangeFromLocalRange:&replaceRange inLineAtPosition:scene.line.position] withString:beatStr];
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
				[self replaceRange:[self.textActions globalRangeFromLocalRange:&removalRange inLineAtPosition:lineWithBeat.position] withString:beatStr];
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
- (void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta {
	if (self.documentIsLoading) return;
	
	// Don't parse anything when editing attributes
	if (editedMask == NSTextStorageEditedAttributes) {
		return;
	}
	
	NSRange affectedRange = NSMakeRange(NSNotFound, 0);
	NSString* string = @"";
	
	if (editedRange.length == 0 && delta < 0) {
		// Single removal. Note that delta is NEGATIVE.
		NSRange removedRange = NSMakeRange(editedRange.location, labs(delta));
		affectedRange = removedRange;
	}
	else if (editedRange.length > 0 && delta <= 0) {
		// Something was replaced. Note that delta is NEGATIVE.
		NSRange addedRange = editedRange;
		NSRange replacedRange = NSMakeRange(editedRange.location, editedRange.length + labs(delta));
		
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
	
	[self.parser parseChangeInRange:affectedRange withString:string];
}

/// Forces text reformat and editor view updates
- (void)textDidChange:(NSNotification *)notification {
	// Faux method for protocol compatibility
	[self textViewDidChange:self.textView];
}

-(void)textViewDidChangeSelection:(UITextView *)textView {
	if (self.currentLine != self.characterInputForLine) {
		self.characterInput = false;
		self.characterInputForLine = nil;
	}
	
	[self.textView updateAssistingViews];
}

-(void)textViewDidChange:(UITextView *)textView {
	if (_lastChangedRange.location == NSNotFound) _lastChangedRange = NSMakeRange(0, 0);
	_attrTextCache = textView.attributedText;
	
	// If we are just opening the document, do nothing
	if (_documentIsLoading) return;
	
	// Register changes
	if (_revisionMode) [self.revisionTracking registerChangesInRange:_lastChangedRange];
	
	// Save
	[self.document updateChangeCount:UIDocumentChangeDone];
	
	// Update formatting
	[self applyFormatChanges];
	
	// If outline has changed, we will rebuild outline & timeline if needed
	bool changeInOutline = [self.parser getAndResetChangeInOutline];
	
	// NOTE: calling this method removes the outline changes from parser
	NSSet* changesInOutline = self.parser.changesInOutline;
	
	if (changeInOutline == YES) {
		[self.parser createOutline];
		[self.parser updateOutlineWithChangeInRange:_lastChangedRange];
		/*
		 if (self.sidebarVisible && self.sideBarTabs.selectedTabViewItem == _tabOutline) [self.outlineView reloadOutline:changesInOutline];
		 if (self.timeline.visible) [self.timeline reload];
		 if (self.timelineBar.visible) [self reloadTouchTimeline];
		 if (self.runningPlugins.count) [self updatePluginsWithOutline:self.parser.outline];
		 */
	} else {
		//if (self.timeline.visible) [_timeline refreshWithDelay];
	}
	
	// Editor views can register themselves and have to conform to BeatEditorView protocol,
	// which includes methods for reloading both in sync and async
	for (id<BeatEditorView> view in _registeredViews) {
		if (view.visible) [view reloadInBackground];
	}
	
	// Paginate
	[self paginateWithChangeAt:self.lastChangedRange.location sync:false];
	
	
	// Update any running plugins
	// if (runningPlugins.count) [self updatePlugins:_lastChangedRange];
	
	// Save to buffer
	// _contentCache = self.textView.string.copy;
	
	// Fire up autocomplete at the end of string and create cached lists of scene headings / character names
	// if (self.autocomplete) [self.autocompletion autocompleteOnCurrentLine];
	
	// If this was an undo operation, scroll to where the alteration was made
	if (self.undoManager.isUndoing) {
		//[self.textView scrollToRange:NSMakeRange(_lastChangedRange.location, 0)];
		[self.textView scrollRangeToVisible:_lastChangedRange];
	}
	
	// Reset last changed range
	_lastChangedRange = NSMakeRange(NSNotFound, 0);
	
	[self.textView resize];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
	// We won't allow tabs to be inserted
	if ([text isEqualToString:@"\t"]) return false;
	
	Line* currentLine = self.currentLine;
	
	if (!self.undoManager.isUndoing && !self.undoManager.isRedoing && self.selectedRange.length == 0 && currentLine != nil) {
		if (range.length == 0 && [text isEqualToString:@"\n"]) {
			// Test if we'll add extra line breaks and exit the method
			bool shouldAddLineBreak = [self.textActions shouldAddLineBreaks:currentLine range:range];
			if (shouldAddLineBreak) return false;
		}
	}
	
	// If something is being inserted, check whether it is a "(" or a "[[" and auto close it
	else if (self.matchParentheses) {
		[self.textActions matchParenthesesIn:range string:text];
	}
	
	// Jump over already-typed parentheses and other closures
	else if ([self.textActions shouldJumpOverParentheses:text range:range]) {
		return false;
	}
	
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
	/*
	 BeatTextView *textView = (BeatTextView*)self.textView;
	 [textView setSelectedRange:range];
	 [textView scrollToRange:range callback:nil];
	 */
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

- (void)forceFormatChangesInRange:(NSRange)range {
	NSArray* lines = [self.parser linesInRange:range];
	for (Line* line in lines) {
		[_formatting formatLine:line];
	}
}

/// When something was changed, this method takes care of reformatting every line
- (void)applyFormatChanges
{
	[self.parser.changedIndices enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
		if (idx >= self.parser.lines.count) return;
		[_formatting formatLine:self.parser.lines[idx]];
	}];
	[self.parser.changedIndices removeAllIndexes];
}

- (void)reformatLinesAtIndices:(NSMutableIndexSet *)indices {
	[indices enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
		if (idx < self.parser.lines.count) {
			[self.formatting formatLine:self.parser.lines[idx]];
		}
	}];
}


- (void)renderBackgroundForLine:(Line*)line clearFirst:(bool)clear {
	[_formatting renderBackgroundForLine:line clearFirst:clear];
}

- (void)renderBackgroundForLines {
}

- (void)renderBackgroundForRange:(NSRange)range {
	NSArray* lines = [self.parser linesInRange:range];
	for (Line* line in lines) {
		[_formatting formatLine:line];
	}
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
	}
	
	[self addCharacterCue:nil];
}

- (void)registerEditorView:(id)view {
	if (_registeredViews == nil) _registeredViews = NSMutableArray.new;
	if (![_registeredViews containsObject:view]) [_registeredViews addObject:view];
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
	if ([self.text isEqualToString:_bufferedText]) return NO;
	else {
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

-(void)keyboardWillShowWith:(CGSize)size animationTime:(double)animationTime {
	NSLog(@"Hiehg: %f", size.height);
	UIEdgeInsets insets = UIEdgeInsetsMake(0, 0, size.height, 0);
	
	[UIView animateWithDuration:0.0 animations:^{
		self.scrollView.contentInset = insets;
	} completion:^(BOOL finished) {
		[self.textView resize];
		
		if (self.selectedRange.location == NSNotFound) return;
		
		CGRect rect = [self.textView rectForRangeWithRange:self.selectedRange];
		CGRect visible = [self.textView convertRect:rect toView:self.scrollView];
		[self.scrollView scrollRectToVisible:visible animated:true];
	}];
}

-(void)keyboardWillHide {
	self.scrollView.contentInset = UIEdgeInsetsZero;
}

- (void)paginationDidFinish:(BeatPagination * _Nonnull)operation {
	//NSLog(@"Pagination did finish");
}

-(void)navigationItem:(UINavigationItem *)navigationItem didEndRenamingWithTitle:(NSString *)title {
	if (![title.pathExtension isEqualToString:@"fountain"]) {
		title = [title stringByAppendingString:@".fountain"];
	}
	
	DocumentBrowserViewController* browser = DocumentBrowserViewController.new;
	[browser renameDocumentAtURL:self.document.fileURL proposedName:title completionHandler:^(NSURL * _Nullable finalURL, NSError * _Nullable error) {
		if (error) {
			NSLog(@"ERROR! %@", error);
			return;
		}
		
		[self.document presentedItemDidMoveToURL:finalURL];
	}];
	
	/*
	NSLog(@"Title: %@", title);
	
	[self renameDocumentTo:title completion:^(NSError * error) {
		if (error) {
			NSLog(@"ERROR! %@", error);
		}
	}];
	 */
}

@end
