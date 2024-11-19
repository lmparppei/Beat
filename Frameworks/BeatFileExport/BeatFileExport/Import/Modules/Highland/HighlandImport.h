//
//  HighlandImport.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.11.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatFileExport/BeatImportModule.h>

NS_ASSUME_NONNULL_BEGIN

@interface HighlandImport : NSObject <BeatFileImportModule>
@property (nonatomic) NSString *script;
@property (nonatomic) NSString *fountain;
- (id)initWithURL:(NSURL*)url;
@end

NS_ASSUME_NONNULL_END
