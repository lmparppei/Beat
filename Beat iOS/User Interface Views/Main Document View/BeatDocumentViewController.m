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

#import "Beat-Swift.h"
#import <OSLog/OSLog.h>

@interface BeatDocumentViewController () <KeyboardManagerDelegate, BeatPreviewManagerDelegate, iOSDocumentDelegate, NSTextStorageDelegate, BeatTextIODelegate, BeatExportSettingDelegate, BeatTextEditorDelegate, UINavigationItemRenameDelegate, BeatPluginDelegate>

@property (nonatomic, weak) IBOutlet BeatPageView* pageView;
@property (nonatomic) NSString* bufferedText;
@property (nonatomic) BeatUITextView* textView;

@property (nonatomic) BeatPreviewView* previewView;
@property (nonatomic) bool previewUpdated;
@property (nonatomic) NSTimer* previewTimer;

@property (nonatomic, readonly) bool typewriterMode;
@property (nonatomic, readonly) bool disableFormatting;

/// The range which was *actually* changed
@property (nonatomic) NSRange lastChangedRange;

/// Preview controller override
@property (nonatomic) BeatPreviewController* previewController;

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

/// Split view. Defined in storyboard segue.
@property (nonatomic, weak) BeatEditorSplitViewController* editorSplitView;
@property (nonatomic, weak) IBOutlet UIView* splitViewContainer;

@end

@implementation BeatDocumentViewController
@dynamic textView;
@dynamic previewController;

-(instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	if (self) {
		self.documentIsLoading = true;
	}
	
	return self;
}

- (BXWindow*)documentWindow {
	return self.view.window;
}

/// Creates the text view and replaces placeholder text view
- (void)createTextView
{
	if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
		// For iPhone, we'll compact the scroll view
		CGRect f = self.pageView.frame;
		f.size.width = 200.0;
		self.pageView.frame = f;
		self.scrollView.maximumZoomScale = 1.0;
		self.scrollView.minimumZoomScale = 1.0;
	}
	
	NSLog(@"!! SETTING UP TEXT VIEW");
	
	CGRect frame = CGRectMake(0, 0, self.pageView.frame.size.width, self.pageView.frame.size.height);
	BeatUITextView* textView = [BeatUITextView createTextViewWithEditorDelegate:self frame:frame pageView:self.pageView scrollView:self.scrollView];
	
	textView.inputAccessoryView.translatesAutoresizingMaskIntoConstraints = true;
	
	//[self.textView removeFromSuperview];
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

