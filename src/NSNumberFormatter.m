//
//  NSNumberFormatter.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <CoreFoundation/CFNumberFormatter.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSAttributedString.h>
#import <Foundation/NSDecimalNumber.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSString.h>
#import <Foundation/NSLocale.h>
#import <dispatch/dispatch.h>

@implementation NSNumberFormatter

+ (NSString *)localizedStringFromNumber:(NSNumber *)num numberStyle:(NSNumberFormatterStyle)nstyle
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:nstyle];
    NSString *str = [formatter stringFromNumber:num];
    [formatter release];
    return str;
}

static NSNumberFormatterBehavior defaultBehavior = NSNumberFormatterBehaviorDefault;

+ (NSNumberFormatterBehavior)defaultFormatterBehavior
{
    return defaultBehavior;
}

+ (void)setDefaultFormatterBehavior:(NSNumberFormatterBehavior)behavior
{
    defaultBehavior = behavior;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _attributes = [[NSMutableDictionary alloc] init];
        [self setAllowsFloats:YES];
        [self setFormatterBehavior:NSNumberFormatterBehavior10_4];
        [self setNilSymbol:@""];
        [self setNegativeInfinitySymbol:[NSString stringWithUTF8String:"-∞"]];
        [self setPositiveInfinitySymbol:[NSString stringWithUTF8String:"+∞"]];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter->_attributes release];
    formatter->_attributes = [_attributes copy];
    return formatter;
}

- (void)dealloc
{
    [self _clearFormatter];
    [_attributes release];
    [super dealloc];
}

- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)errorStr
{
    NSError *error = nil;
    NSRange r;
    BOOL success = [self getObjectValue:obj forString:string range:&r error:&error];
    if (errorStr != NULL)
    {
        *errorStr = [error localizedDescription];
    }
    return success;
}

- (NSString *)stringFromNumber:(NSNumber *)number
{
    if (number == nil) {
        return nil;
    }
    [self _regenerateFormatter];
    return [(NSString *)CFNumberFormatterCreateStringWithNumber(kCFAllocatorDefault, _formatter, (CFNumberRef)number) autorelease];
}

- (NSNumber *)numberFromString:(NSString *)string
{
    if (string == nil) {
        return nil;
    }
    [self _regenerateFormatter];
    return [(NSNumber *)CFNumberFormatterCreateNumberFromString(kCFAllocatorDefault, _formatter, (CFStringRef)string, NULL, [_attributes[@"parseIntegersOnly"] boolValue] ? kCFNumberFormatterParseIntegersOnly : 0) autorelease];
}

- (NSNumberFormatterStyle)numberStyle
{
    [self _regenerateFormatter];
    return (NSNumberFormatterStyle)CFNumberFormatterGetStyle(_formatter);
}

- (void)setNumberStyle:(NSNumberFormatterStyle)style
{
    _attributes[@"style"] = @(style);
    [self _reset];
}

- (NSLocale *)locale
{
    [self _regenerateFormatter];
    return (NSLocale *)CFNumberFormatterGetLocale(_formatter);
}

- (void)setLocale:(NSLocale *)locale
{
    if (locale == nil)
    {
        locale = [NSLocale currentLocale];
    }
    _attributes[@"locale"] = locale;
    [self _reset];
}

- (BOOL)generatesDecimalNumbers
{
    return [_attributes[@"generatesDecimalNumbers"] boolValue];
}

- (void)setGeneratesDecimalNumbers:(BOOL)b
{
    _attributes[@"generatesDecimalNumbers"] = @(b);
}

- (NSNumberFormatterBehavior)formatterBehavior
{
    return [_attributes[@"formatterBehavior"] intValue];
}

- (void)setFormatterBehavior:(NSNumberFormatterBehavior)behavior
{
    _attributes[@"formatterBehavior"] = @(behavior);
}

- (NSString *)negativeFormat
{
    return _attributes[@"negativeFormat"];
}

- (void)setNegativeFormat:(NSString *)format
{
    _attributes[@"negativeFormat"] = format;
}

- (NSDictionary *)textAttributesForNegativeValues
{
    return _attributes[@"textAttributesForNegativeValues"];
}

- (void)setTextAttributesForNegativeValues:(NSDictionary *)newAttributes
{
    _attributes[@"textAttributesForNegativeValues"] = newAttributes;
}

- (NSString *)positiveFormat
{
    return _attributes[@"positiveFormat"];
}

