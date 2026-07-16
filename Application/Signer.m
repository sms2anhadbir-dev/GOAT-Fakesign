#import "Signer.h"
#import <archive.h>
#import <archive_entry.h>
#import <spawn.h>
#import <sys/wait.h>

extern char **environ;

@implementation Signer

#pragma mark - zip helpers (libarchive)

+ (BOOL)extractIPAAtPath:(NSString *)ipaPath toDirectory:(NSString *)outDir error:(NSError **)error {
	struct archive *a = archive_read_new();
	archive_read_support_format_zip(a);
	if (archive_read_open_filename(a, ipaPath.fileSystemRepresentation, 10240) != ARCHIVE_OK) {
		if (error) *error = [NSError errorWithDomain:@"Signer" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to open IPA"}];
		archive_read_free(a);
		return NO;
	}

	struct archive_entry *entry;
	while (archive_read_next_header(a, &entry) == ARCHIVE_OK) {
		NSString *entryPath = [NSString stringWithUTF8String:archive_entry_pathname(entry)];
		NSString *dest = [outDir stringByAppendingPathComponent:entryPath];

		if (archive_entry_filetype(entry) == AE_IFDIR) {
			[[NSFileManager defaultManager] createDirectoryAtPath:dest withIntermediateDirectories:YES attributes:nil error:nil];
			continue;
		}

		[[NSFileManager defaultManager] createDirectoryAtPath:dest.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];

		FILE *fp = fopen(dest.fileSystemRepresentation, "wb");
		if (!fp) continue;

		const void *buff;
		size_t size;
		la_int64_t offset;
		while (archive_read_data_block(a, &buff, &size, &offset) == ARCHIVE_OK) {
			fwrite(buff, 1, size, fp);
		}
		fclose(fp);

		mode_t mode = archive_entry_perm(entry);
		if (mode) chmod(dest.fileSystemRepresentation, mode);
	}

	archive_read_free(a);
	return YES;
}

+ (BOOL)compressDirectory:(NSString *)dir toIPAPath:(NSString *)ipaPath error:(NSError **)error {
	struct archive *a = archive_write_new();
	archive_write_set_format_zip(a);
	if (archive_write_open_filename(a, ipaPath.fileSystemRepresentation) != ARCHIVE_OK) {
		if (error) *error = [NSError errorWithDomain:@"Signer" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create output IPA"}];
		archive_write_free(a);
		return NO;
	}

	NSFileManager *fm = [NSFileManager defaultManager];
	NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:dir];
	NSString *file;
	while ((file = [enumerator nextObject])) {
		NSString *fullPath = [dir stringByAppendingPathComponent:file];
		BOOL isDir = NO;
		[fm fileExistsAtPath:fullPath isDirectory:&isDir];
		if (isDir) continue;

		struct stat st;
		stat(fullPath.fileSystemRepresentation, &st);

		struct archive_entry *entry = archive_entry_new();
		archive_entry_set_pathname(entry, file.UTF8String);
		archive_entry_set_size(entry, st.st_size);
		archive_entry_set_filetype(entry, AE_IFREG);
		archive_entry_set_perm(entry, st.st_mode & 0777);
		archive_write_header(a, entry);

		NSData *data = [NSData dataWithContentsOfFile:fullPath];
		archive_write_data(a, data.bytes, data.length);
		archive_entry_free(entry);
	}

	archive_write_close(a);
	archive_write_free(a);
	return YES;
}

#pragma mark - Mach-O detection

+ (BOOL)isMachOAtPath:(NSString *)path {
	NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:path];
	if (!fh) return NO;
	NSData *header = [fh readDataOfLength:4];
	[fh closeFile];
	if (header.length < 4) return NO;
	uint32_t magic;
	[header getBytes:&magic length:4];
	// MH_MAGIC_64, MH_CIGAM_64, FAT_MAGIC, FAT_CIGAM
	return magic == 0xfeedfacf || magic == 0xcffaedfe || magic == 0xcafebabe || magic == 0xbebafeca;
}

+ (NSArray<NSString *> *)machOFilesInAppBundle:(NSString *)appPath {
	NSMutableArray *results = [NSMutableArray array];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:appPath];
	NSString *file;
	while ((file = [enumerator nextObject])) {
		NSString *fullPath = [appPath stringByAppendingPathComponent:file];
		BOOL isDir = NO;
		[fm fileExistsAtPath:fullPath isDirectory:&isDir];
		if (isDir) continue;
		if ([self isMachOAtPath:fullPath]) [results addObject:fullPath];
	}
	return results;
}

#pragma mark - ldid

+ (BOOL)ldidSignPath:(NSString *)path {
	NSString *ldidPath = [[NSBundle mainBundle] pathForResource:@"ldid" ofType:nil];
	if (!ldidPath) return NO;

	pid_t pid;
	char *argv[] = {(char *)ldidPath.fileSystemRepresentation, "-S", (char *)path.fileSystemRepresentation, NULL};
	int status = posix_spawn(&pid, ldidPath.fileSystemRepresentation, NULL, NULL, argv, environ);
	if (status != 0) return NO;
	int wstatus;
	waitpid(pid, &wstatus, 0);
	return WIFEXITED(wstatus) && WEXITSTATUS(wstatus) == 0;
}

#pragma mark - public entry point

+ (void)fakesignIPAAtURL:(NSURL *)ipaURL
                 progress:(SignerProgress)progress
               completion:(SignerCompletion)completion {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSError *error;
		NSString *workDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
		[[NSFileManager defaultManager] createDirectoryAtPath:workDir withIntermediateDirectories:YES attributes:nil error:nil];

		if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(@"Extracting IPA..."); });
		if (![self extractIPAAtPath:ipaURL.path toDirectory:workDir error:&error]) {
			if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
			return;
		}

		NSString *payloadDir = [workDir stringByAppendingPathComponent:@"Payload"];
		NSArray *apps = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadDir error:nil];
		NSString *appName = nil;
		for (NSString *item in apps) {
			if ([item hasSuffix:@".app"]) { appName = item; break; }
		}
		if (!appName) {
			if (completion) dispatch_async(dispatch_get_main_queue(), ^{
				completion(nil, [NSError errorWithDomain:@"Signer" code:3 userInfo:@{NSLocalizedDescriptionKey: @"No .app bundle found in IPA"}]);
			});
			return;
		}
		NSString *appPath = [payloadDir stringByAppendingPathComponent:appName];

		if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(@"Fakesigning binaries..."); });
		NSArray<NSString *> *machOFiles = [self machOFilesInAppBundle:appPath];
		for (NSString *machO in machOFiles) {
			if (progress) {
				NSString *name = machO.lastPathComponent;
				dispatch_async(dispatch_get_main_queue(), ^{ progress([NSString stringWithFormat:@"Signing %@", name]); });
			}
			[self ldidSignPath:machO];
		}

		if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(@"Repackaging IPA..."); });
		NSString *outPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
			[NSString stringWithFormat:@"%@-fakesigned.ipa", ipaURL.lastPathComponent.stringByDeletingPathExtension]];
		[[NSFileManager defaultManager] removeItemAtPath:outPath error:nil];

		if (![self compressDirectory:workDir toIPAPath:outPath error:&error]) {
			if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
			return;
		}

		[[NSFileManager defaultManager] removeItemAtPath:workDir error:nil];

		if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion([NSURL fileURLWithPath:outPath], nil); });
	});
}

@end
