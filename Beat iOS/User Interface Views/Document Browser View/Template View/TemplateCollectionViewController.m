//
//  TemplateCollectionViewController.m
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 2.7.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

/*
 
 Most of this code is stolen from iOS version of LibreOffice.
 
 */

#import "TemplateCollectionViewController.h"
#import "Beat-Swift.h"

@interface TemplateCollectionViewController ()
@property (nonatomic) NSArray *templates;
@property (nonatomic) bool didPickTemplate;
@property (nonatomic, weak) IBOutlet UICollectionView* collectionView;
@end


@implementation TemplateCollectionViewController

- (void)viewDidLoad {
	self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
	
    [super viewDidLoad];
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
	BeatTemplateCell* cell = (BeatTemplateCell*)[collectionView cellForItemAtIndexPath:indexPath];
	
	NSURL* template = cell.url;
    self.importHandler(template, UIDocumentBrowserImportModeCopy);


    _didPickTemplate = YES;
	
    [self dismissViewControllerAnimated:YES completion:^ {
        // Do nothing here
    }];

    return YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    // If we didn't pick a template, the import handler still has to be called
    if (!_didPickTemplate) self.importHandler(nil, UIDocumentBrowserImportModeNone);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
	return CGSizeMake(collectionView.frame.size.width, 150.0);
}

@end
