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

#import "BeatDocumentViewController+KeyboardEvents.h"

#import "Beat-Swift.h"
#import <OSLog/OSLog.h>

@interface BeatDocumentViewController () <BeatPreviewManagerDelegate, iOSDocumentDelegate, NSTextStorageDelegate, BeatTextIODelegate, BeatExportSettingDelegate, BeatTextEditorDelegate, UINavigationItemRenameDelegate, BeatPluginDelegate, UITextInputDelegate>

@property (nonatomic, weak) IBOutlet BeatPageView* pageView;
@property (nonatomic) NSString* bufferedText;

@property (nonatomic) BeatPageViewController* previewView;
@property (nonatomic) bool previewUpdated;
@property (nonatomic) NSTimer* previewTimer;

@property (nonatomic) bool disableFormatting;

/// Preview controller override
@property (nonatomic) BeatPreviewController* previewController;
 
@property (nonatomic) bool sidebarVisible;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint* sidebarConstraint;

@property (nonatomic) bool matchParentheses;

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
	
	// Let the app state know this is the current document view controller
	BeatAppState.shared.documentController = self;
	
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
	BeatAppState.shared.documentController = nil;
	
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
	if (is_Mobile) {
		// Phones require a specific set of fonts scaled by user setting
		[super loadFontsWithScale:self.fontScale];
	} else {
		[super loadFonts];
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
	
	// Observers
	[self setupKeyboardObserver];
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
	[self.textView setNeedsDisplay];
	[self.textView setNeedsLayout];
}

- (void)updateLayout
{
	[self ensureLayout];
}

- (void)updateTheme
{
	[self updateUIColors];
}


#pragma mark - Text view

@synthesize inputModifierFlags;

- (BXTextView*)getTextView { return self.textView; }
- (CGFloat)editorLineHeight { return self.editorStyles.page.lineHeight; }
- (UIKeyModifierFlags)inputModifierFlags { return self.textView.modifierFlags; }


#pragma mark - Application data and file access

- (NSURL *)fileURL
{
	return _document.fileURL;
}

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
	
	[self.outlineView setupColors];
	self.sidebar.backgroundColor = ThemeManager.sharedManager.outlineBackground;
	
	self.scrollView.backgroundColor = (isDark) ?  ThemeManager.sharedManager.marginColor.darkColor : ThemeManager.sharedManager.marginColor.lightColor;
	self.textView.backgroundColor = (isDark) ? ThemeManager.sharedManager.backgroundColor.darkColor : ThemeManager.sharedManager.backgroundColor.lightColor;
	
	[self.formatting refreshRevisionTextColors];
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


#pragma mark - Apply user settings

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

- (id)documentForDelegation
{
	return self.document;
}

- (UIPrintInfo*)printInfo
{
	return UIPrintInfo.new;
}


#pragma mark - General editor stuff

- (void)focusEditor
{
	[self.textView becomeFirstResponder];
}

- (void)toggleMode:(BeatEditorMode)mode {
	NSLog(@"• Do additional checks for mode change");
	self.mode = mode;
}


#pragma mark - For avoiding throttling

- (bool)hasChanged
{
	bool changed = ![self.text isEqualToString:_bufferedText];
	if (changed) _bufferedText = self.text.copy;
	
	return changed;
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
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

- (void)registerPluginViewController:(BeatPluginHTMLViewController *)view
{
	//
}


- (void)unregisterPluginViewController:(BeatPluginHTMLViewController *)view
{
	//
}

@end
