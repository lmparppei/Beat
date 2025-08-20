//  Document.m
//  Beat
//
//  Copyright © 2019-2025 Lauri-Matti Parppei
//  Based on Writer, copyright © 2016 Hendrik Noeller

/*
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 
 
 THIS IS AN ANTI-CAPITALIST VENTURE.
 No ethical consumption under capitalism.
 
 N.B.
 
 Beat has been cooked up by using lots of trial and error, and this file has become a monster. I am a filmmaker and musician, with no real coding experience prior to this project. I've started fixing some of my silliest coding practices, but it's still a WIP. Parts of the code originally came from Writer, an open source Fountain editor by Hendrik Noeller.
 
 Some structures are legacy from Writer and original Fountain repository, and while most have since been replaced with a totally different approach, some variable names and complimentary methods still linger around. You can find some *very* shady stuff lying around here and there, with no real purpose. I built some very convoluted UI methods on top of legacy code from Writer before getting a grip on AppKit & Objective-C programming. I have since made it much more sensible, but dismantling those weird solutions is still WIP.
 
 As I started this project, I had close to zero knowledge on Objective-C, and it really shows. I have gotten gradually better at writing code, and there is even some multi-threading, omg. Some clumsy stuff is still lingering around, unfortunately. I'll keep on fixing that stuff when I have the time.
 
 I originally started the project to combat a creative block, while overcoming some difficult PTSD symptoms. Coding helped to escape those feelings. If you are in an abusive relationship, leave RIGHT NOW. You might love that person, but it's not your job to try and help them. I wish I could have gotten this sort of advice back then from a random source code file.
 
 Beat is released under GNU General Public License, so all of this code will remain open forever - even if I'd make a commercial version to finance the development. Beat has become a real app with a dedicated user base, which I'm thankful for. If you find this code or the app useful, you can always send some currency through PayPal or hide bunch of coins in an old oak tree. Or, even better, donate to a NGO helping less fortunate people. I'm already on the top of Maslow hierarchy.


 Anyway, may this be of some use to you, dear friend.
 The abandoned git repository will be my monument when I'm gone.
 
 You who will emerge from the flood
 In which we have gone under
 Remember
 When you speak of our failings
 The dark time too
 Which you have escaped.
 
 
 Lauri-Matti Parppei
 Helsinki/Kokemäki
 Finland
 2019-2021
 

 = = = = = = = = = = = = = = = = = = = = = = = =
 
 I plant my hands in the garden soil—
 I will sprout,
              I know, I know, I know.
 And in the hollow of my ink-stained palms
 swallows will make their nest.
 
 = = = = = = = = = = = = = = = = = = = = = = = =
 
*/

#define AUTOSAVE_INTERVAL 10.0
#define AUTOSAVE_INPLACE_INTERVAL 60.0

#import <os/log.h>
#import <QuartzCore/QuartzCore.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatCore.h>
#import <BeatCore/BeatCore-Swift.h>
#import <BeatFileExport/BeatFileExport.h>
#import <BeatPagination2/BeatPagination2-Swift.h>
#import "Beat-Swift.h"

#import "Document.h"
#import "Document+WindowManagement.h"
#import "Document+SceneActions.h"
#import "Document+Menus.h"
#import "Document+AdditionalActions.h"
#import "Document+ThemesAndAppearance.h"
#import "Document+Sidebar.h"
#import "Document+Lock.h"
#import "Document+TextEvents.h"
#import "Document+SceneColorPicker.h"
#import "Document+Scrolling.h"
#import "Document+EditorMode.h"
#import "Document+UI.h"
#import "Document+InitialFormatting.h"

#import "ScrollView.h"
#import "BeatAppDelegate.h"
#import "ColorCheckbox.h"
#import "SceneFiltering.h"
#import "SceneCards.h"
#import "MarginView.h"
#import "BeatLockButton.h"
#import "BeatColorMenuItem.h"
#import "BeatSegmentedControl.h"
#import "BeatPrintDialog.h"
#import "BeatEditorButton.h"
#import "BeatTextView.h"
#import "BeatTextView+Popovers.h"

