#import "RepoManager.h"

static NSArray *kCategoryKeys;

@implementation RepoManager

+ (void)initialize {
	kCategoryKeys = @[@"Games", @"Tweaked", @"Jailbreaks", @"Emulators", @"Other"];
}

+ (void)fetchRepoAtURL:(NSURL *)url completion:(void (^)(NSDictionary *, NSError *))completion {
	NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
		completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
			if (error || !data) {
				dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
				return;
			}

			NSError *jsonError;
			NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
			if (jsonError || ![json isKindOfClass:[NSDictionary class]]) {
				dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, jsonError); });
				return;
			}

			NSString *repoName = json[@"META"][@"repoName"] ?: url.host;
			NSString *repoIcon = json[@"META"][@"repoIcon"];

			NSMutableArray *apps = [NSMutableArray array];
			for (NSString *category in kCategoryKeys) {
				NSArray *entries = json[category];
				if (![entries isKindOfClass:[NSArray class]]) continue;
				for (NSDictionary *entry in entries) {
					if (![entry isKindOfClass:[NSDictionary class]]) continue;
					NSMutableDictionary *app = [entry mutableCopy];
					app[@"category"] = app[@"category"] ?: category;
					app[@"sourceURL"] = url.absoluteString;
					app[@"repoName"] = repoName;
					[apps addObject:app];
				}
			}

			NSDictionary *result = @{
				@"repoName": repoName ?: @"",
				@"repoIcon": repoIcon ?: @"",
				@"apps": apps,
			};
			dispatch_async(dispatch_get_main_queue(), ^{ completion(result, nil); });
		}];
	[task resume];
}

@end
