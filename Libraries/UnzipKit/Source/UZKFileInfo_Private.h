//
//  UZKFileInfo_Private.h
//  UnzipKit
//
//

@import Foundation;

#import "unzip.h"

@interface UZKFileInfo (Private)

/**
 *  Returns a UZKFileInfo instance for the given extended header data
 *
 *  @param fileInfo The header data for a Zip file
 *  @param filename The archive that contains the file
 *
 *  @return an instance of UZKFileInfo
 */
+ (instancetype) fileInfo:(unz_file_info64 *)fileInfo filename:(NSString *)filename;

@end