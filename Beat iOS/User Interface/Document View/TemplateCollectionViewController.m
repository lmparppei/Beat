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

@interface TemplateCollectionViewController ()
@property (nonatomic) NSArray *templates;
@property (nonatomic) bool didPickTemplate;
@end


@implementation TemplateCollectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.templates.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"Cell" forIndexPath:indexPath];
    
    //UIImageView *image = (UIImageView *)[cell viewWithTag:1];
    UILabel *title = (UILabel *)[cell viewWithTag:2];

	NSString* fileName = _templates[[indexPath indexAtPosition:1]];
    fileName = fileName.lastPathComponent.stringByDeletingPathExtension;
	
    title.text = fileName;
    
    return cell;
}


- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger index = [indexPath indexAtPosition:1];
    NSURL *selectedTemplate = [self templates][index];

    self.importHandler(selectedTemplate, UIDocumentBrowserImportModeCopy);

    _didPickTemplate = YES;
    [self dismissViewControllerAnimated:YES completion:^ {
        // Do nothing here
    }];

    return YES;
}

- (NSArray*)templates {
    if (!_templates) _templates = [NSBundle.mainBundle URLsForResourcesWithExtension:@"fountain" subdirectory:nil];
    return _templates;
}

- (void)viewWillDisappear:(BOOL)animated {
    // If we didn't pick a template, the import handler still has to be called
    if (!_didPickTemplate) self.importHandler(nil, UIDocumentBrowserImportModeNone);
}

@end
