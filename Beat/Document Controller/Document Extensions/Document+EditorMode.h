//
//  Document+EditorMode.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 30.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "Document.h"

NS_ASSUME_NONNULL_BEGIN

@interface Document (EditorMode)

- (void)toggleMode:(BeatEditorMode)mode;
- (void)setMode:(BeatEditorMode)mode;
/// Updates the window by editor mode. When adding new modes, remember to call this method and add new conditionals.
- (void)updateEditorMode;

@end

NS_ASSUME_NONNULL_END
