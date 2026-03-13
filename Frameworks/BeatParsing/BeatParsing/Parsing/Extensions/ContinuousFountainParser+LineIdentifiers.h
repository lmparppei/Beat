//
//  ContinuousFountainParser+LineIdentifiers.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 8.3.2026.
//

#import <BeatParsing/BeatParsing.h>

NS_ASSUME_NONNULL_BEGIN

@interface ContinuousFountainParser (LineIdentifiers)

/// Returns every line UUID as an arrayg
- (NSArray<NSUUID*>*)lineIdentifiers:(NSArray<Line*>* _Nullable)lines;

/// Sets the given UUIDs to each line at the same index. Note that you can provide either an array of `NSString`s or __REAL__ `NSUUID`s.
- (void)setIdentifiers:(NSArray* _Nullable)uuids;

/// Sets the given UUIDs to each outline element at the same index
- (void)setIdentifiersForOutlineElements:(NSArray<NSDictionary<NSString*, NSString*>*>* _Nullable)uuids;

/// Returns a fully built map with the UUID as key to identify actual line objects. Note that this BUILDS the full map every time. If you are looking for a specific line at runtime, use `lineWithUUID:`.
- (NSMapTable<NSUUID*, Line*>*)uuidsToLines;

@end

NS_ASSUME_NONNULL_END
