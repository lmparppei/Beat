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
 
 Note that we use a "clever" JavaScript hack to jump into the correct scene.
 BeatHTMLScript writes a span element with scene number id into the content,
 and we evaluate a "scroll to" JavaScript code whenever the print view is
 opened. That happens in the document, if you were looking for it here,
 as I was.
 
 */

#import "BeatPreview.h"
#import "Line.h"
#import "ContinuousFountainParser.h"
#import "OutlineScene.h"
#import "BeatHTMLScript.h"
#import "BeatDocumentSettings.h"
#import "BeatRevisionTracking.h"
#import "BeatExportSettings.h"

@interface BeatPreview ()
@property (nonatomic, weak) NSDocument *document;
@end

@implementation BeatPreview

- (id)initWithDocument:(id)document {
	self = [super init];
	if (self) {
		_document = document;
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
		
		// Bake revision attributes
		NSAttributedString *attrStr = self.delegate.attrTextCache;
		[BeatRevisionTracking bakeRevisionsIntoLines:parser.lines text:attrStr parser:parser];
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
		BeatHTMLScript *html = [BeatHTMLScript.alloc initWithScript:script settings:[BeatExportSettings operation:ForPreview  document:_document header:@"" printSceneNumbers:_delegate.showSceneNumberLabels revisionColor:@"" coloredPages:NO scene:_delegate.currentScene.sceneNumber]];
		//BeatHTMLScript *html = [[BeatHTMLScript alloc] initForPreview:script document:_document scene:_delegate.currentScene.sceneNumber printSceneNumbers:_delegate.showSceneNumberLabels];
		
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
