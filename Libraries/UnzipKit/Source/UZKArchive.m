//
//  UZKArchive.m
//  UnzipKit
//
//

#import "UZKArchive.h"

#import "zip.h"

#import "UZKFileInfo.h"
#import "UZKFileInfo_Private.h"
#import "UnzipKitMacros.h"
#import "NSURL+UnzipKitExtensions.h"


NSString *UZKErrorDomain = @"UZKErrorDomain";

#define FILE_IN_ZIP_MAX_NAME_LENGTH (512)


typedef NS_ENUM(NSUInteger, UZKFileMode) {
    UZKFileModeUnassigned = -1,
    UZKFileModeUnzip = 0,
    UZKFileModeCreate,
    UZKFileModeAppend
};

static NSBundle *_resources = nil;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundef"
#if UNIFIED_LOGGING_SUPPORTED
os_log_t unzipkit_log;
BOOL unzipkitIsAtLeast10_13SDK;
#endif
#pragma clang diagnostic pop


@interface UZKArchive ()

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithFile:(NSURL *)fileURL password:(NSString*)password error:(NSError * __autoreleasing*)error
#if (TARGET_OS_IPHONE && __IPHONE_OS_VERSION_MIN_REQUIRED > __IPHONE_7_0) || MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_9
NS_DESIGNATED_INITIALIZER
#endif
;

@property (strong) NSData *fileBookmark;
@property (strong) NSURL *fallbackURL;

@property (assign) NSInteger openCount;

@property (assign) UZKFileMode mode;
@property (assign) zipFile zipFile;
@property (assign) unzFile unzFile;
@property (strong) NSDictionary *archiveContents;

@property (strong) NSObject *threadLock;

@property (assign) BOOL commentRetrieved;

@end


@implementation UZKArchive

@synthesize comment = _comment;


#pragma mark - Deprecated Convenience Methods


+ (UZKArchive *)zipArchiveAtPath:(NSString *)filePath
{
    return [[UZKArchive alloc] initWithPath:filePath error:nil];
}

+ (UZKArchive *)zipArchiveAtURL:(NSURL *)fileURL
{
    return [[UZKArchive alloc] initWithURL:fileURL error:nil];
}

+ (UZKArchive *)zipArchiveAtPath:(NSString *)filePath password:(NSString *)password
{
    return [[UZKArchive alloc] initWithPath:filePath password:password error:nil];
}

+ (UZKArchive *)zipArchiveAtURL:(NSURL *)fileURL password:(NSString *)password
{
    return [[UZKArchive alloc] initWithURL:fileURL password:password error:nil];
}



#pragma mark - Initializers

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSURL *resourcesURL = [mainBundle URLForResource:@"UnzipKitResources" withExtension:@"bundle"];
        
        _resources = (resourcesURL
                      ? [NSBundle bundleWithURL:resourcesURL]
                      : mainBundle);
        
        UZKLogInit();
    });
}

- (instancetype)init {
    NSAssert(NO, @"Do not use -init. Use one of the -initWithPath or -initWithURL variants", nil);
    @throw nil;
}

- (instancetype)initWithPath:(NSString *)filePath error:(NSError * __autoreleasing*)error
{
    return [self initWithFile:[NSURL fileURLWithPath:filePath] error:error];
}

- (instancetype)initWithURL:(NSURL *)fileURL error:(NSError * __autoreleasing*)error
{
    return [self initWithFile:fileURL error:error];
}

- (instancetype)initWithPath:(NSString *)filePath password:(NSString *)password error:(NSError * __autoreleasing*)error
{
    return [self initWithFile:[NSURL fileURLWithPath:filePath]
                     password:password
                        error:error];
}

- (instancetype)initWithURL:(NSURL *)fileURL password:(NSString *)password error:(NSError * __autoreleasing*)error
{
    return [self initWithFile:fileURL password:password error:error];
}

- (instancetype)initWithFile:(NSURL *)fileURL error:(NSError * __autoreleasing*)error
{
    return [self initWithFile:fileURL password:nil error:error];
}

- (instancetype)initWithFile:(NSURL *)fileURL password:(NSString*)password error:(NSError * __autoreleasing*)error
{
    if ((self = [super init])) {
        UZKCreateActivity("Init Archive");
        
        if (!fileURL) {
            UZKLogError("Nil fileURL passed to UZKArchive initializer")
            return nil;
        }
        
        UZKLogInfo("Initializing archive with URL %{public}@, path %{public}@, password %{public}@", fileURL, fileURL.path, [password length] != 0 ? @"given" : @"not given");
        
        if ([fileURL checkResourceIsReachableAndReturnError:NULL]) {
            NSError *bookmarkError = nil;
            if (![self storeFileBookmark:fileURL error:&bookmarkError]) {
                UZKLogError("Error creating bookmark to ZIP archive: %{public}@", bookmarkError);
                
                if (error) {
                    *error = bookmarkError;
                }
                
                return nil;
            }
        } else {
            UZKLogInfo("URL %{public}@ doesn't yet exist", fileURL)
        }

        UZKLogDebug("Initializing private fields");

        _openCount = 0;
        _mode = UZKFileModeUnassigned;
        
        _fallbackURL = fileURL;
        _password = password;
        _threadLock = [[NSObject alloc] init];
        
        _commentRetrieved = NO;
    }
    
    return self;
}



#pragma mark - Properties


- (NSURL *)fileURL
{
    UZKCreateActivity("Read Archive URL");

    NSError *checkExistsError = nil;

    if (!self.fileBookmark
        || (self.fallbackURL && [self.fallbackURL checkResourceIsReachableAndReturnError:&checkExistsError]))
    {
		UZKLogDebug("checkResourceIsReachableAndReturnError returned false with error: %{public}@", checkExistsError);
        UZKLogInfo("Returning fallback URL for archive");
        return self.fallbackURL;
    }
    
    UZKLogInfo("Resolving archive bookmark (base64):\n%{public}@", [self.fileBookmark base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength]);
    
    BOOL bookmarkIsStale = NO;
    NSError *error = nil;
    
    NSURL *result = [NSURL URLByResolvingBookmarkData:self.fileBookmark
                                              options:(NSURLBookmarkResolutionOptions)0
                                        relativeToURL:nil
                                  bookmarkDataIsStale:&bookmarkIsStale
                                                error:&error];
    
    
    if (!result) {
        UZKLogFault("Error resolving bookmark to ZIP archive: %{public}@", error);
        return nil;
    }
    
    UZKLogDebug("Resolved bookmark. URL: %{public}@, isStale: %{public}@", result, bookmarkIsStale ? @"YES" : @"NO");

    if (bookmarkIsStale) {
        UZKLogDebug("Refreshing stale bookmark");
        self.fallbackURL = result;
        
        if (![self storeFileBookmark:result
                               error:&error]) {
            UZKLogFault("Error creating fresh bookmark to ZIP archive: %{public}@", error);
        }
    }
    
    return result;
}

- (NSString *)filename
{
    UZKCreateActivity("Read Archive Filename");
    
    NSURL *url = self.fileURL;
    
    if (!url) {
        return nil;
    }
    
    return url.path;
}

- (NSString *)comment
{
    UZKCreateActivity("Read Archive Comment");
    
    if (self.commentRetrieved) {
        UZKLogDebug("Returning cached comment");
        return _comment;
    }
    
    _comment = [self readGlobalComment];
    return _comment;
}

- (void)setComment:(NSString *)comment
{
    UZKCreateActivity("Write Archive Comment");
    
    _comment = comment;
    self.commentRetrieved = YES;

    UZKLogInfo("Opening archive in Append mode with comment set to write it");
    
    NSError *error = nil;
    BOOL success = [self performActionWithArchiveOpen:nil
                                               inMode:UZKFileModeAppend
                                                error:&error];

    if (!success) {
        UZKLogError("Failed to write comment to archive: %{public}@", error);
    }
}



#pragma mark - Zip file detection


+ (BOOL)pathIsAZip:(NSString *)filePath
{
    UZKCreateActivity("Determining File Type (Path)");
    
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    
    if (!handle) {
        UZKLogError("No file handle returned for path: %{public}@", filePath);
        return NO;
    }
    
    @try {
        NSData *fileData = [handle readDataOfLength:4];
        
        if (fileData.length < 4) {
            UZKLogDebug("File is not a ZIP. Less than 4 bytes of data");
            return NO;
        }
        
        const unsigned char *dataBytes = fileData.bytes;

        // First two bytes must equal 'PK'
        if (dataBytes[0] != 0x50 || dataBytes[1] != 0x4b) {
            UZKLogDebug("File is not a ZIP. First two bytes are not PK");
            return NO;
        }
        
        // Check for standard Zip
        if (dataBytes[2] == 0x03 &&
            dataBytes[3] == 0x04) {
            UZKLogDebug("File is a standard ZIP");
            return YES;
        }
        
        // Check for empty Zip
        if (dataBytes[2] == 0x05 &&
            dataBytes[3] == 0x06) {
            UZKLogDebug("File is an empty ZIP");
            return YES;
        }
        
        // Check for spanning Zip
        if (dataBytes[2] == 0x07 &&
            dataBytes[3] == 0x08) {
            UZKLogDebug("File is a spanning ZIP");
            return YES;
        }

        UZKLogDebug("File is not a ZIP. Unknown contents in 3rd and 4th bytes (%02X %02X)", dataBytes[2], dataBytes[3]);
    }
    @finally {
        [handle closeFile];
    }
    
    return NO;
}

+ (BOOL)urlIsAZip:(NSURL *)fileURL
{
    UZKCreateActivity("Determining File Type (URL)");
    
    if (!fileURL || !fileURL.path) {
        UZKLogDebug("File is not a ZIP: nil URL or path");
        return NO;
    }
    
    return [UZKArchive pathIsAZip:(NSString* _Nonnull)fileURL.path];
}



#pragma mark - Read Methods


- (NSArray<NSString*> *)listFilenames:(NSError * __autoreleasing*)error
{
    UZKCreateActivity("Listing Filenames");
    
    NSArray *zipInfos = [self listFileInfo:error];
    
    if (!zipInfos) {
        UZKLogDebug("No file info returned");
        return nil;
    }
    
    return (NSArray* _Nonnull)[zipInfos valueForKeyPath:@"filename"];
}

- (NSArray<UZKFileInfo*> *)listFileInfo:(NSError * __autoreleasing*)error
{
    UZKCreateActivity("Listing File Info");
    
    if (error) {
        *error = nil;
    }
    
    NSError *checkExistsError = nil;
    if (![self.fileURL checkResourceIsReachableAndReturnError:&checkExistsError]) {
        UZKLogError("File %{public}@ doesn't exist: %{public}@", self.fileURL, checkExistsError);
        return @[];
    }
    
    NSError *unzipError;
    
    __weak UZKArchive *welf = self;
    NSMutableArray *zipInfos = [NSMutableArray array];
    
    BOOL success = [self performActionWithArchiveOpen:^(NSError * __autoreleasing*innerError) {
        UZKCreateActivity("Finding File Info Items");
        
        UZKLogInfo("Getting global info...");
        unzGoToNextFile(welf.unzFile);
        
        unz_global_info gi;
        int err = unzGetGlobalInfo(welf.unzFile, &gi);
        if (err != UNZ_OK) {
            NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error getting global info (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                                err];
            UZKLogError("UZKErrorCodeArchiveNotFound: %{public}@", detail);
            [welf assignError:innerError code:UZKErrorCodeArchiveNotFound
                       detail:detail];
            return;
        }
        
        NSUInteger fileCount = gi.number_entry;
        UZKLogDebug("fileCount: %lu", (unsigned long)fileCount);

        UZKLogInfo("Going to first file...");
        err = unzGoToFirstFile(welf.unzFile);
        
        if (err != UNZ_OK) {
            NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error going to first file in archive (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                                err];
            UZKLogError("UZKErrorCodeFileNavigationError: %{public}@", detail);
            [welf assignError:innerError code:UZKErrorCodeFileNavigationError
                       detail:detail];
            return;
        }
        
        for (NSUInteger i = 0; i < fileCount; i++) {
            UZKLogDebug("Iterating through file info (iteration #%lu)", (unsigned long)i+1);
            UZKFileInfo *info = [welf currentFileInZipInfo:innerError];
            
            if (info) {
                UZKLogDebug("Info found: %{public}@", info.filename);
                [zipInfos addObject:info];
            } else {
                UZKLogDebug("Info not found");
                return;
            }
            
            UZKLogDebug("Going to next file...");
            err = unzGoToNextFile(welf.unzFile);
            if (err == UNZ_END_OF_LIST_OF_FILE) {
                UZKLogInfo("End of file found");
                return;
            }
            
            if (err != UNZ_OK) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error navigating to next file (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                                    err];
                UZKLogError("UZKErrorCodeFileNavigationError: %{public}@", detail);
                [welf assignError:innerError code:UZKErrorCodeFileNavigationError
                           detail:detail];
                return;
            }
        }
    } inMode:UZKFileModeUnzip error:&unzipError];
    
    if (!success) {
        if (error) {
            *error = unzipError;
        }
        
        return nil;
    }
    
    return [zipInfos copy];
}

