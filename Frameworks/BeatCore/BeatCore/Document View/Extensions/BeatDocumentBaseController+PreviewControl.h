//
//  BeatDocumentBaseController+PreviewControl.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 3.12.2025.
//

#import <BeatCore/BeatCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatDocumentBaseController (PreviewControl)

- (void)createPreviewAt:(NSRange)range;
- (void)createPreviewAt:(NSRange)range sync:(BOOL)sync;
- (void)invalidatePreview;
- (void)invalidatePreviewAt:(NSInteger)index;
- (void)resetPreview;

@end

NS_ASSUME_NONNULL_END
