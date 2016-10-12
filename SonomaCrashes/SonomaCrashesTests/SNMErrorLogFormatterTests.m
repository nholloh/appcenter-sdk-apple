/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "SNMAppleErrorLog.h"
#import "SNMCrashTestHelper.h"
#import "SNMCrashesPrivate.h"
#import "SNMErrorLogFormatterPrivate.h"
#import "SNMSonomaInternal.h"
#import "SNMDeviceTracker.h"

@interface SNMErrorLogFormatterTests : XCTestCase

@end

@implementation SNMErrorLogFormatterTests

- (void)testCreateErrorReport {
  NSData *crashData = [SNMCrashTestHelper dataOfFixtureCrashReportWithFileName:@"live_report_signal"];
  XCTAssertNotNil(crashData);

  SNMDevice *device = [[SNMDeviceTracker alloc] init].device;
  XCTAssertNotNil(device);
  
  NSError *error = nil;
  SNMPLCrashReport *report = [[SNMPLCrashReport alloc] initWithData:crashData error:&error];

  SNMErrorReport *errorReport = [SNMErrorLogFormatter createErrorReportFrom:report];
  XCTAssertNotNil(errorReport);

  XCTAssertNotNil(errorReport.incidentIdentifier);
  assertThat(errorReport.reporterKey, equalTo([[SNMSonoma installId] UUIDString]));

  XCTAssertEqual(errorReport.signal, report.signalInfo.name);

  XCTAssertEqual(errorReport.exceptionName, report.signalInfo.name);
  XCTAssertEqual(errorReport.exceptionReason, report.exceptionInfo.exceptionReason);
  XCTAssertEqual(errorReport.appStartTime, report.processInfo.processStartTime);
  XCTAssertEqual(errorReport.appErrorTime, report.systemInfo.timestamp);
  XCTAssertTrue([errorReport.device isEqual:device]);
  XCTAssertEqual(errorReport.appProcessIdentifier, report.processInfo.processID);

  crashData = [SNMCrashTestHelper dataOfFixtureCrashReportWithFileName:@"live_report_exception"];
  XCTAssertNotNil(crashData);

  error = nil;
  report = [[SNMPLCrashReport alloc] initWithData:crashData error:&error];

  errorReport = [SNMErrorLogFormatter createErrorReportFrom:report];
  XCTAssertNotNil(errorReport);

  XCTAssertNotNil(errorReport.incidentIdentifier);
  assertThat(errorReport.reporterKey, equalTo([[SNMSonoma installId] UUIDString]));

  XCTAssertEqual(errorReport.signal, report.signalInfo.name);

  XCTAssertEqual(errorReport.exceptionName, report.exceptionInfo.exceptionName);
  XCTAssertEqual(errorReport.exceptionReason, report.exceptionInfo.exceptionReason);
  XCTAssertEqual(errorReport.appStartTime, report.processInfo.processStartTime);
  XCTAssertEqual(errorReport.appErrorTime, report.systemInfo.timestamp);
  XCTAssertTrue([errorReport.device isEqual:device]);
  XCTAssertEqual(errorReport.appProcessIdentifier, report.processInfo.processID);
}

- (void)testErrorIdFromCrashReport {
  NSData *crashData = [SNMCrashTestHelper dataOfFixtureCrashReportWithFileName:@"live_report_signal"];
  XCTAssertNotNil(crashData);

  NSError *error = nil;
  SNMPLCrashReport *report = [[SNMPLCrashReport alloc] initWithData:crashData error:&error];

  NSString *expected = (NSString *) CFBridgingRelease(CFUUIDCreateString(NULL, report.uuidRef));
  NSString *actual = [SNMErrorLogFormatter errorIdForCrashReport:report];
  assertThat(actual, equalTo(expected));
}

- (void)testAddProcessInfoAndApplicationPath {
  NSData *crashData = [SNMCrashTestHelper dataOfFixtureCrashReportWithFileName:@"live_report_exception"];
  XCTAssertNotNil(crashData);

  NSError *error = nil;
  SNMPLCrashReport *report = [[SNMPLCrashReport alloc] initWithData:crashData error:&error];

  SNMAppleErrorLog *actual = [SNMAppleErrorLog new];
  actual = [SNMErrorLogFormatter addProcessInfoAndApplicationPathTo:actual fromCrashReport:report];

  assertThat(actual.processId, equalTo(@(report.processInfo.processID)));
  XCTAssertEqual(actual.processName, report.processInfo.processName);
  XCTAssertNotNil(actual.applicationPath);
  // Not using the report.processInfo.processPath directly to compare as it will be anonymized in the Simulator.
  assertThat(actual.applicationPath, equalTo(@"/Users/USER/Library/Application Support/iPhone "
                                             @"Simulator/7.0/Applications/E196971A-6809-48AF-BB06-FD67014A35B2/"
                                             @"HockeySDK-iOSDemo.app/HockeySDK-iOSDemo"));

  XCTAssertEqual(actual.parentProcessName, report.processInfo.parentProcessName);
  assertThat(actual.parentProcessId, equalTo(@(report.processInfo.parentProcessID)));
}

