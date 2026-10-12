//
//  NSListFormatter.m
//  Foundation
//

#import <Foundation/NSListFormatter.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSFormatter.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSString.h>

#import <stdlib.h>
#import <unicode/ulistformatter.h>

//
// NSListFormatter: the class a client binds as _OBJC_CLASS_$_NSListFormatter.
//
// WHY IT IS HERE.  A client that formats a list of items carries a two-level class reference to
// this class, so it binds _OBJC_CLASS_$_NSListFormatter STRONG and EAGER and dyld refuses the
// client until the name resolves, whether or not the class is ever used.  Measured on the client
// that stopped this ladder's rung: DVTFoundation binds the class object from Foundation and uses
// exactly ONE API of it -- the CLASS METHOD +localizedStringByJoiningStrings:, in
// _$sSo23DVTExtendedPlatformInfoC13DVTFoundationE28checkMachOHeaderValuesUniqueyySayABGKFZ... (a
// Swift closure: the class object is loaded, passed through _objc_opt_self, and sent
// localizedStringByJoiningStrings: with an NSArray bridged from a [String]).  IDEFoundation binds
// the class and the same selector.  A class with an EMPTY METHOD LIST WOULD CRASH THAT CLIENT
// (unrecognized selector), so the join is implemented rather than stubbed.
//
// WHAT THE JOIN IS.  A list formatter joins items with the list pattern of a locale: for en_US the
// "standard" pattern is "A, B, and C" and for two items "A and B".  That pattern is CLDR data, and
// the only list formatter in this tree is ICU's -- the same one the payload's Swift Foundation
// binds (measured: src/external/swift/libswiftFoundation.dylib imports _ulistfmt_openForType,
// _ulistfmt_format and _ulistfmt_close), served by the libicucore this prefix deploys.
// UListFormatter with the default type (AND) and the default width (WIDE) IS the standard list
// pattern, so this is a real locale-aware join, not a fixed separator: ulistfmt_open takes the
// locale's identifier and ulistfmt_format does the joining.  Nothing here invents a separator for
// a locale ICU does not know -- with no formatter there is no string (nil), which is what Apple's
// -stringFromItems: documents for a list it cannot represent.
//
// The instance API (locale, itemFormatter, -stringFromItems:, -stringForObjectValue:) is Apple's
// declared surface for the class, implemented on the same join so that the whole class behaves
// rather than only the one selector the current client happens to send.
//

/* The item-formatting fallback Apple's header documents; declared here because NSObject in this
   tree declares neither method, so a plain send would be an undeclared selector. */
@protocol NSListFormatterItem <NSObject>
- (NSString *)descriptionWithLocale:(id)locale;
- (NSString *)localizedDescription;
@end

/* One item as the string that enters the list, or nil when neither the item formatter nor the
   item's own methods can produce one. */
static NSString *NSListFormatterStringForItem(id item, NSFormatter *itemFormatter, NSLocale *locale)
{
    if (itemFormatter != nil)
    {
        NSString *string = [itemFormatter stringForObjectValue:item];
        if (string != nil)
        {
            return string;
        }
    }

    if ([item respondsToSelector:@selector(descriptionWithLocale:)])
    {
        return [(id<NSListFormatterItem>)item descriptionWithLocale:locale];
    }
    if ([item respondsToSelector:@selector(localizedDescription)])
    {
        return [(id<NSListFormatterItem>)item localizedDescription];
    }

    return [item description];
}

/* The join itself: ICU's list formatter for `locale`, over `strings` (UTF-16, as NSString is).
   Every element must be a string -- an array that is not all strings has no representation, so
   this answers nil rather than formatting something else. */
