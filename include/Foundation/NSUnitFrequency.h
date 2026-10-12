#import <Foundation/NSDimension.h>
#import <Foundation/NSUnitConverter.h>

// NSUnitFrequency (macOS 10.12+): the NSDimension subclass for frequency.
// Its base unit is hertz, so +baseUnit returns [self hertz]; every unit carries a linear
// NSUnitConverterLinear relative to hertz (coefficient 1 for Hz, 1e3 for kHz, ...).
@interface NSUnitFrequency : NSDimension
{
    NSString *_symbol;
    NSUnitConverter *_converter;
}

@property (readonly, copy) NSString *symbol;
@property (readonly, strong) NSUnitConverter *converter;

+ (NSUnitFrequency *)hertz;
+ (NSUnitFrequency *)kilohertz;
+ (NSUnitFrequency *)megahertz;
+ (NSUnitFrequency *)gigahertz;
+ (NSUnitFrequency *)baseUnit;

- (instancetype)initWithSymbol:(NSString *)symbol converter:(NSUnitConverter *)converter;

@end
