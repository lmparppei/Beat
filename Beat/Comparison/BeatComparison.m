//
//  BeatComparison.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.10.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

/*
 
 You who will emerge from the flood
 In which we have gone under
 Remember
 When you speak of our failings
 The dark time too
 Which you have escaped.
 
 This is a class for comparing two Fountain files against each other, using Google's
 diff-match-patch framework.
 
 The system is a bit convoluted, so let me elaborate. This class also provides the
 UI functions, which then sends the script to PrintView, which THEN calls this class
 again to set comparison markers (line.changed = YES) and prints out the HTML file.
 
 Comparison can be run outside the UI too:
 BeatComparison *comparison = [[BeatComparison alloc] init];
 [comparison compare:parser.lines with:oldScript];
 
 It's multiple systems built on top of each other in a messy way, but it works for now.
 Hopefully I don't need to touch it again.
 
 */

#import <Cocoa/Cocoa.h>
#import <DiffMatchPatch/DiffMatchPatch.h>
#import <WebKit/WebKit.h>
#import <Quartz/Quartz.h>
#import "BeatComparison.h"

#import "ContinousFountainParser.h"
#import "Line.h"
#import "OutlineScene.h"
#import "BeatPreview.h"
#import "PrintView.h"

@interface BeatComparison ()
@property (weak) IBOutlet NSWindow *panel;
@property (weak) IBOutlet NSTextField *fileLabel;
@property (weak) IBOutlet NSTextField *reportLabel;
@property (nonatomic) IBOutlet WKWebView *webView;
@property (weak) IBOutlet PDFView *pdfView;
@property (strong, nonatomic) PrintView *printView;

@property (nonatomic) NSURL *compareWith;
@property (nonatomic) BeatPreview *preview;

@end

@implementation BeatComparison


- (IBAction)open:(id)sender {
	[self updatePreview];
	[self.window beginSheet:_panel completionHandler:nil];
}
- (IBAction)close:(id)sender {
	[self.window endSheet:_panel];
}
- (IBAction)pickFile:(id)sender {
	NSOpenPanel *openDialog = [NSOpenPanel openPanel];
	
	[openDialog setAllowedFileTypes:@[@"fountain"]];
	[openDialog beginSheetModalForWindow:self.panel completionHandler:^(NSModalResponse result) {
		if (result == NSFileHandlingPanelOKButton) {
			//NSError *error;
			
			[self setFile:openDialog.URL];
			[self updatePreview];
			
			//NSString *previousVersion = [NSString stringWithContentsOfURL:previousVersionURL encoding:NSUTF8StringEncoding error:&error];
			
			/*
			if (self.printSceneNumbers) {
				self.preprocessedText = [self preprocessSceneNumbers];
			} else {
				self.preprocessedText = [self.getText copy];
			}
			
			self.printView = [[PrintView alloc] initWithDocument:self toPDF:NO toPrint:YES compareWith:previousVersion];
			 */
		}
	}];
}

- (void) didFinishPreviewAt:(NSURL*)url {
	// Delegate method to update the PDF preview window
	
	PDFDocument *doc = [[PDFDocument alloc] initWithURL:url];
	[self.pdfView setDocument:doc];
	[self.pdfView setScaleFactor:.5];
}

