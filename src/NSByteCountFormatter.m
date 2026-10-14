//
//  NSByteCountFormatter.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSByteCountFormatter.h>
#import <Foundation/NSNumberFormatter.h>
#import "NSObjectInternal.h"
#import <Foundation/NSLocale.h>

@implementation NSByteCountFormatter

static NSArray *_NSByteCountFormatterUnits;

+ (void)initialize
{
    if ([self class] == [NSByteCountFormatter class])
    {
        _NSByteCountFormatterUnits = [[NSArray alloc] initWithObjects:@"bytes", @"KB", @"MB", @"GB", @"TB", @"PB", @"EB", @"ZB", @"YB", nil];
    }
}

+ (NSString *)stringFromByteCount:(long long)byteCount countStyle:(NSByteCountFormatterCountStyle)style
{
    NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
    formatter->_countStyle = style;

    NSString *string = [formatter stringFromByteCount:byteCount];

    [formatter release];

    return string;
}

- (NSByteCountFormatter *)init
{
    self = [super init];

    if (self)
    {
        _adaptive = YES;
        _allowsNonnumericFormatting = YES;
        _includesUnit = YES;
        _includesCount = YES;
    }

    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSByteCountFormatter *copy = [[NSByteCountFormatter allocWithZone:zone] init];

    copy->_allowedUnits = _allowedUnits;
    copy->_countStyle = _countStyle;
    copy->_allowsNonnumericFormatting = _allowsNonnumericFormatting;
    copy->_includesUnit = _includesUnit;
    copy->_includesCount = _includesCount;
    copy->_includesActualByteCount = _includesActualByteCount;
    copy->_adaptive = _adaptive;
    copy->_zeroPadsFractionDigits = _zeroPadsFractionDigits;

    return copy;
}

- (id)initWithCoder:(NSCoder *)coder
{
#warning TODO coder
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
#warning TODO coder
    return;
}

// This property must be defined by hand as the type of the ivar does
// not match the declared type in the getter and setter.
- (NSByteCountFormatterCountStyle)countStyle
{
    return _countStyle;
}

- (void)setCountStyle:(NSByteCountFormatterCountStyle)countStyle
{
    _countStyle = countStyle;
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr
              originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString **)error
{
    return NO;
}

- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)error
{
    return NO;
}

