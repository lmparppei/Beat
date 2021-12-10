//
//  BeatExportSettings.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.6.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatExportSettings.h"

@implementation BeatExportSettings

+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation document:(NSDocument*)doc header:(NSString*)header  printSceneNumbers:(bool)printSceneNumbers {
	return [[BeatExportSettings alloc] initWithOperation:operation document:doc header:header printSceneNumbers:printSceneNumbers revisionColor:@"" coloredPages:NO scene:@"" compareWith:nil];
}

+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation document:(NSDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers revisionColor:(NSString*)revisionColor coloredPages:(bool)coloredPages  {
	return [[BeatExportSettings alloc] initWithOperation:operation document:doc header:header printSceneNumbers:printSceneNumbers revisionColor:revisionColor coloredPages:coloredPages scene:@"" compareWith:nil];
}

+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation document:(NSDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers revisionColor:(NSString*)revisionColor coloredPages:(bool)coloredPages scene:(NSString*)scene {
	return [[BeatExportSettings alloc] initWithOperation:operation document:doc header:header printSceneNumbers:printSceneNumbers revisionColor:revisionColor coloredPages:coloredPages scene:scene compareWith:nil];
}

+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation document:(NSDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers revisionColor:(NSString*)revisionColor coloredPages:(bool)coloredPages compareWith:(NSString*)oldScript {
	return [[BeatExportSettings alloc] initWithOperation:operation document:doc header:header printSceneNumbers:printSceneNumbers revisionColor:revisionColor coloredPages:coloredPages scene:nil compareWith:oldScript];
}

-(instancetype)initWithOperation:(BeatHTMLOperation)operation document:(NSDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers revisionColor:(NSString*)revisionColor coloredPages:(bool)coloredPages scene:(NSString* _Nullable )scene compareWith:(NSString* _Nullable)oldScript {
	self = [super init];
	
	if (self) {
		_document = doc;
		_operation = operation;
		_header = (header.length) ? header : @"";
		_printSceneNumbers = printSceneNumbers;
		_revisionColor = (revisionColor) ? revisionColor : @"";
		_coloredPages = coloredPages;
		_currentScene = scene;
		_oldScript = oldScript;
	}
	return self;
}

- (BeatPaperSize)paperSize {
	// Check paper size
	if (self.document.printInfo.paperSize.width > 595) return BeatUSLetter;
	else return BeatA4;
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
