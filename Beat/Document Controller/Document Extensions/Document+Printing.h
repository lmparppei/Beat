//
//  Document+Printing.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 23.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "Document.h"

NS_ASSUME_NONNULL_BEGIN

@interface Document (Printing)

- (void)releasePrintDialog;

@end

NS_ASSUME_NONNULL_END