- (void)setPositiveFormat:(NSString *)format
{
    _attributes[@"positiveFormat"] = format;
}

- (NSDictionary *)textAttributesForPositiveValues
{
    return _attributes[@"textAttributesForPositiveValues"];
}

- (void)setTextAttributesForPositiveValues:(NSDictionary *)newAttributes
{
    _attributes[@"textAttributesForPositiveValues"] = newAttributes;
}

- (BOOL)allowsFloats
{
    return [_attributes[@"allowsFloats"] boolValue];
}

- (void)setAllowsFloats:(BOOL)flag
{
    _attributes[@"allowsFloats"] = @(flag);
}


#define GET_BOOL(prop) ({ \
    if (_formatter == NULL) { \
        [self _reset]; \
    } \
    [[(NSNumber *)CFNumberFormatterCopyProperty(_formatter, (prop)) autorelease] boolValue]; \
});

#define SET_BOOL(prop, val) \
_attributes[(id)(prop)] = @(val); \
if (_formatter != NULL) { \
    CFNumberFormatterSetProperty(_formatter, (prop), (CFTypeRef)@(val)); \
}

#define GET_UNSIGNEDINTEGER(prop) ({ \
    if (_formatter == NULL) { \
        [self _reset]; \
    } \
    [[(NSNumber *)CFNumberFormatterCopyProperty(_formatter, (prop)) autorelease] unsignedIntegerValue]; \
})

#define SET_UNSIGNEDINTEGER(prop, val) \
_attributes[(id)(prop)] = @(val); \
if (_formatter != NULL) { \
    CFNumberFormatterSetProperty(_formatter, (prop), (CFTypeRef)@(val)); \
}

#define GET_ID(prop) ({ \
    if (_formatter == NULL) { \
        [self _reset]; \
    } \
    [(id)CFNumberFormatterCopyProperty(_formatter, (prop)) autorelease]; \
})

#define SET_ID(prop, val) \
_attributes[(id)(prop)] = (val); \
if (_formatter != NULL) { \
    CFNumberFormatterSetProperty(_formatter, (prop), (CFTypeRef)val); \
}

- (NSString *)decimalSeparator
{
    return GET_ID(kCFNumberFormatterDecimalSeparator);
}

- (void)setDecimalSeparator:(NSString *)string
{
    SET_ID(kCFNumberFormatterDecimalSeparator, string);
}

- (BOOL)alwaysShowsDecimalSeparator
{
    return GET_BOOL(kCFNumberFormatterAlwaysShowDecimalSeparator);
}

- (void)setAlwaysShowsDecimalSeparator:(BOOL)b
{
    SET_BOOL(kCFNumberFormatterAlwaysShowDecimalSeparator, b);
}

- (NSString *)currencyDecimalSeparator
{
    return GET_ID(kCFNumberFormatterCurrencyDecimalSeparator);
}

- (void)setCurrencyDecimalSeparator:(NSString *)string
{
    SET_ID(kCFNumberFormatterCurrencyDecimalSeparator, string);
}

- (BOOL)usesGroupingSeparator
{
    return GET_BOOL(kCFNumberFormatterUseGroupingSeparator);
}

- (void)setUsesGroupingSeparator:(BOOL)b
{
    SET_BOOL(kCFNumberFormatterUseGroupingSeparator, b);
}

- (NSString *)groupingSeparator
{
    return GET_ID(kCFNumberFormatterGroupingSeparator);
}

- (void)setGroupingSeparator:(NSString *)string
{
    SET_ID(kCFNumberFormatterGroupingSeparator, string);
}

- (NSString *)zeroSymbol
{
    return GET_ID(kCFNumberFormatterZeroSymbol);
}

- (void)setZeroSymbol:(NSString *)string
{
    SET_ID(kCFNumberFormatterZeroSymbol, string);
}

- (NSDictionary *)textAttributesForZero
{
    return _attributes[@"textAttributesForZero"];
}

- (void)setTextAttributesForZero:(NSDictionary *)newAttributes
{
    _attributes[@"textAttributesForZero"] = newAttributes;
}

- (NSString *)nilSymbol
{
    return _attributes[@"nilSymbol"];
}

- (void)setNilSymbol:(NSString *)string
{
    _attributes[@"nilSymbol"] = string;
}

- (NSDictionary *)textAttributesForNil
{
    return _attributes[@"textAttributesForNil"];
}