- (BOOL)extractFilesTo:(NSString *)destinationDirectory
             overwrite:(BOOL)overwrite
                 error:(NSError * __autoreleasing*)error
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self extractFilesTo:destinationDirectory
                      overwrite:overwrite
                       progress:nil
                          error:error];
#pragma clang diagnostic pop
}

- (BOOL)extractFilesTo:(NSString *)destinationDirectory
             overwrite:(BOOL)overwrite
              progress:(void (^)(UZKFileInfo *currentFile, CGFloat percentArchiveDecompressed))progressBlock
                 error:(NSError * __autoreleasing*)error
{
    UZKCreateActivity("Extracting Files to Directory");
    
    NSError *listError = nil;
    NSArray *fileInfo = [self listFileInfo:&listError];
    
    if (!fileInfo || listError) {
        UZKLogError("Error listing contents of archive: %{public}@", listError);
        
        if (error) {
            *error = listError;
        }
        
        return NO;
    }
    
    NSFileManager *fm = [[NSFileManager alloc] init];

    NSNumber *totalSize = [fileInfo valueForKeyPath:@"@sum.uncompressedSize"];
    UZKLogDebug("totalSize: %lld", totalSize.longLongValue);
    __block long long bytesDecompressed = 0;
    __block NSInteger filesExtracted = 0;

    NSProgress *progress = [self beginProgressOperation:totalSize.longLongValue];
    progress.kind = NSProgressKindFile;

    __weak UZKArchive *welf = self;
    NSError *extractError = nil;
    
    BOOL success = [self performActionWithArchiveOpen:^(NSError * __autoreleasing*innerError) {
        UZKCreateActivity("Performing Extraction");
        
        NSError *strongError = nil;
        
        @try {
            for (UZKFileInfo *info in fileInfo) {
                UZKLogDebug("Extracting %{public}@ to disk", info.filename);

                if (progress.isCancelled) {
                    NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error locating file '%@' in archive", @"UnzipKit", _resources, @"Detailed error string"),
                                        info.filename];
                    UZKLogError("Halted file extraction due to user cancellation: %{public}@", detail);
                    [welf assignError:&strongError code:UZKErrorCodeUserCancelled
                               detail:detail];
                    return;
                }
                
                @autoreleasepool {
                    if (progressBlock) {
                        progressBlock(info, bytesDecompressed / totalSize.doubleValue);
                    }
                    
                    if (![self locateFileInZip:info.filename error:&strongError]) {
                        NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error locating file '%@' in archive", @"UnzipKit", _resources, @"Detailed error string"),
                                            info.filename];
                        UZKLogError("UZKErrorCodeFileNotFoundInArchive: %{public}@", detail);
                        [welf assignError:&strongError code:UZKErrorCodeFileNotFoundInArchive
                                   detail:detail];
                        return;
                    }
                    
                    NSString *extractPath = [destinationDirectory stringByAppendingPathComponent:info.filename];
                    UZKLogDebug("Extracting to %{public}@", extractPath);
                    if ([fm fileExistsAtPath:extractPath] && !overwrite) {
                        UZKLogDebug("File exists and overwrite==NO. Skipping file");
                        return;
                    }
                    
                    NSString *extractDir = (info.isDirectory
                                            ? extractPath
                                            : extractPath.stringByDeletingLastPathComponent);
                    if (![fm fileExistsAtPath:extractDir]) {
                        UZKLogDebug("Creating directories for path %{public}@", extractDir);
                        BOOL directoriesCreated = [fm createDirectoryAtPath:extractDir
                                                withIntermediateDirectories:YES
                                                                 attributes:nil
                                                                      error:error];
                        if (!directoriesCreated) {
                            NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Failed to create destination directory: %@", @"UnzipKit", _resources, @"Detailed error string"),
                                                extractDir];
                            UZKLogError("UZKErrorCodeOutputError: %{public}@", detail);
                            [welf assignError:&strongError code:UZKErrorCodeOutputError
                                       detail:detail];
                            return;
                        }
                    }
                    
                    if (info.isDirectory) {
                        UZKLogDebug("Created empty directory")
                        continue;
                    }
                    
                    NSURL *deflatedDirectoryURL = [NSURL fileURLWithPath:destinationDirectory];
                    NSURL *deflatedFileURL = [deflatedDirectoryURL URLByAppendingPathComponent:info.filename];
                    [progress setUserInfoObject:deflatedFileURL
                                         forKey:NSProgressFileURLKey];
                    [progress setUserInfoObject:info
                                         forKey:UZKProgressInfoKeyFileInfoExtracting];
                    NSString *path = deflatedFileURL.path;
                    
                    UZKLogDebug("Creating empty file at path %{public}@", path);
                    BOOL createSuccess = [fm createFileAtPath:path
                                                     contents:nil
                                                   attributes:nil];

                    if (!createSuccess) {
                        NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error creating current file (%d) '%@'", @"UnzipKit", _resources, @"Detailed error string"),
                                            strongError, info.filename];
                        UZKLogError("UZKErrorCodeOutputError: %{public}@", detail);
                        [welf assignError:&strongError code:UZKErrorCodeOutputError
                                   detail:detail];
                        return;
                    }
                                        
                    UZKLogDebug("Opening file handle for URL %{public}@", deflatedFileURL);
                    NSFileHandle *deflatedFileHandle = [NSFileHandle fileHandleForWritingToURL:deflatedFileURL
                                                                                         error:&strongError];

                    
                    if (!deflatedFileHandle) {
                        NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error writing to file: %@", @"UnzipKit", _resources, @"Detailed error string"),
                                            deflatedFileURL];
                        UZKLogError("UZKErrorCodeOutputError: %{public}@", detail);
                        [welf assignError:&strongError code:UZKErrorCodeOutputError
                                   detail:detail];
                        return;
                    }
                    
                    UZKLogDebug("Extracting buffered data");
                    BOOL extractSuccess = [welf extractBufferedDataFromFile:info.filename
                                                                  error:&strongError
                                                                 action:
                                    ^(NSData *dataChunk, CGFloat percentDecompressed) {
                                        UZKLogDebug("Writing data chunk of size %lu (%lld total so far)", (unsigned long)dataChunk.length, bytesDecompressed);
                                        bytesDecompressed += dataChunk.length;
                                        [deflatedFileHandle writeData:dataChunk];
                                        if (progressBlock) {
                                            progressBlock(info, (double)bytesDecompressed / totalSize.doubleValue);
                                        }
                                    }];

                    UZKLogDebug("Closing file handle");
                    [deflatedFileHandle closeFile];
                    
                    // Restore the timestamp and permission attributes of the file
                    NSDictionary* attribs = @{NSFileModificationDate: info.timestamp,
                                              NSFilePosixPermissions: @(info.posixPermissions)};
                    [[NSFileManager defaultManager] setAttributes:attribs ofItemAtPath:path error:nil];
                    
                    if (!extractSuccess) {
                        UZKLogError("Error extracting file (%ld): %{public}@", (long)strongError.code, strongError.localizedDescription);
                        
                        UZKLogInfo("Cleaning up target directory after failure: %{public}@", deflatedFileURL);
                        // Remove the directory we were going to unzip to if it fails.
                        [fm removeItemAtURL:deflatedDirectoryURL
                                      error:nil];
                        return;
                    }

                    [progress setUserInfoObject:@(++filesExtracted)
                                         forKey:NSProgressFileCompletedCountKey];
                    [progress setUserInfoObject:@(fileInfo.count)
                                         forKey:NSProgressFileTotalCountKey];
                    progress.completedUnitCount = bytesDecompressed;
                }
            }
        }
        @finally {
            if (strongError && innerError) {
                *innerError = strongError;
            }
        }
    } inMode:UZKFileModeUnzip error:&extractError];
    
    if (error) {
        *error = extractError ? extractError : nil;
    }

    return success;
}

- (nullable NSData *)extractData:(UZKFileInfo *)fileInfo
                           error:(NSError * __autoreleasing*)error
{
    return [self extractDataFromFile:fileInfo.filename
                               error:error];
}

- (nullable NSData *)extractData:(UZKFileInfo *)fileInfo
                        progress:(void (^)(CGFloat))progress
                           error:(NSError * __autoreleasing*)error
{
    return [self extractDataFromFile:fileInfo.filename
                            progress:progress
                               error:error];
}

- (nullable NSData *)extractDataFromFile:(NSString *)filePath
                                   error:(NSError * __autoreleasing *)error
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self extractDataFromFile:filePath
                            progress:nil
                               error:error];
#pragma clang diagnostic pop
}

- (nullable NSData *)extractDataFromFile:(NSString *)filePath
                                progress:(void (^)(CGFloat))progressBlock
                                   error:(NSError * __autoreleasing*)error
{
    UZKCreateActivity("Extracting Data from File");
    
    NSMutableData *result = [NSMutableData data];
    
    UZKLogInfo("Extracting buffered data from file %{public}@", filePath);
    
    NSError *extractError = nil;
    BOOL success = [self extractBufferedDataFromFile:filePath
                                               error:&extractError
                                              action:^(NSData *dataChunk, CGFloat percentDecompressed) {
                                                  UZKLogDebug("Appending data chunk of size %lu (%.3f%% complete)", (unsigned long)dataChunk.length, (double)percentDecompressed * 100);

                                                  if (progressBlock) {
                                                      progressBlock(percentDecompressed);
                                                  }
                                                  
                                                  [result appendData:dataChunk];
                                              }];
    
    if (progressBlock) {
        UZKLogDebug("Declaring extraction progress as completed");
        progressBlock(1.0);
    }
    
    if (success) {
        return [NSData dataWithData:result];
    }

    UZKLogError("Error extracting file (%ld): %{public}@", (long)extractError.code, extractError.localizedDescription);

    if (error) {
        *error = extractError;
    }
    
    return nil;
}

- (BOOL)performOnFilesInArchive:(void (^)(UZKFileInfo *, BOOL *))action
                          error:(NSError * __autoreleasing*)error
{
    UZKCreateActivity("Performing Action on Each File");
    
    UZKLogInfo("Listing file info");
    
    NSError *listError = nil;
    NSArray *fileInfo = [self listFileInfo:&listError];
    
    if (listError || !fileInfo) {
        UZKLogError("Failed to list the files in the archive: %{public}@", listError);
        
        if (error) {
            *error = listError;
        }
        
        return NO;
    }
    
    NSProgress *progress = [self beginProgressOperation:fileInfo.count];
    
    UZKLogInfo("Sorting file info by name/path");

    NSArray *sortedFileInfo = [fileInfo sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"filename" ascending:YES]]];
    
    BOOL success = [self performActionWithArchiveOpen:^(NSError * __autoreleasing*innerError) {
        UZKCreateActivity("Iterating Each File Info");
        
        BOOL stop = NO;

        for (UZKFileInfo *info in sortedFileInfo) {
            if (progress.isCancelled) {
                UZKLogInfo("File info iteration was cancelled");
                break;
            }
            UZKLogDebug("Performing action on %{public}@", info.filename);
            action(info, &stop);
            progress.completedUnitCount += 1;

            if (stop) {
                UZKLogInfo("Action dictated an early stop");
                progress.completedUnitCount = progress.totalUnitCount;
                break;
            }
        }
    } inMode:UZKFileModeUnzip error:error];
    
    if (progress.isCancelled) {
        NSString *detail = NSLocalizedStringFromTableInBundle(@"User cancelled operation", @"UnzipKit", _resources, @"Detailed error string");
        UZKLogError("UZKErrorCodeUserCancelled: %{public}@", detail);
        [self assignError:error code:UZKErrorCodeUserCancelled
                   detail:detail];
        return NO;
    }
    
    return success;
}

