//
//  NSString+Compression.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 20.2.2025.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Compression)

/// Compresses the string using Gzip and returns a Base64-encoded string.
- (NSString* _Nullable)gzipCompressedString;

/// Decompresses a Base64-encoded, Gzip-compressed string.
- (NSString* _Nullable)gzipDecompressedString;

@end

NS_ASSUME_NONNULL_END
