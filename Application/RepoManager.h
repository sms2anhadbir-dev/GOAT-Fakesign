#import <Foundation/Foundation.h>

// Parses repo.json sources in the AltStore-style format:
// { "META": {...}, "Games": [...], "Tweaked": [...], "Jailbreaks": [...], "Emulators": [...], "Other": [...] }
@interface RepoManager : NSObject

+ (void)fetchRepoAtURL:(NSURL *)url
             completion:(void (^)(NSDictionary *repoName_and_apps, NSError *error))completion;

@end
