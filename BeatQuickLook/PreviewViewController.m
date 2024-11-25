//
//  PreviewViewController.m
//  BeatQuickLook
//
//  Created by Lauri-Matti Parppei on 27.5.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

#import "PreviewViewController.h"
#import <BeatCore/BeatCore.h>
#import <BeatParsing/BeatParsing.h>
#import <Quartz/Quartz.h>
#import <BeatPagination2/BeatPagination2.h>

@interface PreviewViewController () <QLPreviewingController>
@property (nonatomic) IBOutlet NSTextView* textView;
@property (nonatomic) BeatDocumentSettings* settings;
@end

@implementation PreviewViewController

- (NSString *)nibName {
    return @"PreviewViewController";
}

- (void)loadView {
    [super loadView];
	
	self.textView.textContainer.widthTracksTextView = false;
	self.textView.linkTextAttributes = @{
		NSForegroundColorAttributeName: BXColor.textColor,
		NSUnderlineStyleAttributeName: @0
	};
}

- (void)preparePreviewOfFileAtURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable))handler
{
	self.document = [BeatDocument.alloc initWithURL:url];
	
	// Calculate correct page size
	CGSize size = self.textView.textContainer.size;
	size.width = [BeatPaperSizing sizeFor:self.pageSize].width;
	self.textView.textContainer.size = size;
	
	// Create export settings
	BeatExportSettings* settings = self.exportSettings;
	
	// Renderer
	BeatRenderer* renderer = [BeatRenderer.alloc initWithSettings:settings];
	
	// Construct the attributed string
	NSMutableAttributedString* attrStr = NSMutableAttributedString.new;
	for (Line* line in [self.document.parser preprocessForPrintingWithExportSettings:settings]) {
		if (line.type == empty) continue;
		NSAttributedString* str = [renderer renderLine:line];
		[attrStr appendAttributedString:str];
	}
	
	// To make things more native-looking, let's replace foreground color for the whole text and remove links
	[attrStr addAttribute:NSForegroundColorAttributeName value:NSColor.textColor range:NSMakeRange(0, attrStr.length)];
	[attrStr removeAttribute:NSLinkAttributeName range:NSMakeRange(0, attrStr.length)];
	
	// Set string
	[self.textView.textStorage setAttributedString:attrStr];
	
    handler(nil);
}

#pragma mark - Delegate methods

-(BeatPaperSize)pageSize
{
	return (BeatPaperSize)[self.document.settings getInt:DocSettingPageSize];
}

-(BeatExportSettings*)exportSettings
{
	BeatExportSettings* settings = BeatExportSettings.new;
	settings.printSceneNumbers = true;
	
	NSMutableIndexSet* additionalTypes = NSMutableIndexSet.new;
	if ([self.document.settings getBool:DocSettingPrintSections]) [additionalTypes addIndex:section];
	if ([self.document.settings getBool:DocSettingPrintSynopsis]) [additionalTypes addIndex:synopse];
	
	if ([self.document.settings getString:DocSettingStylesheet].length > 0) {
		BeatStylesheet* styles = [BeatStyles.shared stylesWithName:[self.document.settings getString:DocSettingStylesheet] delegate:nil forEditor:false];

		if (styles.shouldPrintSections) [additionalTypes addIndex:section];
		if (styles.shouldPrintSynopses) [additionalTypes addIndex:synopse];
		
		settings.styles = styles;
	}
	
	
	settings.additionalTypes = additionalTypes;
	
	return settings;
}

@end

