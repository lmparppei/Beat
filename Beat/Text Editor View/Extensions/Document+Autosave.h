//
//  Document+Autosave.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 10.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "Document.h"

NS_ASSUME_NONNULL_BEGIN

@interface Document (Autosave)

- (void)setupAutosave;

/// Returns `true` if user has toggled Beat autosave on
- (BOOL)autosave;

/// Custom autosave in place
- (void)autosaveInPlace;

- (NSURL *)mostRecentlySavedFileURL;
- (NSURL*)autosavedContentsFileURL;

@end

NS_ASSUME_NONNULL_END
