#import <Foundation/Foundation.h>

typedef void (^SignerProgress)(NSString *message);
typedef void (^SignerCompletion)(NSURL * _Nullable signedIPA, NSError * _Nullable error);

@interface Signer : NSObject

// Unzips ipa, ldid -S's every Mach-O in the bundle (fakesign), rezips.
// Returns the path to the fakesigned .ipa via completion.
+ (void)fakesignIPAAtURL:(NSURL *)ipaURL
                 progress:(SignerProgress)progress
               completion:(SignerCompletion)completion;

// Real signing with a developer cert: shells out to the bundled `zsign`
// binary with the given .p12 (+ password) and .mobileprovision, which
// embeds the profile and produces a properly CMS-signed IPA that will
// install on a stock, non-jailbroken device.
+ (void)signIPAAtURL:(NSURL *)ipaURL
             p12URL:(NSURL *)p12URL
        p12Password:(NSString *)p12Password
    provisionURL:(NSURL *)provisionURL
           progress:(SignerProgress)progress
         completion:(SignerCompletion)completion;

@end
