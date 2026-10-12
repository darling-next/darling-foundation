#import <Foundation/NSFormatter.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

@class NSLocale;

/*
 NSListFormatter provides locale-correct formatting of a list of items using the appropriate
 separator and conjunction, as Apple's header of the same name does.  The class exists in this
 tree because a client binds _OBJC_CLASS_$_NSListFormatter eagerly: see src/NSListFormatter.m.
*/
@interface NSListFormatter : NSFormatter
{
    NSLocale *_locale;
    NSFormatter *_itemFormatter;
}

/* Specifies the locale to format the items. Defaults to autoupdatingCurrentLocale. Also resets to
   autoupdatingCurrentLocale on assignment of nil. */
@property (copy) NSLocale *locale;

/* Specifies how each object should be formatted. If not set, the object is formatted using its
   instance method in the following order: -descriptionWithLocale:, -localizedDescription, and
   -description. */
@property (copy) NSFormatter *itemFormatter;

/* Convenience method to return a string constructed from an array of strings using the list format
   specific to the current locale. */
+ (NSString *)localizedStringByJoiningStrings:(NSArray *)strings;

/* Convenience method for -stringForObjectValue:. Returns a string constructed from an array in the
   locale-aware format. Each item is formatted using the itemFormatter, falling back to the item's
   -descriptionWithLocale: or -localizedDescription if implemented, or -description if not.

   Returns nil if `items` is nil or if the list formatter cannot generate a string representation
   for all items in the array. */
- (NSString *)stringFromItems:(NSArray *)items;

/* Inherited from NSFormatter. `obj` must be an instance of NSArray. Returns nil if `obj` is nil,
   not an instance of NSArray, or if the list formatter cannot generate a string representation for
   all objects in the array. */
- (NSString *)stringForObjectValue:(id)obj;

@end
