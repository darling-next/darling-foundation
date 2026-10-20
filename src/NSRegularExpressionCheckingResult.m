//
//  NSRegularExpressionCheckingResult.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "NSRegularExpressionCheckingResult.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSRegularExpression.h>
#import "NSObjectInternal.h"

@implementation NSRegularExpressionCheckingResult

- (id)initWithRangeArray:(NSArray *)ranges regularExpression:(NSRegularExpression *)expression
{
    NSRequestConcreteImplementation();
    [self release];
    return nil;
}

- (id)initWithRanges:(NSRangePointer)ranges count:(NSUInteger)count regularExpression:(NSRegularExpression *)expression
{
    NSRequestConcreteImplementation();
    [self release];
    return nil;
}

- (id)resultByAdjustingRangesWithOffset:(NSInteger)offset
{
    NSArray *ranges = self.rangeArray;
    NSMutableArray *newRanges = [NSMutableArray array];
    NSUInteger numRanges = ranges.count;
    
    if (numRanges != 0)
    {
        for (NSUInteger i = 0; i < numRanges; ++i)
        {
            NSValue *rangeValue = [ranges objectAtIndex:i];
            NSRange range = [rangeValue rangeValue];
            
            if (range.location != NSNotFound)
            {
                if (offset < 0 && range.location < offset)
                {
                    [NSException raise:NSInvalidArgumentException format:@"%@: %ld invalid offset for range %@", _NSFullMethodName(self, _cmd), (long)offset, NSStringFromRange(range)];
                }
                range.location += offset;
            }
            [newRanges addObject:[NSValue valueWithRange:range]];
        }
    }
    
    NSRegularExpressionCheckingResult *result = [[[[self class] alloc] initWithRangeArray:newRanges regularExpression:self.regularExpression] autorelease];
    
    return result;
}

- (BOOL)_adjustRangesWithOffset:(NSInteger)offset
{
    NSRequestConcreteImplementation();
    return NO;
}

- (NSTextCheckingType)resultType
{
    return NSTextCheckingTypeRegularExpression;
}

/*
 * Walk a regular-expression pattern and return the capture-group index of the
 * group named `name`, or -1.  ICU numbers capture groups by their opening
 * parenthesis order and gives every named group (?<name>...) its own number.
 * Escapes, character classes and the non-capturing (?: (?= (?! (?<= (?<! (?# and
 * inline-flag groups do not consume a number, and a lookbehind's trailing '=' or
 * '!' is not a group name.
 */
static NSInteger _NSRegexCaptureGroupIndexForName(NSString *pattern, NSString *name)
{
    NSUInteger length = [pattern length];
    NSUInteger idx = 0;
    NSInteger group = 0;

    while (idx < length)
    {
        unichar ch = [pattern characterAtIndex:idx];

        if (ch == '\\')
        {
            idx += 2;
            continue;
        }

        if (ch == '[')
        {
            idx++;
            if (idx < length && [pattern characterAtIndex:idx] == '^')
            {
                idx++;
            }
            while (idx < length)
            {
                unichar cls = [pattern characterAtIndex:idx];
                if (cls == '\\')
                {
                    idx += 2;
                    continue;
                }
                idx++;
                if (cls == ']')
                {
                    break;
                }
            }
            continue;
        }

        if (ch != '(')
        {
            idx++;
            continue;
        }

        if (idx + 1 < length && [pattern characterAtIndex:idx + 1] == '?')
        {
            unichar kind = (idx + 2 < length) ? [pattern characterAtIndex:idx + 2] : 0;
            if (kind == '<' && idx + 3 < length)
            {
                unichar after = [pattern characterAtIndex:idx + 3];
                if (after != '=' && after != '!')
                {
                    NSRange tail = NSMakeRange(idx + 3, length - (idx + 3));
                    NSRange close = [pattern rangeOfString:@">" options:0 range:tail];
                    if (close.location != NSNotFound)
                    {
                        NSString *candidate = [pattern substringWithRange:NSMakeRange(idx + 3, close.location - (idx + 3))];
                        group += 1;
                        if ([candidate isEqualToString:name])
                        {
                            return group;
                        }
                        idx = close.location + 1;
                        continue;
                    }
                }
            }
            else if (kind == '\'' && idx + 3 < length)
            {
                NSRange tail = NSMakeRange(idx + 3, length - (idx + 3));
                NSRange close = [pattern rangeOfString:@"'" options:0 range:tail];
                if (close.location != NSNotFound)
                {
                    NSString *candidate = [pattern substringWithRange:NSMakeRange(idx + 3, close.location - (idx + 3))];
                    group += 1;
                    if ([candidate isEqualToString:name])
                    {
                        return group;
                    }
                    idx = close.location + 1;
                    continue;
                }
            }
            idx += 2;
            continue;
        }

        group += 1;
        idx++;
    }

    return -1;
}

