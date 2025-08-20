//
//  BeatPrintDialog.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.4.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 This class works as an intermediate between PrintView and the Beat document
 and handles the UI side of printing, too. The printing itself is done in PrintView,
 which also does all the necessary preprocessing.
 
 This is a HORRIBLY convoluted system. I'm sorry for any inconvenience.
 
 NOTE: PrintView is stored into HOST DOCUMENT to keep it in memory after
 closing the dialog.
 
 */

#import <BeatCore/BeatCore-Swift.h>
#import <BeatParsing/BeatParsing.h>
#import "BeatPrintDialog.h"
#import "Beat-Swift.h"

#define ADVANCED_PRINT_OPTIONS_KEY @"Show Advanced Print Options"

@interface BeatPrintDialog () <NSTextFieldDelegate, PDFViewDelegate>

@property (weak) IBOutlet NSButton* printSceneNumbers;
@property (weak) IBOutlet NSButton* radioA4;
@property (weak) IBOutlet NSButton* radioLetter;
@property (weak) IBOutlet PDFView* pdfView;
@property (weak) IBOutlet NSButton* primaryButton;
@property (weak) IBOutlet NSButton* secondaryButton;
@property (weak) IBOutlet NSTextField* title;
@property (weak) IBOutlet NSTextField* headerText;
@property (weak) IBOutlet NSSegmentedControl* headerAlign;
@property (weak) IBOutlet NSPopUpButton *revisedPageColorMenu;
@property (weak) IBOutlet NSButton *colorCodePages;
@property (weak) IBOutlet NSView *advancedOptions;
@property (weak) IBOutlet NSButton* advancedOptionsButton;


@property (weak) IBOutlet NSProgressIndicator* progressIndicator;

@property (weak) IBOutlet NSLayoutConstraint *advancedOptionsWidthConstraint;

@property (weak) IBOutlet NSButton* revisionFirst;
@property (weak) IBOutlet NSButton* revisionSecond;
@property (weak) IBOutlet NSButton* revisionThird;
@property (weak) IBOutlet NSButton* revisionFourth;
@property (weak) IBOutlet NSButton* revisionFifth;
@property (weak) IBOutlet NSButton* revisionSixth;
@property (weak) IBOutlet NSButton* revisionSeventh;
@property (weak) IBOutlet NSButton* revisionEight;

@property (weak) IBOutlet NSButton* printSections;
@property (weak) IBOutlet NSButton* printSynopsis;
@property (weak) IBOutlet NSButton* printNotes;

@property (nonatomic) NSString *compareWith;

@property (nonatomic) bool automaticPreview;

@property (nonatomic) NSMutableArray<BeatPrintView*>* renderQueue;

@property (nonatomic) NSTimer* previewTimer;

@property (nonatomic) bool firstPreview;

@property (nonatomic) CGFloat panelWidth;

@end

@implementation BeatPrintDialog

+ (BeatPrintDialog*)showForPDF:(id)delegate
{
	BeatPrintDialog *dialog = [BeatPrintDialog.alloc initWithWindowNibName:self.className];
	dialog.documentDelegate = delegate;
	[dialog openForPDF:nil];
	return dialog;
}
+ (BeatPrintDialog*)showForPrinting:(id)delegate
{
	BeatPrintDialog *dialog = [BeatPrintDialog.alloc initWithWindowNibName:self.className];
	dialog.documentDelegate = delegate;
	[dialog open:nil];
	return dialog;
}

-(instancetype)initWithWindowNibName:(NSNibName)windowNibName
{
	return [super initWithWindowNibName:windowNibName owner:self];
}

#pragma mark - Window actions

-(void)awakeFromNib
{
	self.renderQueue = NSMutableArray.new;
	self.panelWidth = self.window.frame.size.width;
	
	// Show advanced options?
	
	[self showOrHideAdvancedOptionsAndAnimate:false];
	_advancedOptionsButton.state = ([NSUserDefaults.standardUserDefaults boolForKey:ADVANCED_PRINT_OPTIONS_KEY]) ? NSOnState : NSOffState;
	
	// Restore settings for note/synopsis/section printing
	if ([self.documentDelegate.documentSettings getBool:DocSettingPrintSections]) _printSections.state = NSOnState;
	if ([self.documentDelegate.documentSettings getBool:DocSettingPrintSynopsis]) _printSynopsis.state = NSOnState;
	if ([self.documentDelegate.documentSettings getBool:DocSettingPrintNotes]) _printNotes.state = NSOnState;
	
	NSArray<NSButton*>* revisionControls = @[self.revisionFirst, _revisionSecond, _revisionThird, _revisionFourth, _revisionFifth, _revisionSixth, _revisionSeventh, _revisionEight];
	NSIndexSet* hiddenRevisions = [NSIndexSet fromArray:[self.documentDelegate.documentSettings get:DocSettingHiddenRevisions]];
	
	for (NSButton* b in revisionControls) {
		b.state = ([hiddenRevisions containsIndex:b.tag]) ? NSOffState : NSOnState;
	}
	
	BeatExportSettings* settings = self.exportSettings;
	
	self.headerText.stringValue = settings.header;
	[self.headerAlign setSelectedSegment:[self.documentDelegate.documentSettings getInt:DocSettingHeaderAlignment]];
	
	[self toggleAdvancedOptions:_advancedOptionsButton];
	
	//[self.window center];
}