@interface Document () <BeatPreviewManagerDelegate, BeatTextIODelegate, BeatQuickSettingsDelegate, BeatExportSettingDelegate, BeatTextViewDelegate, BeatPluginDelegate, BeatOutlineViewEditorDelegate>

@property (atomic) NSData* dataCache;
@property (nonatomic) NSString* bufferedText;

/// If set `true`, editor formatting won't be applied
@property (nonatomic) bool disableFormatting;

/// Autocompletion class which delivers us character names and scene headings
@property (nonatomic, weak) IBOutlet BeatAutocomplete *autocompletion;
/// Print dialog has to be retained in memory when processing the PDF
@property (nonatomic) BeatPrintDialog *printDialog;
/// Preview controller handles updating the preview view
@property (nonatomic) IBOutlet BeatPreviewController *previewController;

@property (weak) NSTimer *autosaveTimer;

@property (weak) IBOutlet NSTouchBar *touchBar;

@end


// WARNING!!!
// We're suppressing protocol warnings because we're conforming to the main delegate using multiple categories
#pragma clang diagnostic ignored "-Wprotocol"
@implementation Document

@dynamic textView;
@dynamic previewController;

#pragma mark - Document Initialization

/// **Warning**: This is used for returning the actual document object through editor delegate. Handle with care. 
-(Document*)document { return self; }

/// A paranoid method to actually null every-fucking-thing.
- (void)close
{
	// Save frame IF the document was saved
	if (!self.hasUnautosavedChanges) [self.documentWindow saveFrameUsingName:self.fileNameString];

	self.previewController.pagination.finishedPagination = nil;
	
	// Remove local styles from memory to avoid retain cycles
	[self forgetStyles];
	
	// Unload all plugins
	[self.pluginAgent unloadPlugins];
	
	// Close all assisting windows
	for (NSWindow* window in self.assistingWindows.allValues) [window close];
	self.assistingWindows = nil;
	
	// This stuff is here to fix some strange memory issues.
	// Most of these might be unnecessary, but I'm unfamiliar with both ARC & manual memory management. Better safe than sorry.
	[self.previewController.timer invalidate];
	[self.beatTimer.timer invalidate];
	self.beatTimer = nil;
	
	[self.userActivity invalidate];
		
	// Remove all registered views
	for (NSView* view in self.registeredViews) [view removeFromSuperview];
	for (NSView* view in self.registeredOutlineViews) [view removeFromSuperview];
	[self.registeredViews removeAllObjects];
	[self.registeredOutlineViews removeAllObjects];
	[self.registeredSelectionObservers removeAllObjects];
	
	// Invalidate all view timers
	[self.textScrollView.mouseMoveTimer invalidate];
	[self.textScrollView.timerMouseMoveTimer invalidate];
	self.textScrollView.mouseMoveTimer = nil;
	self.textScrollView.timerMouseMoveTimer = nil;
	
	// Invalidate autosave timer
	[self.autosaveTimer invalidate];
	self.autosaveTimer = nil;
	
	// Null other stuff, just in case
	self.formatting = nil;
	self.runningPlugins = nil;
	self.currentLine = nil;
	self.parser = nil;
	self.outlineView = nil;
	self.documentWindow = nil;
	self.contentBuffer = nil;
	self.currentScene = nil;

	self.outlineView = nil;
	self.outlineView.filters = nil;
	self.outlineView.filteredOutline = nil;
	
	self.tagging = nil;
	self.review = nil;
	
	self.previewController = nil;
	
	// Fully deallocate text view
	[self.textView.textStorage replaceCharactersInRange:NSMakeRange(0, self.textView.textStorage.string.length) withString:@""];
	[self.textView removeFromSuperview];
	self.textView = nil;
		
	// Kill observers
	[NSNotificationCenter.defaultCenter removeObserver:self];
	[NSNotificationCenter.defaultCenter removeObserver:self.marginView];
	[NSNotificationCenter.defaultCenter removeObserver:self.widgetView];
	[NSDistributedNotificationCenter.defaultCenter removeObserver:self];
		
	[super close];
	
	// ApplicationDelegate will show welcome screen when no documents are open
	[NSNotificationCenter.defaultCenter postNotificationName:@"Document close" object:nil];
}


#pragma mark - Window loading

