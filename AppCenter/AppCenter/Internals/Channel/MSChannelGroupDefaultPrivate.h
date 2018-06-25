NS_ASSUME_NONNULL_BEGIN

@class MSHttpSender;
@protocol MSStorage;

@interface MSChannelGroupDefault ()

/**
 * Initializes a new `MSChannelGroupDefault` instance.
 *
 * @param sender An HTTP sender instance that is used to send batches of log items to the backend.
 *
 * @return A new `MSChannelGroupDefault` instance.
 */
- (instancetype)initWithSender:(nullable MSHttpSender *)sender;

@end

NS_ASSUME_NONNULL_END
