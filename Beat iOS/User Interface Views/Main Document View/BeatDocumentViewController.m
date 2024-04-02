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

@interface BeatDocumentViewController () <KeyboardManagerDelegate, BeatPreviewManagerDelegate, iOSDocumentDelegate, NSTextStorageDelegate, BeatTextIODelegate, BeatExportSettingDelegate, BeatTextEditorDelegate, UINavigationItemRenameDelegate, BeatPluginDelegate, UITextInputDelegate>

@property (nonatomic, weak) IBOutlet BeatPageView* pageView;
@property (nonatomic) NSString* bufferedText;
@property (nonatomic) BeatUITextView* textView;

@property (nonatomic) BeatPageViewController* previewView;
@property (nonatomic) bool previewUpdated;
@property (nonatomic) NSTimer* previewTimer;

@property (nonatomic, readonly) bool disableFormatting;

/// Preview controller override
@property (nonatomic) BeatPreviewController* previewController;

/// The range where the *edit* happened
@property (nonatomic) NSRange lastEditedRange;
 
@property (nonatomic) bool sidebarVisible;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint* sidebarConstraint;

@property (nonatomic) bool matchParentheses;

@property (nonatomic) KeyboardManager* keyboardManager;

@property (nonatomic, weak) IBOutlet BeatScrollView* scrollView;
@property (nonatomic, weak) IBOutlet BeatiOSOutlineView* outlineView;
@property (nonatomic, weak) IBOutlet UIView* sidebar;

@property (nonatomic) BeatOutlineDataProvider* outlineProvider;

@property (nonatomic) bool hideFountainMarkup;

@property (nonatomic) NSMutableAttributedString* formattedTextBuffer;

@property (nonatomic, weak) NSDictionary* typingAttributes;

//@objc var hideFountainMarkup: Bool = false
@property (nonatomic) bool closing;

/// Split view. Defined in storyboard segue.
@property (nonatomic, weak) BeatEditorSplitViewController* editorSplitView;
@property (nonatomic, weak) IBOutlet UIView* splitViewContainer;

@property (nonatomic, weak) IBOutlet NSLayoutConstraint* topContainerConstraint;

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

/// @warning This method expects the split view controller to be in place (done in storyboard segue)
- (void)setupEditorViews
{
	self.editorSplitView.editorDelegate = self;
	[self.editorSplitView setupWithEditorDelegate:self];
	
	self.pageView = self.editorSplitView.editorView.pageView;
	self.scrollView = self.editorSplitView.editorView.scrollView;
	
	self.outlineView = self.editorSplitView.outlineView;
}

/// Creates the text view and replaces placeholder text view
- (void)createTextView
{
	CGRect frame = CGRectMake(0, 0, self.pageView.frame.size.width, self.pageView.frame.size.height);
	BeatUITextView* textView = [BeatUITextView createTextViewWithEditorDelegate:self frame:frame pageView:self.pageView scrollView:self.scrollView];
	
	textView.inputAccessoryView.translatesAutoresizingMaskIntoConstraints = true;
	
	self.textView = textView;
	self.textView.delegate = self;
	self.textView.editorDelegate = self;
	self.textView.inputDelegate = self;
	
	if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone) {
		self.textView.enclosingScrollView = self.scrollView;
		[self.pageView addSubview:self.textView];
	} else {
		// Completely replace the scroll view with our text view on phones
		self.textView.frame = self.scrollView.frame;
		
		[self.view addSubview:self.textView];
		
		[self.scrollView.superview addSubview:self.textView];
		[self.pageView removeFromSuperview];
		[self.scrollView removeFromSuperview];
	}
	
	self.textView.font = self.fonts.regular;
	
	[self.textView.textStorage setAttributedString:self.formattedTextBuffer];
}

/// Dismisses editor view keyboard
- (IBAction)endEditing:(id)sender
{
	[self.textView endEditing:true];
}

- (NSUndoManager *)undoManager {
	return self.textView.undoManager;
}

