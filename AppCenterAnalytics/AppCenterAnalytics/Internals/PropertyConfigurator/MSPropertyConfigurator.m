#import "MSAnalyticsTransmissionTargetPrivate.h"
#import "MSCommonSchemaLog.h"
#import "MSPropertyConfigurator.h"
#import "MSPropertyConfiguratorPrivate.h"

@implementation MSPropertyConfigurator

- (instancetype)initWithTransmissionTarget:(MSAnalyticsTransmissionTarget *)transmissionTarget {
  if ((self = [super init])) {
    _transmissionTarget = transmissionTarget;
  }
  return self;
}

- (void)setAppVersion:(NSString *)appVersion {
  _appVersion = appVersion;
}

- (void)setAppName:(NSString *)appName {
  _appName = appName;
}

- (void)setAppLocale:(NSString *)appLocale {
  _appLocale = appLocale;
}

#pragma mark - MSChannelDelegate

- (void)channel:(id<MSChannelProtocol>)__unused channel prepareLog:(id<MSLog>)log {
  if ([log isKindOfClass:[MSCommonSchemaLog class]] && [self.transmissionTarget isEnabled]) {

    // TODO Find a better way to override properties.

    // Override the application version.
    MSAnalyticsTransmissionTarget *target = self.transmissionTarget;
    while (target) {
      if (target.propertyConfigurator.appVersion) {
        [((MSCommonSchemaLog *)log)ext].appExt.ver = target.propertyConfigurator.appVersion;
        break;
      }
      target = target.parentTarget;
    }

    // Override the application name.
    target = self.transmissionTarget;
    while (target) {
      if (target.propertyConfigurator.appName) {
        [((MSCommonSchemaLog *)log)ext].appExt.name = target.propertyConfigurator.appName;
        break;
      }
      target = target.parentTarget;
    }

    // Override the application locale.
    target = self.transmissionTarget;
    while (target) {
      if (target.propertyConfigurator.appLocale) {
        [((MSCommonSchemaLog *)log)ext].appExt.locale = target.propertyConfigurator.appLocale;
        break;
      }
      target = target.parentTarget;
    }
  }
}

@end