- (void)updatePreview {
	// Note: this is asynchronous, so it shouldn't be too heavy on the CPU
	NSString *oldScript;
	if (_compareWith != nil) {
		oldScript = [NSString stringWithContentsOfURL:self.compareWith encoding:NSUTF8StringEncoding error:nil];
	}
	
	
	self.printView = [[PrintView alloc] initWithDocument:_document script:_currentScript operation:BeatToPreview compareWith:oldScript delegate:self];
	
	NSMutableString *newScript = [NSMutableString string];
	for (Line *line in self.currentScript) {
		[newScript appendString:line.string];
		[newScript appendString:@"\n"];
	}
	
	if (!self.compareWith) return;
	
	NSArray *diffs = [self diffReportFrom:newScript with:[NSString stringWithContentsOfURL:self.compareWith encoding:NSUTF8StringEncoding error:nil]];
	
	NSInteger additions = 0;
	NSInteger removals = 0;
	
	for (Diff *d in diffs) {
		
		if (d.operation == DIFF_DELETE) removals += d.text.length;
		else if (d.operation == DIFF_INSERT) additions += d.text.length;
	}
	
	NSString* report = [NSString stringWithFormat:@"%lu characters added\n%lu characters deleted", additions, removals];
	[_reportLabel setStringValue:report];
	
	/*
	NSMutableArray *elements = [NSMutableArray array];
	NSMutableArray *titlePage = [NSMutableArray array];
	
	Line *previousLine;
	
	for (Line* line in self.currentScript) {
		if (line.isTitlePage) {
			[titlePage addObject:line];
			continue;;
		}
		// Skip over certain elements
		if (line.type == synopse || line.type == section || line.omited) {
			if (line.type == empty) previousLine = line;
			continue;
		}
	
		// This is a paragraph with a single line break,
		// so append the line to the previous one
		if (line.type == action && line.isSplitParagraph && [self.currentScript indexOfObject:line] > 0) {
			Line *previousLine = [elements objectAtIndex:elements.count - 1];

			previousLine.string = [previousLine.string stringByAppendingFormat:@"\n%@", line.cleanedString];
			continue;
		}
		
		if (line.type == dialogue && line.string.length < 1) {
			line.type = empty;
			previousLine = line;
			continue;
		}

		[elements addObject:line];
				
		// If this is dual dialogue character cue,
		// we need to search for the previous one too
		if (line.isDualDialogueElement) {
			bool previousCharacterFound = NO;
			NSInteger i = elements.count - 2; // Go for previous element
			while (i > 0) {
				Line *previousLine = [elements objectAtIndex:i];
				
				if (!(previousLine.isDialogueElement || previousLine.isDualDialogueElement)) break;
				
				if (previousLine.type == character ) {
					previousLine.nextElementIsDualDialogue = YES;
					previousCharacterFound = YES;
					break;
				}
				i--;
			}
		}
		
		previousLine = line;
	}
	
	NSDictionary *script = @{ @"script": elements, @"title page": titlePage  };
	
	NSString *preview = [BeatPreview createNewPreview:script of:nil scene:nil sceneNumbers:NO type:BeatComparisonPreview];
	[_webView loadHTMLString:preview baseURL:nil];
	*/
}

- (void)setFile:(NSURL*)url {
	self.compareWith = url;
	[self.fileLabel setStringValue:url.path.lastPathComponent];
}

- (NSArray*)diffReportFrom:(NSString*)newScript with:(NSString*)oldScript {
	DiffMatchPatch *diff = [[DiffMatchPatch alloc] init];
		
	// Get edited lines
	NSArray *lines = [diff diff_linesToCharsForFirstString:oldScript andSecondString:newScript];
	NSMutableArray *diffs = [diff diff_mainOfOldString:lines[0] andNewString:lines[1] checkLines:YES];
	
	// Operate the diff report
	[diff diff_chars:diffs toLines:lines[2]];
	[diff diff_cleanupSemantic:diffs];
	
	return diffs;
}

- (void)compare:(NSArray*)script with:(NSString*)oldScript {
	
	NSMutableString *newScript = [NSMutableString string];
	for (Line *line in script) {
		[newScript appendString:line.string];
		[newScript appendString:@"\n"];
	}
	
	NSArray *diffs = [self diffReportFrom:newScript with:oldScript];
	
	// Go through the changed indices and calculate their positions
	// NB: We are running diff-match-patch in line mode, so basically the line indices for inserts should do.
	NSInteger index = 0;
	NSMutableIndexSet *changedIndices = [NSMutableIndexSet indexSet];
	
	NSMutableArray *changedRanges = [NSMutableArray array];
	
	for (Diff *d in diffs) {
		if (d.operation == DIFF_EQUAL) {
			index += d.text.length;
		}
		else if (d.operation == DIFF_INSERT) {
			// This is a new line
			[changedIndices addIndex:index];
			NSRange changedRange = NSMakeRange(index, d.text.length);
			[changedRanges addObject:[NSNumber valueWithRange:changedRange]];
			
			index += d.text.length;
		} else {
			// ... and ignore deletions.
		}
		
	}
	
	// Go through the parsed lines and look if they are contained within changed ranges
	for (Line *l in script) {
		if (l.type == empty || l.isTitlePage) { l.changed = NO; continue; }
		
		bool changed = NO;
		
		NSRange lineRange = NSMakeRange(l.position, l.string.length);
		for (NSNumber *range in changedRanges) {
			if (NSIntersectionRange(range.rangeValue, lineRange).length > 0) {
				changed = YES;
			}
		}
		
		// Mark the line as changed
		if (changed) l.changed = YES;
	}
}

@end