static NSString *NSListFormatterJoinStrings(NSArray *strings, NSLocale *locale)
{
    UErrorCode status = U_ZERO_ERROR;
    UListFormatter *formatter = NULL;
    UChar **items = NULL;
    int32_t *lengths = NULL;
    UChar *result = NULL;
    NSString *joined = nil;
    NSUInteger count = [strings count];
    NSUInteger allocated = 0;
    NSUInteger i;
    int32_t capacity = 0;
    int32_t length = 0;

    formatter = ulistfmt_open([[locale localeIdentifier] UTF8String], &status);
    if (U_FAILURE(status) || formatter == NULL)
    {
        return nil;
    }

    /* ulistfmt_format requires a non-NULL strings array when the count is positive; an empty list
       is still formatted (its pattern is the empty string), so the arrays are always allocated. */
    items = calloc(count > 0 ? count : 1, sizeof(UChar *));
    lengths = calloc(count > 0 ? count : 1, sizeof(int32_t));
    if (items == NULL || lengths == NULL)
    {
        goto done;
    }
    for (i = 0; i < count; i++)
    {
        id element = [strings objectAtIndex:i];
        NSUInteger stringLength;

        if (![element isKindOfClass:[NSString class]])
        {
            goto done;
        }
        stringLength = [element length];
        items[i] = malloc((stringLength + 1) * sizeof(UChar));
        if (items[i] == NULL)
        {
            goto done;
        }
        allocated++;
        [element getCharacters:items[i] range:NSMakeRange(0, stringLength)];
        lengths[i] = (int32_t)stringLength;
        capacity += (int32_t)stringLength;
    }

    /* The joined string is never shorter than its items, so this is a safe first capacity; a
       pattern longer than that reports the size it needs and the buffer is grown once. */
    capacity += (int32_t)(16 * (count + 1));
    result = malloc((capacity + 1) * sizeof(UChar));
    if (result == NULL)
    {
        goto done;
    }

    for (;;)
    {
        status = U_ZERO_ERROR;
        length = ulistfmt_format(formatter, (const UChar *const *)items, lengths, (int32_t)count,
                                 result, capacity, &status);
        if (status == U_BUFFER_OVERFLOW_ERROR)
        {
            UChar *grown;
            capacity = length + 1;
            grown = realloc(result, (capacity + 1) * sizeof(UChar));
            if (grown == NULL)
            {
                goto done;
            }
            result = grown;
            continue;
        }
        if (U_FAILURE(status))
        {
            goto done;
        }
        break;
    }

    joined = [NSString stringWithCharacters:result length:(NSUInteger)length];

done:
    for (i = 0; i < allocated; i++)
    {
        free(items[i]);
    }
    free(items);
    free(lengths);
    free(result);
    ulistfmt_close(formatter);
    return joined;
}

@implementation NSListFormatter

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        _locale = nil;          /* nil means the current locale, as Apple's header says */
        _itemFormatter = nil;
    }
    return self;
}

- (void)dealloc
{
    [_locale release];
    [_itemFormatter release];
    [super dealloc];
}

- (NSLocale *)locale
{
    return _locale != nil ? _locale : [NSLocale autoupdatingCurrentLocale];
}

- (void)setLocale:(NSLocale *)locale
{
    NSLocale *copy = [locale copy];

    [_locale release];
    _locale = copy;
}

- (NSFormatter *)itemFormatter
{
    return _itemFormatter;
}

- (void)setItemFormatter:(NSFormatter *)itemFormatter
{
    NSFormatter *copy = [itemFormatter copy];

    [_itemFormatter release];
    _itemFormatter = copy;
}

- (NSArray *)_stringsFromItems:(NSArray *)items
{
    NSMutableArray *strings = [NSMutableArray arrayWithCapacity:[items count]];
    NSLocale *locale = [self locale];
    NSUInteger i;

    for (i = 0; i < [items count]; i++)
    {
        NSString *string = NSListFormatterStringForItem([items objectAtIndex:i], _itemFormatter, locale);
        if (string == nil)
        {
            return nil;
        }
        [strings addObject:string];
    }
    return strings;
}

+ (NSString *)localizedStringByJoiningStrings:(NSArray *)strings
{
    if (strings == nil)
    {
        return nil;
    }
    return NSListFormatterJoinStrings(strings, [NSLocale autoupdatingCurrentLocale]);
}

- (NSString *)stringFromItems:(NSArray *)items
{
    NSArray *strings;

    if (items == nil)
    {
        return nil;
    }
    strings = [self _stringsFromItems:items];
    if (strings == nil)
    {
        return nil;
    }
    return NSListFormatterJoinStrings(strings, [self locale]);
}

- (NSString *)stringForObjectValue:(id)obj
{
    if (![obj isKindOfClass:[NSArray class]])
    {
        return nil;
    }
    return [self stringFromItems:obj];
}

@end
