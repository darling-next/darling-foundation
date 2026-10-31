# Darling Foundation

*Note: GitHub says this repository is based on gnusteps/libs-base. That was true in the past but it has since been replaced with an entirely different base project (Appportable Cocotron, and some others). We are not thousands of commits behind 😆.*

## TODO
- [ ] Remove warnings

## Conformance notes
- `-[NSDictionary writeToURL:error:]` is implemented on the public base class:
  it serializes with `CFPropertyListCreateData` (XML v1.0), writes through the
  error-preserving `NSData` writer, maps POSIX write failures to Cocoa
  `NSFileWrite*` codes and rejects non-file URL schemes. `__NSCFDictionary`
  inherits it by ordinary dispatch. Current upstream and the vendored
  swift-corelibs reference do not provide this selector.
- `NSOperationQueue.underlyingQueue` retains the supplied executor separately
  from its private serial scheduler. Non-main operations execute on that queue;
  clearing it restores global-queue execution. Scheduler bookkeeping does not
  move onto the caller's executor.
- `NSOperation` releases its copied completion block during teardown, including
  objects captured by it. This balances completed URL-session callback
  operations; completion delivery alone does not prove session/task teardown.
- `-[NSData _createDispatchData]` exposes the existing owned dispatch-data
  snapshot to ARC consumers. Each enumerated region pointer already addresses
  that region; its logical range location is not added a second time. The
  snapshot copies bytes, so it does not borrow the input object's lifetime.
  These primitives do not implement NSURLSession private transport policies.
- Directory creation reports Cocoa file-write errors with the failed path and
  the underlying POSIX error, using the existing vendored errno mapping.
  An existing directory fails without intermediate creation and succeeds with it.
- File removal reports Cocoa file-write errors with the failed path and the
  underlying POSIX error. A missing item remains a failure, reported as
  `NSFileNoSuchFileError`, so callers can distinguish absence from other errors.
- `NSFileHandle` pipe reads preserve data beyond the first buffer and stop at the
  requested length or EOF. A zero-length read does not consume stream data.
  `test/file-io-guest.m` covers directory-error recovery and bounded/EOF pipe reads
  through the public guest APIs.
- XML keyed archives must supply both `$top` and `$objects` before the decoder
  retains their contents. Missing entries raise
  `NSInvalidUnarchiveOperationException` through the legacy initializer;
  `+unarchiveTopLevelObjectWithData:error:` translates this to Cocoa error 4864.
  `test/unarchive-xml-guest.m` exercises both missing entries, the legacy
  exception, and successful decoding after failure. Compile it with guest
  `clang -fno-objc-arc -framework Foundation` and run the resulting guest binary.
  A successful decode asserts the consumer-visible decoded value; the NSError
  out-parameter is inspected only on failure, where its domain and code are
  checked. The decoder releases each owned map exactly once and does not decode
  an array element whose offset/UID could not be read; a valid archive still
  decodes after any number of rejected ones.
- `-[NSDictionary classForCoder]` is implemented on the public base class so
  every Foundation subclass answers the concrete `NSDictionary` /
  `NSMutableDictionary` class, as the keyed archiver requires. A bridged Swift
  `Dictionary` is the measured case: without this it encoded its mangled
  `_SwiftDeferredNSDictionary` runtime name, which `NSClassFromString` cannot
  resolve, so a valid archive decoded as nil with Cocoa error 4865.
  `overlays/tests/unarchive_top_level.swift` covers the round trip.
- `-[NSNumber _reverseCompare:]` is CoreFoundation's equality direction for an
  Objective-C number compared against a `CFNumber`; equal values must answer
  `NSOrderedSame`. Mapping equality to `NSOrderedDescending` made a decoded
  `CFNumber` report itself unequal to an equal number literal
  (`NSConstantIntegerNumber`), while the reverse direction compared equal.
