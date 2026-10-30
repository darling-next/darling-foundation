//
//  NSURL.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSURL.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSException.h>
#import "NSObjectInternal.h"
#import "NSURLInternal.h"
#import <Foundation/NSCoder.h>
#import <Foundation/NSData.h>
#import "ForFoundationOnly.h"
#import <CoreFoundation/CFNumber.h>
#import <CoreFoundation/CFURL.h>
#import <objc/runtime.h>

// Private classes
@interface NSURLFileTypeMappings : NSObject
@end

@implementation NSURLFileTypeMappings
@end

@interface NSURLFileTypeMappingsInternal : NSObject
@end

@implementation NSURLFileTypeMappingsInternal
@end

@implementation NSURL (NSURL)

OBJC_PROTOCOL_IMPL_PUSH
- (id)initFileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir
{
    NSUInteger length = [path length];
    if (length != 0)
    {
        if (![path isAbsolutePath])
        {
            path = [path stringByStandardizingPath];
            length = [path length];
        }
#if 0 // we're supposed to blindly trust the input
        if ([path characterAtIndex:length - 1] == '/')
        {
            isDir = YES;
        }
#endif

#if 0 // nope, we're not supposed to "catch the dirty lies from the user"
        BOOL isDirectory = NO;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
        if (exists && isDir != isDirectory) // catch the dirty lies from the user?
        {
            [self release];
            return nil;
        }
#endif

        [self release];
        self = (NSURL*) CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)path, kCFURLPOSIXPathStyle, isDir);
        return self;
    }
    else
    {
        [self release];
        return nil;
    }
}

- (id)initFileURLWithPath:(NSString *)path
{
    if (path == nil)
    {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"path cannot be nil"];
        return nil;
    }
    BOOL isDir = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
    
	[self release];
	self = (NSURL*) CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)path, kCFURLPOSIXPathStyle, isDir);

    return self;
}

// The designated initializer of the file-URL-with-base family (the SDK declares it
// NS_DESIGNATED_INITIALIZER, macOS 10.11+). Every decision here belongs to CoreFoundation's
// CFURLCreateWithFileSystemPathRelativeToBase, which is the runtime's own implementation of these
// semantics and therefore the only one that cannot drift from the rest of the URL code:
//
//   * an absolute path IGNORES the base ("if fileSystemPath is an absolute path, ignore baseURL
//     (if provided)", CFURL.c _CFURLCreateWithFileSystemPath), so baseURL is nil on the result;
//   * a relative path is kept relative and the base is stored (absolute-ised), so relativeString
//     is the path as given and absoluteURL/absoluteString resolve against the base;
//   * an empty path WITH a base IS the base ("else if (baseURL) { result = CFRetain(baseURL); }"),
//     which is also what the vendored swift-corelibs reference does with the base's own path;
//   * a relative path with NO base falls back to the current directory, exactly like the
//     non-relative initializer above.
//
// The isDirectory flag is passed through unexamined: the SDK documents the flag as the caller's
// statement about the file system, and the tree's existing initializer says the same ("we're
// supposed to blindly trust the input").
- (id)initFileURLWithPath:(NSString *)path relativeToURL:(NSURL *)baseURL
{
    /* The two-argument initializer Darwin documents (NSURL.h) and SwiftPM calls; without it the guest raised
     * "-[NSURL initFileURLWithPath:relativeToURL:]: unrecognized selector" and died with SIGILL (measured with a
     * one-line probe: `[NSURL fileURLWithPath:@".build/checkouts/x" relativeToURL:base]`, rc=132). `isDirectory`
     * is NO, exactly like the matching class method. */
    return [self initFileURLWithPath:path isDirectory:NO relativeToURL:baseURL];
}