- (BOOL)performOnDataInArchive:(void (^)(UZKFileInfo *, NSData *, BOOL *))action
                         error:(NSError * __autoreleasing*)error
{
    UZKCreateActivity("Performing Action on Each File's Data");
    
    __weak UZKArchive *welf = self;

    return [self performOnFilesInArchive:^(UZKFileInfo *fileInfo, BOOL *stop) {
        UZKLogInfo("Locating file %{public}@", fileInfo.filename);
        
        if (![welf locateFileInZip:fileInfo.filename error:error]) {
            NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Failed to locate '%@' in archive during-perform on-data operation", @"UnzipKit", _resources, @"Detailed error string"),
                                fileInfo.filename];
            UZKLogError("UZKErrorCodeFileNotFoundInArchive: %{public}@", detail);
            [welf assignError:error code:UZKErrorCodeFileNotFoundInArchive
                       detail:detail];
            return;
        }
        
        UZKLogInfo("Reading file from archive");
        
        NSData *fileData = [welf readFile:fileInfo.filename
                                   length:fileInfo.uncompressedSize
                                    error:error];
        
        if (!fileData) {
            UZKLogError("Error reading file %{public}@ in archive", fileInfo.filename);
            return;
        }
        
        UZKLogInfo("Performing action on file data");
        action(fileInfo, fileData, stop);
    } error:error];
}

- (BOOL)extractBufferedDataFromFile:(NSString *)filePath
                              error:(NSError * __autoreleasing*)error
                             action:(void (^)(NSData *, CGFloat))action
{
    UZKCreateActivity("Extracting Data into Buffer");
    
    NSProgress *progress = [self beginProgressOperation:0];
    
    __weak UZKArchive *welf = self;
    NSUInteger bufferSize = 1024 * 256; // 256 kb, arbitrary
    
    BOOL success = [self performActionWithArchiveOpen:^(NSError * __autoreleasing*innerError) {
        if (![welf locateFileInZip:filePath error:innerError]) {
            NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Failed to locate '%@' in archive during buffered read", @"UnzipKit", _resources, @"Detailed error string"),
                                filePath];
            UZKLogError("UZKErrorCodeFileNotFoundInArchive: %{public}@", detail);
            [welf assignError:innerError code:UZKErrorCodeFileNotFoundInArchive
                       detail:detail];
            return;
        }
        
        UZKLogInfo("Getting file info");
        UZKFileInfo *info = [welf currentFileInZipInfo:innerError];
        
        if (!info) {
            UZKLogError("Failed to get info of file %{public}@ in archive", filePath);
            return;
        }
        
        progress.totalUnitCount = info.uncompressedSize;

        UZKLogInfo("Opening file");
        if (![welf openFile:innerError]) {
            UZKLogError("Failed to open file %{public}@ in archive", filePath);
            return;
        }
        
        long long bytesDecompressed = 0;
        
        NSError *strongInnerError = nil;
        
        for (;;)
        {
            if (progress.isCancelled) {
                UZKLogInfo("Buffered data read cancelled");
                return;
            }
            
            @autoreleasepool {
                UZKLogDebug("Reading file data");
                NSMutableData *data = [NSMutableData dataWithLength:bufferSize];
                int bytesRead = unzReadCurrentFile(welf.unzFile, data.mutableBytes, (unsigned)bufferSize);
                
                if (bytesRead < 0) {
                    NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Failed to read file %@ in zip", @"UnzipKit", _resources, @"Detailed error string"),
                                        info.filename];
                    UZKLogError("Error reading data (code %d): %{public}@", bytesRead, detail);
                    [welf assignError:&strongInnerError code:bytesRead
                               detail:detail];
                    break;
                }
                else if (bytesRead == 0) {
                    UZKLogDebug("Done reading file");
                    break;
                }
                
                UZKLogDebug("bytesRead: %{iec-bytes}d (%d bytes)", bytesRead, bytesRead);

                data.length = bytesRead;
                bytesDecompressed += bytesRead;
                
                if (action) {
                    UZKLogDebug("Performing action on chunk of data");
                    action([data copy], bytesDecompressed / (CGFloat)info.uncompressedSize);
                }
                
                progress.completedUnitCount = bytesDecompressed;
            }
        }
        
        if (strongInnerError) {
            *innerError = strongInnerError;
            return;
        }
        
        UZKLogInfo("Closing file...");
        int err = unzCloseCurrentFile(welf.unzFile);
        if (err != UNZ_OK) {
            if (err == UZKErrorCodeCRCError) {
                err = UZKErrorCodeInvalidPassword;
            }
            
            NSString *detail = NSLocalizedStringFromTableInBundle(@"Error closing current file during buffered read", @"UnzipKit", _resources, @"Detailed error string");
            UZKLogError("Error closing file (code %d): %{public}@", err, detail);
            [welf assignError:innerError code:err
                       detail:detail];
            return;
        }
        
    } inMode:UZKFileModeUnzip error:error];
    
    if (progress.isCancelled) {
        UZKLogError("User cancelled data extraction");
        NSString *detail = NSLocalizedStringFromTableInBundle(@"User cancelled data read", @"UnzipKit", _resources, @"Detailed error string");
        [self assignError:error code:UZKErrorCodeUserCancelled
                   detail:detail];
        return NO;
    }
    
    return success;
}

- (BOOL)isPasswordProtected
{
    UZKCreateActivity("Checking Password Protection");
    
    NSError *error = nil;
    NSArray *fileInfos = [self listFileInfo:&error];
    
    if (error) {
        UZKLogError("Error checking whether file is password protected: %{public}@", error);
        return NO;
    }
    
    for (UZKFileInfo *fileInfo in fileInfos) {
        if (fileInfo.isEncryptedWithPassword) {
            UZKLogDebug("File %{public}@ is encrypted. Not checking any others", fileInfo.filename);
            return YES;
        }

        UZKLogDebug("File %{public}@ is NOT encrypted. Checking remaining files", fileInfo.filename);
    }
    
    return NO;
}

- (BOOL)validatePassword
{
    UZKCreateActivity("Validating Password");
    
    if (!self.isPasswordProtected) {
        UZKLogInfo("Archive is not password protected. There is no password to validate");
        return YES;
    }
    
    NSError *error = nil;
    NSArray *fileInfos = [self listFileInfo:&error];
    
    if (error) {
        UZKLogError("Error checking whether file is password protected: %{public}@", error);
        return NO;
    }
    
    if (!fileInfos || fileInfos.count == 0) {
        UZKLogInfo("There are no files in the archive");
        return NO;
    }
    
    UZKFileInfo *smallest = [fileInfos sortedArrayUsingComparator:^NSComparisonResult(UZKFileInfo *file1, UZKFileInfo *file2) {
        if (file1.uncompressedSize < file2.uncompressedSize)
            return NSOrderedAscending;
        if (file1.uncompressedSize > file2.uncompressedSize)
            return NSOrderedDescending;
        return NSOrderedSame;
    }].firstObject;

    UZKLogDebug("Decrypting smallest file in archive: %{public}@", smallest.filename);
    
    NSData *smallestData = [self extractData:(UZKFileInfo* _Nonnull)smallest
                                       error:&error];
    
    if (error || !smallestData) {
        UZKLogInfo("Error while checking password: %{public}@", error);
        return NO;
    }
    
    return YES;
}

- (BOOL)checkDataIntegrity
{
    return [self checkDataIntegrityOfFile:(NSString * _Nonnull)nil];
}

- (BOOL)checkDataIntegrityOfFile:(NSString *)filePath
{
    UZKCreateActivity("Checking data integrity");
    
    UZKLogInfo("Checking integrity of %{public}@", filePath ? filePath : @"all files in archive");
    
    NSError *performOnDataError = nil;
    __block BOOL dataIsValid = NO;
    
    BOOL success = [self performOnDataInArchive:
     ^(UZKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
         // Only set this once we've reached this point, validating the archive's structures
         dataIsValid = YES;
         
         if (filePath && ![filePath isEqualToString:fileInfo.filename]) {
             UZKLogDebug("Skipping '%{public}@' != %{public}@", fileInfo.filename, filePath);
             return;
         }
         
         uLong extractedCRC = crc32(0, fileData.bytes, (uInt)fileData.length);

         if (extractedCRC != fileInfo.CRC) {
             UZKLogError("CRC mismatch in '%{public}@': expected %010lu, found %010lu",
                         fileInfo.filename, (unsigned long)fileInfo.CRC, extractedCRC)
             dataIsValid = NO;
         }
         
         if (!dataIsValid || filePath) {
             *stop = YES;
         }
    }
                           error:&performOnDataError];
    
    if (!success) {
        UZKLogError("Failed to iterate through data: %{public}@", performOnDataError);
    }
    
    return success && dataIsValid;
}


#pragma mark - Write Methods


- (BOOL)writeData:(NSData *)data
         filePath:(NSString *)filePath
            error:(NSError * __autoreleasing*)error
{
    return [self writeData:data
                  filePath:filePath
                  fileDate:nil
         compressionMethod:UZKCompressionMethodDefault
                  password:nil
                 overwrite:YES
                     error:error];
}

- (BOOL)writeData:(NSData *)data
         filePath:(NSString *)filePath
         progress:(void (^)(CGFloat percentCompressed))progress
            error:(NSError * __autoreleasing*)error
{
    return [self writeData:data
                  filePath:filePath
                  fileDate:nil
         compressionMethod:UZKCompressionMethodDefault
                  password:nil
                 overwrite:YES
                  progress:progress
                     error:error];
}

- (BOOL)writeData:(NSData *)data
         filePath:(NSString *)filePath
         fileDate:(NSDate *)fileDate
            error:(NSError * __autoreleasing*)error
{
    return [self writeData:data
                  filePath:filePath
                  fileDate:fileDate
         compressionMethod:UZKCompressionMethodDefault
                  password:nil
                 overwrite:YES
                     error:error];
}

- (BOOL)writeData:(NSData *)data
         filePath:(NSString *)filePath
         fileDate:(NSDate *)fileDate
         progress:(void (^)(CGFloat percentCompressed))progress
            error:(NSError * __autoreleasing*)error
{
    return [self writeData:data
                  filePath:filePath
                  fileDate:fileDate
         compressionMethod:UZKCompressionMethodDefault
                  password:nil
                 overwrite:YES
                  progress:progress
                     error:error];
}

- (BOOL)writeData:(NSData *)data
         filePath:(NSString *)filePath
         fileDate:(NSDate *)fileDate
compressionMethod:(UZKCompressionMethod)method
         password:(NSString *)password
            error:(NSError * __autoreleasing*)error
{
    return [self writeData:data
                  filePath:filePath
                  fileDate:fileDate
         compressionMethod:method
                  password:password
                 overwrite:YES
                     error:error];
}

- (BOOL)writeData:(NSData *)data
         filePath:(NSString *)filePath
         fileDate:(NSDate *)fileDate
compressionMethod:(UZKCompressionMethod)method
         password:(NSString *)password
         progress:(void (^)(CGFloat percentCompressed))progress
            error:(NSError * __autoreleasing*)error
{
    return [self writeData:data
                  filePath:filePath
                  fileDate:fileDate
         compressionMethod:method
                  password:password
                 overwrite:YES
                  progress:progress
                     error:error];
}

- (BOOL)writeData:(NSData *)data
         filePath:(NSString *)filePath
         fileDate:(NSDate *)fileDate
compressionMethod:(UZKCompressionMethod)method
         password:(NSString *)password
        overwrite:(BOOL)overwrite
            error:(NSError * __autoreleasing*)error
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self writeData:data
                  filePath:filePath
                  fileDate:fileDate
         compressionMethod:method
                  password:password
                 overwrite:overwrite
                  progress:nil
                     error:error];
#pragma clang diagnostic pop
}

- (BOOL)writeData:(NSData *)data
         filePath:(NSString *)filePath
         fileDate:(NSDate *)fileDate
compressionMethod:(UZKCompressionMethod)method
         password:(NSString *)password
        overwrite:(BOOL)overwrite
         progress:(void (^)(CGFloat percentCompressed))progressBlock
            error:(NSError * __autoreleasing*)error
{
    return [self writeData:data
                  filePath:filePath
                  fileDate:fileDate
          posixPermissions:0
         compressionMethod:method
                  password:password
                 overwrite:overwrite
                  progress:progressBlock
                     error:error];
}

