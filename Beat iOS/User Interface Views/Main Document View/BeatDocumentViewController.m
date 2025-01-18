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

@property (nonatomic) bool disableFormatting;

@property (nonatomic) bool processingEdit;

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
	
	// On iPad, we'll use a free-scaling text view inside a scroll view, and on iPhone we'll just use a single text view
	if (!is_Mobile) {
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
	[self.formatting refreshRevisionTextColors];
}

/// Dismisses editor view keyboard
- (IBAction)endEditing:(id)sender
{
	[self.textView endEditing:true];
}

/// Returns the undo manager from **text view**
- (NSUndoManager *)undoManager { return self.textView.undoManager; }

/// NOTE: You need to call `loadDocument` before actually presenting the view
- (void)viewDidLoad
{
	[super viewDidLoad];
	
	if (!self.documentIsLoading) return;
	
	//[self appearanceChanged:nil];
	
	BeatiOSAppDelegate* delegate = (BeatiOSAppDelegate*)UIApplication.sharedApplication.delegate;
	[delegate checkDarkMode];
	
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
	
	[self updateUIColors];
	
	// Setup document title menu (from Swift extension)
	[self setupTitleBar];
	
	// Setup navigation item delegate
	self.navigationItem.renameDelegate = self;
	
	// Hide sidebar
	self.sidebarConstraint.constant = 0.0;
	
	self.formattingActions = [BeatEditorFormattingActions.alloc initWithDelegate:self];
	
	[self setupDocument];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	[self becomeFirstResponder];
	
	// When returning from another VC, let's check if we should return to editing mode
	if (editorWasActive) {
		editorWasActive = false;
		[self.getTextView becomeFirstResponder];
	}
	
	// Do nothing more if we're not loading the document
	if (!self.documentIsLoading) return;
	
	// Become first responder if text view is empty and scroll to top
	if (self.textView.text.length == 0) [self.textView becomeFirstResponder];
	[self.scrollView scrollRectToVisible:CGRectMake(0.0, 0.0, 300.0, 10.0) animated:false];
	
	// Loading is complete, show page view
	[self.textView layoutIfNeeded];
	
	[self.textView.layoutManager invalidateDisplayForCharacterRange:NSMakeRange(0, self.textView.text.length)];
	[self.textView.layoutManager invalidateLayoutForCharacterRange:NSMakeRange(0, self.textView.text.length) actualCharacterRange:nil];
		
	// This is not a place of honor. No highly esteemed deed is commemorated here.
	[self.textView firstResize];
	[self.textView resize];
	[self restoreCaret];
	
	self.documentIsLoading = false;
	
	//[self appearanceChanged:nil];
	[self displayPatchNotesIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self becomeFirstResponder];
	if (editorWasActive) {
		editorWasActive = false;
		[self.textView becomeFirstResponder];
	}
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	editorWasActive = self.textView.isFirstResponder;
	[self.textView resignFirstResponder];
	[self resignFirstResponder];
}

-(IBAction)dismissViewController:(id)sender
{
	[self unloadViews];
}

- (void)loadDocumentWithCallback:(void (^)(void))callback
{
	[self.document openWithCompletionHandler:^(BOOL success) {
		// Do something here maybe
		if (!success) return;
		
		self.parser = [ContinuousFountainParser.alloc initWithString:self.document.rawText delegate:self];
		self.formattedTextBuffer = [NSMutableAttributedString.alloc initWithString:self.document.rawText];
		self.attrTextCache = self.formattedTextBuffer;
		
		// Load fonts (iOS is limited to serif courier for now)
		[self loadFonts];
		
		// Format the document. We'll create a static formatting instance for this operation.
		BeatEditorFormatting* formatting = [BeatEditorFormatting.alloc initWithTextStorage:self.formattedTextBuffer];
		formatting.delegate = self;
		
		// Perform initial formatting (with autorelease, because this operation can be RAM intensive)
		for (Line* line in self.parser.lines) {
			@autoreleasepool {
				[formatting formatLine:line firstTime:true];
			}
		}
		
		[self.parser.changedIndices removeAllIndexes];
		
		callback();
	}];
}