- (id)initFileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir relativeToURL:(NSURL *)baseURL
{
    if (path == nil)
    {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"path cannot be nil"];
        return nil;
    }
    if ([path length] == 0 && baseURL == nil)
    {
        [self release];
        return nil;
    }

    [self release];
    self = (NSURL*) CFURLCreateWithFileSystemPathRelativeToBase(kCFAllocatorDefault, (CFStringRef)path, kCFURLPOSIXPathStyle, isDir, (CFURLRef)baseURL);
    return self;
}
OBJC_PROTOCOL_IMPL_POP

- (id)initFileURLWithFileSystemRepresentation:(const char *)path isDirectory:(BOOL)isDir relativeToURL:(NSURL *)baseURL
{
    if ([self class] == [NSURL class])
    {
        [self release];
        self = (NSURL*) CFURLCreateFromFileSystemRepresentationRelativeToBase(kCFAllocatorDefault, (const UInt8 *)path, strlen(path), isDir, (CFURLRef)baseURL);
    }
    else
    {
        self = [super init];

        if (self)
        {
            _reserved = (void *)CFURLCreateFromFileSystemRepresentationRelativeToBase(kCFAllocatorDefault, path, strlen(path), isDir, (CFURLRef)baseURL);
        }
    }
    return self;
}

+ (id)allocWithZone:(NSZone *)zone
{
    if (self == [NSURL class])
    {
        return (NSURL *)CFURLCreateWithString(kCFAllocatorDefault, @"", NULL);
    }
    else
    {
        return [super allocWithZone:zone];
    }
}

OBJC_PROTOCOL_IMPL_PUSH
+ (id)fileURLWithFileSystemRepresentation:(const char *)path isDirectory:(BOOL)isDir relativeToURL:(NSURL *)baseURL
{
    return [[[self alloc] initFileURLWithFileSystemRepresentation:path isDirectory:isDir relativeToURL:baseURL] autorelease];
}

+ (id)fileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir
{
    return [[[self alloc] initFileURLWithPath:path isDirectory:isDir] autorelease];
}

+ (id)fileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir relativeToURL:(NSURL *)baseURL
{
    return [[[self alloc] initFileURLWithPath:path isDirectory:isDir relativeToURL:baseURL] autorelease];
}

+ (id)fileURLWithPath:(NSString *)path relativeToURL:(NSURL *)baseURL
{
    /* See -initFileURLWithPath:relativeToURL: above: Darwin declares this pair and the guest called it. */
    return [[[self alloc] initFileURLWithPath:path relativeToURL:baseURL] autorelease];
}

+ (id)fileURLWithPath:(NSString *)path
{
    return [[[self alloc] initFileURLWithPath:path] autorelease];
}

+ (id)URLWithString:(NSString *)str relativeToURL:(NSURL *)url
{
    if (str == nil)
    {
        return nil; 
        // See initWithString:relativeToURL:
        // This is the lack of consistency Gotham needs right now, not the consistency Gotham deserves. 
    }
    return [[[self alloc] initWithString:str relativeToURL:url] autorelease];
}

+ (id)URLWithString:(NSString *)str
{
    return [self URLWithString:str relativeToURL:nil];
}

- (BOOL)isFileURL
{
    return _CFURLIsFileURL([self _cfurl]);
}

- (NSString *)fragment
{
    return [(NSString *)CFURLCopyFragment([self _cfurl], NULL) autorelease];
}

- (NSString *)query
{
    return [(NSString *)CFURLCopyQueryString([self _cfurl], NULL) autorelease];
}

- (NSString *)parameterString
{
    return [(NSString *)CFURLCopyParameterString([self _cfurl], NULL) autorelease];
}

- (NSString *)path
{
    CFURLRef absolute = CFURLCopyAbsoluteURL([self _cfurl]);
    NSString *path = (NSString *)CFURLCopyFileSystemPath(absolute, kCFURLPOSIXPathStyle);
    CFRelease(absolute);
    return [path autorelease];
}

- (NSString *)relativePath
{
    return [(NSString *)CFURLCopyFileSystemPath([self _cfurl], kCFURLPOSIXPathStyle) autorelease];
}

