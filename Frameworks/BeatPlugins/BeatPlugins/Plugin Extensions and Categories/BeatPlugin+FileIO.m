//
//  BeatPlugin+FileIO.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 27.11.2024.
//

#import "BeatPlugin+FileIO.h"
#import "BeatPlugin+Modals.h"

@implementation BeatPlugin (FileIO)

#pragma mark - File i/o

#pragma mark macOS only
#if TARGET_OS_OSX
    /** Presents a save dialog.
     @param format Allowed file extension
     @param callback If the user didn't click on cancel, callback receives an array of paths (containing only a single path). When clicking cancel, the return parameter is nil.
     */
    - (void)saveFile:(NSString*)format callback:(JSValue*)callback
    {
        NSSavePanel *savePanel = [NSSavePanel savePanel];
        savePanel.allowedFileTypes = @[format];
        [savePanel beginSheetModalForWindow:self.delegate.documentWindow completionHandler:^(NSModalResponse returnCode) {
            if (returnCode == NSModalResponseOK) {
                [savePanel close];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 100), dispatch_get_main_queue(), ^(void){
                    [callback callWithArguments:@[savePanel.URL.path]];
                });
            } else {
                
                [self runCallback:callback withArguments:nil];
            }
        }];
    }

    /** Presents an open dialog box.
     @param formats Array of file extensions allowed to be opened
     @param callback Callback is run after the open dialog is closed. If the user selected a file, the callback receives an array of paths, though it contains only a single path.
    */
    - (void)openFile:(NSArray*)formats callBack:(JSValue*)callback
    {
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        openPanel.allowedFileTypes = formats;
        
        NSModalResponse result = [openPanel runModal];
        if (result == NSModalResponseOK) {
            [self runCallback:callback withArguments:@[openPanel.URL.path]];
        } else {
            [self runCallback:callback withArguments:nil];
        }
    }

    /** Presents an open dialog box which allows selecting multiple files.
     @param formats Array of file extensions allowed to be opened
     @param callback Callback is run after the open dialog is closed. If the user selected a file, the callback receives an array of paths.
    */
    - (void)openFiles:(NSArray*)formats callBack:(JSValue*)callback
    {
        // Open MULTIPLE files
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        openPanel.allowedFileTypes = formats;
        openPanel.allowsMultipleSelection = YES;
        
        NSModalResponse result = [openPanel runModal];
        
        if (result == NSModalResponseOK) {
            NSMutableArray *paths = [NSMutableArray array];
            for (NSURL* url in openPanel.URLs) {
                [paths addObject:url.path];
            }
            [self runCallback:callback withArguments:@[paths]];
        } else {
            [self runCallback:callback withArguments:nil];
        }
    }
#endif

#pragma mark Generic writing and reading methods

/// Writes string content to the given path.
- (bool)writeToFile:(NSString*)path content:(NSString*)content
{
    NSError *error;
    [content writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        [self alert:@"Error Writing File" withText:[NSString stringWithFormat:@"%@", error]];
        return NO;
    } else {
        return YES;
    }
}


/// Returns the given path as a string (from anywhere in the system)
- (NSString*)fileToString:(NSString*)path
{
    NSError *error;
    NSString *result = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        [self alert:@"Error Opening File" withText:@"Error occurred while trying to open the file. Did you give Beat permission to acces it?"];
        return nil;
    } else {
        return result;
    }
}

/// Attempts to open  the given path in workspace (system)
- (void)openInWorkspace:(NSString*)path {
#if TARGET_OS_OSX
    [NSWorkspace.sharedWorkspace openFile:path];
#else
    NSURL *fileURL = [NSURL fileURLWithPath:path];

    UIDocumentInteractionController *documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    [documentInteractionController presentOptionsMenuFromRect:CGRectZero inView:self.delegate.textView animated:YES];
#endif
}


#pragma mark - Access plugin assets

/// Returns the given file in plugin container as string
- (NSString*)assetAsString:(NSString *)filename
{
    if ([self.plugin.files containsObject:filename]) {
        NSString *path = [[BeatPluginManager.sharedManager pathForPlugin:self.plugin.name] stringByAppendingPathComponent:filename];
        return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    } else {
#if TARGET_OS_OSX
        NSString* msg = [NSString stringWithFormat:@"Can't find bundled file '%@' – Are you sure the plugin is contained in a self-titled folder? For example: Plugin.beatPlugin/Plugin.beatPlugin", filename];
        [self log:msg];
        return @"";
#else
        NSLog(@"WARNING: asset as string is trying to find files from app bundle. Remove once done.");
        return [self appAssetAsString:filename];
#endif
    }
}

/// Returns the file in app bundle as a string
- (NSString*)appAssetAsString:(NSString *)filename
{
    NSString *path = [NSBundle.mainBundle pathForResource:filename.stringByDeletingPathExtension ofType:filename.pathExtension];
    
    if (path) {
        return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    } else {
        NSString* msg = [NSString stringWithFormat:@"Can't find '%@' in app bundle", filename];
        [self log:msg];
        return @"";
    }
}

/// Returns string rendition of a PDF
- (NSString*)pdfToString:(NSString*)path
{
    NSMutableString *result = [NSMutableString string];
    
    PDFDocument *doc = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
    if (!doc) return @"";
    
    for (int i = 0; i < doc.pageCount; i++) {
        PDFPage *page = [doc pageAtIndex:i];
        if (!page) continue;
        
        [result appendString:page.string];
    }
    
    return result;
}


@end
