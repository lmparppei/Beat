//
//  Document+RevisionActions.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 7.9.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document.h"

NS_ASSUME_NONNULL_BEGIN

@interface Document (RevisionActions)

- (IBAction)toggleVisibleRevision:(NSMenuItem*)sender;

@end

NS_ASSUME_NONNULL_END
