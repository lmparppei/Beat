//
//  BeatDocumentBaseController+Outline.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 3.12.2025.
//

#import <BeatCore/BeatCore.h>
#import <BeatParsing/BeatParsing.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatDocumentBaseController (Outline) <ContinuousFountainParserOutlineDelegate>

- (void)outlineDidUpdateWithChanges:(OutlineChanges*)changes;

@end

NS_ASSUME_NONNULL_END
