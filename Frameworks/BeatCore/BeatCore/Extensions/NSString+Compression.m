//
//  NSString+Compression.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 20.2.2025.
//

#import "NSString+Compression.h"
#import <zlib.h>

@implementation NSString (Compression)

/// Helper to compress any data using Gzip
- (NSData*  _Nullable)gzipCompressData:(NSData *)data
{
    if (data == nil || data.length == 0) return nil;
    
    NSMutableData *compressedData = [NSMutableData dataWithLength:compressBound(data.length)];
    uLongf compressedSize = compressedData.length;
    
    if (compress((Bytef *)compressedData.mutableBytes, &compressedSize, (const Bytef *)data.bytes, data.length) == Z_OK) {
        [compressedData setLength:compressedSize];
        return compressedData;
    }
    
    return nil;
}

/// Helper to decompress any gzip data
- (NSData*  _Nullable)gzipDecompressData:(NSData *)data {
    if (!data || data.length == 0) return nil;
    
    NSMutableData *decompressedData = [NSMutableData dataWithLength:data.length * 4]; // Estimate decompressed size
    uLongf decompressedSize = decompressedData.length;
    
    if (uncompress((Bytef *)decompressedData.mutableBytes, &decompressedSize, (const Bytef *)data.bytes, data.length) == Z_OK) {
        [decompressedData setLength:decompressedSize];
        return decompressedData;
    }
    
    return nil;
}

/// Compresses a string using gzip and encodes it in Base64
- (NSString* _Nullable)gzipCompressedString {
    NSData *utf8Data = [self dataUsingEncoding:NSUTF8StringEncoding];
    NSData *compressedData = [self gzipCompressData:utf8Data];
    
    if (compressedData == nil || compressedData.length == 0) return nil;
    return [compressedData base64EncodedStringWithOptions:0];
}

/// Decodes a Base64 string and decompresses it from gzip
- (NSString*  _Nullable)gzipDecompressedString {
    NSData *compressedData = [[NSData alloc] initWithBase64EncodedString:self options:0];
    
    if (!compressedData) return nil;
    
    NSData *decompressedData = [self gzipDecompressData:compressedData];
    
    if (decompressedData == nil || compressedData.length == 0) return nil;
    return [[NSString alloc] initWithData:decompressedData encoding:NSUTF8StringEncoding];
}

@end
