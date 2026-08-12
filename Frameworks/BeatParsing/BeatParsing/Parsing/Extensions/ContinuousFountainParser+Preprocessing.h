//
//  ContinuousFountainParser+Preprocessing.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 4.1.2024.
//

#import <BeatParsing/BeatParsing.h>

@class BeatExportSettings;
@class BeatScreenplay;

@interface ContinuousFountainParser (Preprocessing)
- (NSArray<Line*>*)preprocessForPrinting;
- (NSArray<Line*>*)preprocessForPrintingWithExportSettings:(BeatExportSettings*)exportSettings;
- (NSArray<Line*>*)preprocessForPrintingWithLines:(NSArray*)lines exportSettings:(BeatExportSettings*)settings screenplayData:(BeatScreenplay**)screenplay;
+ (NSArray<Line*>*)preprocessForPrintingWithLines:(NSArray*)lines documentSettings:(BeatDocumentSettings*)documentSettings;
+ (NSArray<Line*>*)preprocessForPrintingWithLines:(NSArray*)lines documentSettings:(BeatDocumentSettings*)documentSettings exportSettings:(BeatExportSettings*)exportSettings screenplay:(BeatScreenplay**)screenplay;
@end
