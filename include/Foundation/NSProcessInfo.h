#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSDictionary.h>

enum {
    NSWindowsNTOperatingSystem = 1,
    NSWindows95OperatingSystem,
    NSSolarisOperatingSystem,
    NSHPUXOperatingSystem,
    NSMACHOperatingSystem,
    NSSunOSOperatingSystem,
    NSOSF1OperatingSystem,
    NSAndroidOperatingSystem,
};

typedef struct
{
	NSInteger majorVersion;
	NSInteger minorVersion;
	NSInteger patchVersion;
}
NSOperatingSystemVersion;

@class NSArray, NSString, NSDictionary;

@interface NSProcessInfo : NSObject
{
    NSDictionary *environment; // not used it seems
    NSArray *arguments; // is really mutable
    NSString *hostName; // singly created
    NSString *name; // singly created, but replaceable
    NSInteger automaticTerminationOptOutCounter;
}

@property (class, readonly, retain) NSProcessInfo *processInfo;

@property (readonly, copy) NSDictionary<NSString *, NSString *> *environment;
- (NSArray *)arguments;
- (NSString *)hostName;
@property (copy) NSString *processName;
- (int)processIdentifier;
- (NSString *)globallyUniqueString;
- (NSUInteger)operatingSystem;
- (NSString *)operatingSystemName;
- (NSString *)operatingSystemVersionString;
- (NSUInteger)processorCount;
- (NSUInteger)activeProcessorCount;
- (unsigned long long)physicalMemory;
- (NSTimeInterval)systemUptime;
- (NSOperatingSystemVersion)operatingSystemVersion;
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version;

@end

@interface NSProcessInfo (NSSuddenTermination)
- (void)enableSuddenTermination;
- (void)disableSuddenTermination;
@end

@interface NSProcessInfo (NSProcessInfoPlatform)
-(BOOL)isMacCatalystApp;
-(BOOL)isiOSAppOnMac;
@property(readonly, getter=isMacCatalystApp) BOOL macCatalystApp;
@property(readonly, getter=isiOSAppOnMac) BOOL iOSAppOnMac;
@end

#ifdef DARLING
FOUNDATION_EXPORT void __NSInitializeProcess(int argc,const char *argv[]);
#endif