- (void)testAnonymizedPathWorks {
  NSString *testPath = @"/var/containers/Bundle/Application/2A0B0E6F-0BF2-419D-A699-FCDF8ADECD8C/Puppet.app/Puppet";
  NSString *expected = testPath;
  NSString *actual = [SNMErrorLogFormatter anonymizedPathFromPath:testPath];
  assertThat(actual, equalTo(expected));

  testPath = @"/Users/someone/Library/Developer/CoreSimulator/Devices/B8321AD0-C30B-41BD-BA54-5A7759CEC4CD/data/"
             @"Containers/Bundle/Application/8CC7B5B5-7841-45C4-BAC2-6AA1B944A5E1/Puppet.app/Puppet";
  expected = @"/Users/USER/Library/Developer/CoreSimulator/Devices/B8321AD0-C30B-41BD-BA54-5A7759CEC4CD/data/"
             @"Containers/Bundle/Application/8CC7B5B5-7841-45C4-BAC2-6AA1B944A5E1/Puppet.app/Puppet";
  actual = [SNMErrorLogFormatter anonymizedPathFromPath:testPath];
  assertThat(actual, equalTo(expected));
  XCTAssertFalse([actual containsString:@"sampleuser"]);
  XCTAssertTrue([actual hasPrefix:@"/Users/USER/"]);
}

- (void)testOSXImages {
  NSString *processPath = nil;
  NSString *appBundlePath = nil;

  appBundlePath = @"/Applications/MyTestApp.App";

  // Test with default OS X app path
  processPath = [appBundlePath stringByAppendingString:@"/Contents/MacOS/MyApp"];
  [self testOSXNonAppSpecificImagesForProcessPath:processPath];
  [self assertIsOtherWithImagePath:processPath processPath:nil];
  [self assertIsOtherWithImagePath:nil processPath:processPath];
  [self assertIsAppBinaryWithImagePath:processPath processPath:processPath];

  // Test with OS X LoginItems app helper path
  processPath = [appBundlePath
      stringByAppendingString:@"/Contents/Library/LoginItems/net.hockeyapp.helper.app/Contents/MacOS/Helper"];
  [self testOSXNonAppSpecificImagesForProcessPath:processPath];
  [self assertIsOtherWithImagePath:processPath processPath:nil];
  [self assertIsOtherWithImagePath:nil processPath:processPath];
  [self assertIsAppBinaryWithImagePath:processPath processPath:processPath];

  // Test with OS X app in Resources folder
  processPath = @"/Applications/MyTestApp.App/Contents/Resources/Helper";
  [self testOSXNonAppSpecificImagesForProcessPath:processPath];
  [self assertIsOtherWithImagePath:processPath processPath:nil];
  [self assertIsOtherWithImagePath:nil processPath:processPath];
  [self assertIsAppBinaryWithImagePath:processPath processPath:processPath];
}

- (void)testiOSImages {
  NSString *processPath = nil;
  NSString *appBundlePath = nil;

  appBundlePath = @"/private/var/mobile/Containers/Bundle/Application/9107B4E2-CD8C-486E-A3B2-82A5B818F2A0/MyApp.app";

  // Test with iOS App
  processPath = [appBundlePath stringByAppendingString:@"/MyApp"];
  [self testiOSNonAppSpecificImagesForProcessPath:processPath];
  [self assertIsOtherWithImagePath:processPath processPath:nil];
  [self assertIsOtherWithImagePath:nil processPath:processPath];
  [self assertIsAppBinaryWithImagePath:processPath processPath:processPath];
  [self testiOSAppFrameworkAtProcessPath:processPath appBundlePath:appBundlePath];

  // Test with iOS App Extension
  processPath = [appBundlePath stringByAppendingString:@"/Plugins/MyAppExtension.appex/MyAppExtension"];
  [self testiOSNonAppSpecificImagesForProcessPath:processPath];
  [self assertIsOtherWithImagePath:processPath processPath:nil];
  [self assertIsOtherWithImagePath:nil processPath:processPath];
  [self assertIsAppBinaryWithImagePath:processPath processPath:processPath];
  [self testiOSAppFrameworkAtProcessPath:processPath appBundlePath:appBundlePath];
}

#pragma mark - Helpers

- (void)testOSXNonAppSpecificImagesForProcessPath:(NSString *)processPath {
  // system test paths
  NSMutableArray *nonAppSpecificImagePaths = [NSMutableArray new];

  // OS X frameworks
  [nonAppSpecificImagePaths addObject:@"cl_kernels"];
  [nonAppSpecificImagePaths addObject:@""];
  [nonAppSpecificImagePaths addObject:@"???"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/Frameworks/CFNetwork.framework/Versions/A/CFNetwork"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/system/libsystem_platform.dylib"];
  [nonAppSpecificImagePaths
      addObject:
          @"/System/Library/Frameworks/Accelerate.framework/Versions/A/Frameworks/vecLib.framework/Versions/A/vecLib"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/PrivateFrameworks/Sharing.framework/Versions/A/Sharing"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/libbsm.0.dylib"];

  for (NSString *imagePath in nonAppSpecificImagePaths) {
    [self assertIsOtherWithImagePath:imagePath processPath:processPath];
  }
}

