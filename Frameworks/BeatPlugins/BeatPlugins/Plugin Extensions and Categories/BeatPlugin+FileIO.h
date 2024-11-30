//
//  BeatPlugin+FileIO.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 27.11.2024.
//

#import <BeatPlugins/BeatPlugins.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol BeatPluginFileIOExports <JSExport>


#pragma mark - Read app assets

/// Read a PDF file into string variable
- (NSString*)pdfToString:(NSString*)path;
/// Plugin bundle asset as string
- (NSString*)assetAsString:(NSString*)filename;
/// Asset from inside the app container
- (NSString*)appAssetAsString:(NSString*)filename;


#pragma mark - Read and write any files

/// Read any (text) file into string variable
- (NSString*)fileToString:(NSString*)path;
/// Write a string to file in given path. You can't access files unless they are in the container or user explicitly selected them using a save dialog.
JSExportAs(writeToFile, - (bool)writeToFile:(NSString*)path content:(NSString*)content);

#if TARGET_OS_OSX
/// Displays an open dialog
JSExportAs(openFile, - (void)openFile:(NSArray*)formats callBack:(JSValue*)callback);
/// Displays an open dialog with the option to select multiple files
JSExportAs(openFiles, - (void)openFiles:(NSArray*)formats callBack:(JSValue*)callback);
/// Displays a save dialog
JSExportAs(saveFile, - (void)saveFile:(NSString*)format callback:(JSValue*)callback);
#endif

@end

@interface BeatPlugin (FileIO) <BeatPluginFileIOExports>

@end

