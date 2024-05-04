//
//  Document+Menus.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 23.4.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document.h"

NS_ASSUME_NONNULL_BEGIN

@interface Document (Menus)
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
@end

NS_ASSUME_NONNULL_END
