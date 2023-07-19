//
//  NSString+Levenshtein.m
//

#import "NSString+Levenshtein.h"

@implementation NSString (Levenshtein)

-(float)compareWithString:(NSString *)comparisonString
{
    // default match: 0
    // default cost: 1

	NSString *originalString = self;
	
	// Normalize strings
	[originalString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
	[comparisonString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

	originalString = originalString.lowercaseString;
	comparisonString = comparisonString.lowercaseString;

	// Step 1 (Steps follow description at http://www.merriampark.com/ld.htm)
	NSInteger k, i, j, cost, * d, distance;

	NSInteger n = originalString.length;
	NSInteger m = comparisonString.length;

	if( n++ != 0 && m++ != 0 ) {

		d = malloc( sizeof(NSInteger) * m * n );

		// Step 2
		for( k = 0; k < n; k++)
			d[k] = k;

		for( k = 0; k < m; k++)
			d[ k * n ] = k;

		// Step 3 and 4
		for( i = 1; i < n; i++ )
			for( j = 1; j < m; j++ ) {

				// Step 5
				if( [originalString characterAtIndex: i-1] ==
				   [comparisonString characterAtIndex: j-1] )
					cost = 0;
				else
					cost = 1;

				// Step 6
				d[ j * n + i ] = [self smallestOf: d [ (j - 1) * n + i ] + 1
				andOf: d[ j * n + i - 1 ] +  1
				andOf: d[ (j - 1) * n + i - 1 ] + cost ];

				// This conditional adds Damerau transposition to Levenshtein distance
				if( i>1 && j>1 && [originalString characterAtIndex: i-1] ==
					[comparisonString characterAtIndex: j-2] &&
					[originalString characterAtIndex: i-2] ==
					[comparisonString characterAtIndex: j-1] )
				{
					d[ j * n + i] = [self smallestOf: d[ j * n + i ]
					andOf: d[ (j - 2) * n + i - 2 ] + cost ];
				}
			}

		distance = d[ n * m - 1 ];

		free( d );

		return distance;
	}
	return 0.0;
}

// Return the minimum of a, b and c - used by compareString:withString:
-(NSInteger)smallestOf:(NSInteger)a andOf:(NSInteger)b andOf:(NSInteger)c
{
	NSInteger min = a;
	if ( b < min )
		min = b;

	if( c < min )
		min = c;

	return min;
}

-(NSInteger)smallestOf:(NSInteger)a andOf:(NSInteger)b
{
	NSInteger min=a;
	if (b < min)
		min=b;

	return min;
}

@end
