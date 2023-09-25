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

#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatCore.h>
#import <BeatPagination2/BeatPagination2.h>
#import "BeatHTMLRenderer.h"
#import "Beat-Swift.h"

@interface BeatPreview ()
@property (nonatomic) BeatHTMLRenderer *renderer;
@property (nonatomic) ContinuousFountainParser *parser;
@property (nonatomic, weak) BeatPreviewView* previewView;
@end

@implementation BeatPreview

- (id)initWithDelegate:(id<BeatPreviewDelegate>)delegate
{
	self = [super init];
	if (self) {
		_delegate = delegate;
		_previewView = delegate.previewView;
	}
	return self;
}

- (void)setup {
	[_previewView.webview.configuration.userContentController addScriptMessageHandler:_delegate.document name:@"selectSceneFromScript"];
	[_previewView.webview.configuration.userContentController addScriptMessageHandler:_delegate.document name:@"closePrintPreview"];
	
	[_previewView.webview loadHTMLString:@"<html><body style='background-color: #333; margin: 0;'><section style='margin: 0; padding: 0; width: 100%; height: 100vh; display: flex; justify-content: center; align-items: center; font-weight: 200; font-family: \"Helvetica Light\", Helvetica; font-size: .8em; color: #eee;'>Creating Print Preview...</section></body></html>" baseURL:nil];
	
	_previewView.webview.pageZoom = 1.2;
}

- (void)deallocPreview {
	[self.previewView.webview.configuration.userContentController removeScriptMessageHandlerForName:@"selectSceneFromScript"];
	[self.previewView.webview.configuration.userContentController removeScriptMessageHandlerForName:@"closePrintPreview"];
	self.previewView.webview.navigationDelegate = nil;
	self.previewView.webview = nil;
}


/// Create a preview with pre-paginated content from the paginator in document (this should be the way from now on, until we get the new renderer)
- (NSString*)createPreviewFromPagination:(BeatPagination*)pagination {

#if TARGET_OS_IOS
	id doc = _delegate.documentForDelegation;
#else
	id doc = _delegate.document;
#endif
	
	BeatExportSettings *settings;
	
	if (self.delegate) {
		settings = self.delegate.exportSettings;
	} else {
		settings = [BeatExportSettings operation:ForPreview document:doc header:@"" printSceneNumbers:_delegate.showSceneNumberLabels printNotes:NO revisions:BeatRevisions.revisionColors scene:_delegate.currentScene.sceneNumber coloredPages:NO revisedPageColor:@""];
		settings.paperSize = _delegate.pageSize;
	}

	// This following weird code salad is here to circumvent strange corpse exceptions
	BeatHTMLRenderer *renderer = [BeatHTMLRenderer.alloc initWithPagination:pagination settings:settings];
	settings.operation = ForPreview;
	
	NSString * html = renderer.html;
	_renderer = renderer;
	
	return html;
}

- (NSString*)createPreviewFor:(NSString*)rawScript type:(BeatPreviewType)previewType {
	BeatExportSettings* settings;
	
	if (_delegate) {
		// This is probably a normal parser, because a delegate is present
		settings = self.delegate.exportSettings;
		
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
		// ..... we need to get the revisions etc. here
		NSLog(@"IMPORT REVISIONS BEFORE PREVIEW");
		settings =  [BeatExportSettings operation:ForPreview document:nil header:@"" printSceneNumbers:true];
		self.parser = [ContinuousFountainParser.alloc initWithString:rawScript];
	}
	
	// Create a script dict required by the HTML module
	BeatScreenplay *script = [BeatScreenplay from:self.parser settings:settings];
	
	if (previewType == BeatQuickLookPreview) { // Quick look preview
		_renderer = [BeatHTMLRenderer.alloc initWithLines:script.lines settings:settings];
		return _renderer.html;
	} else { // Normal preview
		// This following weird code salad is here to circumvent strange corpse exceptions
		BeatHTMLRenderer *renderer = [BeatHTMLRenderer.alloc initWithPagination:self.delegate.pagination.finishedPagination settings:settings];
		self.renderer = renderer;
		
		return renderer.html;
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
		
		[self.previewView.webview loadHTMLString:self.htmlString baseURL:NSBundle.mainBundle.resourceURL]; // Load HTML
		
		// Revert changes to the code (so we can replace the placeholder again,
		// if needed, without recreating the whole HTML)
		self.htmlString = [self.htmlString stringByReplacingOccurrencesOfString:scrollTo withString:@"<script name='scrolling'></script>"];
		
		// Evaluate JS in window to be sure it shows the correct scene
		[self.previewView.webview evaluateJavaScript:[NSString stringWithFormat:@"scrollToIdentifier(%@);", currentLine.uuid.UUIDString.lowercaseString] completionHandler:nil];
	});
}

- (void)updatePreviewSynchronized {
	self.previewUpdated = false;
	
	self.htmlString = [self createPreviewFromPagination:self.delegate.pagination.finishedPagination];
	self.previewUpdated = true;
	[self.delegate previewDidFinish];
}

- (void)updatePreviewAsync {
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0 ), ^(void) {
		self.htmlString = [self createPreviewFromPagination:self.delegate.pagination.finishedPagination];
		self.previewUpdated = true;
		[self.delegate previewDidFinish];
	});
}

/*
 
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
 
 */

/*
 
 Sä näytät tosi hienolta, Zaia
 kun poltat savukkeen ja katot valokuvia
 sä olet itse niissä
 ja koko huone (myöskin mä)
 on siin kans
 
 */

@end