- (BOOL)writeData:(NSData *)data
         filePath:(NSString *)filePath
         fileDate:(nullable NSDate *)fileDate
 posixPermissions:(short)permissions
compressionMethod:(UZKCompressionMethod)method
         password:(nullable NSString *)password
        overwrite:(BOOL)overwrite
            error:(NSError * __autoreleasing*)error
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self writeData:data
                  filePath:filePath
                  fileDate:fileDate
          posixPermissions:permissions
         compressionMethod:method
                  password:password
                 overwrite:overwrite
                  progress:nil
                     error:error];
#pragma clang diagnostic pop
}

- (BOOL)writeData:(NSData *)data
         filePath:(NSString *)filePath
         fileDate:(NSDate *)fileDate
 posixPermissions:(short)permissions
compressionMethod:(UZKCompressionMethod)method
         password:(NSString *)password
        overwrite:(BOOL)overwrite
         progress:(void (^)(CGFloat percentCompressed))progressBlock
            error:(NSError * __autoreleasing*)error
{
    UZKCreateActivity("Writing Data");
    
    UZKLogInfo("Writing data to archive. filePath: %{public}@, fileDate: %{time_t}ld, compressionMethod: %ld, password: %{public}@, "
               "overwrite: %{public}@, progress block specified: %{public}@, error pointer specified: %{public}@",
               filePath, lrint(fileDate.timeIntervalSince1970), (long)method, password != nil ? @"<specified>" : @"(null)", overwrite ? @"YES" : @"NO",
               progressBlock ? @"YES" : @"NO", error ? @"YES" : @"NO");
    
    const NSUInteger bufferSize = 4096; //Arbitrary
    const void *bytes = data.bytes;
    
    NSProgress *progress = [self beginProgressOperation:data.length];
    progress.cancellable = NO;
    
    if (progressBlock) {
        UZKLogDebug("Calling progress block with zero");
        progressBlock(0);
    }
    
    __weak UZKArchive *welf = self;
    uLong calculatedCRC = crc32(0, data.bytes, (uInt)data.length);
    UZKLogDebug("Calculated CRC: %010lu", calculatedCRC);
    
    BOOL success = [self performWriteAction:^int(uLong *crc, NSError * __autoreleasing*innerError) {
        UZKCreateActivity("Performing File Write");
        
        NSAssert(crc, @"No CRC reference passed", nil);
        *crc = calculatedCRC;
        
        UZKLogInfo("Iterating through all data, in %lu chunks", (unsigned long)bufferSize);
        
        for (NSUInteger i = 0; i <= data.length; i += bufferSize) {
            UZKLogDebug("Writing chunk starting at byte %lu", (unsigned long)i);
            
            unsigned int dataRemaining = (unsigned int)(data.length - i);
            unsigned int size = (unsigned int)(dataRemaining < bufferSize ? dataRemaining : bufferSize);
            int err = zipWriteInFileInZip(welf.zipFile, (const char *)bytes + i, size);
            
            if (err != ZIP_OK) {
                UZKLogError("Error writing data: %d", err);
                return err;
            }
            
            progress.completedUnitCount += size;
            
            if (progressBlock) {
                double percentComplete = i / (double)data.length;
                UZKLogDebug("Calling progress block at %.3f%%", percentComplete * 100);
                progressBlock(percentComplete);
            }
        }
        
        return ZIP_OK;
    }
                                   filePath:filePath
                                   fileDate:fileDate
                           posixPermissions:permissions
                          compressionMethod:method
                                   password:password
                                  overwrite:overwrite
                                        CRC:calculatedCRC
                                      error:error];
    
    return success;
}

- (BOOL)writeIntoBuffer:(NSString *)filePath
                  error:(NSError * __autoreleasing*)error
                  block:(BOOL(^)(BOOL(^writeData)(const void *bytes, unsigned int length), NSError * __autoreleasing*actionError))action
{
    return [self writeIntoBuffer:filePath
                        fileDate:nil
                posixPermissions:0
               compressionMethod:UZKCompressionMethodDefault
                       overwrite:YES
                             CRC:0
                        password:nil
                           error:error
                           block:action];
}

- (BOOL)writeIntoBuffer:(NSString *)filePath
               fileDate:(NSDate *)fileDate
                  error:(NSError * __autoreleasing*)error
                  block:(BOOL(^)(BOOL(^writeData)(const void *bytes, unsigned int length), NSError * __autoreleasing*actionError))action
{
    return [self writeIntoBuffer:filePath
                        fileDate:fileDate
                posixPermissions:0
               compressionMethod:UZKCompressionMethodDefault
                       overwrite:YES
                             CRC:0
                        password:nil
                           error:error
                           block:action];
}

- (BOOL)writeIntoBuffer:(NSString *)filePath
               fileDate:(NSDate *)fileDate
      compressionMethod:(UZKCompressionMethod)method
                  error:(NSError * __autoreleasing*)error
                  block:(BOOL(^)(BOOL(^writeData)(const void *bytes, unsigned int length), NSError * __autoreleasing*actionError))action
{
    return [self writeIntoBuffer:filePath
                        fileDate:fileDate
                posixPermissions:0
               compressionMethod:method
                       overwrite:YES
                             CRC:0
                        password:nil
                           error:error
                           block:action];
}

- (BOOL)writeIntoBuffer:(NSString *)filePath
               fileDate:(NSDate *)fileDate
      compressionMethod:(UZKCompressionMethod)method
              overwrite:(BOOL)overwrite
                  error:(NSError * __autoreleasing*)error
                  block:(BOOL(^)(BOOL(^writeData)(const void *bytes, unsigned int length), NSError * __autoreleasing*actionError))action
{
    return [self writeIntoBuffer:filePath
                        fileDate:fileDate
                posixPermissions:0
               compressionMethod:method
                       overwrite:overwrite
                             CRC:0
                        password:nil
                           error:error
                           block:action];
}

- (BOOL)writeIntoBuffer:(NSString *)filePath
               fileDate:(NSDate *)fileDate
      compressionMethod:(UZKCompressionMethod)method
              overwrite:(BOOL)overwrite
                    CRC:(uLong)preCRC
                  error:(NSError *__autoreleasing *)error
                  block:(BOOL (^)(BOOL (^)(const void *, unsigned int), NSError *__autoreleasing *))action
{
    return [self writeIntoBuffer:filePath
                        fileDate:fileDate
                posixPermissions:0
               compressionMethod:method
                       overwrite:overwrite
                             CRC:preCRC
                        password:nil
                           error:error
                           block:action];
}

- (BOOL)writeIntoBuffer:(NSString *)filePath
               fileDate:(NSDate *)fileDate
      compressionMethod:(UZKCompressionMethod)method
              overwrite:(BOOL)overwrite
                    CRC:(uLong)preCRC
               password:(NSString *)password
                  error:(NSError *__autoreleasing *)error
                  block:(BOOL (^)(BOOL (^)(const void *, unsigned int), NSError *__autoreleasing *))action
{
    return [self writeIntoBuffer:filePath
                        fileDate:fileDate
                posixPermissions:0
               compressionMethod:method
                       overwrite:overwrite
                             CRC:preCRC
                        password:password
                           error:error
                           block:action];
}

- (BOOL)writeIntoBuffer:(NSString *)filePath
               fileDate:(NSDate *)fileDate
       posixPermissions:(short)permissions
      compressionMethod:(UZKCompressionMethod)method
              overwrite:(BOOL)overwrite
                    CRC:(uLong)preCRC
               password:(NSString *)password
                  error:(NSError *__autoreleasing *)error
                  block:(BOOL (^)(BOOL (^)(const void *, unsigned int), NSError *__autoreleasing *))action
{
    UZKCreateActivity("Writing Into Buffer");
    
    UZKLogInfo("Writing data into buffer. filePath: %{public}@, fileDate: %{time_t}ld, compressionMethod: %ld, "
               "overwrite: %{public}@, CRC: %010lu, password: %{public}@, error pointer specified: %{public}@",
               filePath, lrint(fileDate.timeIntervalSince1970), (long)method, overwrite ? @"YES" : @"NO", preCRC,
               password != nil ? @"<specified>" : @"(null)", error ? @"YES" : @"NO");
    
    NSAssert(preCRC != 0 || ([password length] == 0 && [self.password length] == 0),
             @"Cannot provide a password when writing into a buffer, "
             "unless a CRC is provided up front for inclusion in the header", nil);
    
    __weak UZKArchive *welf = self;

    BOOL success = [self performWriteAction:^int(uLong *crc, NSError * __autoreleasing*innerError) {
        UZKCreateActivity("Performing File Write");
        
        NSAssert(crc, @"No CRC reference passed", nil);
        
        if (!action) {
            UZKLogInfo("No write action specified. This is unusual, but not fatal");
            return ZIP_OK;
        }
        
        BOOL result = action(^BOOL(const void *bytes, unsigned int length) {
            UZKLogInfo("Writing %{iec-bytes}u (%u bytes) into archive from buffer", length, length);
            int writeErr = zipWriteInFileInZip(self.zipFile, bytes, length);
            if (writeErr != ZIP_OK) {
                UZKLogError("Error writing data from buffer: %d", writeErr);
                return NO;
            }
            
            uLong oldCRC = *crc;
            *crc = crc32(oldCRC, bytes, (uInt)length);
            UZKLogDebug("Calculated new CRC: %010lu from old CRC: %010lu", *crc, oldCRC);
            
            return YES;
        }, innerError);
        
        if (preCRC != 0 && *crc != preCRC) {
            uLong calculatedCRC = *crc;
            NSString *preCRCStr = [NSString stringWithFormat:@"%010lu", preCRC];
            NSString *calculatedCRCStr = [NSString stringWithFormat:@"%010lu", calculatedCRC];
            NSString *detail = [NSString stringWithFormat:
                                NSLocalizedStringFromTableInBundle(@"Incorrect CRC provided\n%@ given\n%@ calculated", @"UnzipKit", _resources, @"CRC mismatch error detail"),
                                preCRCStr, calculatedCRCStr];
            UZKLogError("UZKErrorCodePreCRCMismatch: %{public}@", detail);
            return [welf assignError:innerError code:UZKErrorCodePreCRCMismatch
                       detail:detail];
        }
        
        return result;
    }
                                   filePath:filePath
                                   fileDate:fileDate
                           posixPermissions:permissions
                          compressionMethod:method
                                   password:password
                                  overwrite:overwrite
                                        CRC:preCRC
                                      error:error];
    
    return success;
}

