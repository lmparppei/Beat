//
//  BeatCardViewController.m
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 31.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatCore/BeatCore.h>
#import <BeatParsing/BeatParsing.h>
#import "BeatCardViewController.h"

@interface BeatCardViewController ()
@property (nonatomic) NSArray *outline;
@property (nonatomic) NSArray *sections;
@property (nonatomic) NSMutableArray *sectionNames;
@end

@implementation BeatCardViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - Collection view

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
	return self.sections.count;
}

- (nonnull __kindof UICollectionViewCell *)collectionView:(nonnull UICollectionView *)collectionView cellForItemAtIndexPath:(nonnull NSIndexPath *)indexPath {
	UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"Card" forIndexPath:indexPath];
	
	cell.contentView.layer.cornerRadius = 2.0;
	cell.contentView.layer.borderWidth = 1.0f;
	cell.contentView.layer.borderColor = [UIColor clearColor].CGColor;
	cell.contentView.layer.masksToBounds = YES;
	cell.contentView.layer.backgroundColor = [BeatColors color:@"#f0f0f0"].CGColor;
	
	cell.layer.shadowColor = [UIColor blackColor].CGColor;
	cell.layer.shadowOffset = CGSizeMake(0, 2.0f);
	cell.layer.shadowRadius = 2.0f;
	cell.layer.shadowOpacity = 0.5f;
	cell.layer.masksToBounds = NO;
	cell.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:cell.bounds cornerRadius:cell.contentView.layer.cornerRadius].CGPath;
	
	NSArray *section = self.sections[ [indexPath indexAtPosition:0] ];
	OutlineScene *scene = section[ [indexPath indexAtPosition:1] ];
	
	//UIImageView *image = (UIImageView *)[cell viewWithTag:1];
	//UILabel *sceneNumber = (UILabel *)[cell viewWithTag:1];
	UILabel *title = (UILabel *)[cell viewWithTag:2];
	
	title.text = scene.stringForDisplay;

	return cell;
}

- (NSInteger)collectionView:(nonnull UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	NSLog(@"#### asking for section %lu", section);
	return [(NSArray*)self.sections[section] count];
}

-(UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
	UICollectionReusableView *view = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"Section Header" forIndexPath:indexPath];
	
	NSInteger index = [indexPath indexAtPosition:0];
	NSLog(@"sect names %@", _sectionNames);
	if (index < _sectionNames.count) {
		UILabel *title = (UILabel*)[view viewWithTag:1];
		title.text = (NSString*)_sectionNames[index];
	}
	
	return view;
}

- (NSArray*)sections {
	if (_sections) return _sections;
	
	_sectionNames = [NSMutableArray array];
	NSMutableArray *sections = [NSMutableArray array];
	NSMutableArray *currentSection = [NSMutableArray array];
		
	for (OutlineScene *scene in self.outline) {
		if (scene.type == section && scene.sectionDepth <= 1) {
			if (currentSection.count != 0) {
				// Check if the first section had no name
				if (_sectionNames.count == 0) [_sectionNames addObject:@""];
				
				// Close the section and begin a new one
				[_sectionNames addObject:scene.stringForDisplay];
				[sections addObject:[NSArray arrayWithArray:currentSection]];
				currentSection = [NSMutableArray array];
			} else {
				[_sectionNames addObject:scene.stringForDisplay];
			}
			
			continue;
		}
		
		if (scene.type != synopse) [currentSection addObject:scene];
	}
	[sections addObject:currentSection];
		
	_sections = sections;
	return sections;
}

/*
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(nonnull id<UIViewControllerTransitionCoordinator>)coordinator {
	<#code#>
}
 */

- (NSArray*)outline {
	if (!_outline) _outline = self.editorDelegate.parser.outline.copy;
	return _outline;
}

-(BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

@end
