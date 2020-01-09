//
//  EditDetector.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 16/11/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

@interface EditDetector : NSObject

- (NSArray*)detectEditsFrom:(NSString*)current to:(NSString*)edited;

@end
