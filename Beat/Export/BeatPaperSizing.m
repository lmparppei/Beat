//
//  BeatPaperSizing.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.11.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import "BeatPaperSizing.h"
#import <Cocoa/Cocoa.h>

// Print margin definitions
#define MARGIN_TOP 30
#define MARGIN_LEFT 50
#define MARGIN_RIGHT 50
#define MARGIN_BOTTOM 40

#define PAPER_A4 595, 842
#define PAPER_USLETTER 612, 792

@implementation BeatPaperSizing

+ (NSPrintInfo*)printInfoFor:(BeatPaperSize)size {
	NSPrintInfo *printInfo = [NSPrintInfo sharedPrintInfo];
	return [BeatPaperSizing setSize:size printInfo:printInfo];
}

+ (NSPrintInfo*)setMargins:(NSPrintInfo*)printInfo {
	[printInfo setTopMargin:MARGIN_TOP];
	[printInfo setBottomMargin:MARGIN_BOTTOM];
	[printInfo setLeftMargin:MARGIN_LEFT];
	[printInfo setRightMargin:MARGIN_RIGHT];
	return printInfo;
}
+ (NSPrintInfo*)setPaperSize:(NSPrintInfo*)printInfo size:(BeatPaperSize)size {
	if (size == BeatA4) printInfo.paperSize = CGSizeMake(PAPER_A4);
	else printInfo.paperSize = CGSizeMake(PAPER_USLETTER);
	return printInfo;
}

+ (NSPrintInfo*)setSize:(BeatPaperSize)size printInfo:(NSPrintInfo*)printInfo {
	printInfo = [BeatPaperSizing setPaperSize:printInfo size:size];
	printInfo = [BeatPaperSizing setMargins:printInfo];
	return printInfo;
}

@end