- (void)setStylesheetAndReformat:(NSString *)name
{
	// We'll set the stylesheet twice to load fonts correctly. Sorry.
	[self setStylesheet:name];
	[self loadFonts];
	[super setStylesheetAndReformat:name];
}

- (void)loadFonts
{
	[super loadFonts];

	// Phones require a specific set of fonts scaled by user setting
	if (is_Mobile) {
		bool variableSize = self.editorStyles.variableFont;
		BeatFontType type = (variableSize) ? BeatFontTypeVariableSerif : BeatFontTypeFixed;
		
		self.fonts = [BeatFontManager.shared fontsWith:type scale:self.fontScale];
	}
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
	self.previewView.delegate = self;
	[self.previewView loadViewIfNeeded];
	
	// Init preview controller and pagination
	self.previewController = [BeatPreviewController.alloc initWithDelegate:self previewView:self.previewView];
	[self.previewController createPreviewWithChangedRange:NSMakeRange(0,1) sync:false];
	
	// Fit to view here
	self.scrollView.zoomScale = 1.4;
	
	// Keyboard manager
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keybWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keybDidShow:) name:UIKeyboardDidShowNotification object:nil];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(appearanceChanged:) name:@"Appearance changed" object:nil];
	
	// Text I/O
	self.textActions = [BeatTextIO.alloc initWithDelegate:self];
	
	// Text view settings
	self.textView.textStorage.delegate = self;
	[self.textView setFindInteractionEnabled:true];
	
	// Don't ask
	[self.textView firstResize];
	[self.textView resize];
	
	// Setup outline view
	self.outlineView = (BeatiOSOutlineView*)_editorSplitView.sidebar.tableView;
	self.outlineView.editorDelegate = self;
	
	// One day we'll migrate to diffable data source, but that day is not now.
	//_outlineProvider = [BeatOutlineDataProvider.alloc initWithDelegate:self tableView:self.outlineView];
}

