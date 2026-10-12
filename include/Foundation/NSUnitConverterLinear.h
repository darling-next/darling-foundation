#import <Foundation/NSUnitConverter.h>

// NSUnitConverterLinear: a linear converter, baseUnitValue = value * coefficient + constant.
@interface NSUnitConverterLinear : NSUnitConverter
{
    double _coefficient;
    double _constant;
}

@property (readonly) double coefficient;
@property (readonly) double constant;

- (instancetype)initWithCoefficient:(double)coefficient;
- (instancetype)initWithCoefficient:(double)coefficient constant:(double)constant;

@end