- (IBAction)open:(id)sender
{
	[self openPanel];
	
	// Change panel title
	_title.stringValue = NSLocalizedString(@"print.print", nil);
		
	// Switch buttons to prioritize printing
	_primaryButton.title = NSLocalizedString(@"print.printButton", nil);
	_primaryButton.action = @selector(print:);
	
	_secondaryButton.title = NSLocalizedString(@"print.pdfButton", nil);
	_secondaryButton.action = @selector(pdf:);
	
	//[self.window center];
}

- (IBAction)openForPDF:(id)sender
{
	[self openPanel];
	
	// Change panel title
	[_title setStringValue:NSLocalizedString(@"print.createPDF", nil)];
	
	// Switch buttons to prioritize PDF creation
	_primaryButton.title = NSLocalizedString(@"print.pdfButton", nil);
	_primaryButton.action = @selector(pdf:);
	
	_secondaryButton.title = NSLocalizedString(@"print.printButton", nil);
	_secondaryButton.action = @selector(print:);
	
	//[self.window center];
}

- (void)openPanel
{
	// Remove the previous preview
	[_pdfView setDocument:nil];
					
	[self loadWindow];
		
	// Get setting from document
	self.printSceneNumbers.state = (_documentDelegate.printSceneNumbers) ? NSOnState : NSOffState;
	
	// Check the paper size
	// WIP: Unify these so the document knows its BeatPaperSize too
	if (_documentDelegate.pageSize == BeatA4) [_radioA4 setState:NSOnState];
	else [_radioLetter setState:NSOnState];
		
	// Reload PDF preview
	_firstPreview = YES;
	[self loadPreview];

	// We have to show the panel here to be able to set the radio buttons, because I can't figure out how to load the window.
	[self.documentDelegate.documentWindow beginSheet:self.window completionHandler:^(NSModalResponse returnCode) {
		[self.documentDelegate releasePrintDialog];
	}];
}

- (IBAction)close:(id)sender
{
	// Remove timer
	[self.previewTimer invalidate];
	
	// End sheet in host window and release this dialog
	[self.documentDelegate.documentWindow endSheet:self.window];
	[self.documentDelegate releasePrintDialog];
	
}

#pragma mark - Printing

/// Exports the file using the given print operation (pdf/print)
- (void)exportWithType:(BeatPrintingOperation)type
{
	// Create a print operation and add it to the render queue.
	BeatPrintView* printing = [BeatPrintView.alloc initWithWindow:self.window operation:type settings:self.exportSettings delegate:self.documentDelegate screenplays:nil callback:^(BeatPrintView * _Nonnull operation, NSURL* _Nullable url) {
		// Remove from queue
		[self.renderQueue removeObject:operation];
		[self printingDidFinish];
	}];

	// Add to render queue (to keep the printing operation in memory)
	[self.renderQueue addObject:printing];
}

- (IBAction)print:(id)sender
{
	[self exportWithType:BeatPrintingOperationToPrint];
}

- (IBAction)pdf:(id)sender
{
	[self exportWithType:BeatPrintingOperationToPDF];
}

/// Once the operation finishes, we'll close this dialog
- (void)printingDidFinish
{
	[self.documentDelegate.documentWindow endSheet:self.window];
}

/// Recreates PDF preview after a small delay.
- (void)loadPreview
{
	[self.previewTimer invalidate];

	// Start progress indicator
	[self.progressIndicator startAnimation:nil];
	self.pdfView.alphaValue = 0.5;
	
	self.previewTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:false block:^(NSTimer * _Nonnull timer) {
		[self updatePreview];
	}];
}

/// Creates a PDF preview with current settings.
- (void)updatePreview
{
	// Update PDF preview
	BeatExportSettings *settings = [self exportSettings];
	
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		BeatPrintView* operation = [BeatPrintView.alloc initWithWindow:self.window operation:BeatPrintingOperationToPreview settings:settings delegate:self.documentDelegate screenplays:nil callback:^(BeatPrintView * _Nonnull operation, id _Nullable value) {
			[self.renderQueue removeObject:operation];
			
			NSURL* url = (NSURL*)value;
			[self didFinishPreviewAt:url];
		}];
		[self.renderQueue addObject:operation];
	});
}


#pragma mark - Export settings

- (BeatExportSettings*)exportSettings
{
	BeatExportSettings* settings = self.documentDelegate.exportSettings;

	// Set header
	// settings.header = (self.headerText.stringValue.length > 0) ? self.headerText.stringValue : @"";
	
	// Set custom settings from dialog
	settings.revisions = [self printedRevisions];
	
	settings.paperSize = self.documentDelegate.pageSize;
	settings.printNotes = (_printNotes.state == NSOnState);
	
	NSMutableIndexSet* additionalTypes = NSMutableIndexSet.new;
	if (_printSections.state == NSOnState) [additionalTypes addIndex:section];
	if (_printSynopsis.state == NSOnState) [additionalTypes addIndex:synopse];
	settings.additionalTypes = additionalTypes;
			
	return settings;
}


