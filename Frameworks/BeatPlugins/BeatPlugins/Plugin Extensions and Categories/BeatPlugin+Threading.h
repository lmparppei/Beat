//
//  BeatPlugin+Threading.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 3.12.2025.
//

#import <BeatPlugins/BeatPlugins.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol BeatPluginThreadingExports <JSExport>

/// Dispatch a block into a background thread
- (void)async:(JSValue* _Nullable)callback;
/// Dispatch a block into the main thread
- (void)sync:(JSValue* _Nullable)callback;
/// Alias for async
- (void)dispatch:(JSValue* _Nullable)callback;
/// Alias for sync
- (void)dispatch_sync:(JSValue* _Nullable)callback;
/// Returns `true` if the current operation happens in main thread
- (bool)isMainThread;

@end

NS_ASSUME_NONNULL_BEGIN

@interface BeatPlugin (Threading) <BeatPluginThreadingExports>

/// Dispatch a block into a background thread
- (void)async:(JSValue* _Nullable)callback;

/// Dispatch a block into the main thread
- (void)sync:(JSValue* _Nullable)callback;

/// Alias for async
- (void)dispatch:(JSValue* _Nullable)callback;

/// Alias for sync
- (void)dispatch_sync:(JSValue* _Nullable)callback;

/// Returns `true` if the current operation happens in main thread
- (bool)isMainThread;

@end

NS_ASSUME_NONNULL_END
