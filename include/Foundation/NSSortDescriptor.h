#import <Foundation/NSArray.h>
#import <Foundation/NSSet.h>

@interface NSSortDescriptor : NSObject <NSCoding, NSCopying>
{
    NSUInteger _sortDescriptorFlags;
    NSString *_key;
    SEL _selector;
    id _selectorOrBlock;
}

+ (id)sortDescriptorWithKey:(NSString *)key ascending:(BOOL)ascending;
+ (id)sortDescriptorWithKey:(NSString *)key ascending:(BOOL)ascending selector:(SEL)selector;
#if NS_BLOCKS_AVAILABLE
+ (id)sortDescriptorWithKey:(NSString *)key ascending:(BOOL)ascending comparator:(NSComparator)comparator;
#endif
- (id)initWithKey:(NSString *)key ascending:(BOOL)ascending;
- (id)initWithKey:(NSString *)key ascending:(BOOL)ascending selector:(SEL)selector;
// Declared as Apple declares them (readonly properties, key/selector nullable), so a Swift importer
// sees `descriptor.key` rather than a `key()` method -- Foundation's own SortDescriptor bridging and
// anything else written against the current SDK reads them as properties.
@property (nullable, readonly, copy) NSString *key;
@property (readonly) BOOL ascending;
@property (nullable, readonly) SEL selector;
#if NS_BLOCKS_AVAILABLE
- (id)initWithKey:(NSString *)key ascending:(BOOL)ascending comparator:(NSComparator)comparator;
- (NSComparator)comparator;
#endif
- (NSComparisonResult)compareObject:(id)obj1 toObject:(id)obj2;
- (id)reversedSortDescriptor;

@end

@interface NSSet (NSSortDescriptorSorting)

- (NSArray *)sortedArrayUsingDescriptors:(NSArray *)sortDescriptors;

@end

@interface NSArray (NSSortDescriptorSorting)

- (NSArray *)sortedArrayUsingDescriptors:(NSArray *)sortDescriptors;

@end

@interface NSMutableArray (NSSortDescriptorSorting)

- (void)sortUsingDescriptors:(NSArray *)sortDescriptors;

@end