- (NSString *)password
{
    return [(NSString *)CFURLCopyPassword([self _cfurl]) autorelease];
}

- (NSString *)user
{
    return [(NSString *)CFURLCopyUserName([self _cfurl]) autorelease];
}

- (NSNumber *)port
{
    SInt32 port = CFURLGetPortNumber([self _cfurl]);
    if (port != -1) // NOTE: it seems that a url as such http://www.apportable.com:-2 is a valid port according to tests
    {
        id num = (id)CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &port);
        return [num autorelease];
    }
    else
    {
        return nil;
    }
}

- (NSString *)host
{
    return [(NSString *)CFURLCopyHostName([self _cfurl]) autorelease];
}
OBJC_PROTOCOL_IMPL_POP

- (id)standardizedURL
{
    NSURL *standardized = nil;
    CFURLComponentsRFC1808 comps;
    while (_CFURLCopyComponents([self _cfurl], kCFURLComponentDecompositionRFC1808, &comps))
    {
        if (comps.pathComponents == NULL)
        {
            break;
        }
        NSMutableArray *components = (NSMutableArray *)CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, comps.pathComponents);
        CFRelease(comps.pathComponents);
        comps.pathComponents = (CFArrayRef)components;

        NSUInteger lastCount, currentCount;
        do {
            BOOL foundUpDir = NO;
            BOOL foundCurrentDir = NO;
            currentCount = [components count];
            NSUInteger idx = [components indexOfObject:@".."];
            if (idx != NSNotFound)
            {
                foundUpDir = YES;
                [components removeObjectAtIndex:idx];
                if (idx > 0)
                {
                    [components removeObjectAtIndex:idx - 1];
                }
            }
            idx = [components indexOfObject:@"."];
            if (idx != NSNotFound)
            {
                foundCurrentDir = YES;
                [components removeObjectAtIndex:idx];
            }
            if (!foundUpDir && !foundCurrentDir)
            {
                break;
            }
            lastCount = [components count];
        } while (lastCount != currentCount);


        standardized = (NSURL *)_CFURLCreateFromComponents(kCFAllocatorDefault, kCFURLComponentDecompositionRFC1808, &comps);
        break;
    }

    if (comps.scheme)
    {
        CFRelease(comps.scheme);
    }
    if (comps.user)
    {
        CFRelease(comps.user);
    }
    if (comps.password)
    {
        CFRelease(comps.password);
    }
    if (comps.host)
    {
        CFRelease(comps.host);
    }
    if (comps.pathComponents)
    {
        CFRelease(comps.pathComponents);
    }
    if (comps.parameterString)
    {
        CFRelease(comps.parameterString);
    }
    if (comps.query)
    {
        CFRelease(comps.query);
    }
    if (comps.fragment)
    {
        CFRelease(comps.fragment);
    }
    if (comps.baseURL)
    {
        CFRelease(comps.baseURL);
    }

    return [standardized autorelease];
}

OBJC_PROTOCOL_IMPL_PUSH
- (NSURL *)absoluteURL
{
    return [(NSURL *)CFURLCopyAbsoluteURL([self _cfurl]) autorelease];
}

- (NSString *)absoluteString
{
    CFURLRef url = CFURLCopyAbsoluteURL([self _cfurl]);
    CFStringRef str = CFRetain(CFURLGetString(url));
    CFRelease(url);
    return [(NSString *)str autorelease];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}
OBJC_PROTOCOL_IMPL_POP

- (id)description
{
    NSURL *base = [self baseURL];

    if (base != nil)
    {
        return [NSString stringWithFormat:@"%@ -- %@", [self relativeString], base];
    }
    else
    {
        return [self absoluteString];
    }
}

