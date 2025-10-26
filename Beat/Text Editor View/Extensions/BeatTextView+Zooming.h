//
//  BeatTextView+Zooming.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 10.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTextView.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatTextView (Zooming)

- (void)setupZoom;
- (void)resetZoom;

/// Adjust zoom by a delta value
- (void)adjustZoomLevelBy:(CGFloat)value;

/// Set zoom level for the editor view, automatically clamped
- (void)adjustZoomLevel:(CGFloat)level;

/// `zoom:true` zooms in, `zoom:false` zooms out
- (void)zoom:(bool)zoomIn;


@end

NS_ASSUME_NONNULL_END
