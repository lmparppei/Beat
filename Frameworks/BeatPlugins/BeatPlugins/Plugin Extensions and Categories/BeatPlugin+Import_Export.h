//
//  BeatPlugin+Import_Export.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 3.12.2025.
//

#import <BeatPlugins/BeatPlugins.h>

@protocol BeatPluginImportExportExports <JSExport>

#pragma mark Import / export plugin handlers
JSExportAs(importHandler, - (void)importHandler:(NSArray*)extensions callback:(JSValue*)callback);
JSExportAs(exportHandler, - (void)exportHandler:(NSArray*)extensions callback:(JSValue*)callback);


@end

@interface BeatPlugin (Import_Export) <BeatPluginImportExportExports>

@end

