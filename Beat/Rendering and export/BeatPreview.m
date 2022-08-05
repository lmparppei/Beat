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

@implementation BeatPreview

- (id)initWithDocument:(id)document {
	self = [super init];
	if (self) {
		_delegate = document;
	}
	return self;
}
- (NSString*)createPreview {
	if (self.delegate) {
		NSString *rawText = self.delegate.text;
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
		NSAttributedString *attrStr = self.delegate.attrTextCache;
		[BeatRevisions bakeRevisionsIntoLines:parser.lines text:attrStr parser:parser];
	} else {
		// This is probably a QuickLook preview
		parser = [ContinuousFountainParser.alloc initWithString:rawScript];
	}
	
	// Create a script dict required by the HTML module
	BeatScreenplay *script = parser.forPrinting;
	
	if (previewType == BeatQuickLookPreview) {
		BeatHTMLScript *html = [BeatHTMLScript.alloc initForQuickLook:script];
		return html.html;
	} else {
#if TARGET_OS_IOS
		id doc = _delegate.documentForDelegation;
#else
		id doc = _delegate.document;
#endif
		
		BeatExportSettings *settings = [BeatExportSettings operation:ForPreview document:doc header:@"" printSceneNumbers:_delegate.showSceneNumberLabels printNotes:NO revisions:BeatRevisions.revisionColors scene:_delegate.currentScene.sceneNumber coloredPages:NO revisedPageColor:@""];
		settings.paperSize = _delegate.pageSize;
		BeatHTMLScript *html = [BeatHTMLScript.alloc initWithScript:script settings:settings];
		
		return html.html;
	}
}

/*
 
 Sä näytät tosi hienolta, Zaia
 kun poltat savukkeen ja katot valokuvia
 sä olet itse niissä
 ja koko huone (myöskin mä)
 on siin kans
 
 */

@end
