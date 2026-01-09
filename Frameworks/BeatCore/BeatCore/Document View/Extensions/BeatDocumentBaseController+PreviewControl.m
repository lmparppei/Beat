//
//  BeatDocumentBaseController+PreviewControl.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 3.12.2025.
//

#import "BeatDocumentBaseController+PreviewControl.h"

@implementation BeatDocumentBaseController (PreviewControl)


#pragma mark - Preview creation
/// - note: The base class has no knowledge of OS-specific implementation of the preview controller. This only conforms to `BeatPreviewControllerInstance` protocol.

- (void)createPreviewAt:(NSRange)range
{
    [self.previewController createPreviewWithChangedRange:range sync:false];
}

- (void)createPreviewAt:(NSRange)range sync:(BOOL)sync
{
    [self.previewController createPreviewWithChangedRange:range sync:sync];
}

- (void)invalidatePreview
{
    [self.previewController resetPreview];
}

- (void)invalidatePreviewAt:(NSInteger)index
{
    [self.previewController invalidatePreviewAt:NSMakeRange(index, 0)];
}

- (void)resetPreview
{
    [self.previewController resetPreview];
}


@end
