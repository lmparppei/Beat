//
//  BeatPlugin+Import_Export.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 3.12.2025.
//

#import "BeatPlugin+Import_Export.h"

@implementation BeatPlugin (Import_Export)

#pragma mark - Import/Export callbacks

/** Creates an import handler.
 @param extensions Array of allowed file extensions
 @param callback Callback for handling the actual import. The callback block receives the file contents as string.
*/
- (void)importHandler:(NSArray*)extensions callback:(JSValue*)callback
{
    self.importedExtensions = extensions;
    self.importCallback = callback;
}
/// Creates an export handler.
- (void)exportHandler:(NSArray*)extensions callback:(JSValue*)callback
{
    self.exportedExtensions = extensions;
    self.exportCallback = callback;
}


@end