- (BOOL)deleteFile:(NSString *)filePath error:(NSError * __autoreleasing*)error
{
    UZKCreateActivity("Deleting File");
    
    // Thanks to Ivan A. Krestinin for much of the code below: http://www.winimage.com/zLibDll/del.cpp
    
    UZKLogInfo("Deleting file %{public}@ from archive", filePath);
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (!self.filename || ![fm fileExistsAtPath:(NSString* _Nonnull)self.filename]) {
        UZKLogError("No archive exists at path %{public}@, when trying to delete %{public}@", self.filename, filePath);
        return YES;
    }
    
    NSString *randomString = [NSString stringWithFormat:@"%@.zip", [[NSProcessInfo processInfo] globallyUniqueString]];
    NSURL *temporaryURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:randomString];
    
    UZKLogInfo("Writing new archive without deleted file to %{public}@", temporaryURL.path);
    
    const char *original_filename = self.filename.UTF8String;
    const char *del_file = filePath.UTF8String;
    const char *temp_filename = temporaryURL.path.UTF8String;
    
    // Open source and destination files
    
    UZKLogInfo("Opening original archive at %{public}s", original_filename);
    zipFile source_zip = unzOpen(original_filename);
    if (source_zip == NULL) {
        NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error opening the source file while deleting %@", @"UnzipKit", _resources, @"Detailed error string"),
                            filePath];
        UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
        return [self assignError:error code:UZKErrorCodeDeleteFile
                          detail:detail];
    }
    
    UZKLogInfo("Opening temporary archive at %{public}s", temp_filename);
    zipFile dest_zip = zipOpen(temp_filename, APPEND_STATUS_CREATE);
    if (dest_zip == NULL) {
        NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error opening the destination file while deleting %@", @"UnzipKit", _resources, @"Detailed error string"),
                            filePath];
        UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
        UZKLogDebug("Closing source_zip");
        unzClose(source_zip);
        return [self assignError:error code:UZKErrorCodeDeleteFile
                          detail:detail];
    }
    
    // Get global commentary
    
    UZKLogInfo("Getting global info from source zip");
    unz_global_info global_info;
    int err = unzGetGlobalInfo(source_zip, &global_info);
    if (err != UNZ_OK) {
        NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error getting the global info of the source file while deleting %@ (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                            filePath, err];
        UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
        UZKLogDebug("Closing source_zip, dest_zip");
        zipClose(dest_zip, NULL);
        unzClose(source_zip);
        return [self assignError:error code:UZKErrorCodeDeleteFile
                          detail:detail];
    }
    
    char *global_comment = NULL;
    
    if (global_info.size_comment > 0)
    {
        UZKLogInfo("Getting global comment from source zip");
        global_comment = (char*)malloc(global_info.size_comment+1);
        if ((global_comment == NULL) && (global_info.size_comment != 0)) {
            NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error reading the global comment of the source file while deleting %@", @"UnzipKit", _resources, @"Detailed error string"),
                                filePath];
            UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
            UZKLogDebug("Closing source_zip, dest_zip");
            zipClose(dest_zip, NULL);
            unzClose(source_zip);
            return [self assignError:error code:UZKErrorCodeDeleteFile
                              detail:detail];
        }
        
        if ((unsigned int)unzGetGlobalComment(source_zip, global_comment, global_info.size_comment + 1) != global_info.size_comment) {
            NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error reading the global comment of the source file while deleting %@ (wrong size)", @"UnzipKit", _resources, @"Detailed error string"),
                                filePath];
            UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
            UZKLogDebug("Closing source_zip, dest_zip, freeing global_comment");
            zipClose(dest_zip, NULL);
            unzClose(source_zip);
            free(global_comment);
            return [self assignError:error code:UZKErrorCodeDeleteFile
                              detail:detail];
        }
    }
    
    BOOL noFilesDeleted = YES;
    int filesCopied = 0;
    
    NSString *filenameToDelete = [UZKArchive figureOutCString:del_file];
    
    UZKLogInfo("Navigating to first file in source archive");
    int nextFileReturnValue = unzGoToFirstFile(source_zip);
    
    while (nextFileReturnValue == UNZ_OK)
    {
        // Get zipped file info
        char filename_inzip[FILE_IN_ZIP_MAX_NAME_LENGTH];
        unz_file_info64 unzipInfo;
        
        UZKLogDebug("Getting file info");
        err = unzGetCurrentFileInfo64(source_zip, &unzipInfo, filename_inzip, sizeof(filename_inzip), NULL, 0, NULL, 0);
        if (err != UNZ_OK) {
            NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error getting file info of file while deleting %@ (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                                filePath, err];
            UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
            UZKLogDebug("Closing source_zip, dest_zip, freeing global_comment");
            zipClose(dest_zip, NULL);
            unzClose(source_zip);
            free(global_comment);
            return [self assignError:error code:UZKErrorCodeDeleteFile
                              detail:detail];
        }
        
        NSString *currentFileName = [UZKArchive figureOutCString:filename_inzip];
        UZKLogDebug("Current file is %{public}@", currentFileName);
        
        // If this is the file to delete
        if ([filenameToDelete isEqualToString:currentFileName.decomposedStringWithCanonicalMapping]) {
            UZKLogDebug("This file is the one we're deleting");
            noFilesDeleted = NO;
        } else {
            UZKLogDebug("Allocating extra field");
            char *extra_field = (char*)malloc(unzipInfo.size_file_extra);
            if ((extra_field == NULL) && (unzipInfo.size_file_extra != 0)) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error allocating extra_field info of %@ while deleting %@", @"UnzipKit", _resources, @"Detailed error string"),
                                    currentFileName, filePath];
                UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
                UZKLogDebug("Closing source_zip, dest_zip, freeing global_comment");
                zipClose(dest_zip, NULL);
                unzClose(source_zip);
                free(global_comment);
                return [self assignError:error code:UZKErrorCodeDeleteFile
                                  detail:detail];
            }
            
            UZKLogDebug("Allocating commentary");
            char *commentary = (char*)malloc(unzipInfo.size_file_comment);
            if ((commentary == NULL) && (unzipInfo.size_file_comment != 0)) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error allocating commentary info of %@ while deleting %@", @"UnzipKit", _resources, @"Detailed error string"),
                                    currentFileName, filePath];
                UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
                UZKLogDebug("Closing source_zip, dest_zip, freeing global_comment, extra_field");
                zipClose(dest_zip, NULL);
                unzClose(source_zip);
                free(global_comment);
                free(extra_field);
                return [self assignError:error code:UZKErrorCodeDeleteFile
                                  detail:detail];
            }
            
            UZKLogDebug("Getting file info");
            err = unzGetCurrentFileInfo64(source_zip, &unzipInfo, filename_inzip, FILE_IN_ZIP_MAX_NAME_LENGTH, extra_field, unzipInfo.size_file_extra, commentary, unzipInfo.size_file_comment);
            if (err != UNZ_OK) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error reading extra_field and commentary info of %@ while deleting %@ (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                                    currentFileName, filePath, err];
                UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
                UZKLogDebug("Closing source_zip, dest_zip, freeing global_comment, extra_field, commentary");
                free(extra_field);
                free(commentary);
                return [self assignError:error code:UZKErrorCodeDeleteFile
                                  detail:detail];
            }
            
            // Open source archive for raw reading
            
            int method;
            int level;
            UZKLogDebug("Opening file in source archive");
            err = unzOpenCurrentFile2(source_zip, &method, &level, 1);
            if (err != UNZ_OK) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error opening %@ for raw reading while deleting %@ (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                                    currentFileName, filePath, err];
                UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
                UZKLogDebug("Closing source_zip, dest_zip, freeing global_comment, extra_field, commentary");
                zipClose(dest_zip, NULL);
                unzClose(source_zip);
                free(global_comment);
                free(extra_field);
                free(commentary);
                return [self assignError:error code:UZKErrorCodeDeleteFile
                                  detail:detail];
            }
            
            UZKLogDebug("Getting local extra field size");
            int size_local_extra = unzGetLocalExtrafield(source_zip, NULL, 0);
            if (size_local_extra < 0) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error getting size_local_extra for file while deleting %@", @"UnzipKit", _resources, @"Detailed error string"),
                                    currentFileName, filePath];
                UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
                UZKLogDebug("Closing source_zip, dest_zip, freeing global_comment, extra_field, commentary");
                zipClose(dest_zip, NULL);
                unzClose(source_zip);
                free(global_comment);
                free(extra_field);
                free(commentary);
                return [self assignError:error code:UZKErrorCodeDeleteFile
                                  detail:detail];
            }
            
            UZKLogDebug("Allocating local extra field");
            void *local_extra = malloc(size_local_extra);
            if ((local_extra == NULL) && (size_local_extra != 0)) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error allocating local_extra for file %@ while deleting %@", @"UnzipKit", _resources, @"Detailed error string"),
                                    currentFileName, filePath];
                UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
                UZKLogDebug("Closing source_zip, dest_zip, freeing global_comment, extra_field, commentary");
                zipClose(dest_zip, NULL);
                unzClose(source_zip);
                free(global_comment);
                free(extra_field);
                free(commentary);
                return [self assignError:error code:UZKErrorCodeDeleteFile
                                  detail:detail];
            }
            
            UZKLogDebug("Getting local extra field");
            if (unzGetLocalExtrafield(source_zip, local_extra, size_local_extra) < 0) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error getting local_extra for file %@ while deleting %@", @"UnzipKit", _resources, @"Detailed error string"),
                                    currentFileName, filePath];
                UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
                UZKLogDebug("Closing source_zip, dest_zip, freeing global_comment, extra_field, commentary, local_extra");
                zipClose(dest_zip, NULL);
                unzClose(source_zip);
                free(global_comment);
                free(extra_field);
                free(commentary);
                free(local_extra);
                return [self assignError:error code:UZKErrorCodeDeleteFile
                                  detail:detail];
            }
            
            // This malloc may fail if the file is very large
            UZKLogDebug("Allocating data read buffer");
            void *buf = malloc((unsigned long)unzipInfo.compressed_size);
            if ((buf == NULL) && (unzipInfo.compressed_size != 0)) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error allocating buffer for file %@ while deleting %@. Is it too large?", @"UnzipKit", _resources, @"Detailed error string"),
                                    currentFileName, filePath];
                UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
                UZKLogDebug("Closing source_zip, dest_zip, freeing global_comment, extra_field, commentary, local_extra");
                zipClose(dest_zip, NULL);
                unzClose(source_zip);
                free(global_comment);
                free(extra_field);
                free(commentary);
                free(local_extra);
                return [self assignError:error code:UZKErrorCodeDeleteFile
                                  detail:detail];
            }
            
            // Read file
            UZKLogDebug("Reading data into buffer");
            int size = unzReadCurrentFile(source_zip, buf, (uInt)unzipInfo.compressed_size);
            if ((unsigned int)size != unzipInfo.compressed_size) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error reading %@ into buffer while deleting %@", @"UnzipKit", _resources, @"Detailed error string"),
                                    currentFileName, filePath];
                UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
                UZKLogDebug("Closing source_zip, dest_zip, freeing global_comment, extra_field, commentary, local_extra, buf");
                zipClose(dest_zip, NULL);
                unzClose(source_zip);
                free(global_comment);
                free(extra_field);
                free(commentary);
                free(local_extra);
                free(buf);
                return [self assignError:error code:UZKErrorCodeDeleteFile
                                  detail:detail];
            }
            
            // Open destination archive
            
            UZKLogDebug("Filling zip_fileinfo struct");
            zip_fileinfo zipInfo;
            memcpy (&zipInfo.tmz_date, &unzipInfo.tmu_date, sizeof(tm_unz));
            zipInfo.dosDate = unzipInfo.dosDate;
            zipInfo.internal_fa = unzipInfo.internal_fa;
            zipInfo.external_fa = unzipInfo.external_fa;
            
            UZKLogDebug("Opening file in destination archive");
            err = zipOpenNewFileInZip2(dest_zip, filename_inzip, &zipInfo,
                                       local_extra, size_local_extra, extra_field, (uInt)unzipInfo.size_file_extra, commentary,
                                       method, level, 1);
            if (err != UNZ_OK) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error opening %@ in destination zip while deleting %@ (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                                    currentFileName, filePath, err];
                UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
                UZKLogDebug("Closing source_zip, dest_zip, freeing global_comment, extra_field, commentary, local_extra, buf");
                zipClose(dest_zip, NULL);
                unzClose(source_zip);
                free(global_comment);
                free(extra_field);
                free(commentary);
                free(local_extra);
                free(buf);
                return [self assignError:error code:UZKErrorCodeDeleteFile
                                  detail:detail];
            }
            
            // Write file
            UZKLogDebug("Writing file in destination archive");
            err = zipWriteInFileInZip(dest_zip, buf, (uInt)unzipInfo.compressed_size);
            if (err != UNZ_OK) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error writing %@ to destination zip while deleting %@ (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                                    currentFileName, filePath, err];
                UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
                UZKLogDebug("Closing source_zip, dest_zip, freeing global_comment, extra_field, commentary, local_extra, buf");
                zipClose(dest_zip, NULL);
                unzClose(source_zip);
                free(global_comment);
                free(extra_field);
                free(commentary);
                free(local_extra);
                free(buf);
                return [self assignError:error code:UZKErrorCodeDeleteFile
                                  detail:detail];
            }
            
            // Close destination archive
            UZKLogDebug("Closing file in destination archive");
            err = zipCloseFileInZipRaw64(dest_zip, unzipInfo.uncompressed_size, unzipInfo.crc);
            if (err != UNZ_OK) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error closing %@ in destination zip while deleting %@ (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                                    currentFileName, filePath, err];
                UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
                UZKLogDebug("Closing source_zip, dest_zip, freeing global_comment, extra_field, commentary, local_extra, buf");
                zipClose(dest_zip, NULL);
                unzClose(source_zip);
                free(global_comment);
                free(extra_field);
                free(commentary);
                free(local_extra);
                free(buf);
                return [self assignError:error code:UZKErrorCodeDeleteFile
                                  detail:detail];
            }
            
            // Close source archive
            UZKLogDebug("Closing source archive");
            err = unzCloseCurrentFile(source_zip);
            if (err != UNZ_OK) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error closing %@ in source zip while deleting %@ (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                                    currentFileName, filePath, err];
                UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
                UZKLogDebug("Closing source_zip, dest_zip, freeing global_comment, extra_field, commentary, local_extra, buf");
                zipClose(dest_zip, NULL);
                unzClose(source_zip);
                free(global_comment);
                free(extra_field);
                free(commentary);
                free(local_extra);
                free(buf);
                return [self assignError:error code:UZKErrorCodeDeleteFile
                                  detail:detail];
            }
            
            UZKLogDebug("Freeing extra_field, commentary, local_extra, buf");
            free(extra_field);
            free(commentary);
            free(local_extra);
            free(buf);
            
            ++filesCopied;
        }
        
        UZKLogDebug("Going to next file");
        nextFileReturnValue = unzGoToNextFile(source_zip);
    }
    
    UZKLogDebug("Closing source_zip, dest_zip (writing global comment)");
    zipClose(dest_zip, global_comment);
    unzClose(source_zip);
    
    UZKLogDebug("Freeing global_comment");
    free(global_comment);

    // Don't swap the files
    if (noFilesDeleted) {
        UZKLogInfo("No files deleted. Not replacing the original archive with the copy");
        return YES;
    }
    
    // Failure
    if (nextFileReturnValue != UNZ_END_OF_LIST_OF_FILE)
    {
        NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Failed to seek to the next file, while deleting %@ from the archive", @"UnzipKit", _resources, @"Detailed error string"),
                            filenameToDelete];
        UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
        UZKLogDebug("Removing temp_filename");
        remove(temp_filename);
        return [self assignError:error code:UZKErrorCodeDeleteFile
                          detail:detail];
    }
    
    // Replace old file with the new (trimmed) one
    NSURL *newURL;
    
    NSString *temporaryVolume = temporaryURL.volumeName;
    NSString *destinationVolume = self.fileURL.volumeName;
    
    if ([temporaryVolume isEqualToString:destinationVolume]) {
        UZKLogInfo("Temporary file URL and destination URL share a volume. Replacing one file with another");
        NSError *replaceError = nil;
        BOOL result = [fm replaceItemAtURL:(NSURL* _Nonnull)self.fileURL
                             withItemAtURL:temporaryURL
                            backupItemName:nil
                                   options:NSFileManagerItemReplacementWithoutDeletingBackupItem
                          resultingItemURL:&newURL
                                     error:&replaceError];
        
        if (!result) {
            NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Failed to replace the old archive with the new one, after deleting '%@' from it (%@)", @"UnzipKit", _resources, @"Detailed error string"),
                                filenameToDelete, replaceError.localizedDescription];
            UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
            return [self assignError:error code:UZKErrorCodeDeleteFile
                              detail:detail
                           underlyer:replaceError];
        }
    } else {
        UZKLogInfo("Temporary file URL and destination URL reside on different volumes. Will remove original archive and copy over the replacement");
        newURL = self.fileURL;
        
        UZKLogDebug("Removing original archive: %{public}@", newURL);
        NSError *deleteError = nil;
        if (![fm removeItemAtURL:(NSURL* _Nonnull)newURL
                           error:&deleteError]) {
            NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Failed to remove original archive from external volume '%@', after deleting '%@' from a new version to replace it (%@)", @"UnzipKit", _resources, @"Detailed error string"),
                                destinationVolume, filenameToDelete, deleteError.localizedDescription];
            UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
            return [self assignError:error code:UZKErrorCodeDeleteFile
                              detail:detail
                           underlyer:deleteError];
        }
        
        UZKLogDebug("Copying temporary archive from %{public}@ to destination %{public}@", temporaryURL, newURL);
        NSError *copyError = nil;
        if (![fm copyItemAtURL:temporaryURL
                         toURL:(NSURL* _Nonnull)newURL
                         error:&copyError]) {
            NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Failed to copy archive to external volume '%@', after deleting '%@' from it (%@)", @"UnzipKit", _resources, @"Detailed error string"),
                                destinationVolume, filenameToDelete, copyError.localizedDescription];
            UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
            return [self assignError:error code:UZKErrorCodeDeleteFile
                              detail:detail
                           underlyer:copyError];
        }
    }
    
    UZKLogInfo("Updating archive bookmark");
    NSError *bookmarkError = nil;
    if (![self storeFileBookmark:newURL
                           error:&bookmarkError]) {
        NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Failed to store the new file bookmark to the archive after deleting '%@' from it: %@", @"UnzipKit", _resources, @"Detailed error string"),
                            filenameToDelete, bookmarkError.localizedDescription];
        UZKLogError("UZKErrorCodeDeleteFile: %{public}@", detail);
        return [self assignError:error code:UZKErrorCodeDeleteFile
                          detail:detail
                       underlyer:bookmarkError];
    }
    
    return YES;
}



