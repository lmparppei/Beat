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
 Line UUIDs are baked into the lines, and when toggling into preview mode,
 our document injects some JS to jump onto the correct line.
 
 */

#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatCore.h>
#import "BeatPreview.h"
#import "BeatHTMLScript.h"

@interface BeatPreview ()
@property (nonatomic) BeatHTMLScript *htmlGenerator;
@property (nonatomic) ContinuousFountainParser *parser;
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

/// Create a preview with pre-paginated content from the paginator in document (this should be the way from now on, until we get the new renderer)
- (NSString*)createPreviewFromPaginator:(BeatPaginator*)paginator {
	NSArray *pages = (paginator != nil) ? paginator.pages.copy : @[];

	NSArray *titlePage = @[];
	if (_delegate != nil) {
		NSString *strForTitlePage = _delegate.text;
		titlePage = [ContinuousFountainParser titlePageForString:strForTitlePage];
	}
	
	return [self createPreviewWithPages:pages titlePage:titlePage];
}

/// Create preview with given pages and title page
- (NSString*)createPreviewWithPages:(NSArray*)pages titlePage:(NSArray*)titlePage {
#if TARGET_OS_IOS
	id doc = _delegate.documentForDelegation;
#else
	id doc = _delegate.document;
#endif
	
	BeatExportSettings *settings = [BeatExportSettings operation:ForPreview document:doc header:@"" printSceneNumbers:_delegate.showSceneNumberLabels printNotes:NO revisions:BeatRevisions.revisionColors scene:_delegate.currentScene.sceneNumber coloredPages:NO revisedPageColor:@""];
	settings.paperSize = _delegate.pageSize;

	// This following weird code salad is here to circumvent strange corpse exceptions
	BeatHTMLScript *generator = [BeatHTMLScript.alloc initWithPages:pages titlePage:titlePage settings:settings];
	NSString * html = generator.html;
	_htmlGenerator = generator;
	
	return html;
}

- (NSString*)createPreview {
	if (self.delegate) {
		NSString *rawText = self.delegate.text.copy;
		return [self createPreviewFor:rawText type:BeatPrintPreview];
	}
	return @"";
}

- (NSString*)createPreviewFor:(NSString*)rawScript type:(BeatPreviewType)previewType {
	if (_delegate) {
		// This is probably a normal parser, because a delegate is present
		// Parse script
		self.parser = [[ContinuousFountainParser alloc] initWithString:rawScript delegate:(id<ContinuousFountainParserDelegate>)_delegate nonContinuous:YES];
		
		// Get identifiers
		NSArray *uuids = [self.delegate.parser lineIdentifiers:nil];
		if (uuids.count) [self.parser setIdentifiers:uuids];
		
		// Bake revision attributes
		NSAttributedString *attrStr = self.delegate.attributedString.copy;
		[BeatRevisions bakeRevisionsIntoLines:self.parser.lines text:attrStr];
	} else {
		// This is probably a QuickLook preview
		self.parser = [ContinuousFountainParser.alloc initWithString:rawScript];
	}
	
	// Create a script dict required by the HTML module
	BeatScreenplay *script = self.parser.forPrinting;
	
	if (previewType == BeatQuickLookPreview) { // Quick look preview
		_htmlGenerator = [BeatHTMLScript.alloc initForQuickLook:script];
		return _htmlGenerator.html;
	} else { // Normal preview
		
#if TARGET_OS_IOS
		id doc = _delegate.documentForDelegation;
#else
		id doc = _delegate.document;
#endif
		
		BeatExportSettings *settings = [BeatExportSettings operation:ForPreview document:doc header:@"" printSceneNumbers:_delegate.showSceneNumberLabels printNotes:NO revisions:BeatRevisions.revisionColors scene:_delegate.currentScene.sceneNumber coloredPages:NO revisedPageColor:@""];
		settings.paperSize = _delegate.pageSize;
		
		// This following weird code salad is here to circumvent strange corpse exceptions
		BeatHTMLScript *generator = [BeatHTMLScript.alloc initWithScript:script settings:settings];
		
		NSString * html = generator.html;
		_htmlGenerator = generator;
		
		return html;
	}
}

- (void)displayPreview {
	if (_htmlString.length == 0 || !_previewUpdated) {
		// Update the preview in sync if it hasn't been built yet
		[self updatePreviewSynchronized];
	}
	
	// Create JS scroll function call and append it straight into the HTML
	Line *currentLine = [self.delegate.parser closestPrintableLineFor:self.delegate.currentLine];
	
	NSString *scrollTo = [NSString stringWithFormat:@"<script>scrollToIdentifier('%@');</script>", currentLine.uuid.UUIDString.lowercaseString];
	
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		self.htmlString = [self.htmlString stringByReplacingOccurrencesOfString:@"<script name='scrolling'></script>" withString:scrollTo];
		[self.previewView loadHTMLString:self.htmlString baseURL:NSBundle.mainBundle.resourceURL]; // Load HTML
		
		// Revert changes to the code (so we can replace the placeholder again,
		// if needed, without recreating the whole HTML)
		self.htmlString = [self.htmlString stringByReplacingOccurrencesOfString:scrollTo withString:@"<script name='scrolling'></script>"];
		
		// Evaluate JS in window to be sure it shows the correct scene
		[self.previewView evaluateJavaScript:[NSString stringWithFormat:@"scrollToIdentifier(%@);", currentLine.uuid.UUIDString.lowercaseString] completionHandler:nil];
	});
	
}

/// Update preview either in background or in sync
- (void)updatePreviewInSync:(bool)sync {
	NSLog(@"PREVIEW: updatePreviewInSync: should be deprecated.");
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

- (void)updatePreviewSynchronized {
	self.previewUpdated = false;
	
	self.htmlString = [self createPreviewFor:self.delegate.text type:BeatPrintPreview];
	self.previewUpdated = true;
	[self.delegate previewDidFinish];
}

- (void)updatePreviewWithPages:(NSArray*)pages titlePage:(NSArray*)titlePage {
	self.htmlString = [self createPreviewWithPages:pages titlePage:titlePage];
	[self.delegate previewDidFinish];
	self.previewUpdated = true;
}

- (void)updateHTMLWithContents:(NSString*)string {
	__block NSString *html = [self createPreviewFor:string type:BeatPrintPreview];
	self.htmlString = html;
	self.previewUpdated = YES;
	[self.delegate previewDidFinish];
}

- (BeatPaginator*)paginator {
	return _delegate.paginator;
	//return _htmlGenerator.paginator;
}

/*
 
 Sä näytät tosi hienolta, Zaia
 kun poltat savukkeen ja katot valokuvia
 sä olet itse niissä
 ja koko huone (myöskin mä)
 on siin kans
 
 */

@end
