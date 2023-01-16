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

#import <BeatParsing/BeatParsing.h>
#import "BeatPrintDialog.h"
#import "BeatPrintView.h"
#import "Beat-Swift.h"

#define ADVANCED_PRINT_OPTIONS_KEY @"Show Advanced Print Options"

@interface BeatPrintDialog ()

@property (weak) IBOutlet NSButton* printSceneNumbers;
@property (weak) IBOutlet NSButton* radioA4;
@property (weak) IBOutlet NSButton* radioLetter;
@property (weak) IBOutlet PDFView* pdfView;
@property (weak) IBOutlet NSButton* primaryButton;
@property (weak) IBOutlet NSButton* secondaryButton;
@property (weak) IBOutlet NSTextField* title;
@property (weak) IBOutlet NSTextField* headerText;
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

@property (weak) IBOutlet BeatCustomExportStyles* exportStyles;

@property (nonatomic) NSString *compareWith;

@property (nonatomic) BeatPrintView *printView;

@property (nonatomic) bool automaticPreview;

@property (nonatomic) NSMutableArray<BeatNativePrinting*>* renderQueue;

@end

@implementation BeatPrintDialog

static CGFloat panelWidth;

+ (BeatPrintDialog*)showForPDF:(id)delegate {
	BeatPrintDialog *dialog = [BeatPrintDialog.alloc initWithWindowNibName:self.className];
	dialog.documentDelegate = delegate;
	[dialog openForPDF:nil];
	return dialog;
}
+ (BeatPrintDialog*)showForPrinting:(id)delegate {
	BeatPrintDialog *dialog = [BeatPrintDialog.alloc initWithWindowNibName:self.className];
	dialog.documentDelegate = delegate;
	[dialog open:nil];
	return dialog;
}

-(instancetype)initWithWindowNibName:(NSNibName)windowNibName {
	return [super initWithWindowNibName:windowNibName owner:self];
}

#pragma mark - Window actions

-(void)awakeFromNib {
	self.renderQueue = NSMutableArray.new;
	
	// Show advanced options?
	panelWidth = self.window.frame.size.width;
	bool showAdvancedOptions = [NSUserDefaults.standardUserDefaults boolForKey:ADVANCED_PRINT_OPTIONS_KEY];
	if (showAdvancedOptions) _advancedOptionsButton.state = NSOnState; else _advancedOptionsButton.state = NSOffState;
	
	[self toggleAdvancedOptions:_advancedOptionsButton];
}

- (IBAction)open:(id)sender {
	[self openPanel];
	
	// Change panel title
	_title.stringValue = NSLocalizedString(@"print.print", nil);
		
	// Switch buttons to prioritize printing
	_primaryButton.title = NSLocalizedString(@"print.printButton", nil);
	_primaryButton.action = @selector(print:);
	
	_secondaryButton.title = NSLocalizedString(@"print.pdfButton", nil);
	_secondaryButton.action = @selector(pdf:);
}

- (IBAction)openForPDF:(id)sender {
	[self openPanel];
	
	// Change panel title
	[_title setStringValue:NSLocalizedString(@"print.createPDF", nil)];
	
	// Switch buttons to prioritize PDF creation
	_primaryButton.title = NSLocalizedString(@"print.pdfButton", nil);
	_primaryButton.action = @selector(pdf:);
	
	_secondaryButton.title = NSLocalizedString(@"print.printButton", nil);
	_secondaryButton.action = @selector(print:);
}
- (void)openPanel {
	NSLog(@"Opening print dialog: %@", self.window);
		
	// Remove the previous preview
	[_pdfView setDocument:nil];
			
	// Get setting from document
	if (_documentDelegate.printSceneNumbers) [_printSceneNumbers setState:NSOnState];
	else [_printSceneNumbers setState:NSOffState];
	
	// Update export styles
	[_exportStyles reloadData];
	
	// Check the paper size
	// WIP: Unify these so the document knows its BeatPaperSize too
	if (_documentDelegate.pageSize == BeatA4) [_radioA4 setState:NSOnState];
	else [_radioLetter setState:NSOnState];

	// To be absolutely sure, set print info to match page size setting
	[BeatPaperSizing setPageSize:_documentDelegate.pageSize printInfo:_documentDelegate.printInfo];
	
	// We have to show the panel here to be able to set the radio buttons (???)
	[self.documentDelegate.documentWindow beginSheet:self.window completionHandler:^(NSModalResponse returnCode) {
		[self.documentDelegate releasePrintDialog];
	}];
	
	// Reload PDF preview
	[self loadPreview];

}
- (IBAction)close:(id)sender {
	[self.documentDelegate.documentWindow endSheet:self.window];
	[self.documentDelegate releasePrintDialog];
	
}

