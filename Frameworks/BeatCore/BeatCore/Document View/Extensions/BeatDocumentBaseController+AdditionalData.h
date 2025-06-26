//
//  BeatDocumentBaseController+AdditionalData.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 26.6.2025.
//

#import <BeatCore/BeatCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatDocumentBaseController (AdditionalData)

- (void)setAdditionalData:(id _Nonnull)data key:(NSString* _Nonnull)key;
- (id _Nullable)getAdditionalDataWithKey:(NSString* _Nonnull)key;

@end

NS_ASSUME_NONNULL_END