- (void)testiOSAppFrameworkAtProcessPath:(NSString *)processPath appBundlePath:(NSString *)appBundlePath {
  NSString *frameworkPath =
      [appBundlePath stringByAppendingString:@"/Frameworks/MyFrameworkLib.framework/MyFrameworkLib"];
  [self assertIsAppFrameworkWithFrameworkPath:frameworkPath processPath:processPath];

  frameworkPath = [appBundlePath stringByAppendingString:@"/Frameworks/libSwiftMyLib.framework/libSwiftMyLib"];
  [self assertIsAppFrameworkWithFrameworkPath:frameworkPath processPath:processPath];

  NSMutableArray *swiftFrameworkPaths = [NSMutableArray new];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftCore.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftDarwin.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftDispatch.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftFoundation.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftObjectiveC.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftSecurity.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftCoreGraphics.dylib"]];

  for (NSString *swiftFrameworkPath in swiftFrameworkPaths) {
    [self assertIsSwiftFrameworkWithFrameworkPath:swiftFrameworkPath processPath:processPath];
  }
}

- (void)testiOSNonAppSpecificImagesForProcessPath:(NSString *)processPath {
  // system test paths
  NSMutableArray *nonAppSpecificImagePaths = [NSMutableArray new];

  // iOS frameworks
  [nonAppSpecificImagePaths
      addObject:@"/System/Library/AccessibilityBundles/AccessibilitySettingsLoader.bundle/AccessibilitySettingsLoader"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/Frameworks/AVFoundation.framework/AVFoundation"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/Frameworks/AVFoundation.framework/libAVFAudio.dylib"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/PrivateFrameworks/AOSNotification.framework/AOSNotification"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/PrivateFrameworks/Accessibility.framework/Frameworks/"
                                      @"AccessibilityUI.framework/AccessibilityUI"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/PrivateFrameworks/Accessibility.framework/Frameworks/"
                                      @"AccessibilityUIUtilities.framework/AccessibilityUIUtilities"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/libAXSafeCategoryBundle.dylib"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/libAXSpeechManager.dylib"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/libAccessibility.dylib"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/system/libcache.dylib"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/system/libcommonCrypto.dylib"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/system/libcompiler_rt.dylib"];

  // iOS Jailbreak libraries
  [nonAppSpecificImagePaths addObject:@"/Library/MobileSubstrate/MobileSubstrate.dylib"];
  [nonAppSpecificImagePaths addObject:@"/Library/MobileSubstrate/DynamicLibraries/WeeLoader.dylib"];
  [nonAppSpecificImagePaths addObject:@"/Library/Frameworks/CydiaSubstrate.framework/Libraries/SubstrateLoader.dylib"];
  [nonAppSpecificImagePaths addObject:@"/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate"];
  [nonAppSpecificImagePaths addObject:@"/Library/MobileSubstrate/DynamicLibraries/WinterBoard.dylib"];

  for (NSString *imagePath in nonAppSpecificImagePaths) {
    [self assertIsOtherWithImagePath:imagePath processPath:processPath];
  }
}

- (void)assertIsAppFrameworkWithFrameworkPath:(NSString *)frameworkPath processPath:(NSString *)processPath {
  SNMBinaryImageType imageType = [SNMErrorLogFormatter imageTypeForImagePath:frameworkPath processPath:processPath];
  XCTAssertEqual(imageType, SNMBinaryImageTypeAppFramework, @"Test framework %@ with process %@", frameworkPath,
                 processPath);
}

- (void)assertIsAppBinaryWithImagePath:(NSString *)imagePath processPath:(NSString *)processPath {
  SNMBinaryImageType imageType = [SNMErrorLogFormatter imageTypeForImagePath:imagePath processPath:processPath];
  XCTAssertEqual(imageType, SNMBinaryImageTypeAppBinary, @"Test app %@ with process %@", imagePath, processPath);
}

- (void)assertIsSwiftFrameworkWithFrameworkPath:(NSString *)swiftFrameworkPath processPath:(NSString *)processPath {
  SNMBinaryImageType imageType =
      [SNMErrorLogFormatter imageTypeForImagePath:swiftFrameworkPath processPath:processPath];
  XCTAssertEqual(imageType, SNMBinaryImageTypeOther, @"Test swift image %@ with process %@", swiftFrameworkPath,
                 processPath);
}

- (void)assertIsOtherWithImagePath:(NSString *)imagePath processPath:(NSString *)processPath {
  SNMBinaryImageType imageType = [SNMErrorLogFormatter imageTypeForImagePath:imagePath processPath:processPath];
  XCTAssertEqual(imageType, SNMBinaryImageTypeOther, @"Test other image %@ with process %@", imagePath, processPath);
}

@end