#pragma mark - Private Methods


- (BOOL)performActionWithArchiveOpen:(void(^)(NSError * __autoreleasing*innerError))action
                              inMode:(UZKFileMode)mode
                               error:(NSError * __autoreleasing*)error
{
    UZKCreateActivity("Performing Action With Archive Open");
    
    @synchronized(self.threadLock) {
        if (error) {
            *error = nil;
        }
        
        NSError *openError = nil;
        NSError *actionError = nil;
        
        @try {
            if (![self openFile:self.filename
                         inMode:mode
                   withPassword:self.password
                          error:&openError])
            {
                UZKLogDebug("Archive failed to open. Reporting error");
                
                if (error) {
                    *error = openError;
                }
                
                return NO;
            }
            
            if (action) {
                UZKLogDebug("Performing action");
                action(&actionError);
            }
        }
        @finally {
            NSError *closeError = nil;
            if (![self closeFile:&closeError inMode:mode]) {
                UZKLogDebug("Archive failed to close");

                if (error && !actionError && !openError) {
                    *error = closeError;
                }
                
                return NO;
            }
        }
        
        if (error && actionError && !openError) {
            *error = actionError;
        }
        
        return !actionError;
    }
}

- (BOOL)performWriteAction:(int(^)(uLong *crc, NSError * __autoreleasing*innerError))write
                  filePath:(NSString *)filePath
                  fileDate:(NSDate *)fileDate
          posixPermissions:(short)permissions
         compressionMethod:(UZKCompressionMethod)method
                  password:(NSString *)password
                 overwrite:(BOOL)overwrite
                       CRC:(uLong)crc
                     error:(NSError * __autoreleasing*)error
{
    UZKCreateActivity("Performing Write");
    
    if (overwrite) {
        UZKLogInfo("Overwriting %{public}@ if it already exists. Will look for existing file to delete", filePath);
        
        NSError *listFilesError = nil;
        NSArray *existingFiles;
        
        @autoreleasepool {
            UZKLogDebug("Listing file info");
            existingFiles = [self listFileInfo:&listFilesError];
        }
        
        if (existingFiles) {
            UZKLogDebug("Existing files found. Looking for matches to filePath %{public}@", filePath);
            NSIndexSet *matchingFiles = [existingFiles indexesOfObjectsPassingTest:
                                         ^BOOL(UZKFileInfo *info, NSUInteger idx, BOOL *stop) {
                                             if ([info.filename isEqualToString:filePath]) {
                                                 *stop = YES;
                                                 return YES;
                                             }
                                             
                                             return NO;
                                         }];
            
            if (matchingFiles.count > 0 && ![self deleteFile:filePath error:error]) {
                UZKLogError("Failed to delete %{public}@ before writing new data for it", filePath);
                return NO;
            }
        }
    }
    
    if (!password) {
        UZKLogDebug("No password specified for file. Using archive's password: %{public}@", password != nil ? @"<hidden>" : @"(null)");
        password = self.password;
    }
    
    __weak UZKArchive *welf = self;

    BOOL success = [self performActionWithArchiveOpen:^(NSError * __autoreleasing*innerError) {
        UZKCreateActivity("Performing Write Action");
        
        UZKLogDebug("Making zip_fileinfo struct for date %{time_t}ld", lrint(fileDate.timeIntervalSince1970));
        zip_fileinfo zi = [UZKArchive zipFileInfoForDate:fileDate
                                        posixPermissions:permissions];
        
        const char *passwordStr = NULL;
        
        if (password) {
            UZKLogDebug("Converting password to NSISOLatin1StringEncoding");
            passwordStr = [password cStringUsingEncoding:NSISOLatin1StringEncoding];
        }
        
        UZKLogDebug("Opening new file...");
        int err = zipOpenNewFileInZip3(welf.zipFile,
                                       filePath.UTF8String,
                                       &zi,
                                       NULL, 0, NULL, 0, NULL,
                                       (method != UZKCompressionMethodNone) ? Z_DEFLATED : 0,
                                       method,
                                       0,
                                       -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY,
                                       passwordStr,
                                       crc);
        
        if (err != ZIP_OK) {
            NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error opening file '%@' for write (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                                filePath, err];
            UZKLogError("UZKErrorCodeFileOpenForWrite: %{public}@", detail);
            [welf assignError:innerError code:UZKErrorCodeFileOpenForWrite
                       detail:detail];
            return;
        }
        
        UZKLogDebug("Writing file");
        uLong outCRC = 0;
        err = write(&outCRC, innerError);
        if (err < 0) {
            NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error writing to file  '%@' (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                                filePath, err];
            UZKLogError("UZKErrorCodeFileOpenForWrite: %{public}@", detail);
            [welf assignError:innerError code:UZKErrorCodeFileWrite
                       detail:detail];
            return;
        }
        
        UZKLogDebug("Closing file...");
        err = zipCloseFileInZipRaw(self.zipFile, 0, outCRC);
        if (err != ZIP_OK) {
            NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error closing file '%@' for write (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                                filePath, err];
            UZKLogError("UZKErrorCodeFileOpenForWrite: %{public}@", detail);
            [welf assignError:innerError code:UZKErrorCodeFileWrite
                       detail:detail];
            return;
        }
        
    } inMode:UZKFileModeAppend error:error];
    
    return success;
}

