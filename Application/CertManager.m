#import "CertManager.h"
#import <Security/Security.h>

static NSString *const kKeychainService = @"com.goat.sign.p12password";
static NSString *const kKeychainAccount = @"p12password";

@implementation CertManager

+ (NSString *)certDirectory {
	NSString *dir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject
		stringByAppendingPathComponent:@"Cert"];
	[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
	return dir;
}

+ (NSURL *)p12URL {
	NSString *path = [[self certDirectory] stringByAppendingPathComponent:@"cert.p12"];
	return [[NSFileManager defaultManager] fileExistsAtPath:path] ? [NSURL fileURLWithPath:path] : nil;
}

+ (NSURL *)provisionURL {
	NSString *path = [[self certDirectory] stringByAppendingPathComponent:@"profile.mobileprovision"];
	return [[NSFileManager defaultManager] fileExistsAtPath:path] ? [NSURL fileURLWithPath:path] : nil;
}

+ (BOOL)hasCertConfigured {
	return [self p12URL] != nil && [self provisionURL] != nil;
}

+ (BOOL)importP12AtURL:(NSURL *)sourceURL error:(NSError **)error {
	NSString *dest = [[self certDirectory] stringByAppendingPathComponent:@"cert.p12"];
	[[NSFileManager defaultManager] removeItemAtPath:dest error:nil];
	return [[NSFileManager defaultManager] copyItemAtURL:sourceURL toURL:[NSURL fileURLWithPath:dest] error:error];
}

+ (BOOL)importProvisionAtURL:(NSURL *)sourceURL error:(NSError **)error {
	NSString *dest = [[self certDirectory] stringByAppendingPathComponent:@"profile.mobileprovision"];
	[[NSFileManager defaultManager] removeItemAtPath:dest error:nil];
	return [[NSFileManager defaultManager] copyItemAtURL:sourceURL toURL:[NSURL fileURLWithPath:dest] error:error];
}

+ (void)setP12Password:(NSString *)password {
	NSDictionary *query = @{
		(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
		(__bridge id)kSecAttrService: kKeychainService,
		(__bridge id)kSecAttrAccount: kKeychainAccount,
	};
	SecItemDelete((__bridge CFDictionaryRef)query);

	NSMutableDictionary *addQuery = [query mutableCopy];
	addQuery[(__bridge id)kSecValueData] = [password dataUsingEncoding:NSUTF8StringEncoding];
	SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
}

+ (NSString *)p12Password {
	NSDictionary *query = @{
		(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
		(__bridge id)kSecAttrService: kKeychainService,
		(__bridge id)kSecAttrAccount: kKeychainAccount,
		(__bridge id)kSecReturnData: @YES,
		(__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
	};
	CFTypeRef result = NULL;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
	if (status != errSecSuccess || !result) return @"";
	NSData *data = (__bridge_transfer NSData *)result;
	return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}

+ (void)clearCert {
	[[NSFileManager defaultManager] removeItemAtPath:[self certDirectory] error:nil];
	NSDictionary *query = @{
		(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
		(__bridge id)kSecAttrService: kKeychainService,
		(__bridge id)kSecAttrAccount: kKeychainAccount,
	};
	SecItemDelete((__bridge CFDictionaryRef)query);
}

@end
