#import <Foundation/NSObject.h>

// NSUnitConverter converts between a unit's own value and its dimension's base unit.
@interface NSUnitConverter : NSObject

- (double)baseUnitValueFromValue:(double)value;
- (double)valueFromBaseUnitValue:(double)baseUnitValue;

@end