- (void)setTextAttributesForNil:(NSDictionary *)newAttributes
{
    _attributes[@"textAttributesForNil"] = newAttributes;
}

- (NSString *)notANumberSymbol
{
    return GET_ID(kCFNumberFormatterNaNSymbol);
}

- (void)setNotANumberSymbol:(NSString *)string
{
    SET_ID(kCFNumberFormatterNaNSymbol, string);
}

- (NSDictionary *)textAttributesForNotANumber
{
    return _attributes[@"textAttributesForNotANumber"]; 
}

- (void)setTextAttributesForNotANumber:(NSDictionary *)newAttributes
{
    _attributes[@"textAttributesForNotANumber"] = newAttributes;
}

- (NSString *)positiveInfinitySymbol
{
    return _attributes[@"positiveInfinitySymbol"];
}

- (void)setPositiveInfinitySymbol:(NSString *)string
{
    _attributes[@"positiveInfinitySymbol"] = string;
}

- (NSDictionary *)textAttributesForPositiveInfinity
{
    return _attributes[@"textAttributesForPositiveInfinity"];
}

- (void)setTextAttributesForPositiveInfinity:(NSDictionary *)newAttributes
{
    _attributes[@"textAttributesForPositiveInfinity"] = newAttributes;
}


- (NSString *)negativeInfinitySymbol
{
    return _attributes[@"negativeInfinitySymbol"];
}

- (void)setNegativeInfinitySymbol:(NSString *)string
{
    _attributes[@"negativeInfinitySymbol"] = string;
}

- (NSDictionary *)textAttributesForNegativeInfinity
{
    return _attributes[@"textAttributesForNegativeInfinity"];
}

- (void)setTextAttributesForNegativeInfinity:(NSDictionary *)newAttributes
{
    _attributes[@"textAttributesForNegativeInfinity"] = newAttributes;
}

- (NSString *)positivePrefix
{
    return GET_ID(kCFNumberFormatterPositivePrefix);
}

- (void)setPositivePrefix:(NSString *)string
{
    SET_ID(kCFNumberFormatterPositivePrefix, string);
}

- (NSString *)positiveSuffix
{
    return GET_ID(kCFNumberFormatterPositiveSuffix);
}

- (void)setPositiveSuffix:(NSString *)string
{
    SET_ID(kCFNumberFormatterPositiveSuffix, string);
}

- (NSString *)negativePrefix
{
    return GET_ID(kCFNumberFormatterNegativePrefix);
}

- (void)setNegativePrefix:(NSString *)string
{
    SET_ID(kCFNumberFormatterNegativePrefix, string);
}

- (NSString *)negativeSuffix
{
    return GET_ID(kCFNumberFormatterNegativeSuffix);
}

- (void)setNegativeSuffix:(NSString *)string
{
    SET_ID(kCFNumberFormatterNegativeSuffix, string);
}

- (NSString *)currencyCode
{
    return GET_ID(kCFNumberFormatterCurrencyCode);
}

- (void)setCurrencyCode:(NSString *)string
{
    SET_ID(kCFNumberFormatterCurrencyCode, string);
}

- (NSString *)currencySymbol
{
    return GET_ID(kCFNumberFormatterCurrencySymbol);
}

- (void)setCurrencySymbol:(NSString *)string
{
    SET_ID(kCFNumberFormatterCurrencySymbol, string);
}

- (NSString *)internationalCurrencySymbol
{
    return GET_ID(kCFNumberFormatterInternationalCurrencySymbol);
}

- (void)setInternationalCurrencySymbol:(NSString *)string
{
    SET_ID(kCFNumberFormatterInternationalCurrencySymbol, string);
}

- (NSString *)percentSymbol
{
    return GET_ID(kCFNumberFormatterPercentSymbol);
}

- (void)setPercentSymbol:(NSString *)string
{
    SET_ID(kCFNumberFormatterPercentSymbol, string);
}

- (NSString *)perMillSymbol
{
    return GET_ID(kCFNumberFormatterPerMillSymbol);
}

- (void)setPerMillSymbol:(NSString *)string
{
    SET_ID(kCFNumberFormatterPerMillSymbol, string);
}

- (NSString *)minusSign
{
    return GET_ID(kCFNumberFormatterMinusSign);
}

- (void)setMinusSign:(NSString *)string
{
    SET_ID(kCFNumberFormatterMinusSign, string);
}

