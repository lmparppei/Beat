//
//  BeatPreview.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//
/*
 
 This acts as a bridge between FNScript and Beat.
 One day we'll have a native system to convert a Beat script into HTML
 and this intermediate class is useless. Hopefully.
 
 ... that day has come long since. It's still a horribly convoluted system.
 
 */

#import "BeatPreview.h"
#import "Line.h"
#import "ContinousFountainParser.h"
#import "OutlineScene.h"
#import "BeatHTMLScript.h"
#import "BeatDocumentSettings.h"

// NOTE NOTE NOTE: These are hard-coded here and in BeatPrint
// This needs to be fixed
#define MARGIN_TOP 30
#define MARGIN_LEFT 50
#define MARGIN_RIGHT 50
#define MARGIN_BOTTOM 40

@interface BeatPreview ()
@property (nonatomic, weak) NSDocument *document;
@end

@implementation BeatPreview

// It's about time to make this a retained fucking class
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
		[_document.printInfo setTopMargin:MARGIN_TOP];
		[_document.printInfo setBottomMargin:MARGIN_BOTTOM];
		[_document.printInfo setLeftMargin:MARGIN_LEFT];
		[_document.printInfo setRightMargin:MARGIN_RIGHT];

		NSString *rawText = [self.delegate getText];
		return [self createPreviewFor:rawText type:BeatPrintPreview];
	}
	return @"";
}
- (NSString*) createPreviewFor:(NSString*)rawScript type:(BeatPreviewType)previewType {
	if (self.document) {
		[_document.printInfo setTopMargin:MARGIN_TOP];
		[_document.printInfo setBottomMargin:MARGIN_BOTTOM];
		[_document.printInfo setLeftMargin:MARGIN_LEFT];
		[_document.printInfo setRightMargin:MARGIN_RIGHT];
	}
	
	ContinousFountainParser *parser;

	if (_delegate) {
		// This is probably a normal parser
		parser = [[ContinousFountainParser alloc] initWithString:rawScript delegate:(id<ContinuousFountainParserDelegate>)_delegate];
	} else {
		// This is probably a QuickLook preview
		parser = [[ContinousFountainParser alloc] initWithString:rawScript];
	}
	
	// Create a script dict required by the HTML module
	NSMutableDictionary *script = [NSMutableDictionary dictionaryWithDictionary:@{
		@"script": [parser preprocessForPrinting],
		@"title page": parser.titlePage
	}];
	
	// Scene numbering should be built into the HTML module rather than elsewhere.
	if (previewType == BeatQuickLookPreview) {
		BeatHTMLScript *html = [[BeatHTMLScript alloc] initWithScript:script quickLook:YES];
		return html.html;
	} else {
		BeatHTMLScript *html = [[BeatHTMLScript alloc] initWithScript:script document:_document scene:[(id<BeatPreviewDelegate>)_delegate currentScene].sceneNumber];
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