OBJC_PROTOCOL_IMPL_PUSH
- (id)initWithCoder:(NSCoder *)coder
{
    NSURL *base = nil;
    NSString *relative = nil;
    if ([coder allowsKeyedCoding])
    {
        base = [coder decodeObjectForKey:@"NS.base"];
        relative = [coder decodeObjectForKey:@"NS.relative"];
    }
    else
    {
        BOOL hasBase = NO;
        [coder decodeValueOfObjCType:@encode(BOOL) at:&hasBase];
        if (hasBase)
        {
            base = [coder decodeObject];
        }
        relative = [coder decodeObject];
    }
    return [self initWithString:relative relativeToURL:base];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if ([coder allowsKeyedCoding])
    {
        [coder encodeObject:[self baseURL] forKey:@"NS.base"];
        [coder encodeObject:[self relativeString] forKey:@"NS.relative"];
    }
    else
    {
        NSURL *baseURL = [self baseURL];
        BOOL hasBase = baseURL != nil;
        [coder encodeValueOfObjCType:@encode(BOOL) at:&hasBase];
        if (hasBase)
        {
             [coder encodeObject:baseURL];   
        }
        else
        {
            [coder encodeObject:[self relativeString]];
        }
    }
}
OBJC_PROTOCOL_IMPL_POP

- (NSUInteger)hash
{
    return CFHash([self _cfurl]);
}

- (BOOL)isEqual:(id)other
{
    if (other == nil)
    {
        return NO;
    }
    id compare = other;
    if ([other isKindOfClass:[NSURL class]])
    {
        compare = (id)[other _cfurl];
    }
    return CFEqual([self _cfurl], compare);
}

