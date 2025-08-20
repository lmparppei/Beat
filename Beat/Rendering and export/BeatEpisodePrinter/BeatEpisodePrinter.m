//
//  BeatEpisodePrinter.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 10.1.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatCore.h>

#import "BeatEpisodePrinter.h"
#import "NSMutableArray+MoveItem.h"
#import "Beat-Swift.h"

@interface BeatEpisodePrinter ()
@property (weak) IBOutlet NSTableView *table;
@property (weak) IBOutlet NSTextField *headerText;

@property (nonatomic) NSMutableArray<NSURL*> *urls;
@property (nonatomic) BeatPrintView* printView;

@property (weak) IBOutlet NSProgressIndicator *progressBar;

@property (weak) IBOutlet NSButton *printButton;
@property (weak) IBOutlet NSButton *pdfButton;
@property (weak) IBOutlet NSButton *radioA4;
@property (weak) IBOutlet NSButton *radioLetter;

@property (weak) IBOutlet NSButton *colorCodePages;
@property (weak) IBOutlet NSPopUpButton *revisedPageColorMenu;
@end

@implementation BeatEpisodePrinter

- (instancetype)init {
	return [super initWithWindowNibName:@"BeatEpisodePrinter" owner:self];
}

- (void)awakeFromNib {
	[_table registerForDraggedTypes:@[NSPasteboardTypeString, @"public.file-url"]]; //NSPasteboardTypeURL is only available 10.13->
}

- (void)windowDidLoad {
	[self.window setFrame:NSMakeRect(
									 (NSScreen.mainScreen.frame.size.width - self.window.frame.size.width) / 2,
									 (NSScreen.mainScreen.frame.size.height - self.window.frame.size.height) / 2,
									 self.window.frame.size.width, self.window.frame.size.height
									 )
						 display:YES];
}

#pragma mark - Select Paper Size

- (IBAction)selectPaper:(id)sender {
	
}

#pragma mark - Table view data source & delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return _urls.count;
}

-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSString *identifier = tableColumn.identifier;
	NSTableCellView *cell = [tableView makeViewWithIdentifier:identifier owner:tableView];
	
	NSURL *url = self.urls[row];
	NSString *name = url.path.lastPathComponent.stringByDeletingPathExtension;
	
	cell.textField.stringValue = name;
	
	return cell;
}

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row {
	NSString *stringRep = self.urls[row].path.lastPathComponent.stringByDeletingPathExtension;
	NSPasteboardItem *pboardItem = [[NSPasteboardItem alloc] init];

	[pboardItem setString:stringRep forType:NSPasteboardTypeString];

	return pboardItem;
}
-(NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
	if (dropOperation == NSTableViewDropAbove) {
		tableView.draggingDestinationFeedbackStyle = NSTableViewDraggingDestinationFeedbackStyleSourceList;
		return NSDragOperationMove;
	} else {
		return NSDragOperationNone;
	}
}
- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
	if (!_urls) _urls = [NSMutableArray array];
		
	NSArray *items = info.draggingPasteboard.pasteboardItems;
	if (!items.count) return NO;

	NSPasteboardItem *item = items.firstObject;
	if ([item.types containsObject:@"public.file-url"]) {
		bool newFilesAdded = NO;
		
		for (NSPasteboardItem *newFile in items) {
			NSString *urlString = [newFile stringForType:@"public.file-url"];
			NSURL *url = [NSURL URLWithString:urlString];

			if (![_urls containsObject:url]) {
				[_urls addObject:url];
				newFilesAdded = YES;
			}
		}
		
		if (newFilesAdded) {
			[self.table reloadData];
			return YES;
		}
	}
	
	// When dragging we need to handle strings for some reason.
	// This shouldn't be so, but what can I say.
	
	NSString *filenameStub =  [item stringForType:NSPasteboardTypeString];
	NSURL *url = [self urlForFilename:filenameStub];
	NSInteger index = [self.urls indexOfObject:url];
	
	if (index >= 0) {
		[_urls moveObjectAtIndex:index toIndex:row];
		[_table reloadData];
		return YES;
	} else {
		return NO;
	}

}

-(id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	return self.urls[row];
}

-(NSURL*)urlForFilename:(NSString*)filenameStub {
	bool found = NO;
	NSInteger index = 0;
	
	for (NSURL *url in self.urls) {
		NSString *filename = url.path.lastPathComponent.stringByDeletingPathExtension;
		if ([filename isEqualToString:filenameStub]) {
			found = YES;
			break;
		}
		index++;
	}
	
	if (found) return self.urls[index];
	else return nil;
}

# pragma mark - UI functions