-(void)restoreDocumentWindowWithIdentifier:(NSUserInterfaceItemIdentifier)identifier state:(NSCoder *)state completionHandler:(void (^)(NSWindow * _Nullable, NSError * _Nullable))completionHandler
{
	if (mask_contains(NSEvent.modifierFlags, NSEventModifierFlagShift)) {
		completionHandler(nil, nil);
		[self close];
	} else {
		[super restoreDocumentWindowWithIdentifier:identifier state:state completionHandler:completionHandler];
		if (self.hasUnautosavedChanges) [self updateChangeCount:NSChangeDone];
	}
}

/// - note: This is a total mess. We should use a similar class as iOS uses for the actual `NSDocument` and initialize our parser/document settings there.
/// This is here purely for legacy reasons, as it's how old macOS apps used to do things by default. Nowadays there are better ways to achieve the same thing, but unfortunately it would require a lot of refactoring at a very deep level, hence we are stuck with doing things in a very clunky way for now.
- (void)windowControllerWillLoadNib:(NSWindowController *)windowController
{
	[super windowControllerWillLoadNib:windowController];

	// Initialize document settings if needed
	if (!self.documentSettings) self.documentSettings = [BeatDocumentSettings.alloc initWithDelegate:self];
	
	// Initialize parser
	self.documentIsLoading = YES;
	self.parser = [[ContinuousFountainParser alloc] initWithString:self.contentBuffer delegate:self];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
	// Hide the welcome screen
	[NSNotificationCenter.defaultCenter postNotificationName:@"Document open" object:nil];
	
	// If there's a tab group, add this window to the tabbed window
	Document* currentDoc = NSDocumentController.sharedDocumentController.currentDocument;
	if (currentDoc.windowControllers.firstObject.window.tabGroup.tabBarVisible) {
		[currentDoc.documentWindow addTabbedWindow:aController.window ordered:NSWindowAbove];
	}
	
	[super windowControllerDidLoadNib:aController];

	_documentWindow = aController.window;
	_documentWindow.delegate = self; // The conformance is provided by a Swift extension
	
	[self setup];
}


#pragma mark - Loading data

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	// This method can crash the app in some instances, so I've tried to solve the issue
	// by wrapping it in try-catch block. Let's see if it helps.
	
	NSData *dataRepresentation;
	bool success = NO;
	@try {
		dataRepresentation = [[self createDocumentFile] dataUsingEncoding:NSUTF8StringEncoding];
		success = YES;
	} @catch (NSException *exception) {
		os_log(OS_LOG_DEFAULT, "Error (auto)saving file: %@", exception);
		
		// If there is data in the cache, return it
		if (_dataCache != nil) return _dataCache;
		else dataRepresentation = [self.textView.string dataUsingEncoding:NSUTF8StringEncoding];
		
		// Everything is terrible, crash and don't overwrite anything.
		if (dataRepresentation == nil) @throw NSInternalInconsistencyException;
	} @finally {
		// If saving was successful, let's store the data into cache
		if (success) _dataCache = dataRepresentation.copy;
	}
	
	if (dataRepresentation == nil) {
		NSLog(@"ERROR: Something went horribly wrong. Trying to crash the app to avoid data loss.");
		@throw NSInternalInconsistencyException;
	}
	
	return dataRepresentation;
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing  _Nullable *)outError
{
	if (![url checkResourceIsReachableAndReturnError:outError]) return NO;
	return [super readFromURL:url ofType:typeName error:outError];
}
- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	return [self readFromData:data ofType:typeName error:outError reverting:NO];
}

/// Loads text & remove settings block from Fountain.
/// - note: `readBeatDocumentString:` is implemented by the super class. It will handle setting `contentBuffer` at load.

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError reverting:(BOOL)reverting
{
	self.documentIsLoading = true;

	NSString* text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding].stringByCleaningUpWindowsLineBreaks.stringByCleaningUpBadControlCharacters;
	text = [self readBeatDocumentString:text];
	
	// If we're not reverting, we can also set the text here
	if (!reverting)	[self setText:text];
	
	return YES;
}

- (void)revertToText:(NSString*)text
{
	[super revertToText:text];
	[self setupDocument];
}


#pragma mark - Document was saved

