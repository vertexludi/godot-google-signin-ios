#!/bin/bash
set -e

# Check if godot headers were generated.
if [[ $(find godot -name '*.gen.h' | wc -l | awk '{$1=$1};1') == 0 ]]; then
	./scripts/generate_headers.sh
fi

# Build archives
xcrun xcodebuild archive -workspace godot-google-signin-ios.xcworkspace -scheme godot-google-signin-ios -destination "generic/platform=iOS" -archivePath "bin/archives/godot-google-signin-ios.debug" -configuration Debug -quiet
xcrun xcodebuild archive -workspace godot-google-signin-ios.xcworkspace -scheme godot-google-signin-ios -destination "generic/platform=iOS" -archivePath "bin/archives/godot-google-signin-ios.release" -configuration Release -quiet
xcrun xcodebuild archive -project Pods/Pods.xcodeproj -scheme GoogleSignIn -destination "generic/platform=iOS" -archivePath "bin/archives/GoogleSignIn.release" -configuration Release -quiet SKIP_INSTALL=NO

# Build xcframework
xcrun xcodebuild -create-xcframework \
		-archive bin/archives/godot-google-signin-ios.debug.xcarchive -library libgodot-google-signin-ios.a \
		-output bin/xcframeworks/google_signin.debug.xcframework
xcrun xcodebuild -create-xcframework \
		-archive bin/archives/godot-google-signin-ios.release.xcarchive -library libgodot-google-signin-ios.a \
		-output bin/xcframeworks/google_signin.release.xcframework

# Move all to release folder
rm -rf bin/google_signin
mkdir -p bin/google_signin

cp godot-google-signin-ios/google_signin.gdip bin/google_signin/
mv bin/xcframeworks/google_signin.debug.xcframework bin/google_signin/
mv bin/xcframeworks/google_signin.release.xcframework bin/google_signin/
mv bin/archives/GoogleSignIn.release.xcarchive/Products/Library/Frameworks/*.framework bin/google_signin/

rm -rf bin/xcframeworks
rm -rf bin/archives

cd bin
zip -r google_signin google_signin
cd ..