- (BOOL)openFile:(NSString *)zipFile
          inMode:(UZKFileMode)mode
    withPassword:(NSString *)aPassword
           error:(NSError * __autoreleasing*)error
{
    UZKCreateActivity("Opening File");
    
    UZKLogDebug("Opening file in mode %lu", (unsigned long)mode);
    
    if (error) {
        *error = nil;
    }
    
    if (self.mode != UZKFileModeUnassigned && self.mode != mode) {
        NSString *message;
        
        if (self.mode == UZKFileModeUnzip) {
            message = NSLocalizedStringFromTableInBundle(@"Unable to begin writing to the archive until all read operations have completed", @"UnzipKit", _resources, @"Detailed error string");
        } else {
            message = NSLocalizedStringFromTableInBundle(@"Unable to begin reading from the archive until all write operations have completed", @"UnzipKit", _resources, @"Detailed error string");
        }
        
        UZKLogError("UZKErrorCodeMixedModeAccess: %{public}@", message);
        return [self assignError:error code:UZKErrorCodeMixedModeAccess detail:message];
    }
    
    if (mode != UZKFileModeUnzip && self.openCount > 0) {
        NSString *detail = NSLocalizedStringFromTableInBundle(@"Attempted to write to the archive while another write operation is already in progress", @"UnzipKit", _resources, @"Detailed error string");
        UZKLogError("UZKErrorCodeFileWrite: %{public}@", detail);
        return [self assignError:error code:UZKErrorCodeFileWrite
                          detail:detail];
    }
    
    // Always initialize comment, so it can be read when the file is closed
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdirect-ivar-access"
    if (!self.commentRetrieved) {
        UZKLogDebug("Retrieving comment");
        self.commentRetrieved = YES;
        _comment = [self readGlobalComment];
    }
#pragma clang diagnostic pop

    if (self.openCount++ > 0) {
        UZKLogDebug("File is already open. Not going any further");
        return YES;
    }
    
    self.mode = mode;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    switch (mode) {
        case UZKFileModeUnzip: {
            if (![fm fileExistsAtPath:zipFile]) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"No file found at path %@", @"UnzipKit", _resources, @"Detailed error string"),
                                    zipFile];
                UZKLogError("UZKErrorCodeArchiveNotFound: %{public}@", detail);
                [self assignError:error code:UZKErrorCodeArchiveNotFound
                           detail:detail];
                return NO;
            }
            
            UZKLogDebug("Opening file for read...");
            self.unzFile = unzOpen(self.filename.UTF8String);
            if (self.unzFile == NULL) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error opening zip file %@", @"UnzipKit", _resources, @"Detailed error string"),
                                    zipFile];
                UZKLogError("UZKErrorCodeBadZipFile: %{public}@", detail);
                [self assignError:error code:UZKErrorCodeBadZipFile
                           detail:detail];
                return NO;
            }
            
            UZKLogDebug("Seeking to first file...");
            int err = unzGoToFirstFile(self.unzFile);
            if (err != UNZ_OK) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error going to first file in archive (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                                    err];
                UZKLogError("UZKErrorCodeFileNavigationError: %{public}@", detail);
                [self assignError:error code:UZKErrorCodeFileNavigationError
                           detail:detail];
                return NO;
            }
            
            NSMutableDictionary *dic = [NSMutableDictionary dictionary];
            
            UZKLogInfo("Reading file info to cache file positions");
            
            do {
                @autoreleasepool {
                    UZKLogDebug("Reading file info for current file in zip");
                    UZKFileInfo *info = [self currentFileInZipInfo:error];
                    
                    if (!info) {
                        UZKLogDebug("No info returned. Exiting loop");
                        return NO;
                    }

                    UZKLogDebug("Got info for %{public}@", info.filename);

                    unz_file_pos pos;
                    int err = unzGetFilePos(self.unzFile, &pos);
                    if (err == UNZ_OK && info.filename) {
                        NSValue *dictValue = [NSValue valueWithBytes:&pos
                                                            objCType:@encode(unz_file_pos)];
                        dic[info.filename.decomposedStringWithCanonicalMapping] = dictValue;
                    }
                }
            } while (unzGoToNextFile (self.unzFile) != UNZ_END_OF_LIST_OF_FILE);
            
            self.archiveContents = [dic copy];
            break;
        }
        case UZKFileModeCreate:
        case UZKFileModeAppend:
            if (![fm fileExistsAtPath:zipFile]) {
                NSError *createFileError = nil;
                
                UZKLogDebug("Creating empty file, since it doesn't exist yet");
                if (![[NSData data] writeToFile:zipFile options:NSDataWritingAtomic error:&createFileError]) {
                    NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Failed to create new file for archive: %@", @"UnzipKit", _resources, @"Detailed error string"),
                                        createFileError.localizedDescription];
                    UZKLogError("UZKErrorCodeFileOpenForWrite: %{public}@", detail);
                    return [self assignError:error code:UZKErrorCodeFileOpenForWrite
                                      detail:detail
                                   underlyer:createFileError];
                }
                
                UZKLogDebug("Storing bookmark for newly created file");
                NSError *bookmarkError = nil;
                if (![self storeFileBookmark:[NSURL fileURLWithPath:zipFile]
                                       error:&bookmarkError])
                {
                    NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error creating bookmark to new archive file: %@", @"UnzipKit", _resources, @"Detailed error string"),
                                        bookmarkError.localizedDescription];
                    UZKLogError("UZKErrorCodeFileOpenForWrite: %{public}@", detail);
                    return [self assignError:error code:UZKErrorCodeFileOpenForWrite
                                      detail:detail
                                   underlyer:bookmarkError];
                }
            }
            
            int appendStatus = mode == UZKFileModeCreate ? APPEND_STATUS_CREATE : APPEND_STATUS_ADDINZIP;
            
            UZKLogDebug("Opening archive for write");
            self.zipFile = zipOpen(self.filename.UTF8String, appendStatus);
            if (self.zipFile == NULL) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error opening zip file for write: %@", @"UnzipKit", _resources, @"Detailed error string"),
                                    zipFile];
                UZKLogError("UZKErrorCodeArchiveNotFound: %{public}@", detail);
                [self assignError:error code:UZKErrorCodeArchiveNotFound
                           detail:detail];
                return NO;
            }
            break;
            
        case UZKFileModeUnassigned:
            NSAssert(NO, @"Cannot call -openFile:inMode:withPassword:error: with a mode of UZKFileModeUnassigned (%lu)", (unsigned long)mode);
            break;
    }
    
    return YES;
}

- (BOOL)closeFile:(NSError * __autoreleasing*)error
           inMode:(UZKFileMode)mode
{
    UZKCreateActivity("Closing File");
    
    if (mode != self.mode) {
        UZKLogInfo("Closing archive for mode %lu, but archive is currently in mode %lu", (unsigned long)mode, (unsigned long)self.mode);
        return NO;
    }
    
    if (--self.openCount > 0) {
        UZKLogDebug("Not closing file, as there have been more calls to open it than to close it");
        return YES;
    }
    
    int err;
    const char *cmt;
    const char *logverb;

    BOOL closeSucceeded = YES;
    
    switch (self.mode) {
        case UZKFileModeUnzip:
            if (!self.unzFile) {
                UZKLogDebug("self.unzFile is nil. File already closed?");
                break;
            }
            UZKLogDebug("Closing file in read mode...");
            err = unzClose(self.unzFile);
            if (err != UNZ_OK) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error closing file in archive after read (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                                    err];
                UZKLogError("UZKErrorCodeZLibError: %{public}@", detail);
                [self assignError:error code:UZKErrorCodeZLibError
                           detail:detail];
                closeSucceeded = NO;
            }
            break;

        case UZKFileModeCreate:
        case UZKFileModeAppend:
            logverb = self.mode == UZKFileModeCreate ? "create" : "append";
            
            if (!self.zipFile) {
                UZKLogDebug("self.zipFile is nil. File already closed?");
                break;
            }
            cmt = self.comment.UTF8String;
            UZKLogDebug("Closing file in %{public}s mode with comment %{public}s...", logverb, cmt);
            err = zipClose(self.zipFile, cmt);
            if (err != ZIP_OK) {
                NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error closing file in archive in write mode %lu (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                                    self.mode, err];
                UZKLogError("UZKErrorCodeZLibError: %{public}@", detail);
                [self assignError:error code:UZKErrorCodeZLibError
                           detail:detail];
                closeSucceeded = NO;
            }
            break;
            
        case UZKFileModeUnassigned:
            NSAssert(NO, @"Unbalanced call to -closeFile:, openCount == %ld", (long)self.openCount);
            break;
    }
    
    if (self.openCount == 0) {
        self.mode = UZKFileModeUnassigned;
    }
    
    return closeSucceeded;
}



#pragma mark - Zip File Navigation


- (UZKFileInfo *)currentFileInZipInfo:(NSError * __autoreleasing*)error {
    UZKCreateActivity("currentFileInZipInfo");
    
    char filename_inzip[FILE_IN_ZIP_MAX_NAME_LENGTH];
    unz_file_info64 file_info;
    
    UZKLogDebug("Getting file info...");
    int err = unzGetCurrentFileInfo64(self.unzFile, &file_info, filename_inzip, sizeof(filename_inzip), NULL, 0, NULL, 0);
    if (err != UNZ_OK) {
        NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error getting current file info (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                            err];
        UZKLogError("UZKErrorCodeArchiveNotFound: %{public}@", detail);
        [self assignError:error code:UZKErrorCodeArchiveNotFound
                   detail:detail];
        return nil;
    }
    
    NSString *filename = [UZKArchive figureOutCString:filename_inzip];
    return [UZKFileInfo fileInfo:&file_info filename:filename];
}

- (BOOL)locateFileInZip:(NSString *)fileNameInZip error:(NSError * __autoreleasing*)error {
    UZKCreateActivity("locateFileInZip");
    
    UZKLogDebug("Looking up file position");
    NSValue *filePosValue = self.archiveContents[fileNameInZip.decomposedStringWithCanonicalMapping];
    
    if (!filePosValue) {
        NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"No file position found for '%@'", @"UnzipKit", _resources, @"Detailed error string"),
                            fileNameInZip];
        UZKLogError("UZKErrorCodeFileNotFoundInArchive: %{public}@", detail);
        return [self assignError:error code:UZKErrorCodeFileNotFoundInArchive
                          detail:detail];
    }
    
    unz_file_pos pos;
    [filePosValue getValue:&pos];
    
    UZKLogDebug("Going to file position");
    int err = unzGoToFilePos(self.unzFile, &pos);
    
    if (err == UNZ_END_OF_LIST_OF_FILE) {
        NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"File '%@' not found in archive", @"UnzipKit", _resources, @"Detailed error string"),
                            fileNameInZip];
        UZKLogError("UZKErrorCodeFileNotFoundInArchive: %{public}@", detail);
        return [self assignError:error code:UZKErrorCodeFileNotFoundInArchive
                          detail:detail];
    }

    if (err != UNZ_OK) {
        NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error seeking to file position (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                            err];
        UZKLogError("%{public}@", detail);
        return [self assignError:error code:err
                          detail:detail];
    }
    
    return YES;
}



#pragma mark - Zip File Operations


- (BOOL)openFile:(NSError * __autoreleasing*)error
{
    UZKCreateActivity("openFile");
    
    char filename_inzip[FILE_IN_ZIP_MAX_NAME_LENGTH];
    unz_file_info64 file_info;
    
    UZKLogDebug("Getting file info");
    int err = unzGetCurrentFileInfo64(self.unzFile, &file_info, filename_inzip, sizeof(filename_inzip), NULL, 0, NULL, 0);
    if (err != UNZ_OK) {
        NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error getting current file info for archive (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                            err];
        UZKLogError("UZKErrorCodeInternalError: %{public}@", detail);
        return [self assignError:error code:UZKErrorCodeInternalError
                          detail:detail];
    }
    
    const char *passwordStr = NULL;
    
    if (self.password) {
        UZKLogDebug("Encoding password in NSISOLatin1StringEncoding");
        passwordStr = [self.password cStringUsingEncoding:NSISOLatin1StringEncoding];
    }
    
    if ([self isDeflate64:file_info]) {
        NSString *detail = NSLocalizedStringFromTableInBundle(@"Cannot open archive, since it was compressed using the Deflate64 algorithm (method ID 9)", @"UnzipKit", _resources, @"Error message");
        UZKLogError("UZKErrorCodeDeflate64: %{public}@", detail);
        return [self assignError:error code:UZKErrorCodeDeflate64
                          detail:detail];
    }
    
    UZKLogDebug("Opening file...");
    err = unzOpenCurrentFilePassword(self.unzFile, passwordStr);
    if (err != UNZ_OK) {
        NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error opening archive (%d)", @"UnzipKit", _resources, @"Detailed error string"),
                            err];
        UZKLogError("%{public}@", detail);
        return [self assignError:error code:err
                          detail:detail];
    }
    
    return YES;
}


- (NSData *)readFile:(NSString *)filePath length:(unsigned long long int)length error:(NSError * __autoreleasing*)error {
    UZKCreateActivity("readFile");
    
    UZKLogDebug("Opening file");
    if (![self openFile:error]) {
        return nil;
    }
    
    UZKLogDebug("Reading data...");
    NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)length];
    int bytes = unzReadCurrentFile(self.unzFile, data.mutableBytes, (unsigned)length);
    
    if (bytes < 0) {
        NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error reading data from '%@' in archive", @"UnzipKit", _resources, @"Detailed error string"),
                            filePath];
        UZKLogError("Error code %d: %{public}@", bytes, detail);
        [self assignError:error code:bytes
                   detail:detail];
        return nil;
    }
    
    UZKLogDebug("%{iec-bytes}d (%d bytes) read", bytes, bytes);
    data.length = bytes;
    return data;
}