- (NSString *)plusSign
{
    return GET_ID(kCFNumberFormatterPlusSign);
}

- (void)setPlusSign:(NSString *)string
{
    SET_ID(kCFNumberFormatterPlusSign, string);
}

- (NSString *)exponentSymbol
{
    return GET_ID(kCFNumberFormatterExponentSymbol);
}

- (void)setExponentSymbol:(NSString *)string
{
    SET_ID(kCFNumberFormatterExponentSymbol, string);
}

- (NSUInteger)groupingSize
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterGroupingSize);
}

- (void)setGroupingSize:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterGroupingSize, number);
}

- (NSUInteger)secondaryGroupingSize
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterSecondaryGroupingSize);
}

- (void)setSecondaryGroupingSize:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterSecondaryGroupingSize, number);
}

- (NSNumber *)multiplier
{
    return GET_ID(kCFNumberFormatterMultiplier);
}

- (void)setMultiplier:(NSNumber *)number
{
    SET_ID(kCFNumberFormatterMultiplier, number);
}

- (NSUInteger)formatWidth
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterFormatWidth);
}

- (void)setFormatWidth:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterFormatWidth, number);
}

- (NSString *)paddingCharacter
{
    return GET_ID(kCFNumberFormatterPaddingCharacter);
}

- (void)setPaddingCharacter:(NSString *)string
{
    SET_ID(kCFNumberFormatterPaddingCharacter, string);
}

- (NSNumberFormatterPadPosition)paddingPosition
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterPaddingPosition);
}

- (void)setPaddingPosition:(NSNumberFormatterPadPosition)position
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterPaddingPosition, position);
}

- (NSNumberFormatterRoundingMode)roundingMode
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterRoundingMode);
}

- (void)setRoundingMode:(NSNumberFormatterRoundingMode)mode
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterRoundingMode, mode);
}

- (NSNumber *)roundingIncrement
{
    return GET_ID(kCFNumberFormatterRoundingIncrement);
}

- (void)setRoundingIncrement:(NSNumber *)number
{
    SET_ID(kCFNumberFormatterRoundingIncrement, number);
}

- (NSUInteger)minimumIntegerDigits
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterMinIntegerDigits);
}

- (void)setMinimumIntegerDigits:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterMinIntegerDigits, number);
}

- (NSUInteger)maximumIntegerDigits
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterMaxIntegerDigits);
}

- (void)setMaximumIntegerDigits:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterMaxIntegerDigits, number);
}

- (NSUInteger)minimumFractionDigits
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterMinFractionDigits);
}

- (void)setMinimumFractionDigits:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterMinFractionDigits, number);
}

- (NSUInteger)maximumFractionDigits
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterMaxFractionDigits);
}

- (void)setMaximumFractionDigits:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterMaxFractionDigits, number);
}

- (NSString *)currencyGroupingSeparator
{
    return GET_ID(kCFNumberFormatterCurrencyGroupingSeparator);
}

- (void)setCurrencyGroupingSeparator:(NSString *)string
{
    SET_ID(kCFNumberFormatterCurrencyGroupingSeparator, string);
}

- (BOOL)isLenient
{
    return GET_BOOL(kCFNumberFormatterIsLenient);
}

- (void)setLenient:(BOOL)b
{
    SET_BOOL(kCFNumberFormatterIsLenient, b);
}

- (BOOL)usesSignificantDigits
{
    return GET_BOOL(kCFNumberFormatterUseSignificantDigits);
}

- (void)setUsesSignificantDigits:(BOOL)b
{
    SET_BOOL(kCFNumberFormatterUseSignificantDigits, b);
}

- (NSUInteger)minimumSignificantDigits
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterMinSignificantDigits);
}

- (void)setMinimumSignificantDigits:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterMinSignificantDigits, number);
}

- (NSUInteger)maximumSignificantDigits
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterMaxSignificantDigits);
}

- (void)setMaximumSignificantDigits:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterMaxSignificantDigits, number);
}