- (void)documentWasSaved
{
	for (NSString *pluginName in self.runningPlugins.allKeys) {
		BeatPlugin *plugin = self.runningPlugins[pluginName];
		[plugin documentWasSaved];
	}
}

/*
 
 But if the while I think on thee,
 dear friend,
 All losses are restor'd,
 and sorrows end.
 
 */


#pragma mark - Setup

/**
 Flow: `windowControllerDidLoadNib` -> `setup` -> `setupDocument` -> `renderDocument` -> (async formatting) -> `loadingComplete`
 */
- (void)setup
{
	[self.previewController setup];
	
	// Setup plugins
	self.runningPlugins = NSMutableDictionary.new;
	self.pluginAgent = [BeatPluginAgent.alloc initWithDelegate:self];
	
	// Setup formatting
	self.formatting = BeatEditorFormatting.new;
	self.formatting.delegate = self;
	
		// Initialize theme
	[self loadSelectedTheme:false];
	
	// Setup views
	[self setupWindow];
	[self readUserSettings];
	
	// Load font set
	[self loadFonts];
	
	// Setup views
	[self setupResponderChain];
	[self.textView setup];
	[self setupColorPicker];
	[self.outlineView setup];
		
	// Print dialog
	self.printDialog.document = nil;
	
	// Set up the document
	[self setupDocument];
}

/// Reloads all necessary things. Should be called when the whole text has changed.
- (void)setupDocument
{
	self.documentIsLoading = true;
	if (self.contentBuffer == nil) self.contentBuffer = @"";
	
	[self.textView setNeedsDisplay:true];
	
	self.textView.alphaValue = 0.0;
	
	// We are re-initializing the parser here for some reason. Do we need to?
	self.parser = [ContinuousFountainParser.alloc initWithString:self.contentBuffer delegate:self];
	
	[self updateChangeCount:NSChangeCleared];
	[self updateChangeCount:NSChangeDone];
	[self.undoManager removeAllActions];
	
	// Put any previously loaded text into the text view when it's loaded
	self.text = (self.contentBuffer.length > 0) ? self.contentBuffer : @"";
	
	// Set up revision tracking before preview is created and lines are rendered on screen
	[self.revisionTracking setup];
	
	// Paginate the whole document at load
	[self.previewController createPreviewWithChangedRange:NSMakeRange(0,1) sync:true];
		
	// Perform first-time rendering
	[self renderDocument];
	
	// Update selection to any views or objects that might require it.
	[self updateSelectionObservers];
}

- (void)loadingComplete
{
	// Reset parser and cache attributed content after load
	[self.parser.changedIndices removeAllIndexes];
	self.attrTextCache = self.textView.attributedString;
	
	// Setup reviews and tagging
	[self.review setup];
	[self.tagging setup];

	// Setup text IO
	self.textActions = [BeatTextIO.alloc initWithDelegate:self];
				
	// Init autosave
	[self initAutosave];
		
	// Lock status
	if ([self.documentSettings getBool:DocSettingLocked]) [self lock];
	
	// Notepad
	[self.notepad setup];
		
	// Sidebar
	[self restoreSidebar];
		
	// Reveal text view
	[self.textView.animator setAlphaValue:1.0];
	
	// Hide Fountain markup if needed
	if (self.hideFountainMarkup) [self.textView redrawAllGlyphs];
	
	// Setup layout
	[self setupLayout];
		
	// Restore previously running plugins
	[self.pluginAgent restorePlugins];
	
	// Reload editor views in background
	[self updateEditorViewsInBackground];
		
	// Load plugin containers
	for (id<BeatPluginContainer> container in self.registeredPluginContainers) {
		[container load];
	}
	
	// Document loading has ended. This has to be done after reviews and tagging are loaded.
	self.documentIsLoading = NO;

	self.textView.editable = true;
	
	// Add title page for new documents if needed
	if (self.fileURL == nil && self.text.length == 0 && [BeatUserDefaults.sharedDefaults getBool:BeatSettingAddTitlePageByDefault]) {
		[self.formattingActions addTitlePage:nil];
	}
}

