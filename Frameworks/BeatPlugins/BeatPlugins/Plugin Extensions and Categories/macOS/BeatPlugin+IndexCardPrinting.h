//
//  BeatPlugin+IndexCardPrinting.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 19.5.2026.
//

#import <BeatPlugins/BeatPlugins.h>
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BeatPluginIndexCardPrintingExports <JSExport>
- (void)printIndexCards;
@end

@interface BeatPlugin (IndexCardPrinting) <BeatPluginIndexCardPrintingExports>
- (void)printIndexCards;
@end

NS_ASSUME_NONNULL_END