OBJC_PROTOCOL_IMPL_PUSH
- (id)initWithScheme:(NSString *)scheme host:(NSString *)host path:(NSString *)path
{
    if (![path isAbsolutePath])
    {
        [NSException raise:NSInvalidArgumentException format:@"path must be absolute %@", path];
    }
    NSString *escapedHost = [host stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *standardizedPath = [path stringByStandardizingPath];
    if (scheme == nil)
    {
        scheme = @"http";
    }

    return [self initWithString:[NSString stringWithFormat:@"%@://%@%@", scheme, escapedHost, standardizedPath]];
}

- (id)initWithString:(NSString *)string
{
    return [self initWithString:string relativeToURL:nil];
}
OBJC_PROTOCOL_IMPL_POP

- (id)init
{
    [self release]; // this is a silent failure on iOS
    return nil;
}

- (id)resourceSpecifier
{
    if (![self _isAbsolute])
    {
        return [self relativeString];
    }
    else
    {
        CFURLRef url = [self _cfurl];

        if (url == NULL)
        {
            return nil; // how can this happen in the wild?
        }
        
        if (!CFURLCanBeDecomposed(url))
        {
            return [(NSString *)CFURLCopyResourceSpecifier(url) autorelease];
        }
        else
        {
            if (CFURLGetBaseURL(url) == NULL)
            {
                NSString *loc = [(NSString *)CFURLCopyNetLocation(url) autorelease];
                NSString *path = [(NSString *)CFURLCopyPath(url) autorelease];
                NSString *res = [(NSString *)CFURLCopyResourceSpecifier(url) autorelease];
                if (loc == nil)
                {
                    // lots of stuff here!
                    if (path == nil)
                    {
                        return nil;
                    }
                    
                    if (res == nil)
                    {
                        return path;
                    }
                    
                    return [NSString stringWithFormat:@"%@%@", path, res];
                }
                else if (path == nil)
                {
                    return [NSString stringWithFormat:@"//%@", loc];
                }
                else if (res != nil)
                {
                    return [NSString stringWithFormat:@"//%@%@%@", loc, path, res];
                }
                else
                {
                    return [NSString stringWithFormat:@"//%@%@", loc, path];
                }
            }
            else
            {
                return (NSString *)CFURLGetString(url);
            }
        }
    }
}

- (BOOL)_isAbsolute
{
    if ([self baseURL] == nil)
    {
        return [self scheme] != nil;
    }
    return YES;
}

- (id)_relativeURLPath
{
    return [(NSString *)CFURLCopyPath([self _cfurl]) autorelease];
}

- (id)scheme
{
    return [(NSString *)CFURLCopyScheme([self _cfurl]) autorelease];
}

- (id)baseURL
{
    return (NSURL *)CFURLGetBaseURL([self _cfurl]);
}

- (id)relativeString
{
    return (NSString *)CFURLGetString([self _cfurl]);
}


/* Diagnostic: NSURL_TRACE=1 prints every Foundation NSURL's identity, its CFURL, and the CF type of that CFURL,
 * so a run that retains a freed URL shows whether the wrapper or the CFURL behind it died first. Inert without
 * the variable. */
/* DARLING_DIAG=url-life is the shared spelling (docs/tooling.md); NSURL_TRACE stays honoured. */
static int _darlDiagHas(const char *token) {
    static const char *all = NULL;
    static int cached = 0;
    if (!cached) { all = getenv("DARLING_DIAG"); cached = 1; }
    if (all == NULL || *all == 0) return 0;
    size_t n = strlen(token);
    for (const char *p = all; (p = strstr(p, token)) != NULL; p += n) {
        int before = (p == all) || (p[-1] == ',');
        int after = (p[n] == 0) || (p[n] == ',');
        if (before && after) return 1;
    }
    return 0;
}
static int _nsurlTraceOn(void) {
    static int on = -1;
    if (on < 0) { const char *e = getenv("NSURL_TRACE"); on = (e && *e && *e != '0') || _darlDiagHas("url-life"); }
    return on;
}
static void _nsurlTrace(const char *what, id self, CFTypeRef cf) {
    if (!_nsurlTraceOn()) return;
    uint32_t cfinfo = cf ? *(uint32_t *)((char *)cf + 8) : 0;
    unsigned tid = (cfinfo >> 8) & 0x3FF;
    long rc = -1;
    if (cf && tid != 0 && tid < 200) rc = (long)CFGetRetainCount(cf);
    fprintf(stderr, "[nsurl] %s self=%p cls=%s cfurl=%p cftype=%u rc=%ld\n",
            what, (void *)self, object_getClassName(self), (void *)cf, tid, rc);
    fflush(stderr);
}

- (void)dealloc
{
    _nsurlTrace("dealloc", self, [self _cfurl]);
    [self _freeClients];
    if (object_getClass(self) != [NSURL class])
    {
        [(id)_reserved release];
    }
    [super dealloc];
}

- (void)_freeClients
{
    CFURLRef url = [self _cfurl];
    CFDictionaryRef reserved = __CFURLReservedPtr(url);
    if (reserved != NULL)
    {
        CFRelease(reserved);
        __CFURLSetReservedPtr(url, NULL);
    }
}

- (CFDictionaryRef)_clientsCreatingIfNecessary:(BOOL)create
{
    CFURLRef url = [self _cfurl];
    CFDictionaryRef reserved = __CFURLReservedPtr(url);
    if (reserved == NULL && create)
    {
        reserved = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
        __CFURLSetReservedPtr(url, (void *)reserved);
    }
    return reserved;
}

- (CFURLRef)_cfurl
{
    // A CFURL carries the class CF registered for it, and Foundation's NSURL is a DIFFERENT class
    // object with the same name (both trees implement `@implementation NSURL`). Comparing class
    // identity alone therefore sends every real CFURL to the `_reserved` branch, which reads the
    // NSObject ivar at an offset a CFRuntime object does not have: MEASURED 2026-10-22 as
    // `-[NSConcreteMapTable _cfurl]: unrecognized selector`, thrown from DVTFoundation's
    // `_launchServicesUTIForFileAtURL:` -> `-[NSURL getResourceValue:forKey:error:]` ->
    // `CFURLCopyResourcePropertyForKey` after `_cfurl` returned that table as if it were a URL,
    // which xcodebuild then reports as an uncaught exception and aborts on (SIGILL/SIGSEGV, rc
    // 132/139, intermittently). `_CFIsObjC` is CF's own discriminator and answers this question
    // without the class-identity assumption.
    if (object_getClass(self) == [NSURL class] || !_CFIsObjC(CFURLGetTypeID(), (void *)self))
    {
        return (CFURLRef)self;
    }
    else
    {
        return _reserved;
    }
}

OBJC_PROTOCOL_IMPL_PUSH
- (id)initWithString:(NSString *)string relativeToURL:(NSURL *)url
{
    if ([self class] == [NSURL class])
    {
		[self release];
        self = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)string, [url _cfurl]);
    }
    else
    {
        self = [super init];

        if (self)
        {
            _reserved = (void *)CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)string, (CFURLRef)url);
        }
    }
    return self;
}
OBJC_PROTOCOL_IMPL_POP

