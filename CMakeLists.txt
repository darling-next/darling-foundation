project(foundation)

remove_sdk_framework(Foundation)

add_subdirectory(services/filecoordinationd)

if(ENABLE_TESTS)
	add_subdirectory(test)
endif()

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -nostdinc -mmacosx-version-min=10.10 \
	-include ${CMAKE_SOURCE_DIR}/src/external/corefoundation/CoreFoundation_Prefix.h \
	-include ${CMAKE_SOURCE_DIR}/src/external/corefoundation/macros.h")

include(darling_framework)

include_directories(
	${CMAKE_SOURCE_DIR}/src/external/corefoundation # for `ForFoundationOnly.h`
	${CMAKE_CURRENT_SOURCE_DIR}/include/Foundation
	${CMAKE_CURRENT_SOURCE_DIR}/src
)

add_definitions(
	-DNSBUILDINGFOUNDATION=1
	-DINCLUDE_OBJC
	-DDEPLOYMENT_TARGET_MACOSX=1
	-D__CONSTANT_CFSTRINGS__=1
	-D__CONSTANT_STRINGS__=1
	-DOBJC_OLD_DISPATCH_PROTOTYPES=1
)

set(foundation_sources
	src/_DebugUtils.m
	src/NSAppleScript.m
	src/NSAddressCheckingResult.m
	src/NSAffineTransform.m
	src/NSAggregateExpression.m
	src/NSAnyKeyExpression.m
	src/NSArchiver.m
	src/NSArray.m
	src/NSAttributedString.m
	src/NSAutoreleasePool.m
	src/NSBetweenPredicateOperator.m
	src/NSBlockExpression.m
	src/NSBlockPredicate.m
	src/NSBOMEncoding.m
	src/NSBundle.m
	src/NSByteCountFormatter.m
	src/NSCalendar.m
	src/NSCheapMutableString.m
	src/NSClassDescription.m
	src/NSCoder.m
	src/NSComparisonPredicate.m
	src/NSComparisonPredicateOperator.m
	src/NSCompoundPredicate.m
	src/NSCompoundPredicateOperator.m
	src/NSConstantValueExpression.m
	src/NSCustomPredicateOperator.m
	src/NSDataDetector.m
	src/NSData.m
	src/NSDateFormatter.m
	src/NSDateCheckingResult.m
	src/NSDate.m
	src/NSDebug.m
	src/NSDecimal.m
	src/NSDecimalNumber.m
	src/NSDictionary.m
	src/NSDirectoryEnumerator.m
	src/NSDistributedNotificationCenter.m
	src/NSEqualityPredicateOperator.m
	src/NSException.m
	src/NSExpression.m
	src/NSExternals.m
	src/NSFalsePredicate.m
	src/NSFileAttributes.m
	src/NSFileCoordinator.m
	src/NSFileHandle.m
	src/_NSFileIO.m
	src/NSFileManager.m
	src/NSFilesystemItemRemoveOperation.m
	src/NSFormatter.m
	src/NSFunctionExpression.m
	src/NSGeometry.m
	src/NSGrammarCheckingResult.m
	src/NSHashTable.m
	src/NSHost.m
	src/NSIndexPath.m
	src/NSIndexSet.m
	src/NSInPredicateOperator.m
	src/NSItemProvider.m
	src/NSJSONSerialization.m
	src/NSKeyedArchiver.m
	src/_NSKeyedCoderOldStyleArray.m
	src/NSKeyedUnarchiver.m
	src/NSKeyPathExpression.m
	src/NSKeyPathSpecifierExpression.m
	src/NSKeyValueAccessor.m
	src/NSKeyValueCodingInternal.m
	src/NSKeyValueCoding.m
	src/NSKeyValueCollectionProxies.m
	src/NSKeyValueComputedProperty.m
	src/NSKeyValueContainerClass.m
	src/NSKeyValueChangeDictionary.m
	src/NSKeyValueNestedProperty.m
	src/NSKeyValueObservance.m
	src/NSKeyValueObservationInfo.m
	src/NSKeyValueObserving.m
	src/NSKeyValueProperty.m
	src/NSKeyValueUnnestedProperty.m
	src/NSLikePredicateOperator.m
	src/NSLinguisticTagger.m
	src/NSLinkCheckingResult.m
	src/NSListFormatter.m
	src/NSLocale.m
	src/NSLocalizableString.m
	src/NSLock.m
	src/NSLog.m
	src/NSMapTable.m
	src/NSMatchingPredicateOperator.m
	src/NSMutableStringProxy.m
	#src/NSMutableStringProxyForMutableAttributedString.m # duplicate?!
	src/NSNestedDictionary.m
	src/NSNetServices.m
	src/NSNotificationCenter.m
	src/NSNotification.m
	src/NSNotificationQueue.m
	src/NSNumberFormatter.m
	src/NSNumber.m
	src/NSObjCRuntime.m
	src/NSObjectInternal.m
	src/NSObject+NSComparisonMethods.m
	src/NSObject+NSScriptClassDescription.m
	src/NSOperation.m
	src/NSOrthographyCheckingResult.m
	src/NSOrthography.m
	src/NSPathStore.m
	src/NSPathUtilities.m
	src/NSPersonNameComponents.m
	src/NSPhoneNumberCheckingResult.m

	src/NSPlatform_Apportable.m  # unrelated
	src/NSPlatform.m
	src/NSPlatform_posix.m
	src/NSPlatform_darwin.m

	src/NSPort.m
	src/NSSocketPort.m
	src/NSSocketPortNameServer.m
	src/NSPortCoder.m
	src/NSPortMessage.m
	src/NSConcretePortCoder.m
	src/NSUnkeyedPortCoder.m
	src/NSKeyedPortCoder.m
	src/NSConnection.m
	src/NSDistantObject.m
	src/NSDistantObjectRequest.m
	src/NSConcreteDistantObjectRequest.m
	src/NSProtocolChecker.m
	src/NSConcreteProtocolChecker.m
	src/NSPortNameServer.m
	src/NSMachBootstrapServer.m

	src/NSPointerArray.m
	src/NSPointerFunctions.m
	src/NSPredicateLexer.m
	src/NSPredicate.m
	src/NSPredicateOperator.m
	src/NSPredicateParser.tab.c
	src/_NSPredicateOperatorUtilities.m
	src/_NSPredicateUtilities.m
	src/NSProcessInfo.m
	src/NSProgress.m
	src/NSProxy.m
	src/NSRange.m
	src/NSRangeEntries.m
	src/NSRaise.m
	src/NSRegularExpressionCheckingResult.m
	src/NSRegularExpression.m
	src/NSRunLoop.m
	src/NSScanner.m
	src/NSSelfExpression.m
	src/NSSetExpression.m
	src/NSSet.m
	src/NSSortDescriptor.m
	src/NSSpellCheckingResult.m
	src/NSString.m
	src/NSStringPredicateOperator.m
	src/NSSubqueryExpression.m
	src/NSSubstitutionCheckingResult.m
	src/NSSubstringPredicateOperator.m
	src/NSSymbolicExpression.m
	src/NSTask.m
	src/NSTernaryExpression.m
	src/NSTextCheckingResult.m
	src/NSThread.m
	src/NSTimer.m
	src/NSTimeZone.m
	src/NSTokenMatchingPredicateOperator.m
	src/NSTransitInformationCheckingResult.m
	src/NSTruePredicate.m
	src/NSUbiquitousKeyValueStore.m
	src/NSUndoGroup.m
	src/NSUndoManager.m
	src/NSUserActivity.m
	src/NSUserDefaults.m
	src/NSURLComponents.m
	src/NSURLError.m
	# src/NSURLHandle.m # deprecated since 10.4, from GNUstep
	src/NSURL.m
	src/NSUUID.m
	src/NSValue.m
	src/NSValueTransformer.m
	src/NSVariableAssignmentExpression.m
	src/NSVariableExpression.m
	src/NSXMLDocument.m
	src/NSXMLDTD.m
	src/NSXMLDTDNode.m
	src/NSXMLElement.m
	src/NSXMLNode.m
	src/NSXMLParser.m

	src/NSXPCInterface.m
	src/NSXPCConnection.m
	src/NSXPCCoder.m
	src/_NSXPCDistantObject.m
	src/NSXPCDecoder.m
	src/NSXPCEncoder.m
	src/NSXPCSerialization.c
	src/NSXPCSerializationObjC.m

	src/NSZone.m

	src/NSConcreteHashTable.m
	src/NSConcreteMapTable.m
	src/NSCallBacks.m

	src/NSSpellServer.m
	src/NSSpellEngine.m
	src/NSFileWrapper.m
	src/NSAppleEventDescriptor.m

	src/NSXPCConnection.m
	src/NSAppleEventManager.m
	src/NSDateComponentsFormatter.m
	src/NSMeasurementFormatter.m
	src/NSAppleScript.m
	src/NSMetadata.m
	src/NSLayoutAnchor.m
	src/NSLayoutConstraint.m
	src/NSExtensionContext.m
	src/NSISO8601DateFormatter.m
	src/NSScriptObjectSpecifiers.m
	src/NSScriptCoercionHandler.m
	src/NSScriptCommand.m
	src/NSScriptCommandDescription.m
	src/NSScriptClassDescription.m
	src/NSScriptExecutionContext.m
	src/NSScriptStandardSuiteCommands.m
	src/NSScriptSuiteRegistry.m
	src/NSUserNotification.m
	src/NSUserScriptTask.m
	src/NSDateInterval.m
	src/NSGarbageCollector.m
	src/NSUnarchiver.m
	src/NSDeserializer.m
	src/NSPortNameServer.m
	src/NSHFSFileTypes.m
	src/NSMeasurement.m
	src/NSUnit.m
	src/NSUnitDuration.m
	src/NSDimension.m
	src/NSUnitConverter.m
	src/NSUnitConverterLinear.m
	src/NSUnitLength.m
	src/NSAutoresizingMaskLayoutConstraint.m
	src/NSContentSizeLayoutConstraint.m
	src/NSIBPrototypingLayoutConstraint.m
	src/NSDeprecatedKeyValueCoding.m
	src/NSCFType.m
)

