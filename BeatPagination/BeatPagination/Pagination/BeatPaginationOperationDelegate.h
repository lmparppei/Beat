//
//  BeatPaginationOperationDelegate.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatParsing/BeatParsing.h>

#if TARGET_OS_IOS
	#define BeatFont UIFont
	#define BeatDocument UIDocument
	#define BeatPrintInfo UIPrintInfo
#else
	#define BeatFont NSFont
	#define BeatDocument NSDocument
	#define BeatPrintInfo NSPrintInfo
#endif

@protocol BeatPaginationOperationDelegate
@property (nonatomic) BeatFont *font;
@property (atomic) BeatExportSettings *settings;

@property (weak, nonatomic) BeatDocument *document;
@property (atomic) BeatPrintInfo *printInfo;
@property (atomic) BeatPaperSize paperSize;
@property (atomic) bool printNotes;

+ (CGFloat)lineHeight;
+ (NSInteger)heightForString:(NSString *)string font:(BeatFont *)font maxWidth:(NSInteger)maxWidth lineHeight:(CGFloat)lineHeight;
- (Line*)moreLineFor:(Line*)line;
- (NSString*)moreString;
- (NSString*)contdString;
- (Line*)contdLineFor:(Line*)line;
- (CGFloat)spaceBeforeForLine:(Line*)line;

- (void)paginationFinished:(id)operation;
@end
