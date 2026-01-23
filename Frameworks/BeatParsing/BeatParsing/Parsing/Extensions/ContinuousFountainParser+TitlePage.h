//
//  ContinuousFountainParser+TitlePage.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 19.1.2026.
//

#import <BeatParsing/BeatParsing.h>
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ContinuousFountainParserTitlePageExports <JSExport>

- (NSString*)titlePageAsString;
- (NSArray<Line*>*)titlePageLines;
- (NSArray<NSDictionary<NSString*,NSArray<Line*>*>*>*)parseTitlePage;

@end

@interface ContinuousFountainParser (TitlePage) <ContinuousFountainParserTitlePageExports>

/// Parses a single line of titlle page at given index and returns the type.
- (LineType)parseTitlePageLineTypeFor:(Line*)line previousLine:(Line*)previousLine lineIndex:(NSInteger)index;

/// Returns the title page lines as string
- (NSString*)titlePageAsString;

/// Returns just the title page lines
- (NSArray<Line*>*)titlePageLines;

/// Re-parses the title page and returns a weird array structure: `[ { "key": "value }, { "key": "value }, { "key": "value } ]`.
/// This is because we want to maintain the order of the keys, and though ObjC dictionaries sometimes stay in the correct order, things don't work like that in Swift.
/// TODO: This should be replaced by some kind struct-like objects instead of dictionary array silliness.
- (NSArray<NSDictionary<NSString*,NSArray<Line*>*>*>*)parseTitlePage;

/// Returns the lines for given title page key. For example,`Title` would return something like `["My Film"]`.
- (NSMutableArray<Line*>* _Nullable)titlePageArrayForKey:(NSString* _Nullable)key;


@end

NS_ASSUME_NONNULL_END
