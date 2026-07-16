#import "RootViewController.h"
#import "Signer.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface RootViewController () <UIDocumentPickerDelegate>
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *pickButton;
@property (nonatomic, strong) NSURL *pickedIPA;
@end

@implementation RootViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"GOAT Sign";
	self.view.backgroundColor = [UIColor systemBackgroundColor];

	self.pickButton = [UIButton buttonWithType:UIButtonTypeSystem];
	[self.pickButton setTitle:@"Select IPA" forState:UIControlStateNormal];
	self.pickButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
	[self.pickButton addTarget:self action:@selector(pickIPA) forControlEvents:UIControlEventTouchUpInside];
	self.pickButton.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:self.pickButton];

	self.statusLabel = [UILabel new];
	self.statusLabel.text = @"No IPA selected";
	self.statusLabel.textColor = [UIColor secondaryLabelColor];
	self.statusLabel.numberOfLines = 0;
	self.statusLabel.textAlignment = NSTextAlignmentCenter;
	self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:self.statusLabel];

	[NSLayoutConstraint activateConstraints:@[
		[self.pickButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
		[self.pickButton.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-40],
		[self.statusLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
		[self.statusLabel.topAnchor constraintEqualToAnchor:self.pickButton.bottomAnchor constant:24],
		[self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
		[self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],
	]];
}

- (void)pickIPA {
	NSArray *types = @[@"public.data"];
	UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:types inMode:UIDocumentPickerModeImport];
	picker.delegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
	NSURL *url = urls.firstObject;
	if (!url) return;
	self.pickedIPA = url;
	self.statusLabel.text = [NSString stringWithFormat:@"Selected: %@\nFakesigning...", url.lastPathComponent];

	[Signer fakesignIPAAtURL:url progress:^(NSString *message) {
		self.statusLabel.text = message;
	} completion:^(NSURL *signedIPA, NSError *error) {
		if (error) {
			self.statusLabel.text = [NSString stringWithFormat:@"Failed: %@", error.localizedDescription];
			return;
		}
		self.statusLabel.text = [NSString stringWithFormat:@"Fakesigned: %@\nTap Share to install.", signedIPA.lastPathComponent];
		[self offerToShare:signedIPA];
	}];
}

- (void)offerToShare:(NSURL *)fileURL {
	UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
	activity.popoverPresentationController.sourceView = self.view;
	[self presentViewController:activity animated:YES completion:nil];
}

@end
