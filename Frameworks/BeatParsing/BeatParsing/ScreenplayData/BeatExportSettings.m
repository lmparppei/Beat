//
//  BeatExportSettings.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.6.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatExportSettings.h"
#import "OutlineScene.h"
#import <BeatParsing/BeatParsing.h>

@implementation BeatExportSettings

+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation document:(BeatHostDocument* _Nullable)doc header:(NSString*)header  printSceneNumbers:(bool)printSceneNumbers {
	return [[BeatExportSettings alloc] initWithOperation:operation document:doc header:header printSceneNumbers:printSceneNumbers printNotes:NO revisions:@[] scene:@"" coloredPages:NO revisedPageColor:@""];
}

+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation document:(BeatHostDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers revisions:(NSArray*)revisions {
	return [[BeatExportSettings alloc] initWithOperation:operation document:doc header:header printSceneNumbers:printSceneNumbers printNotes:NO revisions:revisions scene:@"" coloredPages:NO revisedPageColor:@""];
}

+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation document:(BeatHostDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers revisions:(NSArray*)revisions scene:(NSString* _Nullable )scene {
	return [[BeatExportSettings alloc] initWithOperation:operation document:doc header:header printSceneNumbers:printSceneNumbers printNotes:NO revisions:revisions scene:scene coloredPages:NO revisedPageColor:@""];
}

+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation document:(BeatHostDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers printNotes:(bool)printNotes revisions:(NSArray*)revisions scene:(NSString* _Nullable )scene coloredPages:(bool)coloredPages revisedPageColor:(NSString*)revisedPagecolor {
	return [[BeatExportSettings alloc] initWithOperation:operation document:doc header:header printSceneNumbers:printSceneNumbers printNotes:printNotes revisions:revisions scene:nil coloredPages:coloredPages revisedPageColor:revisedPagecolor];
}

-(instancetype)initWithOperation:(BeatHTMLOperation)operation document:(BeatHostDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers printNotes:(bool)printNotes revisions:(NSArray*)revisions scene:(NSString* _Nullable )scene coloredPages:(bool)coloredPages revisedPageColor:(NSString*)revisedPageColor {
	self = [super init];
	
	if (self) {
		_document = doc;
		_operation = operation;
		_header = (header.length) ? header.copy : @"";
		_printSceneNumbers = printSceneNumbers;
		_revisions = revisions.copy;
		_printNotes = printNotes;
		_coloredPages = coloredPages;
		_pageRevisionColor = revisedPageColor.copy;
		_paperSize = NSNotFound;
	}
	return self;
}

+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation delegate:(id<BeatExportSettingDelegate>)delegate {
    return [BeatExportSettings.alloc initWithOperation:operation delegate:delegate];
}
- (BeatExportSettings*)initWithOperation:(BeatHTMLOperation)operation delegate:(id<BeatExportSettingDelegate>)delegate {
    self = super.init;
    
    if (self) {
        _delegate = delegate;
        
        _operation = operation;
        _document = delegate.document;
        
        _styles = delegate.styles;
        
        _documentSettings = delegate.documentSettings;
        
        _header = @"";
        _printSceneNumbers = delegate.printSceneNumbers || delegate.showSceneNumberLabels;
        _revisions = delegate.shownRevisions;
        
        _coloredPages = false;
        _pageRevisionColor = @"";
        
        _paperSize = delegate.pageSize;
                
        _fileName = delegate.fileNameString;
        
        // Yeah, this is a silly approach. TODO: Make invisible element printing more sensible. We should have a unified way to handle these, regardless of doc/style settings
        id<BeatExportStyleProvider> styles = self.styles;
        NSMutableIndexSet* additionalTypes = NSMutableIndexSet.new;
        
        if ([delegate.documentSettings getBool:DocSettingPrintNotes]) _printNotes = true;
        if ([delegate.documentSettings getBool:DocSettingPrintSections] || styles.shouldPrintSections) [additionalTypes addIndex:section];
        if ([delegate.documentSettings getBool:DocSettingPrintSynopsis] || styles.shouldPrintSynopses) [additionalTypes addIndex:synopse];
        
        _additionalTypes = additionalTypes;
    }
    
    return self;
}

- (BeatPaperSize)paperSize {
	// Check paper size
#if TARGET_OS_IOS
	if (_paperSize == NSNotFound) {
        if (_delegate) return _delegate.pageSize;
		else return BeatA4;
	}
	return _paperSize;
#else
	if (_paperSize == NSNotFound) {
		if (self.document.printInfo.paperSize.width > 596) return BeatUSLetter;
		else return BeatA4;
	} else {
		return _paperSize;
	}
#endif
}

@end
/*

 Olen verkon silmässä kala. En pääse pois:
 ovat viiltävät säikeet jo syvällä lihassa mulla.
 Vesi häilyvä, selvä ja syvä minun silmäini edessä ois.
 Vesiaavikot vapaat, en voi minä luoksenne tulla!
 
 Meren silmiin vihreisiin vain loitolta katsonut oon.
 Mikä autuus ois lohen kilpaveikkona olla!
 Kuka rannan liejussa uupuu, hän pian uupukoon!
 – Vaan verkot on vitkaan-tappavat kohtalolla.
 
 */
