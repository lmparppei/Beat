//
//  BeatPlugin+Printing.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 27.11.2024.
//

#import <BeatPlugins/BeatPlugins.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol BeatPluginPrintingExports <JSExport>
JSExportAs(printHTML, - (void)printHTML:(NSString*)html settings:(NSDictionary*)settings callback:(JSValue*)callback);
- (NSDictionary*)printInfo;
@end

@interface BeatPlugin (Printing)

@end

