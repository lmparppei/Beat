//
//  Document+Printing.m
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 23.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "Document+Printing.h"
#import "BeatPrintDialog.h"

@implementation Document (Printing)

- (IBAction)openPrintPanel:(id)sender {
	self.attrTextCache = [self getAttributedText];
	self.printDialog = [BeatPrintDialog showForPrinting:self];
}

- (IBAction)openPDFPanel:(id)sender {
	self.attrTextCache = [self getAttributedText];
	self.printDialog = [BeatPrintDialog showForPDF:self];
}

- (void)releasePrintDialog { self.printDialog = nil; }

- (void)printDialogDidFinishPreview:(void (^)(void))block {
	block();
}

@end