- (void)viewDidLoad
{
	/// NOTE: You need to use `loadDocument` before actually presenting the view
	
	[super viewDidLoad];
	
	if (!self.documentIsLoading) return;
	
	// Setup plugin support
	self.runningPlugins = NSMutableDictionary.new;
	self.pluginAgent = [BeatPluginAgent.alloc initWithDelegate:self];
	
	// Embed the editor split view
	UIStoryboard* sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
	BeatEditorSplitViewController* splitView = [sb instantiateViewControllerWithIdentifier:@"EditorSplitView"];
	splitView.preferredDisplayMode = UISplitViewControllerDisplayModeSecondaryOnly;
	
	[self embed:splitView inView:self.splitViewContainer];
	[splitView loadView];
	
	self.editorSplitView = splitView;
	self.editorSplitView.preferredDisplayMode = UISplitViewControllerDisplayModeSecondaryOnly;

	// Setup the split view
	[self setupEditorViews];
	
	// Create text view
	[self createTextView];
	
	// Setup document title menu (from Swift extension)
	[self setupTitleMenu];
	[self setupScreenplayMenuWithButton:self.screenplayButton];
	
	// Setup navigation item delegate
	self.navigationItem.renameDelegate = self;
		
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
		self.attrTextCache = self.formattedTextBuffer;
		
		// Load fonts
		[self loadSerifFonts];
		
		// Format the document. We'll create a static formatting instance for this operation.
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
	self.titleBar.title = self.fileNameString;
	self.document.delegate = self;
	
	// Setup revision tracking and reviews
	self.revisionTracking = [BeatRevisions.alloc initWithDelegate:self];
	self.review = [BeatReview.alloc initWithDelegate:self];
	
	// Initialize real-time formatting
	self.formatting = BeatEditorFormatting.new;
	self.formatting.delegate = self;
	
	// Init preview view
	self.previewView = [self.storyboard instantiateViewControllerWithIdentifier:@"Preview"];
	[self.previewView loadViewIfNeeded];
	
	// Init preview controller and pagination
	self.previewController = [BeatPreviewController.alloc initWithDelegate:self previewView:self.previewView];
	[self.previewController createPreviewWithChangedRange:NSMakeRange(0,1) sync:true];
	
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
	
	// Don't ask
	[self.textView resize];
	[self.textView firstResize];
	[self.textView resize];
	
	// Data source
	_outlineProvider = [BeatOutlineDataProvider.alloc initWithDelegate:self tableView:self.outlineView];
	
	// Setup outline view
	self.outlineView = (BeatiOSOutlineView*)_editorSplitView.sidebar.tableView;
	self.outlineView.editorDelegate = self;
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
	
	if (self.documentIsLoading) {
		// Loading is complete, show page view
		[self.textView layoutIfNeeded];
		
		[self.textView.layoutManager invalidateDisplayForCharacterRange:NSMakeRange(0, self.textView.text.length)];
		[self.textView.layoutManager invalidateLayoutForCharacterRange:NSMakeRange(0, self.textView.text.length) actualCharacterRange:nil];
		
		// This is not a place of honor. No highly esteemed deed is commemorated here.
		[self.textView resize];
		[self.textView firstResize];
		[self.textView resize];
		
		self.documentIsLoading = false;
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

- (void)ensureLayout
{
	[self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
	
	[self.textView setNeedsDisplay];
	[self.textView setNeedsLayout];
}


#pragma mark - Text view

- (BXTextView*)getTextView {
	return self.textView;
}
- (CGFloat)editorLineHeight {
	return self.editorStyles.page.lineHeight;
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


#pragma mark - Getters for parser data
/**
 
 These shouldn't exist to be honest, save for maybe `currentScene`. This is mostly a backwards-compatibility thing, and any new classes should target the parser methods directly.
 
 */

- (NSArray*)markers {
	// This could be inquired from the text view, too.
	// Also, rename the method, because this doesn't return actually markers, but marker+scene positions and colors
	NSMutableArray * markers = NSMutableArray.new;
	
	for (Line* line in self.parser.lines) { @autoreleasepool {
		if (line.marker.length == 0 && line.color.length == 0) continue;
		
		NSRange glyphRange = [self.textView.layoutManager glyphRangeForCharacterRange:line.textRange actualCharacterRange:nil];
		CGFloat yPosition = [self.textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textView.textContainer].origin.y;
		CGFloat relativeY = yPosition / [self.textView.layoutManager usedRectForTextContainer:self.textView.textContainer].size.height;
		
		if (line.isOutlineElement) [markers addObject:@{ @"color": line.color, @"y": @(relativeY), @"scene": @(true) }];
		else [markers addObject:@{ @"color": line.marker, @"y": @(relativeY) }];
	} }
	
	return markers;
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
	
	
	if (self.editorSplitView.displayMode == UISplitViewControllerDisplayModeSecondaryOnly) {
		[self.editorSplitView showColumn:UISplitViewControllerColumnPrimary];
	} else {
		[self.editorSplitView hideColumn:UISplitViewControllerColumnPrimary];
	}
}

- (bool)sidebarVisible
{
	return self.editorSplitView.displayMode != UISplitViewControllerDisplayModeSecondaryOnly;
}


#pragma mark - Preview / Pagination

- (IBAction)togglePreview:(id)sender
{
	[self presentViewController:self.previewView animated:true completion:nil];
}

- (void)previewDidFinish
{
	//
}

- (bool)previewVisible
{
	return self.presentedViewController == self.previewView;
}


#pragma mark - Text I/O

- (NSString *)text {
	if (self.textView == nil) return self.formattedTextBuffer.string;
	
	if (NSThread.isMainThread) return self.textView.text;
	else return self.attrTextCache.string;
}


// TODO: Move this to text view somehow
- (void)setTypingAttributes:(NSDictionary*)attrs {
	_typingAttributes = attrs;
	//self.textView.typingAttributes = attrs;
}

- (void)setAutomaticTextCompletionEnabled:(BOOL)value {
	// Does nothing on iOS for now
}


#pragma mark - Text view delegation

/// The main method where changes are parsed.
/// - note: This is different from macOS, where changes are parsed in text view delegate method `shouldChangeText`, meaning they get parsed before anything is actually added to the text view. Changes on iOS are parsed **after** text has hit the text storage, which can cause some headache.
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
		self.characterInput = false;
		self.characterInputForLine = nil;
	}
	
	// Update outline view
	if (self.outlineView.visible) [self.outlineView update];
	
	// Update text view input view and scroll range to visible
	[self.textView updateAssistingViews];
	[self.textView scrollRangeToVisible:textView.selectedRange];
	
	// Update plugins
	[self.pluginAgent updatePluginsWithSelection:textView.selectedRange];
	
	// Show review if needed
	// Review items
	if (self.textView.text.length > 0 && self.selectedRange.location < self.text.length && self.selectedRange.location != NSNotFound) {
		NSInteger pos = self.selectedRange.location;
		BeatReviewItem *reviewItem = [self.textStorage attribute:BeatReview.attributeKey atIndex:pos effectiveRange:nil];
		if (reviewItem && !reviewItem.emptyReview) {
			[self.review showReviewIfNeededWithRange:NSMakeRange(pos, 0) forEditing:NO];
			//[self.textView.window makeFirstResponder:self.textView];
		} else {
			[self.review closePopover];
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
	self.attrTextCache = textView.attributedText;
	
	// If we are just opening the document, do nothing
	if (self.documentIsLoading) return;
	
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
	[self.previewController createPreviewWithChangedRange:_lastChangedRange sync:false];
	
	// Update plugins
	[self.pluginAgent updatePlugins:_lastChangedRange];
	
	// If this was an undo operation, scroll to where the alteration was made
	if (self.undoManager.isUndoing) [self.textView scrollRangeToVisible:_lastChangedRange];
	
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
				[self.formatting formatLine:self.characterInputForLine];
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
	[self.textView setNeedsDisplay];
}

- (bool)showPageNumbers {
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowPageNumbers];
}

- (void)setShowPageNumbers:(bool)showPageNumbers {
	[BeatUserDefaults.sharedDefaults saveBool:showPageNumbers forKey:BeatSettingShowPageNumbers];
	[self.textView setNeedsDisplay];
}

- (bool)showSceneNumberLabels {
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingShowSceneNumbers];
}
-(void)setShowSceneNumberLabels:(bool)showSceneNumberLabels {
	[BeatUserDefaults.sharedDefaults saveBool:showSceneNumberLabels forKey:BeatSettingShowSceneNumbers];
	[self.textView setNeedsDisplay];
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

- (void)setPageSize:(BeatPaperSize)pageSize {
	[super setPageSize:pageSize];
	[self.textView resize];
}

- (void)refreshLayoutByExportSettings
{
	// We need to reformat headings
	[self.formatting formatAllLinesOfType:heading];
	[self resetPreview];
}


#pragma mark - Editor text view values

- (CGFloat)documentWidth { return self.textView.documentWidth; }
- (CGFloat)magnification { return self.textView.enclosingScrollView.zoomScale; }


#pragma mark Editor text view helpers

- (void)updateChangeCount:(BXChangeType)change {
	[self.document updateChangeCount:change];
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
	OutlineScene *scene = [self.parser.outline objectAtIndex:index];
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
	_boldCourier = BeatFonts.sharedFonts.boldCourier;
	_italicCourier = BeatFonts.sharedFonts.italicCourier;
	_boldItalicCourier = BeatFonts.sharedFonts.boldItalicCourier;
	
	// a hack for the iPhone
	if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
		_courier = [BeatFonts.sharedFonts.courier fontWithSize:self.mobileFontSize];
		_boldCourier = [BeatFonts.sharedFonts.boldCourier fontWithSize:self.mobileFontSize];
		_italicCourier = [BeatFonts.sharedFonts.italicCourier fontWithSize:self.mobileFontSize];
		_boldItalicCourier = [BeatFonts.sharedFonts.boldItalicCourier fontWithSize:self.mobileFontSize];
	}
}

- (void)loadSansSerifFonts {
	_courier = BeatFonts.sharedSansSerifFonts.courier;
	_boldCourier = BeatFonts.sharedSansSerifFonts.boldCourier;
	_italicCourier = BeatFonts.sharedSansSerifFonts.italicCourier;
	_boldItalicCourier = BeatFonts.sharedSansSerifFonts.boldItalicCourier;
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

- (CGFloat)mobileFontSize
{
	return 14.0;
}


#pragma mark - Style getters

- (bool)headingStyleBold
{
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingHeadingStyleBold];
}
- (bool)headingStyleUnderline
{
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingHeadingStyleUnderlined];
}

- (void)applySettingsAndRefresh
{
	[self.formatting formatAllLinesOfType:heading];
	[self resetPreview];
}


#pragma mark - Formatting

- (void)applyFormatChanges
{
	[super applyFormatChanges];
	
	[self.textView setTypingAttributes:self.typingAttributes];
}


#pragma mark - Printing stuff for iOS

- (IBAction)openExportPanel:(id)sender {
	BeatExportViewController* vc = [self.storyboard instantiateViewControllerWithIdentifier:@"ExportPanel"];
	vc.modalPresentationStyle = UIModalPresentationFormSheet;
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


#pragma mark - For avoiding throttling

- (bool)hasChanged {
	if ([self.text isEqualToString:_bufferedText]) {
		return NO;
	} else {
		_bufferedText = self.text.copy;
		return YES;
	}
}


#pragma mark - Keyboard manager delegate

- (BOOL)textViewShouldEndEditing:(UITextView *)textView {
	/// WELLL.... because of some weird first responder issues, we'll never end editing, he he.
	return false;
}

-(void)keyboardWillShowWith:(CGSize)size animationTime:(double)animationTime {
	CGFloat height = self.textView.enclosingScrollView.zoomScale * (size.height + 15.0);
	UIEdgeInsets insets = UIEdgeInsetsMake(0, 0, height, 0);
	
	[UIView animateWithDuration:animationTime animations:^{
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
		
		[self.scrollView safelyScrollRectToVisible:visible animated:true];
	}];
}

- (BOOL)disablesAutomaticKeyboardDismissal {
	return false;
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



#pragma mark - Minimal plugin support

- (IBAction)runPlugin:(id)sender
{
	// Get plugin filename from menu item
	//BeatPluginMenuItem *menuItem = (BeatPluginMenuItem*)sender;
	//NSString *pluginName = menuItem.pluginName;
	
	//[self runPluginWithName:pluginName];
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
	else if ([segue.identifier isEqualToString:@"ToEditorSplitView"]) {
		self.editorSplitView = segue.destinationViewController;
	}
}

/// @warning This method expects the split view controller to be in place (done in storyboard segue)
- (void)setupEditorViews
{
	self.editorSplitView.editorDelegate = self;
	[self.editorSplitView setupWithEditorDelegate:self];
	
	self.pageView = self.editorSplitView.editorView.pageView;
	self.scrollView = self.editorSplitView.editorView.scrollView;
	
	self.outlineView = self.editorSplitView.outlineView;
}




/*
- (void)paginationDidFinish:(BeatPagination * _Nonnull)operation {
	<#code#>
}

- (void)traitCollectionDidChange:(nullable UITraitCollection *)previousTraitCollection {
	<#code#>
}

- (void)preferredContentSizeDidChangeForChildContentContainer:(nonnull id<UIContentContainer>)container {
	<#code#>
}

- (CGSize)sizeForChildContentContainer:(nonnull id<UIContentContainer>)container withParentContainerSize:(CGSize)parentSize {
	<#code#>
}

- (void)systemLayoutFittingSizeDidChangeForChildContentContainer:(nonnull id<UIContentContainer>)container {
	<#code#>
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(nonnull id<UIViewControllerTransitionCoordinator>)coordinator {
	<#code#>
}

- (void)willTransitionToTraitCollection:(nonnull UITraitCollection *)newCollection withTransitionCoordinator:(nonnull id<UIViewControllerTransitionCoordinator>)coordinator {
	<#code#>
}

- (void)didUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context withAnimationCoordinator:(nonnull UIFocusAnimationCoordinator *)coordinator {
	<#code#>
}

- (void)setNeedsFocusUpdate {
	<#code#>
}

- (BOOL)shouldUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context {
	<#code#>
}

- (void)updateFocusIfNeeded {
	<#code#>
}
*/
 
@end
