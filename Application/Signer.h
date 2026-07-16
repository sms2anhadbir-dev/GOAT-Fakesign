#import <Foundation/Foundation.h>

typedef void (^SignerProgress)(NSString *message);
typedef void (^SignerCompletion)(NSURL * _Nullable signedIPA, NSError * _Nullable error);

@interface Signer : NSObject

// Unzips ipa, ldid -S's every Mach-O in the bundle (fakesign), rezips.
// Returns the path to the fakesigned .ipa via completion.
+ (void)fakesignIPAAtURL:(NSURL *)ipaURL
                 progress:(SignerProgress)progress
               completion:(SignerCompletion)completion;

@end
