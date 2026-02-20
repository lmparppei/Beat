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

NSString *const BeatExportSettingOperation = @"operation";
NSString *const BeatExportSettingPrintSceneNumbers = @"printSceneNumbers";
NSString *const BeatExportSettingStyles = @"styles";
NSString *const BeatExportSettingHidePageNumbers = @"hidePageNumbers";
NSString *const BeatExportSettingDocumentSettings = @"documentSettings";
NSString *const BeatExportSettingInvisibleElements = @"invisibleElements";

+ (BeatExportSettings*)operation:(BeatExportOperation)operation document:(BeatHostDocument* _Nullable)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers {
	return [[BeatExportSettings alloc] initWithOperation:operation document:doc header:header printSceneNumbers:printSceneNumbers printNotes:NO revisions:nil scene:@"" hidePageNumbers:false];
}

+ (BeatExportSettings*)operation:(BeatExportOperation)operation document:(BeatHostDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers revisions:(NSIndexSet*)revisions {
	return [[BeatExportSettings alloc] initWithOperation:operation document:doc header:header printSceneNumbers:printSceneNumbers printNotes:NO revisions:revisions scene:@"" hidePageNumbers:false];
}

+ (BeatExportSettings*)operation:(BeatExportOperation)operation document:(BeatHostDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers revisions:(NSIndexSet*)revisions scene:(NSString* _Nullable )scene {
	return [[BeatExportSettings alloc] initWithOperation:operation document:doc header:header printSceneNumbers:printSceneNumbers printNotes:NO revisions:revisions scene:scene hidePageNumbers:false];
}

+ (BeatExportSettings*)operation:(BeatExportOperation)operation document:(BeatHostDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers printNotes:(bool)printNotes revisions:(NSIndexSet*)revisions scene:(NSString* _Nullable )scene
{
	return [[BeatExportSettings alloc] initWithOperation:operation document:doc header:header printSceneNumbers:printSceneNumbers printNotes:printNotes revisions:revisions scene:nil hidePageNumbers:false];
}

-(instancetype)initWithOperation:(BeatExportOperation)operation document:(BeatHostDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers printNotes:(bool)printNotes revisions:(NSIndexSet*)revisions scene:(NSString* _Nullable )scene hidePageNumbers:(bool)hidePageNumbers
{
	self = [super init];
	
	if (self) {
		_document = doc;
		_operation = operation;
		_header = (header.length) ? header.copy : @"";
		_printSceneNumbers = printSceneNumbers;
        
        _revisions = revisions.copy;
		_printNotes = printNotes;
		_paperSize = NSNotFound;
        
        _hidePageNumbers = hidePageNumbers;
        
        if (revisions == nil) revisions = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 1024)];
        
        _headerAlignment = 1;
        _firstPageNumber = 1;
	}
	return self;
}

+ (BeatExportSettings*)operation:(BeatExportOperation)operation delegate:(id<BeatExportSettingDelegate>)delegate {
    return [BeatExportSettings.alloc initWithOperation:operation delegate:delegate];
}

/// This doesn't make any sense. Just get the values from the document settings, right?
- (BeatExportSettings*)initWithOperation:(BeatExportOperation)operation delegate:(id<BeatExportSettingDelegate>)delegate
{
    self = super.init;
    
    if (self) {
        _delegate = delegate;
        
        _operation = operation;
        _document = delegate.document;
        _documentSettings = delegate.documentSettings;
        
        _styles = delegate.styles;
                
        NSString* header = [delegate.documentSettings getString:DocSettingHeader];
        _header = (header) ? header : @"";
        _headerAlignment = [delegate.documentSettings getInt:DocSettingHeaderAlignment];
        
        _printSceneNumbers = delegate.printSceneNumbers;
        _hidePageNumbers = delegate.hidePageNumbers;
        _revisions = delegate.shownRevisions;
                
        _paperSize = delegate.pageSize;
                
        _fileName = delegate.fileNameString;
        
        _firstPageNumber = [delegate.documentSettings getInt:DocSettingFirstPageNumber];
        
        _printSceneHeadingColors = [delegate.documentSettings getBool:DocSettingPrintHeadingColor];
        
        // Yeah, this is a silly approach. TODO: Make invisible element printing more sensible. We should have a unified way to handle these, regardless of doc/style settings. Probably a bytemask?
        [self applyInvisibleElementSettings];
        
        _revisionHighlightMode = [delegate.documentSettings getInt:DocSettingPrintedRevisionHighlighting];
    }
    
    return self;
}

- (BeatExportSettings*)initWithSettings:(NSDictionary*)settings
{
    NSLog(@"!!! Warning: Don't use this method, not done yet :-)");
    
    self = [super init];
    
    if (self) {
        _operation = (BeatExportOperation)((NSNumber*)settings[BeatExportSettingOperation]).unsignedIntValue;
        _styles = settings[BeatExportSettingStyles];
        _hidePageNumbers = ((NSNumber*)settings[BeatExportSettingHidePageNumbers]).boolValue;
        _printSceneNumbers = ((NSNumber*)settings[BeatExportSettingPrintSceneNumbers]).boolValue;
        
        _documentSettings = settings[BeatExportSettingDocumentSettings];
        _firstPageNumber = [self.documentSettings getInt:DocSettingFirstPageNumber];
                
        NSNumber* invisibleElements = settings[BeatExportSettingInvisibleElements];
        self.invisibleElements = invisibleElements.unsignedIntValue;
        
        [self applyInvisibleElementSettings];
    }
    
    return self;
}

- (void)applyInvisibleElementSettings
{
    id<BeatExportStyleProvider> styles = self.styles;
    NSMutableIndexSet* additionalTypes = NSMutableIndexSet.new;
    
    if (self.invisibleElements & BeatExportSettingIncludeNotes)
        _printNotes = true;
    if (self.invisibleElements & BeatExportSettingIncludeSections)
        [additionalTypes addIndex:section];
    if (self.invisibleElements & BeatExportSettingIncludeSynopsis)
        [additionalTypes addIndex:synopse];
    
    // We also support setting these through raw document settings
    if ([self.documentSettings getBool:DocSettingPrintNotes]) _printNotes = true;
    if ([self.documentSettings getBool:DocSettingPrintSections] || styles.shouldPrintSections) [additionalTypes addIndex:section];
    if ([self.documentSettings getBool:DocSettingPrintSynopsis] || styles.shouldPrintSynopses) [additionalTypes addIndex:synopse];
    
    _additionalTypes = additionalTypes;
}

- (BeatPaperSize)paperSize
{
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