/* ---------------------------------------------------------------------------------------------------
 * NSNumberFormatterCompatibility -- the macOS-only 10.0-era accessors declared by the Apple SDK (and
 * now re-declared by this tree's own header, in the category the SDK declares them in).
 *
 * WHY THEY ARE HERE, MEASURED. Xcode 26.3's initial plug-in scan completes and xcodebuild then dies
 * inside its own error-printing path with
 *   "Uncaught Exception: -[NSNumberFormatter setHasThousandSeparators:]: unrecognized selector sent
 *    to instance 0x..."
 * from SharedFrameworks/DVTInstrumentsUtilities.framework/Versions/A/DVTInstrumentsUtilities
 * (sha256 ef40c0e5bafa5be8454f535f36347e558f311cd14dae3b5c9e77f494591a8ac5), whose
 * `HexFormatStyle` static initializer (dispatch_once) does
 *   13f04: [fmt setNumberStyle:]           edx=1        (NSNumberFormatterDecimalStyle)
 *   13f19: [fmt setUsesGroupingSeparator:] edx=1
 *   13f2e: [fmt setHasThousandSeparators:] edx=1        <-- the fatal send
 * and, in a second factory,
 *   14022/14037/1404e: the same three, then
 *   14058: [fmt setMinimumFractionDigits:] rdx=<arg>
 *   14068: [fmt setMaximumFractionDigits:] edx=4
 * The three BOOL sends sit on the SAME receiver, so the caller plainly treats the thousand separator
 * as the grouping separator by another name; setNumberStyle:, setUsesGroupingSeparator: and
 * setMinimum/MaximumFractionDigits: already existed here, so setHasThousandSeparators: alone was the
 * wall in that image. The same image also contains selrefs for setLocalizesFormat: and setFormat:,
 * and the plug-in set (IDEInterfaceBuilderCocoaIntegration, CocoaPlugin, InstrumentsPlugIn,
 * DebuggerUI, InstrumentsKit, IDESwiftPackageUI, SpatialInspectorXcodePlugin, MLShared,
 * RealityToolKit, RealityToolsShared, SourceEditorPlugin) references the whole block -- the IB
 * plug-ins enumerate every property of the class -- so the family was implemented whole rather than
 * one selector at a time.
 *
 * WHAT THE SEMANTICS ARE GROUNDED IN. Apple's own swift-corelibs-foundation, vendored in this tree at
 * src/external/corefoundation/submodules/swift-corelibs-foundation/Sources/Foundation/
 * NumberFormatter.swift, implements exactly this block (lines 956-1119): every member is stored
 * per-instance state -- none of hasThousandSeparators, thousandSeparator, localizesFormat,
 * isPartialStringValidationEnabled, attributedStringForZero/Nil/NotANumber or roundingBehavior is
 * pushed into the CFNumberFormatter -- with the defaults `hasThousandSeparators = false`,
 * `localizesFormat = true`, `attributedStringForZero = NSAttributedString("0")`,
 * `attributedStringForNil = NSAttributedString("")`,
 * `attributedStringForNotANumber = NSAttributedString("NaN")`, `roundingBehavior =
 * NSDecimalNumberHandler.default`, `thousandSeparator = nil`. That is what is reproduced here, in
 * this file's own `_attributes` storage (which already holds `allowsFloats`, `style`, `locale` and
 * `formatterBehavior` the same way -- stored, and not all of them applied by _regenerateFormatter).
 *
 * SETFORMAT:, MEASURED AND NOT GUESSED. The literal pool of DVTInstrumentsUtilities contains the
 * ICU patterns "#,##0.00" and "#,##0", and the calls are `[fmt setFormat:@"#,##0.00"]`-shaped (the
 * string is the second argument of the send). `_regenerateFormatter` already had the hook
 * `_attributes[@"format"] -> CFNumberFormatterSetFormat` with no accessor to reach it, so `format` is
 * that hook made live: the value is stored as given and applied as the formatter's pattern.
 * NOTE, because it is the kind of thing a reader will otherwise trip over: this class ALSO declared
 * `@property (copy) NSString *format;` in its main @interface, so the compiler AUTO-SYNTHESIZED
 * -format/-setFormat: and a private `_format` ivar; the runtime therefore already answered setFormat:
 * before this change, it just stored the string in an ivar nothing read. That declaration has been
 * removed from the main interface (Apple declares this property only in the compatibility category),
 * and the accessors below are the ones that take effect.
 *
 * WHAT COULD NOT BE ESTABLISHED, stated rather than papered over:
 *   - Whether Darwin additionally mirrors hasThousandSeparators/thousandSeparator into
 *     usesGroupingSeparator/groupingSeparator. Apple's own corelibs implementation does NOT (it
 *     stores them), so this stores them too; the measured caller sets BOTH properties, so the
 *     grouping behaviour it asks for is what it asks for either way. No macOS oracle is available
 *     here to settle it.
 *   - Darwin's exact `-format` getter shape: corelibs synthesizes "positive;zero;negative", the
 *     measured callers only ever pass a single-component pattern, and this returns the value as set.
 *   - Whether Darwin enforces `localizesFormat`. It is inert here for the same reason as in corelibs.
 *   - `roundingBehavior` is declared `copy`, but this tree's NSDecimalNumberHandler does not declare
 *     NSCopying (unlike Darwin's), so the given instance is stored, exactly as every other object
 *     accessor in this file stores its argument.
 * ------------------------------------------------------------------------------------------------- */

