//
//  BeatPaperSizing.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.11.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPaperSizing.h"

#define PAPER_A4 595.0, 842.0
#define PAPER_USLETTER 612.0, 792.0

@implementation BeatMargins

/// Reads margins from `Page Sizing.plist`
+ (BeatMargins*)margins {
	static BeatMargins* margins;
	if (!margins) margins = BeatMargins.new;
	
	NSDictionary *contents = [NSDictionary dictionaryWithContentsOfURL:[[NSBundle bundleForClass:[self class]] URLForResource:@"Page Sizing" withExtension:@"plist"]];
	margins.top = [(NSNumber*)contents[@"Margin Top"] floatValue];
	margins.bottom = [(NSNumber*)contents[@"Margin Bottom"] floatValue];
	margins.left = [(NSNumber*)contents[@"Margin Left"] floatValue];
	margins.right = [(NSNumber*)contents[@"Margin Right"] floatValue];
	    
	return margins;
}

@end

@implementation BeatPaperSizing

#if TARGET_OS_IOS

/// Paper sizing for iOS, returns predefined rects
+ (CGSize)printableAreaFor:(BeatPaperSize)size {
	BeatMargins *margins = BeatMargins.margins;
	CGSize paperSize;
	
	if (size == BeatA4) paperSize = CGSizeMake(PAPER_A4);
	else paperSize = CGSizeMake(PAPER_USLETTER);
	
	paperSize.width -= margins.left + margins.right;
	paperSize.height -= margins.top + margins.right;
	
	return paperSize;
}

#else

// macOS paper sizing (bake margins etc. into NSPrintInfo)

+ (NSPrintInfo*)printInfoFor:(BeatPaperSize)size {
	NSPrintInfo *printInfo = NSPrintInfo.sharedPrintInfo;
	return [BeatPaperSizing setSize:size printInfo:printInfo];
}

+ (NSPrintInfo*)setMargins:(NSPrintInfo*)printInfo {
	BeatMargins *margins = BeatMargins.margins;
	
	CGSize offset = CGSizeMake(0, 0);
	CGFloat referenceMargin = 12.5;
	CGSize imageableOrigin = CGSizeMake(printInfo.imageablePageBounds.origin.x, printInfo.imageablePageBounds.origin.y);
	
	// The user's system has less visible space on paper than it should (???), so let's fix that in margins.
	if (imageableOrigin.width - referenceMargin > 0)
		offset.width = imageableOrigin.width - referenceMargin;
	if (imageableOrigin.height - margins.top > 0)
		offset.height = imageableOrigin.height - margins.top;
	
	printInfo.topMargin = margins.top - offset.height;
	printInfo.bottomMargin = margins.bottom - offset.height;
	printInfo.leftMargin = margins.left - offset.width;
	printInfo.rightMargin = margins.right;
	
	return printInfo;
}
+ (NSPrintInfo*)setPaperSize:(NSPrintInfo*)printInfo size:(BeatPaperSize)size {
	if (size == BeatA4) {
		[printInfo setPaperName:@"A4"];
		printInfo.paperSize = NSMakeSize(PAPER_A4);
	}
	else {
		[printInfo setPaperName:@"Letter"];
		printInfo.paperSize = NSMakeSize(PAPER_USLETTER);
	}
	
	return printInfo;
}

+ (NSPrintInfo*)setSize:(BeatPaperSize)size printInfo:(NSPrintInfo*)printInfo {
	printInfo = [BeatPaperSizing setPaperSize:printInfo size:size];
	printInfo = [BeatPaperSizing setMargins:printInfo];
	
	return printInfo;
}

+ (void)setPageSize:(BeatPaperSize)size printInfo:(NSPrintInfo*)printInfo {
	if (size == BeatA4) printInfo.paperSize = NSMakeSize(PAPER_A4);
	else printInfo.paperSize = NSMakeSize(PAPER_USLETTER);
	
	printInfo = [self setMargins:printInfo];
}

#endif

+ (CGSize)a4 {
	return CGSizeMake(PAPER_A4);
}
+ (CGSize)usLetter {
	return CGSizeMake(PAPER_USLETTER);
}
+ (CGSize)sizeFor:(BeatPaperSize)size {
	if (size == BeatA4) return BeatPaperSizing.a4;
	else return BeatPaperSizing.usLetter;
}

@end
/*
 
 mä puen villapaidan päälle
 me tehdään kierros järven jäälle
 ja nähdään läheltä saari
 jossa muutama talo on tyhjillään
 
 se ei oo mitenkään ihmeellistä
 se ei oo mitään tyypillistä
 josta joku vois tehdä kivan biisin
 ja kerätä miljoonan
 
 */