-(void)awakeFromNib
{
	// Set up recovery file saving
	[NSDocumentController.sharedDocumentController setAutosavingDelay:AUTOSAVE_INTERVAL];
	[self scheduleAutosaving];
	
	// Set up listener for appearance change. Handled in Document+ThemesAndAppearance.h.
	[NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(didChangeAppearance) name:@"AppleInterfaceThemeChangedNotification" object:nil];
}


#pragma mark - Misc document stuff

- (NSString *)displayName
{
	return (self.fileURL == nil) ? @"Untitled" : self.fileURL.URLByDeletingPathExtension.lastPathComponent;
}

- (NSString*)fileNameString
{
	return self.lastComponentOfFileName.stringByDeletingPathExtension;
}

	
#pragma mark - Misc document stuff

-(void)setValue:(id)value forUndefinedKey:(NSString *)key {
	//NSLog(@"Document: Undefined key (%@) set. This might be intentional.", key);
}

-(id)valueForUndefinedKey:(NSString *)key {
	//NSLog(@"Document: Undefined key (%@) requested. This might be intentional.", key);
	return nil;
}


#pragma mark - Handling user settings

- (void)readUserSettings
{
	[BeatUserDefaults.sharedDefaults readUserDefaultsFor:self];
}

- (void)applyUserSettings
{
	// Apply settings from user preferences panel, some things have to be applied in every document.
	// This should be implemented as a singleton/protocol.
	bool oldShowSceneNumbers = self.showSceneNumberLabels;
	bool oldHideFountainMarkup = self.hideFountainMarkup;
	bool oldShowPageNumbers = self.showPageNumbers;
	
	BeatUserDefaults *defaults = BeatUserDefaults.sharedDefaults;
	[defaults readUserDefaultsFor:self];
		
	// Reload fonts (if needed)
	[self reloadFonts];
	
	if (oldHideFountainMarkup != self.hideFountainMarkup) {
		[self.textView toggleHideFountainMarkup];
		[self ensureLayout];
	}
	
	if (oldShowPageNumbers != self.showPageNumbers) {
		[self.textView setNeedsDisplay:true];
	}
	
	if (oldShowSceneNumbers != self.showSceneNumberLabels) {
		if (self.showSceneNumberLabels) [self ensureLayout];
		//else [self.textView deleteSceneNumberLabels];
		
		// Update the print preview accordingly
		[self.previewController resetPreview];
	}
	
	self.textView.needsDisplay = true;
}


#pragma mark - Window setup

/// Sets up the custom responder chain
- (void)setupResponderChain
{
	// Our desired responder chain, add more custom responders when needed
	NSArray *chain = @[_formattingActions, self.revisionTracking, self.notepad, self.timeline];
	
	// Store the original responder after text view
	NSResponder *prev = self.textView;
	NSResponder *originalResponder = prev.nextResponder;
	
	for (NSResponder *responder in chain) {
		prev.nextResponder = responder;
		prev = responder;
	}
	
	prev.nextResponder = originalResponder;
}

-(void)setupLayout
{
	// Apply layout
	[_documentWindow layoutIfNeeded];
	[self updateLayout];
	
	[self.textView loadCaret];
}

// Can I come over, I need to rest
// lay down for a while, disconnect
// the night was so long, the day even longer
// lay down for a while, recollect


# pragma mark - Window interactions

- (NSString *)windowNibName
{
	return @"Document";
}

/// Ensures minimum window size, sets text view insets and forces editor views to be displayed. After that, ensures text view layout.
- (void)updateLayout
{
	[self setMinimumWindowSize];

	[self.textView setInsets];
	
	self.textView.enclosingScrollView.needsDisplay = true;
	self.marginView.needsDisplay = true;
	
	[self ensureLayout];
}

- (CGFloat)documentWidth { return self.textView.documentWidth; }


#pragma mark - Layout

- (CGFloat)magnification { return self.textView.zoomLevel; }

- (void)setSplitHandleMinSize:(CGFloat)value
{
	self.splitHandle.topOrRightMinSize = value;
}