# Includes ObjC headers -> must be compiled as ObjC
set_source_files_properties(src/NSPredicateParser.tab.c PROPERTIES COMPILE_FLAGS "-x objective-c -fblocks")

set(DYLIB_COMPAT_VERSION "300.0.0")
set(DYLIB_CURRENT_VERSION "1349.0.0")

set(FRAMEWORK_VERSION "C")

generate_sdk_framework(Foundation
    VERSION ${FRAMEWORK_VERSION}
    HEADER "include/Foundation"
)

add_separated_framework(Foundation
    FAT
	CURRENT_VERSION
	SOURCES
		${foundation_sources}
	VERSION ${FRAMEWORK_VERSION}
	DEPENDENCIES
		objc
		system
		CoreFoundation
		IOKit
		# NSListFormatter's join is ICU's list formatter (ulistfmt_open/ulistfmt_format): the list
		# pattern is CLDR data, and libicucore is the only list formatter this tree carries -- the
		# same image the payload's Swift Foundation binds and CoreFoundation already links.
		icucore
		CFNetwork_firstpass
		xml2
	LINK_FLAGS " -Wl,-reexport_library,${CMAKE_BINARY_DIR}/src/external/corefoundation/CoreFoundation \
				-Wl,-reexport_library,${CMAKE_BINARY_DIR}/src/external/objc4/runtime/libobjc.A.dylib"
)