- (NSRange)rangeWithName:(NSString *)name
{
    if (name == nil)
    {
        return NSMakeRange(NSNotFound, 0);
    }

    NSRegularExpression *expression = [self regularExpression];
    NSInteger index = _NSRegexCaptureGroupIndexForName([expression pattern], name);
    if (index < 0 || (NSUInteger)index >= [self numberOfRanges])
    {
        return NSMakeRange(NSNotFound, 0);
    }

    return [self rangeAtIndex:(NSUInteger)index];
}

@end

@implementation NSSimpleRegularExpressionCheckingResult

- (id)initWithRangeArray:(NSArray *)ranges regularExpression:(NSRegularExpression *)expression
{
    if ([ranges count] > NSRegularExpressionCheckingResultSimpleLimit)
    {
        [self release];
        return nil;
    }
    NSRange rangeList[NSRegularExpressionCheckingResultSimpleLimit];
    NSUInteger count = 0;
    for (NSValue *rangeValue in ranges)
    {
        [rangeValue getValue:&rangeList[count]];
        count++;
    }
    _numberOfRanges = count;
    return [self initWithRanges:rangeList count:count regularExpression:expression];
}

- (id)initWithRanges:(NSRangePointer)ranges count:(NSUInteger)count regularExpression:(NSRegularExpression *)expression
{
    self = [super init];
    if (self)
    {
        NSAssert(count <= NSRegularExpressionCheckingResultSimpleLimit, @"Should be no more than %u ranges", NSRegularExpressionCheckingResultSimpleLimit);
        _numberOfRanges = count;
        memcpy(_ranges, ranges, count * sizeof(NSRange));
        _regularExpression = [expression retain];
    }
    return self;
}

- (void)dealloc
{
    [_regularExpression release];
    [super dealloc];
}

- (NSArray *)rangeArray
{
    NSMutableArray *rangeArray = [[NSMutableArray alloc] init];
    for (NSUInteger idx = 0; idx < _numberOfRanges; idx++)
    {
        [rangeArray addObject:[NSValue valueWithBytes:&_ranges[idx] objCType:@encode(NSRange)]];
    }
    return [rangeArray autorelease];
}

- (NSRange)rangeAtIndex:(NSUInteger)index
{
    return _ranges[index];
}

- (NSUInteger)numberOfRanges
{
    return _numberOfRanges;
}

- (BOOL)_adjustRangesWithOffset:(NSInteger)offset
{
    for (NSUInteger i = 0; i < _numberOfRanges; ++i) {
        _ranges[i].location += offset;
    }
    return YES;
}

- (NSRange)range
{
    return _ranges[0];
}


- (NSRegularExpression *)regularExpression
{
    return _regularExpression;
}


@end

@implementation NSExtendedRegularExpressionCheckingResult

- (id)initWithRangeArray:(NSArray *)ranges regularExpression:(NSRegularExpression *)expression
{
    if ([ranges count] > NSRegularExpressionCheckingResultExtendedLimit)
    {
        [self release];
        return nil;
    }
    NSRange rangeList[NSRegularExpressionCheckingResultExtendedLimit];
    NSUInteger count = 0;
    for (NSValue *rangeValue in ranges)
    {
        [rangeValue getValue:&rangeList[count]];
        count++;
    }
    return [self initWithRanges:rangeList count:count regularExpression:expression];
}

