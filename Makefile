ARCHS = arm64
TARGET := iphone:clang:14.5:14.0
THEOS_DEVICE_IP =

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = GOATSign

GOATSign_FILES = Application/main.m Application/AppDelegate.m Application/RootViewController.m Application/Signer.m Application/RepoManager.m Application/ArchiveManager.m Application/SourcesViewController.m Application/CertManager.m Application/CertViewController.m
GOATSign_FRAMEWORKS = UIKit Foundation MobileCoreServices UniformTypeIdentifiers Security
GOATSign_LIBRARIES = archive
GOATSign_CFLAGS = -fobjc-arc -Wall -IApplication/Headers -Wno-error=nullability-completeness -Wno-error=deprecated-declarations
GOATSign_INFOPLIST = Application/GOATSign-Info.plist

include $(THEOS_MAKE_PATH)/application.mk

after-stage::
	@mkdir -p $(THEOS_STAGING_DIR)/Applications/GOATSign.app
	@cp Application/Resources/ldid $(THEOS_STAGING_DIR)/Applications/GOATSign.app/ldid
	@chmod 755 $(THEOS_STAGING_DIR)/Applications/GOATSign.app/ldid
	@if [ -f Application/Resources/zsign ]; then \
		cp Application/Resources/zsign $(THEOS_STAGING_DIR)/Applications/GOATSign.app/zsign; \
		chmod 755 $(THEOS_STAGING_DIR)/Applications/GOATSign.app/zsign; \
	else \
		echo "WARNING: Application/Resources/zsign not found - real signing will fail at runtime until you build and place it there."; \
	fi

after-package::
	@echo "GOATSign.ipa built (unsigned). Run: ldid -S <path-to-GOATSign-executable> to fakesign the app itself before installing."
