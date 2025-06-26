//
//  Document+Scrolling.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 21.6.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "Document.h"

NS_ASSUME_NONNULL_BEGIN

@interface Document (Scrolling)

/// Scroll to given scene number (number is `NSString`)
- (void)scrollToSceneNumber:(NSString* __nullable)sceneNumber;
/// Scroll to given scene object.
- (void)scrollToScene:(OutlineScene* __nullable)scene;
/// Legacy method. Use selectAndScrollToRange
- (void)scrollToRange:(NSRange)range;
/// Scrolls to given range and runs a callback after animation is done.
- (void)scrollToRange:(NSRange)range callback:(nullable void (^)(void))callbackBlock;
/// Scrolls the given position into view
- (void)scrollTo:(NSInteger)location;
/// Selects the given line and scrolls it into view
- (void)scrollToLine:(Line* __nullable)line;
/// Selects the line at given index and scrolls it into view
- (void)scrollToLineIndex:(NSInteger)index;
/// Selects the scene at given index and scrolls it into view
- (void)scrollToSceneIndex:(NSInteger)index;
/// Selects the given range and scrolls it into view
- (void)selectAndScrollTo:(NSRange)range;

@end

NS_ASSUME_NONNULL_END