- (void)ensureLayout
{
	[self.textView.layoutManager invalidateLayoutForCharacterRange:NSMakeRange(0, self.text.length) actualCharacterRange:nil];
	[self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
	
	self.textView.needsDisplay = true;
	self.textView.needsLayout = true;
	
	[self.marginView updateBackground];
	
	[self.textView ensureCaret];
}



#pragma mark - Reverting to versions

-(void)revertDocumentToSaved:(id)sender
{
	if (!self.fileURL) return;
	[self readDocumentWithURL:self.fileURL typeName:@"com.kapitanFI.fountain"];
}

-(BOOL)revertToContentsOfURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing  _Nullable *)outError
{
	[self readDocumentWithURL:url typeName:typeName];
	return YES;
}

- (void)readDocumentWithURL:(NSURL*)url typeName:(NSString*)typeName
{
	NSData *data = [NSData dataWithContentsOfURL:url];
	_revertedTo = url;
	self.documentIsLoading = YES;
	
	[self readFromData:data ofType:typeName error:nil reverting:YES];
	
	[self setupDocument];
}


#pragma mark - Print & Export

- (IBAction)openPrintPanel:(id)sender {
	self.attrTextCache = [self getAttributedText];
	self.printDialog = [BeatPrintDialog showForPrinting:self];
}

- (IBAction)openPDFPanel:(id)sender {
	self.attrTextCache = [self getAttributedText];
	self.printDialog = [BeatPrintDialog showForPDF:self];
}

- (void)releasePrintDialog { _printDialog = nil; }

- (void)printDialogDidFinishPreview:(void (^)(void))block {
	block();
}

- (IBAction)exportFile:(id)sender
{
	BeatFileExportMenuItem* menuItem = sender;
	(void)[BeatFileExportManager.shared exportWithDelegate:self format:menuItem.format];
}


# pragma mark - Undo

- (IBAction)undoEdit:(id)sender {
	[self.undoManager undo];
	[self ensureLayout];
}
- (IBAction)redoEdit:(id)sender {
	[self.undoManager redo];
	[self ensureLayout];
}

/*
 
 and in a darkened underpass
 I thought, oh god, my chance has come at last
 but then
 a strange fear gripped me
 and I just couldn't ask
 
 */


#pragma mark - Toggling user default settings on/off

/// Toggles user default or document setting value on or off. Requires `BeatOnOffMenuItem` with a defined `settingKey`.
- (IBAction)toggleSetting:(BeatOnOffMenuItem*)menuItem
{
	if (menuItem == nil || menuItem.settingKey.length == 0) return;
	
	if (menuItem.documentSetting) [self.documentSettings toggleBool:menuItem.settingKey];
	else [BeatUserDefaults.sharedDefaults toggleBool:menuItem.settingKey];
	
	[self ensureLayout];
	
	// This notification should be the preferred way of updating any views etc. in the future
	[NSNotificationCenter.defaultCenter postNotification:[NSNotification.alloc initWithName:@"SettingToggled" object:nil userInfo:nil]];
}


#pragma mark - Text did change
// Other text events are in a category (why isn't this?)

- (void)textDidChange:(NSNotification *)notification
{
	[super textDidChange];
	
	// Fire up autocomplete at the end of string and create cached lists of scene headings / character names
	if (self.autocomplete) [self.autocompletion autocompleteOnCurrentLine];
	
	// If this was an undo operation, scroll to where the alteration was made
	if (self.undoManager.isUndoing) [self.textView ensureRangeIsVisible:self.lastChangedRange];
		
	[self updateChangeCount:NSChangeDone];
	
	// Apply any revisions
	[self.revisionTracking applyQueuedChanges];
	
	// Finally, reset last changed range
	self.lastChangedRange = NSMakeRange(NSNotFound, 0);	
}



#pragma mark - Text I/O

- (void)setAutomaticTextCompletionEnabled:(BOOL)value
{
	self.textView.automaticTextCompletionEnabled = value;
}

- (void)setZoom:(CGFloat)zoomLevel
{
	[self.textView adjustZoomLevel:zoomLevel];
}


// There is no shortage of ugliness in the world.
// If a person closed their eyes to it,
// there would be even more.


# pragma mark - Autocomplete stub

/// Forwarding method for autocompletion (why don't we set the autocompletion as the deleg.... oh well, I won't ask.)
- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index {
	return [_autocompletion completions:words forPartialWordRange:charRange indexOfSelectedItem:index];
}



# pragma  mark - Fonts

