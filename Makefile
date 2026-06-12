android_arm64:
	dart ./setup.dart android --arch arm64
macos_arm64:
	dart ./setup.dart macos --arch arm64
macos_amd64:
	dart ./setup.dart macos --arch amd64
macos_universal:
	dart ./setup.dart macos --universal
android_app:
	dart ./setup.dart android
android_arm64_core:
	dart ./setup.dart android --arch arm64 --out core
macos_arm64_core:
	dart ./setup.dart macos --arch arm64  --out core
macos_amd64_core:
	dart ./setup.dart macos --arch amd64 --out core
macos_universal_core:
	dart ./setup.dart macos --universal --out core