# if (TARGET_i386)
# set_property(
# 	TARGET CoreFoundation_i386 APPEND_STRING PROPERTY
# 	LINK_FLAGS " -Wl,-reexported_symbols_list,${CMAKE_CURRENT_SOURCE_DIR}/reexport_i386.exp")
# endif (TARGET_i386)
if (TARGET_x86_64)
set_property(
	TARGET Foundation_x86_64 APPEND_STRING PROPERTY
	LINK_FLAGS " -Wl,-reexported_symbols_list,${CMAKE_CURRENT_SOURCE_DIR}/reexport_x86_64.exp"
)
# Apple's Foundation.framework binary IS the Swift Foundation: clients built against a macOS SDK bind their
# Swift Foundation symbols to /System/Library/Frameworks/Foundation.framework/Versions/C/Foundation, not to
# /usr/lib/swift/libswiftFoundation.dylib, and dyld resolves a two-level reference through the image's
# re-export chain. Measured with a real client: Xcode 26.3's DVTSystemPrerequisites loads the framework and
# does NOT load the overlay dylib at all, while referencing _$s10Foundation19PropertyListDecoder...
# Darling's Foundation is Objective-C only, so the Swift half lives in the payload's overlay image; re-exporting
# it here is what makes the framework path satisfy such a client, and it is the same mechanism this target
# already uses for CoreFoundation and libobjc.A.dylib a few lines above. It is a re-export, not a stub: the
# symbols are defined by that image, and the framework defines none of them locally.
set(_foundation_swift_overlay "${CMAKE_SOURCE_DIR}/src/external/swift/libswiftFoundation.dylib")
if(NOT EXISTS "${_foundation_swift_overlay}")
	message(FATAL_ERROR
		"Foundation must re-export the Swift Foundation overlay, but "
		"src/external/swift/libswiftFoundation.dylib is absent: materialise the git-lfs payload first")
endif()
set_property(
	TARGET Foundation_x86_64 APPEND_STRING PROPERTY
	LINK_FLAGS " -Wl,-reexport_library,${_foundation_swift_overlay}"
)
endif (TARGET_x86_64)

add_darling_executable(defaults tools/defaults.m)
target_link_libraries(defaults Foundation)
install(TARGETS defaults DESTINATION libexec/darling/usr/bin)
install(FILES tools/defaults.1 DESTINATION libexec/darling/usr/share/man/man1)