/// Called for any OS-specific stuff after fonts were loaded
- (void)fontDidLoad
{
	self.textView.font = self.fonts.regular;
}


#pragma mark - Select stylesheet

- (IBAction)selectStylesheet:(BeatMenuItemWithStylesheet*)sender
{
	[self setStylesheetAndReformat:sender.stylesheet];
}


#pragma mark - Return to editor from any subview

- (void)returnToEditor {
	[self showTab:_editorTab];
	[self updateLayout];
}


#pragma mark - Preview

- (IBAction)preview:(id)sender
{
	if (self.currentTab != _nativePreviewTab) {
		[self.previewController renderOnScreen];
		[self showTab:_nativePreviewTab];
	} else {
		[self returnToEditor];
	}
}

- (BOOL)previewVisible { return (self.currentTab == _nativePreviewTab); }

- (void)cancelOperation:(id) sender
{
	// ESCAPE KEY pressed
	if (self.currentTab == _nativePreviewTab || self.currentTab == _cardsTab) {
		[self returnToEditor];
	} else {
		for (NSString* pluginName in self.runningPlugins.allKeys) {
			BeatPlugin* plugin = self.runningPlugins[pluginName];
			[plugin escapePressed];
		}
	}
}


/*
 
 Oh, table, on which I write!
 I thank you with all my heart:
 You’ve given a trunk to me –
 With goal a table to be –
 
 But keep being the living trunk! –
 With – over my head – your leaf, young,
 With fresh bark and hot pitch’s tears,
 With roots – till the bottom of Earth!
 
 */

#pragma  mark - Sidebar methods

- (BOOL)sidebarVisible
{
	return !self.splitHandle.bottomOrLeftViewIsCollapsed;
}

- (CGFloat)sidebarWidth
{
	return self.splitHandle.bottomOrLeftView.frame.size.width;
}



#pragma mark - Sidebar

/// The rest of sidebar methods are found in `Document+Sidebar`. These are just here to conform to editor delegate protocol. Oh well, oh fuck.

- (IBAction)toggleSidebar:(id)sender
{
	[self toggleSidebarView:sender];
}

- (IBAction)showWidgets:(id)sender {
	if (!self.sidebarVisible) [self toggleSidebarView:nil];
	[self.sideBarTabs selectTabViewItem:self.tabWidgets];
}


/*
 
 I'm very good with plants
 while my friends are away
 they let me keep the soil moist.
 
 */


#pragma mark - Paper size

- (void)setPageSize:(BeatPaperSize)pageSize
{
	[super setPageSize:pageSize];
	[self updateLayout];
}


#pragma mark - Autosave

/*
 Beat has *three* kinds of autosave: autosave vault, saving in place and automatic macOS autosave.
 */

- (BOOL)autosave
{
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingAutosave];
}

+ (BOOL)autosavesInPlace { return NO; }

+ (BOOL)autosavesDrafts { return YES; }

+ (BOOL)preservesVersions {
	// Versions are only supported from 12.0+ because of a strange bug in older macOSs
	// WHY IS THIS BUGGY? It works but produces weird error messages.
	//if (@available(macOS 13.0, *)) return YES;
	// else return NO;
	return NO;
}

- (BOOL)writeSafelyToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError *__autoreleasing  _Nullable *)outError {
	bool result = [super writeSafelyToURL:url ofType:typeName forSaveOperation:saveOperation error:outError];
	
	if (result && (saveOperation == NSSaveOperation || saveOperation == NSSaveAsOperation)) {
		bool backup = [BeatBackup backupWithDocumentURL:url name:[self fileNameString] autosave:false];
		if (!backup) NSLog(@"Backup failed");
	}
	
	return result;
}

- (NSURL *)mostRecentlySavedFileURL;
{
	// Before the user chooses where to place a new document, it has an autosaved URL only
	NSURL *result = [self autosavedContentsFileURL];
	if (result == nil) result = [self fileURL];
	return result;
}

// Custom autosave in place
- (void)autosaveInPlace {	
	if (_autosave && self.documentEdited && self.fileURL) {
		[self saveDocument:nil];
	} else {

		if ([NSFileManager.defaultManager fileExistsAtPath:self.autosavedContentsFileURL.path]) {
			bool autosave = [BeatBackup backupWithDocumentURL:self.autosavedContentsFileURL name:self.fileNameString autosave:true];
			if (!autosave) NSLog(@"AUTOSAVE ERROR");
		}
	}
}