#pragma mark - Printing

- (IBAction)print:(id)sender {
	BeatPrintView *printView = [[BeatPrintView alloc] initWithDocument:_documentDelegate.document script:nil operation:BeatToPrint settings:[self exportSettings] delegate:self];
	[self addPrintViewToQueue:printView];
	
	[self.documentDelegate.documentWindow endSheet:self.window];
}
- (IBAction)pdf:(id)sender {
	if (self.documentDelegate.nativeRendering) {
		BeatNativePrinting* printing = [BeatNativePrinting.alloc initWithWindow:self.window operation:BeatPrintingOperationToPreview settings:[self exportSettings] delegate:self.documentDelegate screenplay:nil callback:^(BeatNativePrinting * _Nonnull operation, id _Nullable value) {
			[self.renderQueue removeObject:operation];
			
			NSURL* url = (NSURL*)value;
			[self didFinishPreviewAt:url];
		}];
		
		// Add to render queue (to keep the printing operation in memory)
		[self.renderQueue addObject:printing];
		
	} else {
		BeatPrintView *printView = [[BeatPrintView alloc] initWithDocument:_documentDelegate.document script:nil operation:BeatToPDF settings:[self exportSettings] delegate:self];
		[self addPrintViewToQueue:printView];
		
		[self.documentDelegate.documentWindow endSheet:self.window];
	}
}

- (void)printingDidFinish {
	[self.documentDelegate.documentWindow endSheet:self.window];
}

- (void)loadPreview {
	// Start progress indicator
	[self.progressIndicator startAnimation:nil];
	
	// Update PDF preview
	BeatExportSettings *settings = [self exportSettings];
	
	if (self.documentDelegate.nativeRendering) {
		// Native rendering for development
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			BeatNativePrinting* operation = [BeatNativePrinting.alloc initWithWindow:self.window operation:BeatPrintingOperationToPreview settings:settings delegate:self.documentDelegate screenplay:nil callback:^(BeatNativePrinting * _Nonnull operation, id _Nullable value) {
				[self.renderQueue removeObject:operation];
				
				NSURL* url = (NSURL*)value;
				[self didFinishPreviewAt:url];
			}];
			[self.renderQueue addObject:operation];
		});
		
	} else {
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			@synchronized (self) {
				BeatPrintView * printView = [[BeatPrintView alloc] initWithDocument:self.documentDelegate.document script:nil operation:BeatToPreview settings:settings delegate:self];
				[self addPrintViewToQueue:printView];
			}
		});
	}
}

/// Adds the print view to document's queue. It will be automatically removed by the print view itself.
- (void)addPrintViewToQueue:(BeatPrintView*)printView {
	if (self.documentDelegate.printViews == nil) self.documentDelegate.printViews = NSMutableArray.new;
	[self.documentDelegate.printViews addObject:printView];
}


#pragma mark - Export settings

- (IBAction)headerTextChange:(id)sender {
	[self loadPreview];
}

- (IBAction)selectPaperSize:(id)sender {
	BeatPaperSize oldSize = _documentDelegate.pageSize;
	
	if ([(NSButton*)sender tag] == 1) {
		// A4
		_documentDelegate.pageSize = BeatA4;
	} else {
		// US Letter
		_documentDelegate.pageSize = BeatUSLetter;
	}
	
	[BeatPaperSizing setPageSize:_documentDelegate.pageSize printInfo:_documentDelegate.printInfo];
	
	// Preview needs refreshing
	if (oldSize != _documentDelegate.pageSize) {
		[self loadPreview];
	}
}
- (IBAction)selectSceneNumberPrinting:(id)sender {
	if (_printSceneNumbers.state == NSOnState) {
		[_documentDelegate setPrintSceneNumbers:YES];
	} else {
		[_documentDelegate setPrintSceneNumbers:NO];
	}

	[self loadPreview];
}