- (void)dealloc
{
	[NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)setupTitleBar
{
	// Show document name
	self.titleBar.title = self.fileNameString;
}

- (IBAction)dismissDocumentViewController:(id)sender
{
	[self unloadViews];
}

- (void)unloadViews
{
	self.previewView = nil;
	
	self.previewController.pagination.finishedPagination = nil;
	self.previewController.pagination = nil;
	[self.textView removeFromSuperview];
	
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
	//[self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
	
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

- (UIKeyModifierFlags)inputModifierFlags {
	return self.textView.modifierFlags;
}

- (void)restoreCaret
{
	// Restore caret position from settings
	NSInteger position = [self.documentSettings getInt:DocSettingCaretPosition];
	if (position < self.text.length) {
		[self.textView setSelectedRange:NSMakeRange(position, 0)];
		[self.textView scrollToRange:self.textView.selectedRange];
	}
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


#pragma mark - Appearance

- (void)setDarkMode:(BOOL)value
{
	BeatiOSAppDelegate* delegate = (BeatiOSAppDelegate*)UIApplication.sharedApplication.delegate;
	[delegate toggleDarkMode];
}

- (void)appearanceChanged:(NSNotification*)notification
{
	[self updateUIColors];
}

- (void)updateUIColors
{
	BeatiOSAppDelegate* delegate = (BeatiOSAppDelegate*)UIApplication.sharedApplication.delegate;
	
	bool isDark = delegate.isDark;
	UIUserInterfaceStyle effectiveStyle = UITraitCollection.currentTraitCollection.userInterfaceStyle;
	
	self.overrideUserInterfaceStyle = 0;
	if (isDark && effectiveStyle != UIUserInterfaceStyleDark) {
		self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
	} else if (!isDark && effectiveStyle != UIUserInterfaceStyleLight) {
		self.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
	}
	[self.view setNeedsDisplay];
	
	self.scrollView.backgroundColor = (isDark) ?  ThemeManager.sharedManager.marginColor.darkColor : ThemeManager.sharedManager.marginColor.lightColor;
	self.textView.backgroundColor = (isDark) ? ThemeManager.sharedManager.backgroundColor.darkColor : ThemeManager.sharedManager.backgroundColor.lightColor;
	
	[self.formatting refreshRevisionTextColors];
	
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
	bool shown = false;
	
	if (is_Mobile) {
		// iPhone
		if (self.editorSplitView.sidebar.viewIfLoaded.window) {
			[self.editorSplitView showColumn:UISplitViewControllerColumnSecondary];
		} else {
			//[self.outlineProvider update];
			[self.editorSplitView showColumn:UISplitViewControllerColumnPrimary];
			shown = true;
		}
	} else {
		// iPad
		if (self.editorSplitView.displayMode == UISplitViewControllerDisplayModeSecondaryOnly) {
			//[self.outlineProvider update];
			[self.editorSplitView showColumn:UISplitViewControllerColumnPrimary];
			shown = true;
		} else {
			[self.editorSplitView hideColumn:UISplitViewControllerColumnPrimary];
		}
	}
	
	if (shown) {
		self.outlineView.aboutToShow = true;
		[self.outlineView reloadInBackground];
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

bool editorWasActive = false;
- (IBAction)togglePreview:(id _Nullable)sender
{
	if (![self.navigationController.viewControllers containsObject:self.previewView]) {
		editorWasActive = self.textView.isFirstResponder;
		[self.navigationController pushViewController:self.previewView animated:true];
		[self.previewController renderOnScreen];
		[self.textView scrollToRange:self.textView.selectedRange];
	}
}

- (void)previewDidFinish
{
	//
}

- (bool)previewVisible
{
	return (self.presentedViewController == self.previewView || self.navigationController.viewControllers.lastObject == self.previewView);
}


#pragma mark - Notepad

- (IBAction)toggleNotepad:(id _Nullable)sender
{
	UIStoryboard* sb = [UIStoryboard storyboardWithName:@"BeatNotepadView" bundle:nil];
	BeatNotepadViewController* vc = [sb instantiateViewControllerWithIdentifier:@"Notepad"];
	vc.delegate = self;
	
	UINavigationController* nc = [UINavigationController.alloc initWithRootViewController:vc];
	[self presentViewController:nc animated:true completion:^{
		NSLog(@"ok");
	}];
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
			[self.revisionTracking registerChangesInRange:NSMakeRange(editedRange.location, self.lastChangedRange.length) delta:delta];
		}
	}
	
	_processingEdit = true;
	
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
	if (!self.textView.floatingCursor) {
		[self textViewDidEndSelection:textView selectedRange:textView.selectedRange];
	}
}

/// Called when touch event *actually* changed the selection
- (void)textViewDidEndSelection:(UITextView *)textView selectedRange:(NSRange)selectedRange
{
	// Let's not do any of this stuff if we're processing an edit. For some reason selection end is posted *before* text change. :--)
	if (self.documentIsLoading) return;
	
	if (!_processingEdit) {
		if (self.selectedRange.length == 0) [self.textView scrollRangeToVisible:NSMakeRange(NSMaxRange(textView.selectedRange), 0)];
		[self updateSelection];
	}
	
	_processingEdit = false;
}

/// Call this whenever selection can be safely posted to assisting views and observers
- (void)updateSelection
{
	// Update outline view
	if (self.outlineView.visible) [self.outlineView selectCurrentScene];
	
	// Update text view input view and scroll range to visible
	[self.textView updateAssistingViews];
	
	// Update plugins
	[self.pluginAgent updatePluginsWithSelection:self.selectedRange];
	
	// Show review if needed
	[self showReviewIfNeeded];
}

- (void)textDidChange:(id<UITextInput>)textInput
{
	if (textInput == self.textView) [self textViewDidChange:self.getTextView]; 
}

-(void)textViewDidChange:(UITextView *)textView
{
	[super textDidChange];

	// If this was an undo operation, scroll to where the alteration was made
	if (self.undoManager.isUndoing) [self.textView scrollRangeToVisible:self.lastChangedRange];
	
	// Reset last changed range
	self.lastChangedRange = NSMakeRange(NSNotFound, 0);
	
	if (!self.documentIsLoading) [self updateChangeCount:UIDocumentChangeDone];
	
	[self.textView resize];
	
	// We should update selection here
	[self updateSelection];
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
	bool change = true;
	
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
	
	if (!undoOrRedo && self.selectedRange.length == 0 && range.length == 0 && [text isEqualToString:@"\n"] && currentLine != nil) {
		// Test if we'll add extra line breaks and exit the method
		if (currentLine.isAnyCharacter && self.automaticContd) {
			// Line break after character cue
			// Look back to see if we should add (cont'd), and if the CONT'D got added, don't run this method any longer
			if ([self.textActions shouldAddContdIn:range string:text]) change = NO;
		} else {
			change = ![self.textActions shouldAddLineBreaks:currentLine range:range];
		}
	}
	else if (self.matchParentheses && [self.textActions shouldMatchParenthesesIn:range string:text]) {
		// If something is being inserted, check whether it is a "(" or a "[[" and auto close it
		change = NO;
	}
	else if ([self.textActions shouldJumpOverParentheses:text range:range]) {
		// Jump over already-typed parentheses and other closures
		change = NO;
	}
	
	if (change) self.lastChangedRange = (NSRange){ range.location, text.length };
	
	return change;
}


#pragma mark - Text input delegate

- (void)selectionDidChange:(id<UITextInput>)textInput
{
	//
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

- (bool)revisionMode {
	return [self.documentSettings getBool:DocSettingRevisionMode];
}

-(void)setRevisionMode:(bool)revisionMode {
	[self.documentSettings setBool:DocSettingRevisionMode as:revisionMode];
}

- (NSInteger)spaceBeforeHeading {
	return [BeatUserDefaults.sharedDefaults getInteger:BeatSettingSceneHeadingSpacing];
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

- (void)updateChangeCount:(BXChangeType)change
{
	[self.document updateChangeCount:change];
}

/// Marks the document as changed
- (void)addToChangeCount
{
	[self.document updateChangeCount:BXChangeDone];
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
	if (line != nil) [self selectAndScrollTo:NSMakeRange(NSMaxRange(line.textRange), 0)];
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

- (void)lineWasRemoved:(Line *)line {
	
}


#pragma mark - Printing stuff for iOS

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

/// Fuck me, sorry for this
- (void)keybWillShow:(NSNotification*)notification
{
	NSValue* endFrame = notification.userInfo[UIKeyboardFrameEndUserInfoKey];
	NSNumber* rate = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey];
	
	if (endFrame == nil || rate == nil) return;
	
	CGRect currentKeyboard = endFrame.CGRectValue;
	CGRect convertedFrame = [self.view convertRect:currentKeyboard fromView:nil];
	
	[self keyboardWillShowWith:convertedFrame.size animationTime:rate.floatValue];
}

-(void)keyboardWillShowWith:(CGSize)size animationTime:(double)animationTime
{
	// Let's not use this on phones
	if (is_Mobile) return;
	
	UIEdgeInsets insets = UIEdgeInsetsMake(0, 0, size.height, 0);
	
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

-(void)keyboardWillHide
{
	self.outlineView.contentInset = UIEdgeInsetsZero;
	self.scrollView.contentInset = UIEdgeInsetsZero;
}

- (void)keybDidShow:(NSNotification*)notification
{
	NSValue* endFrame = notification.userInfo[UIKeyboardFrameEndUserInfoKey];
	
	// This is a hack to fix weird scrolling bugs on iPhone. Let's make sure the content size is adjusted correctly when keyboard has been shown.
	if (is_Mobile && endFrame != nil) {
		UIEdgeInsets insets = self.textView.contentInset;
		
		CGRect currentKeyboard = endFrame.CGRectValue;
		CGRect convertedFrame = [self.view convertRect:currentKeyboard fromView:nil];
		
		if (insets.bottom < convertedFrame.size.height) {
			insets.bottom = convertedFrame.size.height;
			self.textView.contentInset = insets;
			[self.textView scrollRangeToVisible:self.textView.selectedRange];
		}
	}
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
		
	} else if ([segue.identifier isEqualToString:@"ToEditorSplitView"]) {
		self.editorSplitView = segue.destinationViewController;
	}
}

- (IBAction)toggleCards:(id)sender
{
	[self performSegueWithIdentifier:@"Cards" sender:nil];
}


#pragma mark - Registering view controllers

- (void)registerPluginViewController:(BeatPluginHTMLViewController *)view {
	//
}


- (void)unregisterPluginViewController:(BeatPluginHTMLViewController *)view {
	//
}

@end
