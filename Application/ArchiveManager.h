#import <Foundation/Foundation.h>

// Downloads app IPAs into a local archive directory and keeps a
// persistent index so they survive relaunch and stay available even
// if the originating source/repo goes offline.
@interface ArchiveManager : NSObject

+ (NSArray<NSDictionary *> *)archivedApps;

+ (BOOL)isArchived:(NSDictionary *)appEntry;

+ (NSString *)localIPAPathForApp:(NSDictionary *)appEntry;

+ (void)downloadApp:(NSDictionary *)appEntry
           progress:(void (^)(float fractionComplete))progress
         completion:(void (^)(NSError *error))completion;

+ (void)deleteArchivedApp:(NSDictionary *)appEntry;

@end