- (IBAction)toggleAdvancedOptions:(id)sender {
	NSButton *button = sender;
	
	NSRect frame = self.window.contentView.frame;
	if (button.state == NSOffState) {
		frame.size.width = panelWidth - _advancedOptionsWidthConstraint.constant;
		[NSUserDefaults.standardUserDefaults setBool:NO forKey:ADVANCED_PRINT_OPTIONS_KEY];
	} else {
		frame.size.width = panelWidth;
		[NSUserDefaults.standardUserDefaults setBool:YES forKey:ADVANCED_PRINT_OPTIONS_KEY];
	}
	
	[self.window.animator setFrame:frame display:YES];
}

- (IBAction)toggleColorCodePages:(id)sender {
	NSButton *checkbox = sender;
	if (checkbox.state == NSOnState) [_documentDelegate.documentSettings setBool:DocSettingColorCodePages as:YES];
	else [_documentDelegate.documentSettings setBool:DocSettingColorCodePages as:NO];

	[self loadPreview];
}
- (IBAction)setRevisedPageColor:(id)sender {
	NSPopUpButton *menu = sender;
	NSString *color = menu.selectedItem.title.lowercaseString;
	
	[_documentDelegate.documentSettings set:DocSettingRevisedPageColor as:color];
	[self loadPreview];
}

- (IBAction)toggleRevision:(id)sender {
	[self loadPreview];
}


- (void)didFinishPreviewAt:(NSURL *)url {
	// Stop progress indicator
	[self.progressIndicator stopAnimation:nil];
	
	// This is a hack. Sorry.
	// We find the scroll view for PDFView, save its bounds and load them when
	// the preview is refreshed. Because the coordinate system is flipped, we
	// can only do it after the initial preview was created, not to end up at the
	// end of the document.
	static bool firstPreview = YES;
	NSScrollView *scrollView = _pdfView.subviews.firstObject;
	NSRect frame = scrollView.contentView.bounds;
	
	// Load the actual PDF into the view
	PDFDocument *doc = [[PDFDocument alloc] initWithURL:url];
	[_pdfView setDocument:doc];
	
	// Load the old bounds (if this is not the first time preview was loaded)
	if (!firstPreview) scrollView.contentView.bounds = frame;
	firstPreview = NO;
}

- (BeatExportSettings*)exportSettings {
	// Set how we see revisions
	bool coloredPages = NO;
	if (_colorCodePages.state == NSOnState) coloredPages = YES;
	
	NSString *revisionColor = @"";
	if (coloredPages) revisionColor = _revisedPageColorMenu.selectedItem.title.lowercaseString;
	
	// Set header
	NSString *header = (self.headerText.stringValue.length > 0) ? self.headerText.stringValue : @"";
	
	// Get custom CSS
	NSString *css = self.exportStyles.customCSS;
	
	BeatExportSettings *settings = [BeatExportSettings operation:ForPrint document:self.documentDelegate.document header:header printSceneNumbers:self.documentDelegate.printSceneNumbers printNotes:NO revisions:[self printedRevisions] scene:@"" coloredPages:coloredPages revisedPageColor:revisionColor];

	settings.paperSize = self.documentDelegate.pageSize;
	settings.customCSS = css;
	
	settings.sceneHeadingSpacing = [BeatUserDefaults.sharedDefaults getInteger:BeatSettingSceneHeadingSpacing];
	
	return settings;
}

- (NSArray*)printedRevisions {
	NSMutableArray *printedRevisions = NSMutableArray.new;
	NSArray *colors = BeatRevisions.revisionColors;
	if (self.revisionFirst.state == NSOnState) [printedRevisions addObject:colors[0]];
	if (self.revisionSecond.state == NSOnState) [printedRevisions addObject:colors[1]];
	if (self.revisionThird.state == NSOnState) [printedRevisions addObject:colors[2]];
	if (self.revisionFourth.state == NSOnState) [printedRevisions addObject:colors[3]];
	
	return printedRevisions;
}

@end
