#import <Foundation/NSData.h>

void *_NSReadBytesFromFile(NSString *path, NSDataReadingOptions readOptionsMask, NSUInteger *length, BOOL *vm, NSError **err) CF_PRIVATE;
BOOL _NSWriteBytesToFile(NSData *data, id pathOrURL, NSDataWritingOptions options, NSError **errorPtr) CF_PRIVATE;

// The file-error constructor Foundation reports a failed file operation with: the errno maps to the
// NSFileRead*/NSFileWrite* Cocoa code for the direction of the failed call, the path (or URL, keyed
// the way the argument's class implies) is stored, and the POSIX error becomes NSUnderlyingError.
// Defined in _NSFileIO.m; the plist readers in NSDictionary.m need it for the same reason this file's
// own readers do.
NSError *_NSErrorWithFilePathErrnoAndVariant(int posixErrno, id path, int variant, intptr_t unmeasured);
