//
//  BeatPrint.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.10.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

/*
 
 This class works as an intermediate between PrintView and the Beat document
 and handles the UI side of printing, too. The printing itself is done in PrintView,
 which also does all the necessary preprocessing.
 
 This is a HORRIBLY convoluted system. I'm sorry for any inconvenience.
 
 */


#import <Quartz/Quartz.h>
#import "BeatPrint.h"
#import "PrintView.h"
#import "BeatPaperSizing.h"

#define TITLE_PRINT @"Print"
#define TITLE_PDF @"Create PDF"
#define PDF_BUTTON_WHEN_PRINTING @"PDF"
#define PDF_BUTTON @"Create PDF..."

#define PAPER_A4 595, 842
#define PAPER_USLETTER 612, 792


@interface BeatPrint ()
@property (weak) IBOutlet NSButton* printSceneNumbers;
@property (weak) IBOutlet NSButton* radioA4;
@property (weak) IBOutlet NSButton* radioLetter;
@property (weak) IBOutlet NSWindow* panel;
@property (weak) IBOutlet NSWindow* window;
@property (weak) IBOutlet PDFView* pdfView;
@property (weak) IBOutlet NSButton* printButton;
@property (weak) IBOutlet NSButton* pdfButton;
@property (weak) IBOutlet NSTextField* title;
@property (weak) IBOutlet NSTextField* headerText;
@property (weak) IBOutlet NSPopUpButton *revisedPageColorMenu;
@property (weak) IBOutlet NSButton *colorCodePages;

@property (nonatomic) NSString *compareWith;

@property (nonatomic) BeatPaperSize paperSize;
@property (nonatomic) PrintView *printView;

@property (nonatomic) bool automaticPreview;
@end

@implementation BeatPrint

- (IBAction)open:(id)sender {
	// Change panel title
	[_title setStringValue:TITLE_PRINT];
	
	// Hide the PDF button and reset keyboard shortcut
	[_pdfButton setHidden:YES];
	
	[_printButton setHidden:NO];
	[_printButton setKeyEquivalent:@"\r"];
	[self openPanel];
}
- (IBAction)openForPDF:(id)sender {
	// Change panel title
	[_title setStringValue:TITLE_PDF];
	
	// Hide print button
	[_printButton setHidden:YES];
	
	// Change value for the PDF button
	[_pdfButton setTitle:PDF_BUTTON];
	[_pdfButton setHidden:NO];
	
	// Set Create PDF as the  default button
	[_pdfButton setKeyEquivalent:@"\r"];
	
	[self openPanel];
}
- (void)openPanel {
	// Remove the previous preview
	[_pdfView setDocument:nil];
	
	// Get setting from document
	if (_document.printSceneNumbers) [_printSceneNumbers setState:NSOnState];
	else [_printSceneNumbers setState:NSOffState];
	
	// Check the paper size
	if (_document.printInfo.paperSize.width > 595) [_radioLetter setState:NSOnState];
	else [_radioA4 setState:NSOnState];
	_document.printInfo = [BeatPaperSizing setMargins:_document.printInfo];
	
	// Show window
	[self loadPreview];
	[self.window beginSheet:_panel completionHandler:nil];
}
- (IBAction)close:(id)sender {
	[self.window endSheet:_panel];
	
}
- (IBAction)print:(id)sender {
	//self.printView = [[PrintView alloc] initWithDocument:_document script:nil operation:BeatToPrint compareWith:_compareWith];
	self.printView = [[PrintView alloc] initWithDocument:_document script:nil operation:BeatToPrint settings:[self exportSettings] delegate:self];

	[self.window endSheet:_panel];
}
- (IBAction)pdf:(id)sender {
	//self.printView = [[PrintView alloc] initWithDocument:_document script:nil operation:BeatToPDF compareWith:_compareWith];
	self.printView = [[PrintView alloc] initWithDocument:self.document script:nil operation:BeatToPDF settings:[self exportSettings] delegate:self];
	[self.window endSheet:_panel];
}

- (void)loadPreview {
	// Update PDF preview
	BeatExportSettings *settings = [self exportSettings];
	
	dispatch_async(dispatch_get_main_queue(), ^(void){
		//self.printView = [[PrintView alloc] initWithDocument:self.document script:nil operation:BeatToPreview compareWith:self.compareWith delegate:self];
		self.printView = [[PrintView alloc] initWithDocument:self.document script:nil operation:BeatToPreview settings:settings delegate:self];
	});
}

- (IBAction)pickFileToCompare:(id)sender {
	NSOpenPanel *openDialog = [NSOpenPanel openPanel];
	
	[openDialog setAllowedFileTypes:@[@"fountain", @"beat"]];
	[openDialog beginSheetModalForWindow:self.panel completionHandler:^(NSModalResponse result) {
		if (result == NSFileHandlingPanelOKButton) {
			[self setComparisonFile:openDialog.URL];
			[self loadPreview];
		}
	}];
}
- (void) setComparisonFile:(NSURL*)url {
	_compareWith = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
}
- (IBAction)headerTextChange:(id)sender {
	[self loadPreview];
}

- (IBAction)selectPaperSize:(id)sender {
	BeatPaperSize oldSize = _paperSize;
	
	if ([(NSButton*)sender tag] == 1) {
		// A4
		_document.printInfo = [BeatPaperSizing setSize:BeatA4 printInfo:_document.printInfo];
		_paperSize = BeatA4;
	} else {
		// US Letter
		_document.printInfo = [BeatPaperSizing setSize:BeatUSLetter printInfo:_document.printInfo];
		_paperSize = BeatUSLetter;
	}
	
	// Preview needs refreshing
	if (oldSize != _paperSize) {
		[self loadPreview];
	}
}
- (IBAction)selectSceneNumberPrinting:(id)sender {
	if (_printSceneNumbers.state == NSOnState) {
		[_document setPrintSceneNumbers:YES];
	} else {
		[_document setPrintSceneNumbers:NO];
	}

	[self loadPreview];
}

- (IBAction)toggleColorCodePages:(id)sender {
	NSButton *checkbox = sender;
	if (checkbox.state == NSOnState) [_document setColorCodePages:YES];
	else [_document setColorCodePages:NO];

	[self loadPreview];
}
- (IBAction)setRevisedPageColor:(id)sender {
	NSPopUpButton *menu = sender;
	NSString *color = menu.selectedItem.title.lowercaseString;
	
	[_document setRevisedPageColor:color];
	[self loadPreview];
}


- (void)didFinishPreviewAt:(NSURL *)url {
	PDFDocument *doc = [[PDFDocument alloc] initWithURL:url];
	[_pdfView setDocument:doc];
}

- (BeatExportSettings*)exportSettings {
	// Set how we see revisions
	bool coloredPages = NO;
	if (_colorCodePages.state == NSOnState) coloredPages = YES;
	
	NSString *revisionColor = @"";
	if (coloredPages) revisionColor = _revisedPageColorMenu.selectedItem.title.lowercaseString;
	
	// Set header
	NSString *header = (self.headerText.stringValue.length > 0) ? self.headerText.stringValue : @"";
	
	BeatExportSettings *settings = [BeatExportSettings operation:ForPrint document:self.document header:header  printSceneNumbers:self.document.printSceneNumbers revisionColor:revisionColor coloredPages:coloredPages];
	
	return settings;
}

@end