/* The three attributed-string defaults are created once for the process and shared: a formatter that
 * is never asked for one must not pay for it, and every formatter that is asked must get the same
 * object, because nothing here is per-instance state until a caller sets it. */
static NSAttributedString *_NSNumberFormatterDefaultAttributedStringForZero;
static NSAttributedString *_NSNumberFormatterDefaultAttributedStringForNil;
static NSAttributedString *_NSNumberFormatterDefaultAttributedStringForNotANumber;
static dispatch_once_t _NSNumberFormatterCompatibilityDefaultsOnce;

static void _NSNumberFormatterMakeCompatibilityDefaults(void)
{
    dispatch_once(&_NSNumberFormatterCompatibilityDefaultsOnce, ^{
        _NSNumberFormatterDefaultAttributedStringForZero = [[NSAttributedString alloc] initWithString:@"0"];
        _NSNumberFormatterDefaultAttributedStringForNil = [[NSAttributedString alloc] initWithString:@""];
        _NSNumberFormatterDefaultAttributedStringForNotANumber = [[NSAttributedString alloc] initWithString:@"NaN"];
    });
}

- (BOOL)hasThousandSeparators
{
    return [_attributes[@"hasThousandSeparators"] boolValue];
}

- (void)setHasThousandSeparators:(BOOL)b
{
    _attributes[@"hasThousandSeparators"] = @(b);
}

- (NSString *)thousandSeparator
{
    return _attributes[@"thousandSeparator"];
}

- (void)setThousandSeparator:(NSString *)string
{
    _attributes[@"thousandSeparator"] = [string copy];
}

- (BOOL)localizesFormat
{
    id value = _attributes[@"localizesFormat"];
    return value != nil ? [value boolValue] : YES;
}

- (void)setLocalizesFormat:(BOOL)b
{
    _attributes[@"localizesFormat"] = @(b);
}

- (NSString *)format
{
    return _attributes[@"format"];
}

- (void)setFormat:(NSString *)format
{
    _attributes[@"format"] = [format copy];
    [self _reset];
}

- (NSAttributedString *)attributedStringForZero
{
    _NSNumberFormatterMakeCompatibilityDefaults();
    id value = _attributes[@"attributedStringForZero"];
    return value != nil ? value : _NSNumberFormatterDefaultAttributedStringForZero;
}

- (void)setAttributedStringForZero:(NSAttributedString *)string
{
    _attributes[@"attributedStringForZero"] = [string copy];
}

- (NSAttributedString *)attributedStringForNil
{
    _NSNumberFormatterMakeCompatibilityDefaults();
    id value = _attributes[@"attributedStringForNil"];
    return value != nil ? value : _NSNumberFormatterDefaultAttributedStringForNil;
}

- (void)setAttributedStringForNil:(NSAttributedString *)string
{
    _attributes[@"attributedStringForNil"] = [string copy];
}

- (NSAttributedString *)attributedStringForNotANumber
{
    _NSNumberFormatterMakeCompatibilityDefaults();
    id value = _attributes[@"attributedStringForNotANumber"];
    return value != nil ? value : _NSNumberFormatterDefaultAttributedStringForNotANumber;
}

- (void)setAttributedStringForNotANumber:(NSAttributedString *)string
{
    _attributes[@"attributedStringForNotANumber"] = [string copy];
}

- (NSDecimalNumberHandler *)roundingBehavior
{
    id value = _attributes[@"roundingBehavior"];
    return value != nil ? value : [NSDecimalNumberHandler defaultDecimalNumberHandler];
}

- (void)setRoundingBehavior:(NSDecimalNumberHandler *)behavior
{
    _attributes[@"roundingBehavior"] = behavior;
}

- (void)_reset
{
    [self _clearFormatter];
    [self _regenerateFormatter];
}

