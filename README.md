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