#warning TODO localization
- (NSString *)stringFromByteCount:(long long)byteCount
{
    unsigned long long unsignedByteCount = (unsigned long long)byteCount;

    if (unsignedByteCount == 0 && _allowsNonnumericFormatting && _includesUnit && _includesCount)
    {
        // Use "Zero KB" for default or all style, or if KB is allowed and bytes isn't.
        if (_allowedUnits == NSByteCountFormatterUseAll ||
            _allowedUnits == NSByteCountFormatterUseDefault ||
            (_allowedUnits & NSByteCountFormatterUseKB && !(_allowedUnits & NSByteCountFormatterUseBytes)))
        {
            return @"Zero KB";
        }
        else
        {
            return @"Zero bytes";
        }
    }

    unsigned long long thousand = 0;
    switch (_countStyle)
    {
        case NSByteCountFormatterCountStyleBinary:
        case NSByteCountFormatterCountStyleMemory:
            thousand = 1024;
            break;
        default:
            thousand = 1000;
            break;
    }

    NSString *countString = @"";
    NSString *unitString = @"";
    NSString *spaceString = @"";

    NSUInteger unitIdx = 0;
    unsigned long long unitMax = thousand;
    unsigned long long unitMin = 1;

    if (_allowedUnits == NSByteCountFormatterUseDefault || _allowedUnits == NSByteCountFormatterUseAll)
    {
        while (unitMax < unsignedByteCount)
        {
            unitIdx++;
            unitMin = unitMax;

            if (byteCount / unitMin < thousand)
            {
                break;
            }
            else
            {
                unitMax *= thousand;
            }
        }

        if (_includesCount)
        {
            countString = [NSString stringWithFormat:@"%llu", unsignedByteCount / unitMin];
        }

        if (_includesUnit)
        {
            unitString = [_NSByteCountFormatterUnits objectAtIndex:unitIdx];
        }

        if (_includesCount && _includesUnit)
        {
            spaceString = @" ";
        }
    }
    else
    {
#warning TODO figure out these other cases
    }

    NSUInteger fractionDigits = 2;
    if (_adaptive)
    {
        if (unitIdx <= 1)
        {
            fractionDigits = 0;
        }
        else if (unitIdx == 2)
        {
            fractionDigits = 1;
        }
    }

    NSString *actualCountString = @"";
    if (_includesActualByteCount)
    {
        static NSNumberFormatter *fileSizeFormatter = nil;
        static dispatch_once_t once = 0L;
        dispatch_once(&once, ^{
            fileSizeFormatter = [[NSNumberFormatter alloc] init];
            [fileSizeFormatter setLocale:[NSLocale currentLocale]];
            [fileSizeFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
            [fileSizeFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
            [fileSizeFormatter setUsesGroupingSeparator:YES];
            [fileSizeFormatter setRoundingMode:NSNumberFormatterRoundUp];
            [fileSizeFormatter setMaximumFractionDigits:0];
            [fileSizeFormatter setGroupingSize:3];
        });
        actualCountString = [NSString stringWithFormat:@" (%@ %@)", [fileSizeFormatter stringFromNumber:@(unsignedByteCount)],
                             [_NSByteCountFormatterUnits objectAtIndex:0]];
    }

    return [NSString stringWithFormat:@"%@%@%@%@", countString, spaceString, unitString, actualCountString];
}

- (NSString *)stringForObjectValue:(id)obj
{
    if ([obj isNSNumber__])
    {
        long long byteCount = [obj longLongValue];
        return [self stringFromByteCount:byteCount];
    }
    else
    {
        return nil;
    }
}

@end

/*
 * NSLocalizedFileSizeDescription(size, maximumDisplayedValue, options) -- the C entry point of the
 * NSByteCountFormatter family, and the one strong eager Foundation import that stops Xcode 26.3's
 * iOS plug-in from loading (bead dar-liaq, rung unmet-eager-closure):
 *
 *   dlopen(.../PlugIns/IDEiOSSupportCore.framework/IDEiOSSupportCore):
 *     Symbol not found: _NSLocalizedFileSizeDescription
 *     Referenced from: .../SharedFrameworks/DTDeviceKitBase.framework/Versions/A/DTDeviceKitBase
 *     Expected in: /System/Library/Frameworks/Foundation.framework/Versions/C/Foundation
 *
 * WHERE THE DECLARATION AND THE BODY COME FROM (read, not guessed):
 *
 *  * the symbol is Apple's own Foundation export -- the SDK's Foundation.tbd lists both
 *    `_NSLocalizedFileSizeDescription` and `__NSLocalizedFileSizeDescription` among
 *    /System/Library/Frameworks/Foundation.framework/Versions/C/Foundation's exports -- and its
 *    prototype is in Apple's internal `Foundation/NSFileSizeFormatter.h`, which the SDK does not
 *    ship; the tree's own vendored copy of that declaration,
 *    src/external/WebCore/PAL/pal/spi/cocoa/NSFileSizeFormatterSPI.h, has
 *    `typedef uint64_t NSFileSizeFormatterOptions; extern "C" NSString *
 *    NSLocalizedFileSizeDescription(uint64_t size, uint64_t maximumDisplayedValue,
 *    NSFileSizeFormatterOptions);` and the same tree calls it as the *file* size formatter
 *    (PAL/pal/cocoa/FileSizeFormatterCocoa.mm: `return NSLocalizedFileSizeDescription(size, 0, 0);`),
 *    with PAL/pal/FileSizeFormatter.cpp carrying the non-Cocoa fallback of the same shape
 *    ("N bytes", "X.Y KB", "X.Y MB", "X.Y GB", decimal steps of 1000).
 *  * that is the same user-visible answer this tree's own NSByteCountFormatter produces with the
 *    FILE count style (NSByteCountFormatterCountStyleFile -> steps of 1000; `stringFromByteCount:`
 *    above is the value's own formatter), which is why this is implemented beside that sibling
 *    rather than re-derived: the demanded member is the C face of the same operation.
 *
 * ONE MEASURED CALLER, and what it passes.  `-[DTDKFileSizeTransformer transformedValue:]`
 * (x86_64 slice of the sha256 69832aa102764bbb54363ab7d76997d28e950d38ba195c7668688510b1cfbb15
 * binary named above) is the image's only reference and tail-calls this entry point:
 *
 *   4f27e: movq   %rdx, %rdi                       ; value = transformedValue:'s argument
 *   4f281: movq   <selref vm+0x935e8>, %rsi        ; DTDK_safeUnsignedLongLongValue
 *   4f288: callq  *<objc_msgSend>                  ; the uint64 byte count
 *   4f28e: movl   $0x280000, %edx                  ; options
 *   4f293: movq   %rax, %rdi                       ; size
 *   4f296: xorl   %esi, %esi                       ; maximumDisplayedValue = 0
 *   4f299: jmpq   _NSLocalizedFileSizeDescription
 *
 * so the argument shape is (uint64_t size, 0, 0x280000) -- the same `maximumDisplayedValue = 0` the
 * tree's own WebKit caller passes, i.e. no maximum.  The two trailing arguments are ACCEPTED AND NOT
 * INTERPRETED: Apple's header that gives the option bits their meaning is not in the SDK and the one
 * measured caller's values establish no behaviour for them, so nothing here guesses a cap or a unit
 * style from a bit pattern.  Only `size` is interpreted, by the sibling above.
 */
NSString *NSLocalizedFileSizeDescription(uint64_t size, uint64_t maximumDisplayedValue,
                                         uint64_t options)
{
    (void) maximumDisplayedValue;
    (void) options;

    return [NSByteCountFormatter stringFromByteCount:(long long) size
                                           countStyle:NSByteCountFormatterCountStyleFile];
}
