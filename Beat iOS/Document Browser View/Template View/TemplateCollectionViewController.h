//
//  TemplateCollectionViewController.h
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 2.7.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TemplateCollectionViewController : UIViewController <UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>
@property (copy) void (^ _Nullable importHandler)(NSURL * _Nullable, UIDocumentBrowserImportMode);
@end

NS_ASSUME_NONNULL_END
