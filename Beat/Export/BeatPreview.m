//
//  BeatPreview.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//
/*
 
 This is a very convoluted system.
 All hope abandon ye who enter here.
 
 */

#import "BeatPreview.h"
#import "Line.h"
#import "ContinousFountainParser.h"
#import "OutlineScene.h"
#import "BeatHTMLScript.h"
#import "BeatDocumentSettings.h"
#import "BeatRevisionTracking.h"

@interface BeatPreview ()
@property (nonatomic, weak) NSDocument *document;
@end

@implementation BeatPreview

- (id) initWithDocument:(id)document {
	self = [super init];
	if (self) {
		_document = document;
		_delegate = document;
	}
	return self;
}
- (NSString*) createPreview {
	if (self.delegate) {
		NSString *rawText = [self.delegate getText];
		return [self createPreviewFor:rawText type:BeatPrintPreview];
	}
	return @"";
}
- (NSString*) createPreviewFor:(NSString*)rawScript type:(BeatPreviewType)previewType {
	ContinousFountainParser *parser;

	if (_delegate) {
		// This is probably a normal parser, because a delegate is present
		// Parse script
		parser = [[ContinousFountainParser alloc] initWithString:rawScript delegate:(id<ContinuousFountainParserDelegate>)_delegate];
		
		// Bake revision attributes
		NSAttributedString *attrStr = self.delegate.attrTextCache;
		[BeatRevisionTracking bakeRevisionsIntoLines:parser.lines text:attrStr parser:parser];
	} else {
		// This is probably a QuickLook preview
		parser = [[ContinousFountainParser alloc] initWithString:rawScript];
	}
	
	// Create a script dict required by the HTML module
	NSDictionary *script = [parser scriptForPrinting];

	if (previewType == BeatQuickLookPreview) {
		BeatHTMLScript *html = [[BeatHTMLScript alloc] initForQuickLook:script];
		return html.html;
	} else {
		BeatHTMLScript *html = [[BeatHTMLScript alloc] initForPreview:script document:_document scene:[(id<BeatPreviewDelegate>)_delegate currentScene].sceneNumber];
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