// What is this for?
#if 0
- (id)_initWithMinimalBookmarkData:(id)minimalBookmarkData
{

}
#endif

- (CFTypeID)_cfTypeID
{
    return CFURLGetTypeID();
}

- (BOOL)_isDeallocating
{
    return _CFIsDeallocating([self _cfurl]);
}

- (BOOL)_tryRetain
{
    return _CFTryRetain([self _cfurl]) != NULL;
}

- (NSUInteger)retainCount
{
    return CFGetRetainCount([self _cfurl]);
}

- (oneway void)release
{
    CFURLRef url = [self _cfurl];
    _nsurlTrace("release", self, url);
    /* This wrapper has its own identity but forwards retain/release to the CFURL it wraps, so the two counts are
     * one count. When this release is the CFURL's last reference the CFURL dies; the wrapper must die with it in
     * the same step, otherwise a later -retain messages an object whose CFURL is already gone. MEASURED
     * 2026-10-23 as the intermittent xcodebuild crash: Xcode's PathEntryBackedURL wrapper outlived its CFURL and
     * -[NSURL retain] then dispatched -retain to freed memory (evidence section 73). */
    if (url != NULL && (CFTypeRef)url == (CFTypeRef)_reserved && CFGetRetainCount(url) == 1)
    {
        _reserved = NULL;
        CFRelease(url);
        [self dealloc];
        return;
    }
    CFRelease(url);
}

- (id)retain
{
    _nsurlTrace("retain", self, [self _cfurl]);
    CFRetain([self _cfurl]);
    return self;
}

- (NSURL *)URLByAppendingPathComponent:(NSString *)pathComponent
{
    return [self URLByAppendingPathComponent:pathComponent isDirectory:NO];
}

- (NSURL *)URLByAppendingPathComponent:(NSString *)pathComponent isDirectory:(BOOL)isDirectory
{
    return [(NSURL *)CFURLCreateCopyAppendingPathComponent(CFGetAllocator([self _cfurl]), [self _cfurl], (CFStringRef) pathComponent, isDirectory) autorelease];
}

@end

@implementation NSURL (NSURLPathUtilities)

+ (NSURL *)fileURLWithPathComponents:(NSArray *)components
{
    return [NSURL fileURLWithPath:[components componentsJoinedByString:@"/"]];
}

- (NSArray *)pathComponents
{
    return [[self path] pathComponents];
}

- (NSString *)lastPathComponent
{
    return [[self path] lastPathComponent];
}

- (NSString *)pathExtension
{
    return [[self path] pathExtension];
}

- (NSURL *)URLByAppendingPathComponent:(NSString *)pathComponent
{
    if (pathComponent == nil)
    {
        [NSException raise:NSInvalidArgumentException format:@"cannot append nil path component"];
        return nil;
    }

    BOOL isDirectory = NO;
    if (![pathComponent hasSuffix:@"/"])
    {
        if ([self isFileURL])
        {
            NSNumber *val = nil;
            if ([self getResourceValue:&val forKey:NSURLIsDirectoryKey error:NULL])
            {
                if (![val boolValue])
                {
                    return nil;
                }
            }
        }
    }

    return [self URLByAppendingPathComponent:pathComponent isDirectory:isDirectory];
}