- (void)_regenerateFormatter
{
    if (_formatter != NULL)
    {
        return;
    }
    // NOTE: _attributes stores both the creation/parameters AND properties, so a simple iterator wont work
    _formatter = CFNumberFormatterCreate(kCFAllocatorDefault, (CFLocaleRef)_attributes[@"locale"] ?: (CFLocaleRef)[NSLocale currentLocale], [_attributes[@"style"] intValue]);

    if (_formatter == nil)
    {
        DEBUG_LOG("Number Formatter creation failed.  Are ICU tables built in?");
        return;
    }

    if (_attributes[@"format"])
    {
        CFNumberFormatterSetFormat(_formatter, (CFStringRef)_attributes[@"format"]);
    }
    if (_attributes[(id)kCFNumberFormatterCurrencyCode])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterCurrencyCode, (CFTypeRef)_attributes[(id)kCFNumberFormatterCurrencyCode]);
    }
    if (_attributes[(id)kCFNumberFormatterDecimalSeparator])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterDecimalSeparator, (CFTypeRef)_attributes[(id)kCFNumberFormatterDecimalSeparator]);
    }
    if (_attributes[(id)kCFNumberFormatterCurrencyDecimalSeparator])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterCurrencyDecimalSeparator, (CFTypeRef)_attributes[(id)kCFNumberFormatterCurrencyDecimalSeparator]);
    }
    if (_attributes[(id)kCFNumberFormatterAlwaysShowDecimalSeparator])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterAlwaysShowDecimalSeparator, (CFTypeRef)_attributes[(id)kCFNumberFormatterAlwaysShowDecimalSeparator]);
    }
    if (_attributes[(id)kCFNumberFormatterGroupingSeparator])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterGroupingSeparator, (CFTypeRef)_attributes[(id)kCFNumberFormatterGroupingSeparator]);
    }
    if (_attributes[(id)kCFNumberFormatterUseGroupingSeparator])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterUseGroupingSeparator, (CFTypeRef)_attributes[(id)kCFNumberFormatterUseGroupingSeparator]);
    }
    if (_attributes[(id)kCFNumberFormatterPercentSymbol])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterPercentSymbol, (CFTypeRef)_attributes[(id)kCFNumberFormatterPercentSymbol]);
    }
    if (_attributes[(id)kCFNumberFormatterZeroSymbol])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterZeroSymbol, (CFTypeRef)_attributes[(id)kCFNumberFormatterZeroSymbol]);
    }
    if (_attributes[(id)kCFNumberFormatterNaNSymbol])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterNaNSymbol, (CFTypeRef)_attributes[(id)kCFNumberFormatterNaNSymbol]);
    }
    if (_attributes[(id)kCFNumberFormatterInfinitySymbol])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterInfinitySymbol, (CFTypeRef)_attributes[(id)kCFNumberFormatterInfinitySymbol]);
    }
    if (_attributes[(id)kCFNumberFormatterMinusSign])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterMinusSign, (CFTypeRef)_attributes[(id)kCFNumberFormatterMinusSign]);
    }
    if (_attributes[(id)kCFNumberFormatterPlusSign])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterPlusSign, (CFTypeRef)_attributes[(id)kCFNumberFormatterPlusSign]);
    }
    if (_attributes[(id)kCFNumberFormatterCurrencySymbol])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterCurrencySymbol, (CFTypeRef)_attributes[(id)kCFNumberFormatterCurrencySymbol]);
    }
    if (_attributes[(id)kCFNumberFormatterExponentSymbol])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterExponentSymbol, (CFTypeRef)_attributes[(id)kCFNumberFormatterExponentSymbol]);
    }
    if (_attributes[(id)kCFNumberFormatterMinIntegerDigits])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterMinIntegerDigits, (CFTypeRef)_attributes[(id)kCFNumberFormatterMinIntegerDigits]);
    }
    if (_attributes[(id)kCFNumberFormatterMaxIntegerDigits])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterMaxIntegerDigits, (CFTypeRef)_attributes[(id)kCFNumberFormatterMaxIntegerDigits]);
    }
    if (_attributes[(id)kCFNumberFormatterMinFractionDigits])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterMinFractionDigits, (CFTypeRef)_attributes[(id)kCFNumberFormatterMinFractionDigits]);
    }
    if (_attributes[(id)kCFNumberFormatterMaxFractionDigits])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterMaxFractionDigits, (CFTypeRef)_attributes[(id)kCFNumberFormatterMaxFractionDigits]);
    }
    if (_attributes[(id)kCFNumberFormatterGroupingSize])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterGroupingSize, (CFTypeRef)_attributes[(id)kCFNumberFormatterGroupingSize]);
    }
    if (_attributes[(id)kCFNumberFormatterSecondaryGroupingSize])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterSecondaryGroupingSize, (CFTypeRef)_attributes[(id)kCFNumberFormatterSecondaryGroupingSize]);
    }
    if (_attributes[(id)kCFNumberFormatterRoundingMode])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterRoundingMode, (CFTypeRef)_attributes[(id)kCFNumberFormatterRoundingMode]);
    }
    if (_attributes[(id)kCFNumberFormatterRoundingIncrement])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterRoundingIncrement, (CFTypeRef)_attributes[(id)kCFNumberFormatterRoundingIncrement]);
    }
    if (_attributes[(id)kCFNumberFormatterFormatWidth])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterFormatWidth, (CFTypeRef)_attributes[(id)kCFNumberFormatterFormatWidth]);
    }
    if (_attributes[(id)kCFNumberFormatterPaddingPosition])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterPaddingPosition, (CFTypeRef)_attributes[(id)kCFNumberFormatterPaddingPosition]);
    }
    if (_attributes[(id)kCFNumberFormatterPaddingCharacter])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterPaddingCharacter, (CFTypeRef)_attributes[(id)kCFNumberFormatterPaddingCharacter]);
    }
    if (_attributes[(id)kCFNumberFormatterDefaultFormat])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterDefaultFormat, (CFTypeRef)_attributes[(id)kCFNumberFormatterDefaultFormat]);
    }
    if (_attributes[(id)kCFNumberFormatterMultiplier])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterMultiplier, (CFTypeRef)_attributes[(id)kCFNumberFormatterMultiplier]);
    }
    if (_attributes[(id)kCFNumberFormatterPositivePrefix])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterPositivePrefix, (CFTypeRef)_attributes[(id)kCFNumberFormatterPositivePrefix]);
    }
    if (_attributes[(id)kCFNumberFormatterPositiveSuffix])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterPositiveSuffix, (CFTypeRef)_attributes[(id)kCFNumberFormatterPositiveSuffix]);
    }
    if (_attributes[(id)kCFNumberFormatterNegativePrefix])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterNegativePrefix, (CFTypeRef)_attributes[(id)kCFNumberFormatterNegativePrefix]);
    }
    if (_attributes[(id)kCFNumberFormatterNegativeSuffix])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterNegativeSuffix, (CFTypeRef)_attributes[(id)kCFNumberFormatterNegativeSuffix]);
    }
    if (_attributes[(id)kCFNumberFormatterPerMillSymbol])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterPerMillSymbol, (CFTypeRef)_attributes[(id)kCFNumberFormatterPerMillSymbol]);
    }
    if (_attributes[(id)kCFNumberFormatterInternationalCurrencySymbol])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterInternationalCurrencySymbol, (CFTypeRef)_attributes[(id)kCFNumberFormatterInternationalCurrencySymbol]);
    }
    if (_attributes[(id)kCFNumberFormatterCurrencyGroupingSeparator])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterCurrencyGroupingSeparator, (CFTypeRef)_attributes[(id)kCFNumberFormatterCurrencyGroupingSeparator]);
    }
    if (_attributes[(id)kCFNumberFormatterIsLenient])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterIsLenient, (CFTypeRef)_attributes[(id)kCFNumberFormatterIsLenient]);
    }
    if (_attributes[(id)kCFNumberFormatterUseSignificantDigits])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterUseSignificantDigits, (CFTypeRef)_attributes[(id)kCFNumberFormatterUseSignificantDigits]);
    }
    if (_attributes[(id)kCFNumberFormatterMinSignificantDigits])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterMinSignificantDigits, (CFTypeRef)_attributes[(id)kCFNumberFormatterMinSignificantDigits]);
    }
    if (_attributes[(id)kCFNumberFormatterMaxSignificantDigits])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterMaxSignificantDigits, (CFTypeRef)_attributes[(id)kCFNumberFormatterMaxSignificantDigits]);
    }
}

- (void)_clearFormatter
{
    if (_formatter != NULL)
    {
        CFRelease(_formatter);
        _formatter = NULL;
    }
}


@end