-(IBAction)removeFile:(id)sender {
	if (!_urls) _urls = [NSMutableArray array];
	
	NSInteger index = _table.selectedRow;
	
	if (index >= 0) {
		NSURL *url = self.urls[index];
		[_urls removeObject:url];
		[_table removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:index] withAnimation:NSTableViewAnimationSlideUp];
	}
}
-(IBAction)addFiles:(id)sender {
	if (!_urls) _urls = [NSMutableArray array];
	
	NSOpenPanel *dialog = [NSOpenPanel openPanel];
	dialog.allowsMultipleSelection = YES;
	dialog.allowedFileTypes = @[@"fountain"];
	
	if ([dialog runModal] == NSModalResponseOK) {
		for (NSURL *url in dialog.URLs) {
			if (![_urls containsObject:url]) [_urls addObject:url];
		}
		
		[_table reloadData];
	}
}

#pragma mark - Print all documents

-(IBAction)cancel:(id)sender {
	[self close];
}

-(IBAction)print:(id)sender {
	if (!_urls.count) return;
	
	[self printDocuments:NO];
}
-(IBAction)createPDF:(id)sender {
	if (!_urls.count) return;
	
	[self printDocuments:YES];
}


- (void)toggleProgressUI:(bool)inProgress {
	if (inProgress) {
		// Setup progress bar
		_progressBar.maxValue = _urls.count * 1.0;
		_progressBar.doubleValue = 0.0;

		[_progressBar setHidden:NO];
		
		[_printButton setEnabled:NO];
		[_pdfButton setEnabled:NO];
	} else {
		[_progressBar setHidden:YES];
		
		[_printButton setEnabled:YES];
		[_pdfButton setEnabled:YES];
	}
}

- (BeatExportSettings*)settings
{
	NSString *header = (self.headerText.stringValue.length) ? self.headerText.stringValue : @"";
	
	bool colorCodePages = NO;
	NSString *revisedPageColor = @"";
	if (self.colorCodePages.state == NSOnState) {
		colorCodePages = YES;
		revisedPageColor = _revisedPageColorMenu.selectedItem.title.lowercaseString;
	}
	
	BeatExportSettings *settings = [BeatExportSettings operation:ForPrint document:nil header:header printSceneNumbers:YES printNotes:NO revisions:BeatRevisions.everyRevisionIndex scene:nil coloredPages:colorCodePages revisedPageColor:revisedPageColor];
	settings.paperSize = (_radioA4.state == NSOnState) ? BeatA4 : BeatUSLetter;

	return settings;
}

- (void)printDocuments:(bool)toPDF
{
	[self toggleProgressUI:YES];
				
	BeatExportSettings *settings = [self settings];
	
	// The operation can be quite heavy, so do it in another thread
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		NSError *error;

		// Parse documents
		NSMutableArray<BeatScreenplay*>* screenplays = NSMutableArray.new;
		for (NSURL* url in self.urls) {
			NSString *text = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
			
			if (error) {
				NSString *filename = url.path.lastPathComponent;
				[self alertPanelWithTitle:@"Error Opening File" content:[NSString stringWithFormat:@"%@ could not be opened. Other documents will be printed normally.", filename]];
				error = nil;
			} else {
				// Add processed screenplay to queue
				BeatScreenplay* screenplay = [self screenplayForText:text settings:settings];
				[screenplays addObject:screenplay];
				
				dispatch_async(dispatch_get_main_queue(), ^{
					[self.progressBar incrementBy:1.0];
					[self.progressBar display];
				});
			}
		}
		
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			BeatPrintingOperation operation = (toPDF) ? BeatPrintingOperationToPDF : BeatPrintingOperationToPrint;
			
			self.printView = [BeatPrintView.alloc initWithWindow:self.window operation:operation settings:settings delegate:nil screenplays:screenplays callback:^(BeatPrintView * _Nonnull printing, id _Nullable item) {
				[self close];
			}];

		});
	});
}

-(BeatScreenplay*)screenplayForText:(NSString*)text settings:(BeatExportSettings*)exportSettings {
	BeatDocumentSettings *settings = BeatDocumentSettings.new;
	[settings readSettingsAndReturnRange:text];
	
	ContinuousFountainParser *parser = [ContinuousFountainParser.alloc initStaticParsingWithString:text settings:settings];
	
	// Bake revision data into the document
	NSDictionary *revisions = [settings get:DocSettingRevisions];
	if (revisions.count) [BeatRevisions bakeRevisionsIntoLines:parser.lines revisions:revisions string:text];
	
	BeatScreenplay* screenplay = [BeatScreenplay from:parser settings:exportSettings];
	return screenplay;
}

-(void)alertPanelWithTitle:(NSString*)title content:(NSString*)content {
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:title];
	[alert setInformativeText:content];
	[alert setAlertStyle:NSAlertStyleWarning];
	
	[alert runModal];
}


@end