- (NSURL *)URLByAppendingPathComponent:(NSString *)pathComponent isDirectory:(BOOL)isDirectory
{
    if (pathComponent == nil)
    {
        [NSException raise:NSInvalidArgumentException format:@"cannot append nil path component"];
        return nil;
    }

    return [(NSURL *)CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault, [self _cfurl], (CFStringRef)pathComponent, isDirectory) autorelease];
}

- (NSURL *)URLByDeletingLastPathComponent
{
    return [(NSURL *)CFURLCreateCopyDeletingLastPathComponent(kCFAllocatorDefault, [self _cfurl]) autorelease];
}

- (NSURL *)URLByAppendingPathExtension:(NSString *)pathExtension
{
    return [(NSURL *)CFURLCreateCopyAppendingPathExtension(kCFAllocatorDefault, [self _cfurl], (CFStringRef)pathExtension) autorelease];
}

- (NSURL *)URLByDeletingPathExtension
{
    return [(NSURL *)CFURLCreateCopyDeletingPathExtension(kCFAllocatorDefault, [self _cfurl]) autorelease];
}

- (NSURL *)URLByStandardizingPath
{
    if ([self isFileURL])
    {
        if ([self isFileReferenceURL])
        {
            return [self filePathURL];
        }
        else
        {
            return [NSURL fileURLWithPath:[[self path] stringByStandardizingPath]];
        }
    }
    return self;
}

- (NSURL *)URLByResolvingSymlinksInPath
{
    if ([self isFileURL])
    {
        if ([self isFileReferenceURL])
        {
            return [self filePathURL];
        }
        else
        {
            return [NSURL fileURLWithPath:[[self path] stringByResolvingSymlinksInPath]];
        }
    }
    return self;
}

OBJC_PROTOCOL_IMPL_PUSH
- (BOOL)getFileSystemRepresentation:(char *)buffer maxLength:(NSUInteger)maxBufferLength
{
    return CFURLGetFileSystemRepresentation([self _cfurl], true, buffer, maxBufferLength);
}

- (const char *)fileSystemRepresentation NS_RETURNS_INNER_POINTER
{
    CFURLRef url = [self _cfurl];
    if (url == NULL)
    {
        [NSException raise:NSInvalidArgumentException format:@"the url %p was not initialized", self];
        return NULL;
    }
    size_t sz = 1024;
    
    UInt8 *buffer = malloc(sz);
    if (buffer == NULL)
    {
        [NSException raise:NSMallocException format:@"Could not allocate 1024 bytes for file url"];
        return NULL;
    }

    if (CFURLGetFileSystemRepresentation(url, true, buffer, sz))
    {
        return (const char *)[[NSData dataWithBytesNoCopy:buffer length:sz] bytes];
    }

    CFStringRef path = CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle);
    sz = CFStringGetMaximumSizeOfFileSystemRepresentation(path);
    CFRelease(path);
    if (sz > 1024)
    {
        UInt8 *new_buffer = (UInt8 *)realloc(buffer, sz);
        if (new_buffer == NULL)
        {
            free(buffer);
            [NSException raise:NSMallocException format:@"Could not allocate %zu bytes for file url", sz];
            return NULL;
        }
        buffer = new_buffer;
    }

    if (!CFURLGetFileSystemRepresentation(url, true, buffer, sz))
    {
        free(buffer);
        [NSException raise:NSInvalidArgumentException format:@"Unable to convert url %@ to file system representation", self];
        return NULL;
    }
    
    return (const char *)[[NSData dataWithBytesNoCopy:buffer length:sz] bytes];
}
OBJC_PROTOCOL_IMPL_POP

@end

@implementation NSURLQueryItem
@end
