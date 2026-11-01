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
  Concurrent intermediate creators recheck an `EEXIST` component and converge
  only when it is now a directory. Non-directory `EEXIST` collisions, including
  dangling symlinks, preserve the original file error, path and underlying POSIX error.
- File removal reports Cocoa file-write errors with the failed path and the
  underlying POSIX error. A missing item remains a failure, reported as
  `NSFileNoSuchFileError`, so callers can distinguish absence from other errors.
  Root files and symbolic links, including dangling links, use the ordinary
  removal callback directly. Real directories use postorder physical traversal:
  removing a link, or a directory containing links, does not remove the links'
  destinations. This avoids Darwin `nftw` following its root even with
  `FTW_PHYS`; delegate decisions and error propagation remain on the same route.
- Symbolic links are created at the requested path and store the requested
  destination verbatim, including relative, unnormalized and dangling
  destinations, and the getter returns a stored destination whole even when it
  is longer than the path buffer. Creating a link rejects an occupied path with
  a Cocoa file-exists error carrying the failed path and the underlying POSIX
  error; a getter read or buffer-allocation failure is reported instead of a
  shortened destination. `test/file-io-guest.m` checks these link semantics.
- `NSFileHandle` pipe reads preserve data beyond the first buffer and stop at the
  requested length or EOF. A zero-length read does not consume stream data.
  `test/file-io-guest.m` covers directory-error recovery, symbolic-link
  creation and destination semantics, and bounded/EOF pipe reads through the
  public guest APIs.
- `-[NSFileManager subpathsOfDirectoryAtPath:error:]` retains each descendant's
  path relative to the requested root, including intervening directory names.
  Equal basenames in separate directories remain distinct and resolve when
  appended to that root. `test/file-io-guest.m` checks these paths and file
  contents, with shallow string and complete child-URL listings as controls.
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
- `NSXMLParser` rejects EOF with open elements or unfinished markup, and a
  closing tag must match the innermost open element. These failures populate
  `parserError` and notify an interested error delegate; `NSXMLDocument` then
  returns nil instead of exposing a partial tree.
  `test/xml-parser-wellformed-guest.m` checks these rejection boundaries and
  usable self-closed/nested documents through both public APIs. Compile it
  with guest `clang -fno-objc-arc -framework Foundation`.
- `-[NSString commonPrefixWithString:options:]` compares whole extended
  grapheme clusters and returns the receiver's original UTF-16 spelling.
  Default comparisons use canonical equivalence; `NSLiteralSearch` preserves
  encoding differences and `NSCaseInsensitiveSearch` applies case folding.
  CRLF pairs, surrogate pairs and regional-indicator flags are not split.
  ASCII comparisons borrow byte storage; Unicode comparisons use native ICU
  character boundaries with a borrowed or checked contiguous UTF-16 view.
  Inputs beyond ICU's Unicode iterator limit raise rather than truncate.
- `NSISO8601DateFormatter` uses the native CF ISO formatter with an ISO week
  calendar, fixed POSIX locale and configurable timezone/options. Cached
  formatters are invalidated on value changes; copies own independent caches.
  Formatting and parsing retain the real calendar, week-year, ordinal,
  fractional-second and offset semantics of the vendored corelibs provider.
  Keyed archives preserve these settings through the real `NSTimeZone` codec;
  wrong-type decoded timezone values reject the formatter.
  `NSTimeZone` uses the `NS.name` / `NS.data` archive contract and native
  class-cluster construction; concrete immutable timezones implement copying.
  These providers do not implement the archiver engine's missing secure mode.