- (NSURL *)autosavedContentsFileURL {
	NSString *filename = self.fileNameString;
	NSString* extension = self.fileURL.pathExtension;
	if (!filename) filename = @"Untitled";
	if (!extension) extension = @"fountain";
	
	NSURL *autosavePath = [self autosavePath];
	autosavePath = [autosavePath URLByAppendingPathComponent:filename];
	autosavePath = [autosavePath URLByAppendingPathExtension:extension];
	
	return autosavePath;
}

- (NSURL*)autosavePath {
	return [BeatAppDelegate appDataPath:@"Autosave"];
}

- (void)autosaveDocumentWithDelegate:(id)delegate didAutosaveSelector:(SEL)didAutosaveSelector contextInfo:(void *)contextInfo {
	self.autosavedContentsFileURL = [self autosavedContentsFileURL];
	[super autosaveDocumentWithDelegate:delegate didAutosaveSelector:didAutosaveSelector contextInfo:contextInfo];
	
	[NSDocumentController.sharedDocumentController setAutosavingDelay:AUTOSAVE_INTERVAL];
	[self scheduleAutosaving];
}

- (BOOL)hasUnautosavedChanges {
	// Always return YES if the file is a draft
	if (self.fileURL == nil) return YES;
	else { return [super hasUnautosavedChanges]; }
}

- (void)initAutosave {
	_autosaveTimer = [NSTimer scheduledTimerWithTimeInterval:AUTOSAVE_INPLACE_INTERVAL target:self selector:@selector(autosaveInPlace) userInfo:nil repeats:YES];
}

- (void)saveDocumentAs:(id)sender {
	[super saveDocumentAs:sender];
}

-(void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo {
	[super runModalSavePanelForSaveOperation:saveOperation delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}


#pragma mark - split view listener

- (void)splitViewDidResize
{
	[self.documentSettings setInt:DocSettingSidebarWidth as:(NSInteger)self.splitHandle.bottomOrLeftView.frame.size.width];
	[self updateLayout];
}

- (void)leftViewDidShow
{
	self.sidebarVisible = YES;
	[_outlineButton setState:NSOnState];
	[self.outlineView reloadOutline];
}

- (void)leftViewDidHide
{
	self.sidebarVisible = NO;
}


#pragma mark - Widgets

- (void)addWidget:(id)widget {
	[self.widgetView addWidget:widget];
	[self showWidgets:nil];
}



#pragma mark - For avoiding throttling

- (bool)hasChanged {
	if ([self.textView.string isEqualToString:_bufferedText] || self.textView.string == nil) return NO;
	
	_bufferedText = [NSString stringWithString:self.textView.string];
	return YES;
}


#pragma mark - Appearance

/// Because we are supporting forced light/dark mode even on pre-10.14 systems, you can reliably check the appearance with this method.
- (bool)isDark { return [(BeatAppDelegate *)[NSApp delegate] isDark]; }


#pragma mark - Copy

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
	return [Document.alloc initWithContentsOfURL:self.fileURL ofType:self.fileType error:nil];
}


#pragma mark - Pagination handler

- (void)paginationFinished:(BeatPagination *)operation indices:(NSIndexSet *)indices pageBreaks:(NSDictionary<NSValue *,NSArray<NSNumber *> *> *)pageBreaks
{
	[super paginationFinished:operation indices:indices pageBreaks:pageBreaks];
	
	// If we have relative outline on, we'll need to update the heights... TODO: this should be a registered event
	if ([BeatUserDefaults.sharedDefaults getBool:BeatSettingRelativeOutlineHeights]) {
		for (OutlineScene* scene in self.parser.outline) {
			CGFloat oldHeight = scene.printedLength;
			scene.printedLength = [self.pagination heightForScene:scene];
			if (oldHeight == scene.printedLength) continue;
			
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				[self.outlineView reloadItem:scene];
			});
		}
	}
}

@end

/*
 
 some moments are nice, some are
 nicer, some are even worth
 writing
 about
 
 */