- (id)initWithRanges:(NSRangePointer)ranges count:(NSUInteger)count regularExpression:(NSRegularExpression *)expression
{
    self = [super init];
    if (self)
    {
        /* The storage is a fixed array, but the RESULT has exactly `count` ranges: the whole match plus one
         * per capture group. Darwin's match answers -numberOfRanges with that count (and the vendored
         * reference in this tree, swift-corelibs-foundation's NSRegularExpressionCheckingResult, derives it
         * from the range array it was handed), so the limit is a storage bound and not the reported count. */
        NSAssert(count <= NSRegularExpressionCheckingResultExtendedLimit, @"Should be no more than %u ranges", NSRegularExpressionCheckingResultExtendedLimit);
        _numberOfRanges = count;
        memcpy(_ranges, ranges, count * sizeof(NSRange));
        _regularExpression = [expression retain];
    }
    return self;
}

- (void)dealloc
{
    [_regularExpression release];
    [super dealloc];
}

- (NSArray *)rangeArray
{
    NSMutableArray *rangeArray = [[NSMutableArray alloc] init];
    for (NSUInteger idx = 0; idx < _numberOfRanges; idx++)
    {
        [rangeArray addObject:[NSValue valueWithBytes:&_ranges[idx] objCType:@encode(NSRange)]];
    }
    return [rangeArray autorelease];
}

- (NSRange)rangeAtIndex:(NSUInteger)index
{
    return _ranges[index];
}

- (NSUInteger)numberOfRanges
{
    return _numberOfRanges;
}

- (BOOL)_adjustRangesWithOffset:(NSInteger)offset
{
    for (NSUInteger i = 0; i < _numberOfRanges; ++i)
    {
        _ranges[i].location += offset;
    }
    return YES;
}

- (NSRange)range
{
    return _ranges[0];
}

- (NSRegularExpression *)regularExpression
{
    return _regularExpression;
}


@end

@implementation NSComplexRegularExpressionCheckingResult

- (id)initWithRangeArray:(NSArray *)ranges regularExpression:(NSRegularExpression *)expression
{
    self = [super init];
    if (self)
    {
        _rangeArray = [ranges copy];
        _regularExpression = [expression retain];
    }
    return self;
}

- (id)initWithRanges:(NSRangePointer)ranges count:(NSUInteger)count regularExpression:(NSRegularExpression *)expression
{
    NSMutableArray *rangeArray = [NSMutableArray array];
    for (NSUInteger idx = 0; idx < count; idx++)
    {
        [rangeArray addObject:[NSValue valueWithBytes:&ranges[idx] objCType:@encode(NSRange)]];
    }
    return [self initWithRangeArray:rangeArray regularExpression:expression];
}

- (void)dealloc
{
    [_rangeArray release];
    [_regularExpression release];
    [super dealloc];
}

- (NSArray *)rangeArray
{
    return _rangeArray;
}

- (NSRange)rangeAtIndex:(NSUInteger)index
{
    NSRange r;
    [(NSValue *)_rangeArray[index] getValue:&r];
    return r;
}

- (NSUInteger)numberOfRanges
{
    return [_rangeArray count];
}

- (BOOL)_adjustRangesWithOffset:(NSInteger)offset
{
    NSMutableArray *ranges = [NSMutableArray arrayWithCapacity:_rangeArray.count];
    
    for (NSValue *range in _rangeArray)
    {
        NSRange r = { 0, 0 };
        
        [range getValue:&r];
        r.location += offset;
        [ranges addObject:[NSValue valueWithBytes:&r objCType:@encode(NSRange)]];
    }
    [_rangeArray release];
    _rangeArray = ranges.copy;
    return YES;
}

- (NSRange)range
{
    NSValue *range = [_rangeArray objectAtIndex:0];
    NSRange result = { 0, 0 };
    
    [range getValue:&result];
    return result;
}

- (NSRegularExpression *)regularExpression
{
    return _regularExpression;
}

@end