#pragma mark - Export setting actions

- (IBAction)selectPaperSize:(id)sender
{
	BeatPaperSize oldSize = _documentDelegate.pageSize;
	
	// Tag 1 = A4
	if ([(NSButton*)sender tag] == 1) _documentDelegate.pageSize = BeatA4;
	else _documentDelegate.pageSize = BeatUSLetter;
	
	// Preview needs refreshing
	if (oldSize != _documentDelegate.pageSize) {
		[self loadPreview];
	}
}

- (IBAction)selectSceneNumberPrinting:(id)sender
{
	_documentDelegate.printSceneNumbers = (_printSceneNumbers.state == NSOnState);
	[self loadPreview];
}

- (IBAction)toggleAdvancedOptions:(id)sender
{
	NSButton *button = sender;
	
	[NSUserDefaults.standardUserDefaults setBool:(button.state == NSOnState) forKey:ADVANCED_PRINT_OPTIONS_KEY];
	[self showOrHideAdvancedOptionsAndAnimate:true];
}

- (void)showOrHideAdvancedOptionsAndAnimate:(bool)animated
{
	bool show = [NSUserDefaults.standardUserDefaults boolForKey:ADVANCED_PRINT_OPTIONS_KEY];
	
	CGSize contentSize = self.window.contentView.frame.size;
	
	if (show) {
		contentSize.width = self.panelWidth;
	} else {
		contentSize.width = self.panelWidth - _advancedOptionsWidthConstraint.constant;
	}
	
	if (animated) [self.window.animator setContentSize:contentSize];
	else [self.window setContentSize:contentSize];
}

- (IBAction)toggleColorCodePages:(id)sender
{
	NSButton *checkbox = sender;
	if (checkbox.state == NSOnState) [_documentDelegate.documentSettings setBool:DocSettingColorCodePages as:YES];
	else [_documentDelegate.documentSettings setBool:DocSettingColorCodePages as:NO];

	[self loadPreview];
}

- (IBAction)setRevisedPageColor:(id)sender
{
	NSPopUpButton *menu = sender;
	NSString *color = menu.selectedItem.title.lowercaseString;
	
	[_documentDelegate.documentSettings set:DocSettingRevisedPageColor as:color];
	[self loadPreview];
}

- (IBAction)toggleRevision:(id)sender
{
	[self.documentDelegate.documentSettings set:DocSettingHiddenRevisions as:self.hiddenRevisions];
	[self loadPreview];
}

- (IBAction)toggleInvisibleElement:(id)sender
{
	BeatUserDefaultCheckbox* checkbox = sender;

	if (checkbox.userDefaultKey.length > 0) {
		[self.documentDelegate.documentSettings setBool:checkbox.userDefaultKey as:(checkbox.state == NSOnState)];
	}
	
	[self loadPreview];
}

- (void)didFinishPreviewAt:(NSURL *)url
{
	// Stop progress indicator
	[self.progressIndicator stopAnimation:nil];
	self.pdfView.alphaValue = 1.0;

	// Load the actual PDF into the view
	PDFDocument *doc = [[PDFDocument alloc] initWithURL:url];
	[_pdfView setDocument:doc];
	
	_firstPreview = NO;
}

- (NSArray<NSNumber*>*)hiddenRevisions
{
	NSMutableIndexSet* hiddenIndices = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, BeatRevisions.revisionGenerations.count)];
	NSArray<NSButton*>* revisionControls = @[self.revisionFirst, _revisionSecond, _revisionThird, _revisionFourth, _revisionFifth, _revisionSixth, _revisionSeventh, _revisionEight];
	
	for (NSButton* b in revisionControls) {
		if (b.state == NSOnState) [hiddenIndices removeIndex:b.tag];
	}
	
	return hiddenIndices.toArray;
}

- (NSIndexSet*)printedRevisions
{
	NSMutableIndexSet* revisions = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, BeatRevisions.revisionGenerations.count)];
	NSArray<NSButton*>* revisionControls = @[self.revisionFirst, _revisionSecond, _revisionThird, _revisionFourth, _revisionFifth, _revisionSixth, _revisionSeventh, _revisionEight];
	
	for (NSButton* b in revisionControls) {
		if (b.state != NSOnState) [revisions removeIndex:b.tag];
	}
	
	return revisions;
}

- (IBAction)toggleHeaderAlignment:(NSSegmentedControl*)sender
{
	[self.documentDelegate.documentSettings setInt:DocSettingHeaderAlignment as:sender.selectedSegment];
	[self loadPreview];
}


#pragma mark - Header text did change

- (void)controlTextDidChange:(NSNotification *)obj
{
	[self headerTextChange:nil];
}

- (IBAction)headerTextChange:(id)sender
{
	[self.documentDelegate.documentSettings setString:DocSettingHeader as:(self.headerText.stringValue != nil) ? self.headerText.stringValue : @""];
	[self loadPreview];
}

@end
