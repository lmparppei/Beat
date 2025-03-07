//
//  ContinuousFountainParser+Omissions.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 15.7.2024.
//

#import <BeatParsing/BeatParsing.h>

NS_ASSUME_NONNULL_BEGIN

@interface ContinuousFountainParser (Omissions)
- (NSInteger)findSceneOmissionStartFor:(OutlineScene*)scene;
- (NSInteger)findOmissionStartFrom:(NSInteger)position;
@end

NS_ASSUME_NONNULL_END