- (NSString *)readGlobalComment {
    UZKCreateActivity("readGlobalComment");
    
    UZKLogDebug("Checking archive exists");

    NSError *checkExistsError = nil;
    if (![self.fileURL checkResourceIsReachableAndReturnError:&checkExistsError]) {
        UZKLogDebug("Archive not found");
        return nil;
    }
    
    __weak UZKArchive *welf = self;
    __block NSString *comment = nil;
    NSError *error = nil;
    
    BOOL success = [self performActionWithArchiveOpen:^(NSError * __autoreleasing*innerError) {
        UZKCreateActivity("Perform Action");
        
        UZKLogDebug("Getting global info...");
        unz_global_info global_info;
        int err = unzGetGlobalInfo(welf.unzFile, &global_info);
        if (err != UNZ_OK) {
            NSString *detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Error getting global info of archive during comment read: %d", @"UnzipKit", _resources, @"Detailed error string"),
                                err];
            UZKLogError("UZKErrorCodeReadComment: %{public}@", detail);
            UZKLogDebug("Closing archive...");
            unzClose(welf.unzFile);
            
            [welf assignError:innerError code:UZKErrorCodeReadComment detail:detail];
            return;
        }
        
        char *global_comment = NULL;
        
        if (global_info.size_comment > 0)
        {
            UZKLogDebug("Allocating global comment...");
            global_comment = (char*)malloc(global_info.size_comment+1);
            if ((global_comment == NULL) && (global_info.size_comment != 0)) {
                NSString *detail = NSLocalizedStringFromTableInBundle(@"Error allocating the global comment during comment read", @"UnzipKit", _resources, @"Detailed error string");
                UZKLogError("UZKErrorCodeReadComment: %{public}@", detail);
                UZKLogDebug("Closing archive...");
                unzClose(welf.unzFile);
                
                [welf assignError:innerError code:UZKErrorCodeReadComment detail:detail];
                return;
            }
            
            UZKLogDebug("Reading global comment...");
            if ((unsigned int)unzGetGlobalComment(welf.unzFile, global_comment, global_info.size_comment + 1) != global_info.size_comment) {
                NSString *detail = NSLocalizedStringFromTableInBundle(@"Error reading the comment (readGlobalComment)", @"UnzipKit", _resources, @"Detailed error string");
                UZKLogError("UZKErrorCodeReadComment: %{public}@", detail);
                UZKLogDebug("Closing archive and freeing global_comment...");
                unzClose(welf.unzFile);
                free(global_comment);
                
                [welf assignError:innerError code:UZKErrorCodeReadComment detail:@"Error reading global comment (unzGetGlobalComment)"];
                return;
            }
            
            UZKLogDebug("Turning C string into NSString");
            comment = [UZKArchive figureOutCString:global_comment];
            free(global_comment);
        }
    } inMode:UZKFileModeUnzip error:&error];
    
    self.commentRetrieved = YES;

    if (!success) {
        return nil;
    }
    
    return comment;
}



#pragma mark - Misc. Private Methods


- (BOOL)storeFileBookmark:(NSURL *)fileURL error:(NSError * __autoreleasing*)error
{
    UZKCreateActivity("storeFileBookmark");

    UZKLogDebug("Creating bookmark");
    NSError *bookmarkError = nil;
    self.fileBookmark = [fileURL bookmarkDataWithOptions:(NSURLBookmarkCreationOptions)0
                          includingResourceValuesForKeys:@[]
                                           relativeToURL:nil
                                                   error:&bookmarkError];

    if (bookmarkError) {
        UZKLogFault("Error creating bookmark for URL %{public}@: %{public}@", fileURL, bookmarkError);
    }

    if (error) {
        *error = bookmarkError ? bookmarkError : nil;
    }
    
    return bookmarkError == nil;
}

+ (NSString *)figureOutCString:(const char *)filenameBytes
{
    UZKCreateActivity("figureOutCString");
    
    UZKLogDebug("Trying out UTF-8");
    NSString *stringValue = [NSString stringWithUTF8String:filenameBytes];
    
    if (!stringValue) {
        UZKLogDebug("Trying out NSWindowsCP1252StringEncoding");
        stringValue = [NSString stringWithCString:filenameBytes
                                         encoding:NSWindowsCP1252StringEncoding];
    }
    
    if (!stringValue) {
        UZKLogDebug("Trying out defaultCStringEncoding");
        stringValue = [NSString stringWithCString:filenameBytes
                                         encoding:[NSString defaultCStringEncoding]];
    }
    
    UZKLogDebug("Returning decomposedStringWithCanonicalMapping");
    return [stringValue decomposedStringWithCanonicalMapping];
}

+ (NSString *)errorNameForErrorCode:(NSInteger)errorCode
{
    NSString *errorName;
    
    switch (errorCode) {
        case UZKErrorCodeZLibError:
            errorName = NSLocalizedStringFromTableInBundle(@"Error reading/writing file", @"UnzipKit", _resources, @"UZKErrorCodeZLibError");
            break;
            
        case UZKErrorCodeParameterError:
            errorName = NSLocalizedStringFromTableInBundle(@"Parameter error", @"UnzipKit", _resources, @"UZKErrorCodeParameterError");
            break;
            
        case UZKErrorCodeBadZipFile:
            errorName = NSLocalizedStringFromTableInBundle(@"Bad zip file", @"UnzipKit", _resources, @"UZKErrorCodeBadZipFile");
            break;
            
        case UZKErrorCodeInternalError:
            errorName = NSLocalizedStringFromTableInBundle(@"Internal error", @"UnzipKit", _resources, @"UZKErrorCodeInternalError");
            break;
            
        case UZKErrorCodeCRCError:
            errorName = NSLocalizedStringFromTableInBundle(@"The data got corrupted during decompression", @"UnzipKit", _resources, @"UZKErrorCodeCRCError");
            break;
            
        case UZKErrorCodeArchiveNotFound:
            errorName = NSLocalizedStringFromTableInBundle(@"Can't open archive", @"UnzipKit", _resources, @"UZKErrorCodeArchiveNotFound");
            break;
            
        case UZKErrorCodeFileNavigationError:
            errorName = NSLocalizedStringFromTableInBundle(@"Error navigating through the archive", @"UnzipKit", _resources, @"UZKErrorCodeFileNavigationError");
            break;
            
        case UZKErrorCodeFileNotFoundInArchive:
            errorName = NSLocalizedStringFromTableInBundle(@"Can't find a file in the archive", @"UnzipKit", _resources, @"UZKErrorCodeFileNotFoundInArchive");
            break;
            
        case UZKErrorCodeOutputError:
            errorName = NSLocalizedStringFromTableInBundle(@"Error extracting files from the archive", @"UnzipKit", _resources, @"UZKErrorCodeOutputError");
            break;
            
        case UZKErrorCodeOutputErrorPathIsAFile:
            errorName = NSLocalizedStringFromTableInBundle(@"Attempted to extract the archive to a path that is a file, not a directory", @"UnzipKit", _resources, @"UZKErrorCodeOutputErrorPathIsAFile");
            break;
            
        case UZKErrorCodeInvalidPassword:
            errorName = NSLocalizedStringFromTableInBundle(@"Incorrect password provided", @"UnzipKit", _resources, @"UZKErrorCodeInvalidPassword");
            break;
            
        case UZKErrorCodeFileRead:
            errorName = NSLocalizedStringFromTableInBundle(@"Error reading a file in the archive", @"UnzipKit", _resources, @"UZKErrorCodeFileRead");
            break;
            
        case UZKErrorCodeFileOpenForWrite:
            errorName = NSLocalizedStringFromTableInBundle(@"Error opening a file in the archive to write it", @"UnzipKit", _resources, @"UZKErrorCodeFileOpenForWrite");
            break;
            
        case UZKErrorCodeFileWrite:
            errorName = NSLocalizedStringFromTableInBundle(@"Error writing a file in the archive", @"UnzipKit", _resources, @"UZKErrorCodeFileWrite");
            break;
            
        case UZKErrorCodeFileCloseWriting:
            errorName = NSLocalizedStringFromTableInBundle(@"Error clonsing a file in the archive after writing it", @"UnzipKit", _resources, @"UZKErrorCodeFileCloseWriting");
            break;
            
        case UZKErrorCodeDeleteFile:
            errorName = NSLocalizedStringFromTableInBundle(@"Error deleting a file in the archive", @"UnzipKit", _resources, @"UZKErrorCodeDeleteFile");
            break;
            
        case UZKErrorCodeMixedModeAccess:
            errorName = NSLocalizedStringFromTableInBundle(@"Attempted to read before all writes have completed, or vise-versa", @"UnzipKit", _resources, @"UZKErrorCodeMixedModeAccess");
            break;
            
        case UZKErrorCodePreCRCMismatch:
            errorName = NSLocalizedStringFromTableInBundle(@"The CRC given up front doesn't match the calculated CRC", @"UnzipKit", _resources, @"UZKErrorCodePreCRCMismatch");
            break;
            
        case UZKErrorCodeDeflate64:
            errorName = NSLocalizedStringFromTableInBundle(@"The archive was compressed with the Deflate64 method, which isn't supported", @"UnzipKit", _resources, @"UZKErrorCodeDeflate64");
            break;
            
        default:
            errorName = [NSString localizedStringWithFormat:
                         NSLocalizedStringFromTableInBundle(@"Unknown error code: %ld", @"UnzipKit", _resources, @"UnknownErrorCode"), errorCode];
            break;
    }
    
    return errorName;
}

+ (zip_fileinfo)zipFileInfoForDate:(NSDate *)fileDate
                  posixPermissions:(short)permissions
{
    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    
    // Use "now" if no date given
    if (!fileDate) {
        fileDate = [NSDate date];
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wassign-enum"

    NSDateComponents *date = [calendar components:(NSCalendarUnitSecond |
                                                   NSCalendarUnitMinute |
                                                   NSCalendarUnitHour |
                                                   NSCalendarUnitDay |
                                                   NSCalendarUnitMonth |
                                                   NSCalendarUnitYear)
                                         fromDate:fileDate];

#pragma clang diagnostic pop

    zip_fileinfo zi;
    zi.tmz_date.tm_sec = (uInt)date.second;
    zi.tmz_date.tm_min = (uInt)date.minute;
    zi.tmz_date.tm_hour = (uInt)date.hour;
    zi.tmz_date.tm_mday = (uInt)date.day;
    zi.tmz_date.tm_mon = (uInt)date.month - 1; // 0-indexed
    zi.tmz_date.tm_year = (uInt)date.year;
    zi.internal_fa = 0;
    zi.external_fa = 0;
    zi.dosDate = 0;
    
    if (permissions > 0) {
        unsigned long permissionsMask = (permissions & 0777) << 16;
        zi.external_fa |= permissionsMask;
    }

    return zi;
}

/**
 *  @return Always returns NO
 */
- (BOOL)assignError:(NSError * __autoreleasing*)error
               code:(NSInteger)errorCode
             detail:(NSString *)errorDetail
{
    return [self assignError:error
                        code:errorCode
                      detail:errorDetail
                   underlyer:nil];
}

/**
 *  @return Always returns NO
 */
- (BOOL)assignError:(NSError * __autoreleasing*)error
               code:(NSInteger)errorCode
             detail:(NSString *)errorDetail
          underlyer:(NSError *)underlyingError
{
    if (error) {
        NSString *errorName = [UZKArchive errorNameForErrorCode:errorCode];
        
        // If this error is being re-wrapped, include the original error
        if (!underlyingError && *error && [*error isKindOfClass:[NSError class]]) {
            underlyingError = *error;
        }
        
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:
                                         @{NSLocalizedFailureReasonErrorKey: errorName,
                                           NSLocalizedDescriptionKey: errorName,
                                           NSLocalizedRecoverySuggestionErrorKey: errorDetail}];
        
        if (self.fileURL) {
            userInfo[NSURLErrorKey] = self.fileURL;
        }
        
        if (underlyingError) {
            userInfo[NSUnderlyingErrorKey] = underlyingError;
        }
        
        *error = [NSError errorWithDomain:UZKErrorDomain
                                     code:errorCode
                                 userInfo:[NSDictionary dictionaryWithDictionary:userInfo]];
    }
    
    return NO;
}

- (BOOL)isDeflate64:(unz_file_info64)file_info
{
    UZKCreateActivity("isDeflate64");
    
    UZKLogDebug("Compression method: %lu", file_info.compression_method);
    return file_info.compression_method == 9;
}

- (NSProgress *)beginProgressOperation:(unsigned long long)totalUnitCount
{
    UZKCreateActivity("-beginProgressOperation:");
    
    NSProgress *progress;
    progress = self.progress;
    self.progress = nil;
    
    if (!progress) {
        progress = [[NSProgress alloc] initWithParent:[NSProgress currentProgress]
                                             userInfo:nil];
    }
    
    if (totalUnitCount > 0) {
        progress.totalUnitCount = totalUnitCount;
    }
    
    progress.cancellable = YES;
    progress.pausable = NO;
    
    return progress;
}


@end


