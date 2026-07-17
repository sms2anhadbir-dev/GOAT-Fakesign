#import <Foundation/Foundation.h>

// Persists the user's uploaded .p12 + .mobileprovision (copied into the
// app's local storage) and the p12 password (Keychain), so real signing
// can be reused across launches without re-uploading every time.
@interface CertManager : NSObject

+ (BOOL)hasCertConfigured;

+ (NSURL *)p12URL;
+ (NSURL *)provisionURL;
+ (NSString *)p12Password;

+ (BOOL)importP12AtURL:(NSURL *)sourceURL error:(NSError **)error;
+ (BOOL)importProvisionAtURL:(NSURL *)sourceURL error:(NSError **)error;
+ (void)setP12Password:(NSString *)password;

+ (void)clearCert;

@end