/// NOTE: You need to call `loadDocument` before actually presenting the view
- (void)viewDidLoad
{
	[super viewDidLoad];
	
	if (!self.documentIsLoading) return;
	
	self.navigationController.view.backgroundColor = UIColor.systemBackgroundColor;
	
	// Setup plugin support
	self.runningPlugins = NSMutableDictionary.new;
	self.pluginAgent = [BeatPluginAgent.alloc initWithDelegate:self];
	
	// Embed the editor split view
	UIStoryboard* sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
	BeatEditorSplitViewController* splitView = [sb instantiateViewControllerWithIdentifier:@"EditorSplitView"];
	[self embed:splitView inView:self.splitViewContainer];
	[splitView loadView];
	
	self.editorSplitView = splitView;
	
	// Setup the split view
	[self setupEditorViews];
	
	// Create text view
	[self createTextView];
	
	// Setup document title menu (from Swift extension)
	[self setupTitleBar];
	
	// Setup navigation item delegate
	self.navigationItem.renameDelegate = self;
	
	// Hide sidebar
	self.sidebarConstraint.constant = 0.0;
	
	self.scrollView.backgroundColor = ThemeManager.sharedManager.marginColor;
	self.textView.backgroundColor = ThemeManager.sharedManager.backgroundColor;
	
	self.formattingActions = [BeatEditorFormattingActions.alloc initWithDelegate:self];
	
	[self setupDocument];
	
	// Become first responder if text view is empty and scroll to top
	if (self.textView.text.length == 0) [self.textView becomeFirstResponder];
	[self.scrollView scrollRectToVisible:CGRectMake(0.0, 0.0, 300.0, 10.0) animated:false];
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
		
		// Load fonts (iOS is limited to serif courier for now)
		[self loadFonts];
		
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

- (void)setupTitleBar
{
	// Show document name
	self.titleBar.title = self.fileNameString;
	
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


- (void)updateLayout {
	[self ensureLayout];
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
	NSLog(@" -> content");
	return [self createDocumentFile];
}


#pragma mark - Getters for parser data

- (NSArray*)markers
{
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
	if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
		if (self.editorSplitView.sidebar.viewIfLoaded.window) {
			[self.outlineProvider update];
			[self.editorSplitView showColumn:UISplitViewControllerColumnSecondary];
		} else {
			[self.editorSplitView showColumn:UISplitViewControllerColumnPrimary];
		}
		
		return;
	}
	
	// iPad
	if (self.editorSplitView.displayMode == UISplitViewControllerDisplayModeSecondaryOnly) {
		[self.outlineProvider update];
		[self.editorSplitView showColumn:UISplitViewControllerColumnPrimary];
	} else {
		[self.editorSplitView hideColumn:UISplitViewControllerColumnPrimary];
	}
}

- (bool)sidebarVisible
{
	// iPhone
	if (self.editorSplitView.isCollapsed) {
		if (self.editorSplitView.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact) {
			return false;
		} else {
			return true;
		}
	}
	
	// iPad
	return self.editorSplitView.displayMode != UISplitViewControllerDisplayModeSecondaryOnly;
}


#pragma mark - Preview / Pagination

- (IBAction)togglePreview:(id)sender
{
	[self presentViewController:self.previewView animated:true completion:nil];
	[self.previewController renderOnScreen];
	[self.textView scrollToRange:self.textView.selectedRange];
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
		if (self.revisionMode && self.lastChangedRange.location != NSNotFound) {
			[self.revisionTracking registerChangesWithLocation:editedRange.location length:self.lastChangedRange.length delta:delta];
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

-(void)textViewDidChangeSelection:(UITextView *)textView
{
	if (self.characterInputForLine != nil && self.currentLine != self.characterInputForLine) {
		[self.textView cancelCharacterInput];
	}
			
	// If this is not a touch event, scroll to content
	if (self.textView.floatingCursor) return;
	
	[self textViewDidEndSelection:textView selectedRange:textView.selectedRange];
}

/// Called when touch event *actually* changed the selection
- (void)textViewDidEndSelection:(UITextView *)textView selectedRange:(NSRange)selectedRange
{
	[self.textView scrollRangeToVisible:textView.selectedRange];
	
	// Update outline view
	if (self.outlineView.visible) [self.outlineView reloadData];
	
	// Update text view input view and scroll range to visible
	[self.textView updateAssistingViews];

	// Update plugins
	[self.pluginAgent updatePluginsWithSelection:selectedRange];
	
	// Show review if needed
	[self showReviewIfNeeded];
}


/// Forces text reformat and editor view updates
- (void)textDidChange:(NSNotification *)notification {
	// Faux method for protocol compatibility
	[self textViewDidChange:self.textView];
}

// TODO: This can be made OS-agnostic
-(void)textViewDidChange:(UITextView *)textView {
	[super textDidChange];
	
	// If this was an undo operation, scroll to where the alteration was made
	if (self.undoManager.isUndoing) [self.textView scrollRangeToVisible:self.lastChangedRange];
	
	// Reset last changed range
	self.lastChangedRange = NSMakeRange(NSNotFound, 0);

	if (!self.documentIsLoading) [self updateChangeCount:UIDocumentChangeDone];
	
	[self.textView resize];
}

/// Alias for macOS-compatibility
- (BOOL)textView:(BXTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	return [self textView:textView shouldChangeTextInRange:affectedCharRange replacementText:replacementString];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
	// We won't allow tabs to be inserted
	if ([text isEqualToString:@"\t"]) {
		[self handleTabPress];
		return false;
	}
	
	bool undoOrRedo = (self.undoManager.isUndoing || self.undoManager.isRedoing);
	
	Line* currentLine = self.currentLine;
	
	// Process line break after a forced character input
	if ([text isEqualToString:@"\n"] && self.characterInput && self.characterInputForLine) {
		// If the cue is empty, reset it
		if (self.characterInputForLine.length == 0) {
			self.characterInputForLine.type = empty;
			[self.formatting formatLine:self.characterInputForLine];
		} else {
			self.characterInputForLine.forcedCharacterCue = YES;
		}
	}
	
	if (!undoOrRedo && self.selectedRange.length == 0 && currentLine != nil) {
		// Test if we'll add extra line breaks and exit the method
		if (range.length == 0 && [text isEqualToString:@"\n"]) {
			// Line break after character cue
			if (currentLine.isAnyCharacter && self.automaticContd) {
				// Look back to see if we should add (cont'd), and if the CONT'D got added, don't run this method any longer
				if ([self.textActions shouldAddContdIn:range string:text]) {
					return NO;
				}
			} else if ([self.textActions shouldAddLineBreaks:currentLine range:range]) {
				return NO;
			}
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
	
	self.lastChangedRange = (NSRange){ range.location, text.length };
	
	return true;
}


#pragma mark - Text input delegate

- (void)selectionDidChange:(id<UITextInput>)textInput
{
	
}

- (void)selectionWillChange:(id<UITextInput>)textInput
{
	//
}

- (void)textWillChange:(nullable id<UITextInput>)textInput
{
	//
}


#pragma mark - Display reviews
// TODO: Wtf. Move this to the review class. Isn't this just duplicate code?

- (void)showReviewIfNeeded
{
	if (self.text.length == 0 || self.selectedRange.location == self.text.length) return;
	
	NSInteger pos = self.selectedRange.location;
	BeatReviewItem *reviewItem = [self.textStorage attribute:BeatReview.attributeKey atIndex:pos effectiveRange:nil];
	
	if (reviewItem && !reviewItem.emptyReview) {
		[self.review showReviewIfNeededWithRange:NSMakeRange(pos, 0) forEditing:NO];
	} else {
		[self.review closePopover];
	}
}



#pragma mark - User default shorthands
// TODO: Adapt the same pattern for macOS (and move this to base class)

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

- (bool)automaticContd {
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingAutomaticContd];
}

- (bool)revisionMode {
	return [self.documentSettings getBool:DocSettingRevisionMode];
}

-(void)setRevisionMode:(bool)revisionMode {
	[self.documentSettings setBool:DocSettingRevisionMode as:revisionMode];
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
	//BeatExportViewController* vc = [self.storyboard instantiateViewControllerWithIdentifier:@"ExportPanel"];
	BeatExportSettingController* vc = [self.storyboard instantiateViewControllerWithIdentifier:@"ExportSettingsTable"];
	vc.editorDelegate = self;
	
	[self.navigationController pushViewController:vc animated:true];
}

- (id)documentForDelegation
{
	return self.document;
}

- (UIPrintInfo*)printInfo
{
	return UIPrintInfo.new;
}


#pragma mark - General editor stuff

/// TODO: Move this to text view?
- (void)handleTabPress {
	if (self.textView.assistantView.numberOfSuggestions > 0) {
		//Select the first one
		[self.textView.assistantView selectItemAt:0];
		return;
	}
	
	[self.formattingActions addCue];
	[self.textView updateAssistingViews];
}

-(void)focusEditor {
	[self.textView becomeFirstResponder];
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
	return true;
}

-(void)keyboardWillShowWith:(CGSize)size animationTime:(double)animationTime {
	// Let's not use this on phones
	if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) return;
	
	CGFloat keyboardHeight = self.textView.keyboardLayoutGuide.layoutFrame.size.height;
	
	UIEdgeInsets insets = UIEdgeInsetsMake(0, 0, keyboardHeight, 0);
	
	CGRect bounds = self.scrollView.bounds;
	bool animateBounds = false;
	
	if (self.selectedRange.location != NSNotFound) {
		CGRect selectionRect = [self.textView rectForRangeWithRange:self.selectedRange];
		CGRect visible = [self.textView convertRect:selectionRect toView:self.scrollView];
		
		CGRect modifiedRect = CGRectMake(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height - size.height);
		
		if (CGRectIntersection(visible, modifiedRect).size.height == 0.0) {
			bounds.origin.y += size.height;
			animateBounds = true;
		}
	}
	
	[UIView animateWithDuration:0.0 animations:^{
		self.scrollView.contentInset = insets;
		self.outlineView.contentInset = insets;
		
		if (animateBounds) self.scrollView.bounds = bounds;
		
	} completion:^(BOOL finished) {
		[self.textView resize];
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



#pragma mark - Minimal plugin support

- (IBAction)runPlugin:(id)sender
{
	// Get plugin filename from menu item
	//BeatPluginMenuItem *menuItem = (BeatPluginMenuItem*)sender;
	//NSString *pluginName = menuItem.pluginName;
	
	//[self runPluginWithName:pluginName];
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

- (IBAction)toggleCards:(id)sender
{
	[self performSegueWithIdentifier:@"Cards" sender:nil];
}



@end
