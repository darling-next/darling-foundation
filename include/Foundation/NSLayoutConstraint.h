#import <Foundation/NSObject.h>

@class NSString;

// AppKit's NSLayoutConstraint.h declares these too, under the same guards:
// Swift nests a type only into a class of its own module, and the class is here.
#if !__NSLAYOUT_PRIORITY_SHARED_SECTION__
#define __NSLAYOUT_PRIORITY_SHARED_SECTION__ 1
typedef float NSLayoutPriority NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(NSLayoutConstraint.Priority);

static const NSLayoutPriority NSLayoutPriorityRequired NS_SWIFT_NAME(required) = 1000;
static const NSLayoutPriority NSLayoutPriorityDefaultHigh NS_SWIFT_NAME(defaultHigh) = 750;
static const NSLayoutPriority NSLayoutPriorityDefaultLow NS_SWIFT_NAME(defaultLow) = 250;
static const NSLayoutPriority NSLayoutPriorityFittingSizeCompression NS_SWIFT_NAME(fittingSizeCompression) = 50;
#endif

#if !__NSLAYOUT_ORIENTATION_SHARED_SECTION__
#define __NSLAYOUT_ORIENTATION_SHARED_SECTION__ 1
typedef NS_ENUM(NSInteger, NSLayoutConstraintOrientation) {
    NSLayoutConstraintOrientationHorizontal = 0,
    NSLayoutConstraintOrientationVertical = 1,
} NS_SWIFT_NAME(NSLayoutConstraint.Orientation);
#endif

@interface NSLayoutConstraint : NSObject
{
    id _firstItem;
    NSInteger _firstAttribute;
    NSInteger _relation;
    id _secondItem;
    NSInteger _secondAttribute;
    double _multiplier;
    double _constant;
    float _priority;
    NSString *_identifier;
    NSString *_symbolicConstant;
    BOOL _active;
    BOOL _shouldBeArchived;
    id _owner;
}

@end
