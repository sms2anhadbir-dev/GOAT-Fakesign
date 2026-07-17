#import "SourcesViewController.h"
#import "RepoManager.h"
#import "ArchiveManager.h"
#import "Signer.h"
#import "CertManager.h"

static NSString *const kSourcesDefaultsKey = @"GOATSignSourceURLs";

@interface SourcesViewController ()
@property (nonatomic, strong) NSMutableArray<NSString *> *sourceURLs;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *repoResults; // url -> {repoName, apps}
@end

@implementation SourcesViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleInsetGrouped];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Sources";
	self.repoResults = [NSMutableDictionary dictionary];
	self.sourceURLs = [[[NSUserDefaults standardUserDefaults] arrayForKey:kSourcesDefaultsKey] mutableCopy] ?: [NSMutableArray array];

	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addSourceTapped)];

	[self refreshAllSources];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.tableView reloadData]; // pick up archive changes made elsewhere
}

- (void)addSourceTapped {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Add Source"
		message:@"Enter a repo.json URL" preferredStyle:UIAlertControllerStyleAlert];
	[alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
		tf.placeholder = @"https://example.com/repo.json";
		tf.keyboardType = UIKeyboardTypeURL;
		tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
	}];
	[alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
	[alert addAction:[UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		NSString *urlString = alert.textFields.firstObject.text;
		if (urlString.length == 0) return;
		[self.sourceURLs addObject:urlString];
		[[NSUserDefaults standardUserDefaults] setObject:self.sourceURLs forKey:kSourcesDefaultsKey];
		[self refreshAllSources];
	}]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)refreshAllSources {
	for (NSString *urlString in self.sourceURLs) {
		NSURL *url = [NSURL URLWithString:urlString];
		if (!url) continue;
		[RepoManager fetchRepoAtURL:url completion:^(NSDictionary *result, NSError *error) {
			if (result) {
				self.repoResults[urlString] = result;
				[self.tableView reloadData];
			}
		}];
	}
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1 + self.sourceURLs.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0) return @"Archived (installed offline)";
	NSString *urlString = self.sourceURLs[section - 1];
	NSDictionary *result = self.repoResults[urlString];
	return result[@"repoName"] ?: urlString;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0) return [ArchiveManager archivedApps].count;
	NSString *urlString = self.sourceURLs[section - 1];
	NSArray *apps = self.repoResults[urlString][@"apps"];
	return apps.count;
}

- (NSDictionary *)appEntryAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
		return [ArchiveManager archivedApps][indexPath.row];
	}
	NSString *urlString = self.sourceURLs[indexPath.section - 1];
	NSArray *apps = self.repoResults[urlString][@"apps"];
	return apps[indexPath.row];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];

	NSDictionary *app = [self appEntryAtIndexPath:indexPath];
	cell.textLabel.text = [NSString stringWithFormat:@"%@ (%@)", app[@"name"], app[@"version"]];
	cell.detailTextLabel.text = app[@"description"] ?: app[@"category"];
	cell.accessoryType = (indexPath.section == 0 || [ArchiveManager isArchived:app])
		? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSDictionary *app = [self appEntryAtIndexPath:indexPath];
	BOOL archived = [ArchiveManager isArchived:app];

	UIAlertController *sheet = [UIAlertController alertControllerWithTitle:app[@"name"] message:nil
		preferredStyle:UIAlertControllerStyleActionSheet];

	if (archived) {
		[sheet addAction:[UIAlertAction actionWithTitle:@"Fakesign & Install" style:UIAlertActionStyleDefault
			handler:^(UIAlertAction *a) { [self installArchivedApp:app]; }]];
		[sheet addAction:[UIAlertAction actionWithTitle:@"Delete from Archive" style:UIAlertActionStyleDestructive
			handler:^(UIAlertAction *a) { [ArchiveManager deleteArchivedApp:app]; [tableView reloadData]; }]];
	} else {
		[sheet addAction:[UIAlertAction actionWithTitle:@"Download & Archive" style:UIAlertActionStyleDefault
			handler:^(UIAlertAction *a) { [self downloadApp:app indexPath:indexPath]; }]];
	}
	[sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
	sheet.popoverPresentationController.sourceView = tableView;
	sheet.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath];
	[self presentViewController:sheet animated:YES completion:nil];
}

- (void)downloadApp:(NSDictionary *)app indexPath:(NSIndexPath *)indexPath {
	UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:@"Downloading…"
		message:@"0%" preferredStyle:UIAlertControllerStyleAlert];
	[self presentViewController:progressAlert animated:YES completion:nil];

	[ArchiveManager downloadApp:app progress:^(float fraction) {
		progressAlert.message = [NSString stringWithFormat:@"%.0f%%", fraction * 100];
	} completion:^(NSError *error) {
		[progressAlert dismissViewControllerAnimated:YES completion:^{
			if (error) {
				UIAlertController *err = [UIAlertController alertControllerWithTitle:@"Download Failed"
					message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
				[err addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
				[self presentViewController:err animated:YES completion:nil];
			} else {
				[self.tableView reloadData];
			}
		}];
	}];
}

- (void)installArchivedApp:(NSDictionary *)app {
	NSString *localPath = [ArchiveManager localIPAPathForApp:app];
	if (!localPath) return;
	NSURL *ipaURL = [NSURL fileURLWithPath:localPath];

	BOOL useRealSign = [CertManager hasCertConfigured];
	UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:useRealSign ? @"Signing…" : @"Fakesigning…"
		message:@"" preferredStyle:UIAlertControllerStyleAlert];
	[self presentViewController:progressAlert animated:YES completion:nil];

	SignerProgress progressBlock = ^(NSString *message) { progressAlert.message = message; };
	SignerCompletion completionBlock = ^(NSURL *signedIPA, NSError *error) {
		[progressAlert dismissViewControllerAnimated:YES completion:^{
			if (error) {
				UIAlertController *err = [UIAlertController alertControllerWithTitle:@"Signing Failed"
					message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
				[err addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
				[self presentViewController:err animated:YES completion:nil];
				return;
			}
			UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[signedIPA] applicationActivities:nil];
			activity.popoverPresentationController.sourceView = self.view;
			[self presentViewController:activity animated:YES completion:nil];
		}];
	};

	if (useRealSign) {
		[Signer signIPAAtURL:ipaURL
		              p12URL:[CertManager p12URL]
		         p12Password:[CertManager p12Password]
		        provisionURL:[CertManager provisionURL]
		            progress:progressBlock
		          completion:completionBlock];
	} else {
		[Signer fakesignIPAAtURL:ipaURL progress:progressBlock completion:completionBlock];
	}
}

@end
