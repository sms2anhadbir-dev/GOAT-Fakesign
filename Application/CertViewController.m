#import "CertViewController.h"
#import "CertManager.h"

typedef NS_ENUM(NSInteger, CertRow) {
	CertRowP12,
	CertRowProvision,
	CertRowPassword,
	CertRowClear,
	CertRowCount,
};

@interface CertViewController () <UIDocumentPickerDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, assign) BOOL pendingImportIsP12;
@end

@implementation CertViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleInsetGrouped];
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Signing Certificate";
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return CertRowCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return @"Get a free .p12 + .mobileprovision by signing in with a free Apple ID through Xcode or a sideloading tool, then export/share them here. The password is stored in the Keychain, not in plain text.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row == CertRowPassword) {
		UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"pw"];
		cell.textLabel.text = @"P12 Password";
		self.passwordField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 180, 30)];
		self.passwordField.placeholder = @"password";
		self.passwordField.secureTextEntry = YES;
		self.passwordField.textAlignment = NSTextAlignmentRight;
		self.passwordField.text = [CertManager p12Password];
		self.passwordField.delegate = self;
		cell.accessoryView = self.passwordField;
		return cell;
	}

	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"row"];
	switch (indexPath.row) {
		case CertRowP12:
			cell.textLabel.text = @"Certificate (.p12)";
			cell.detailTextLabel.text = [CertManager p12URL] ? @"Configured" : @"Not set";
			break;
		case CertRowProvision:
			cell.textLabel.text = @"Provisioning Profile";
			cell.detailTextLabel.text = [CertManager provisionURL] ? @"Configured" : @"Not set";
			break;
		case CertRowClear:
			cell.textLabel.text = @"Clear Certificate";
			cell.textLabel.textColor = [UIColor systemRedColor];
			cell.detailTextLabel.text = @"";
			break;
	}
	return cell;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
	[CertManager setP12Password:textField.text ?: @""];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	switch (indexPath.row) {
		case CertRowP12:
			self.pendingImportIsP12 = YES;
			[self presentDocumentPicker];
			break;
		case CertRowProvision:
			self.pendingImportIsP12 = NO;
			[self presentDocumentPicker];
			break;
		case CertRowClear:
			[CertManager clearCert];
			[tableView reloadData];
			break;
		default:
			break;
	}
}

- (void)presentDocumentPicker {
	// UTIs for .p12/.mobileprovision aren't reliably distinct across iOS
	// versions, so accept any file and rely on which row was tapped.
	UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
		initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeImport];
	picker.delegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
	NSURL *url = urls.firstObject;
	if (!url) return;

	NSError *error;
	BOOL ok = self.pendingImportIsP12
		? [CertManager importP12AtURL:url error:&error]
		: [CertManager importProvisionAtURL:url error:&error];

	if (!ok) {
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Import Failed"
			message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
		[self presentViewController:alert animated:YES completion:nil];
	}
	[self.tableView reloadData];
}

@end
