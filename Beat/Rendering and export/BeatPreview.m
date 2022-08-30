//
//  BeatPreview.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 This is a very convoluted system.
 All hope abandon ye who enter here.
 
 Note that we use "clever" JavaScript hack to jump to the current scene.
 Line UUIDs are baked into the review, and when toggling into preview mode,
 our document injects some JS to jump onto the correct line.
 
 */

#import "BeatPreview.h"
#import "Line.h"
#import "ContinuousFountainParser.h"
#import "BeatHTMLScript.h"
#import "BeatRevisions.h"
#import "BeatExportSettings.h"

@interface BeatPreview ()
@property (nonatomic) BeatHTMLScript *htmlGenerator;
@end

@implementation BeatPreview

- (id)initWithDocument:(id)document {
	self = [super init];
	if (self) {
		_delegate = document;
	}
	return self;
}

- (void)setup {
	[_previewView.configuration.userContentController addScriptMessageHandler:_delegate.document name:@"selectSceneFromScript"];
	[_previewView.configuration.userContentController addScriptMessageHandler:_delegate.document name:@"closePrintPreview"];
	
	[_previewView loadHTMLString:@"<html><body style='background-color: #333; margin: 0;'><section style='margin: 0; padding: 0; width: 100%; height: 100vh; display: flex; justify-content: center; align-items: center; font-weight: 200; font-family: \"Helvetica Light\", Helvetica; font-size: .8em; color: #eee;'>Creating Print Preview...</section></body></html>" baseURL:nil];
	
	if (@available(macOS 11.0, *)) {
		_previewView.pageZoom = 1.2;
	}
}

- (void)deallocPreview {
	[self.previewView.configuration.userContentController removeScriptMessageHandlerForName:@"selectSceneFromScript"];
	[self.previewView.configuration.userContentController removeScriptMessageHandlerForName:@"closePrintPreview"];
	self.previewView.navigationDelegate = nil;
	self.previewView = nil;
}

- (NSString*)createPreview {
	if (self.delegate) {
		NSString *rawText = self.delegate.text.copy;
		return [self createPreviewFor:rawText type:BeatPrintPreview];
	}
	return @"";
}
- (NSString*)createPreviewFor:(NSString*)rawScript type:(BeatPreviewType)previewType {
	ContinuousFountainParser *parser;

	if (_delegate) {
		// This is probably a normal parser, because a delegate is present
		// Parse script
		parser = [[ContinuousFountainParser alloc] initWithString:rawScript delegate:(id<ContinuousFountainParserDelegate>)_delegate nonContinuous:YES];
		
		// Get identifiers
		NSArray *uuids = [self.delegate.parser lineIdentifiers:nil];
		if (uuids.count) [parser setIdentifiers:uuids];
		
		// Bake revision attributes
		NSAttributedString *attrStr = self.delegate.attrTextCache.copy;
		[BeatRevisions bakeRevisionsIntoLines:parser.lines text:attrStr parser:parser];
	} else {
		// This is probably a QuickLook preview
		parser = [ContinuousFountainParser.alloc initWithString:rawScript];
	}
	
	// Create a script dict required by the HTML module
	BeatScreenplay *script = parser.forPrinting;
	
	if (previewType == BeatQuickLookPreview) {
		_htmlGenerator = [BeatHTMLScript.alloc initForQuickLook:script];
		return _htmlGenerator.html;
	} else {
#if TARGET_OS_IOS
		id doc = _delegate.documentForDelegation;
#else
		id doc = _delegate.document;
#endif
		
		BeatExportSettings *settings = [BeatExportSettings operation:ForPreview document:doc header:@"" printSceneNumbers:_delegate.showSceneNumberLabels printNotes:NO revisions:BeatRevisions.revisionColors scene:_delegate.currentScene.sceneNumber coloredPages:NO revisedPageColor:@""];
		settings.paperSize = _delegate.pageSize;
		_htmlGenerator = [BeatHTMLScript.alloc initWithScript:script settings:settings];
		
		return _htmlGenerator.html;
	}
}

- (void)displayPreview {
	if (_htmlString.length == 0 || !_previewUpdated) {
		// Update the preview in sync if it hasn't been built yet
		[self updatePreviewInSync:YES];
	}
	
	// Create JS scroll function call and append it straight into the HTML
	Line *currentLine = [self.delegate.parser closestPrintableLineFor:self.delegate.currentLine];
	
	NSString *scrollTo = [NSString stringWithFormat:@"<script>scrollToIdentifier('%@');</script>", currentLine.uuid.UUIDString.lowercaseString];
	
	_htmlString = [_htmlString stringByReplacingOccurrencesOfString:@"<script name='scrolling'></script>" withString:scrollTo];
	[_previewView loadHTMLString:_htmlString baseURL:nil]; // Load HTML
	
	// Revert changes to the code (so we can replace the placeholder again,
	// if needed, without recreating the whole HTML)
	_htmlString = [_htmlString stringByReplacingOccurrencesOfString:scrollTo withString:@"<script name='scrolling'></script>"];
	
	// Evaluate JS in window to be sure it shows the correct scene
	[_previewView evaluateJavaScript:[NSString stringWithFormat:@"scrollToIdentifier(%@);", currentLine.uuid.UUIDString.lowercaseString] completionHandler:nil];
	
}

/// Update preview either in background or in sync
- (void)updatePreviewInSync:(bool)sync {
	[_previewTimer invalidate];
	self.previewUpdated = NO;
	
	// Wait 1.5 seconds after writing has ended to build preview
	// If there is no preview present, do it immediately
	CGFloat previewWait = 1.5;
	if (_htmlString.length < 1 || sync) {
		[self updateHTMLWithContents:self.delegate.text.copy];
	} else {
		_previewTimer = [NSTimer scheduledTimerWithTimeInterval:previewWait repeats:NO block:^(NSTimer * _Nonnull timer) {
			NSString *rawText = self.delegate.text.copy;
			
			dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
				[self updateHTMLWithContents:rawText];
			});
		}];
	}
}

- (void)updateHTMLWithContents:(NSString*)string {
	__block NSString *html = [self createPreviewFor:string type:BeatPrintPreview];
	self.htmlString = html;
	self.previewUpdated = YES;
	[self.delegate previewDidFinish];
}

- (BeatPaginator*)paginator {
	return _htmlGenerator.paginator;
}

/*
 
 Sä näytät tosi hienolta, Zaia
 kun poltat savukkeen ja katot valokuvia
 sä olet itse niissä
 ja koko huone (myöskin mä)
 on siin kans
 
 */

@end
