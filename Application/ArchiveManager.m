#import "ArchiveManager.h"
#import <objc/runtime.h>

@interface ArchiveDownloadObserver : NSObject
@property (nonatomic, copy) void (^progressBlock)(float);
@end
@implementation ArchiveDownloadObserver
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	NSProgress *p = object;
	if (self.progressBlock) {
		dispatch_async(dispatch_get_main_queue(), ^{ self.progressBlock(p.fractionCompleted); });
	}
}
@end

@implementation ArchiveManager

+ (NSString *)archivesDirectory {
	NSString *dir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject
		stringByAppendingPathComponent:@"Archives"];
	[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
	return dir;
}

+ (NSString *)indexPath {
	return [[self archivesDirectory] stringByAppendingPathComponent:@"archive-index.json"];
}

+ (NSString *)identifierForApp:(NSDictionary *)appEntry {
	return [NSString stringWithFormat:@"%@-%@", appEntry[@"bundleID"], appEntry[@"version"]];
}

+ (NSArray<NSDictionary *> *)archivedApps {
	NSData *data = [NSData dataWithContentsOfFile:[self indexPath]];
	if (!data) return @[];
	NSArray *index = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
	return [index isKindOfClass:[NSArray class]] ? index : @[];
}

+ (void)saveIndex:(NSArray *)index {
	NSData *data = [NSJSONSerialization dataWithJSONObject:index options:NSJSONWritingPrettyPrinted error:nil];
	[data writeToFile:[self indexPath] atomically:YES];
}

+ (NSDictionary *)indexEntryForApp:(NSDictionary *)appEntry {
	NSString *identifier = [self identifierForApp:appEntry];
	for (NSDictionary *entry in [self archivedApps]) {
		if ([entry[@"identifier"] isEqualToString:identifier]) return entry;
	}
	return nil;
}

+ (BOOL)isArchived:(NSDictionary *)appEntry {
	return [self indexEntryForApp:appEntry] != nil;
}

+ (NSString *)localIPAPathForApp:(NSDictionary *)appEntry {
	NSDictionary *entry = [self indexEntryForApp:appEntry];
	if (!entry) return nil;
	return [[self archivesDirectory] stringByAppendingPathComponent:entry[@"localFileName"]];
}

+ (void)downloadApp:(NSDictionary *)appEntry
           progress:(void (^)(float))progress
         completion:(void (^)(NSError *))completion {
	NSString *down = appEntry[@"down"];
	NSURL *url = [NSURL URLWithString:down];
	if (!url) {
		completion([NSError errorWithDomain:@"ArchiveManager" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid download URL"}]);
		return;
	}

	NSString *identifier = [self identifierForApp:appEntry];
	NSString *localFileName = [NSString stringWithFormat:@"%@.ipa", identifier];
	NSString *localPath = [[self archivesDirectory] stringByAppendingPathComponent:localFileName];

	ArchiveDownloadObserver *observer = [ArchiveDownloadObserver new];
	observer.progressBlock = progress;

	NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithURL:url
		completionHandler:^(NSURL *tempLocation, NSURLResponse *response, NSError *error) {
			[task removeObserver:observer forKeyPath:@"progress" context:nil];

			if (error || !tempLocation) {
				dispatch_async(dispatch_get_main_queue(), ^{ completion(error); });
				return;
			}

			[[NSFileManager defaultManager] removeItemAtPath:localPath error:nil];
			NSError *moveError;
			[[NSFileManager defaultManager] moveItemAtURL:tempLocation toURL:[NSURL fileURLWithPath:localPath] error:&moveError];
			if (moveError) {
				dispatch_async(dispatch_get_main_queue(), ^{ completion(moveError); });
				return;
			}

			NSMutableArray *index = [[self archivedApps] mutableCopy];
			[index removeObjectsInArray:[index filteredArrayUsingPredicate:
				[NSPredicate predicateWithFormat:@"identifier == %@", identifier]]];
			[index addObject:@{
				@"identifier": identifier,
				@"name": appEntry[@"name"] ?: @"",
				@"version": appEntry[@"version"] ?: @"",
				@"bundleID": appEntry[@"bundleID"] ?: @"",
				@"category": appEntry[@"category"] ?: @"",
				@"repoName": appEntry[@"repoName"] ?: @"",
				@"localFileName": localFileName,
				@"archivedDate": @([NSDate date].timeIntervalSince1970),
			}];
			[self saveIndex:index];

			dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
		}];

	[task addObserver:observer forKeyPath:@"progress" options:NSKeyValueObservingOptionNew context:nil];
	objc_setAssociatedObject(task, "observer", observer, OBJC_ASSOCIATION_RETAIN);
	[task resume];
}

+ (void)deleteArchivedApp:(NSDictionary *)appEntry {
	NSDictionary *entry = [self indexEntryForApp:appEntry];
	if (!entry) return;
	NSString *localPath = [[self archivesDirectory] stringByAppendingPathComponent:entry[@"localFileName"]];
	[[NSFileManager defaultManager] removeItemAtPath:localPath error:nil];

	NSMutableArray *index = [[self archivedApps] mutableCopy];
	[index removeObjectsInArray:[index filteredArrayUsingPredicate:
		[NSPredicate predicateWithFormat:@"identifier == %@", entry[@"identifier"]]]];
	[self saveIndex:index];
}

@end
