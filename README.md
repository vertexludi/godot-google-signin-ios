# GodotGoogleSignIn iOS Plugin

## Usage

Since this is only available for iOS, you cannot use the class name directly. Instead, use `ClassDB` to create an instance:

```gdscript
var signin_handler = null

func _ready() -> void:
	if ClassDB.class_exists("GodotGoogleSignIn"):
		signin_handler = ClassDB.instantiate("GodotGoogleSignIn")
```

Then you can call methods and connect signals using the custom variable.

## API

### Methods

**`initiate_signin(hint: String = "", additional_scopes: Array[String] = []) -> void`**

Initiate signin with Google. This will start the flow of authentication, asking if the user wants to sign in with Google and showing a webview for them to allow or deny the request.

The result of this will come asynchronously with the `signin_completed` signal.

**Parameters**:
- `hint`: Provide a hint to the signin system of what user to login. This can be the user's email, for example. If not provided, the user may have to select which Google account they want to use to signin.
- `additional_scopes`: A list of additional scopes to ask authorization from the user. If left unset, only the default ones will be included (email and public profile). A list of scopes is available at https://developers.google.com/identity/protocols/oauth2/scopes.

**`is_signed_in() -> bool`**

Returns whether or not the user is signed in with Google. The library automatically stores this in keychain, so this call is synchronous and does not require any server call.

You can use this information to decide whether you want to restore a session in the background or actually ask the user to sign in.

**`get_current_user() -> Dictionary`**

Returns the current user data as a Dictionary. This is synchronous and only give information stored by the Google library in the keychain. If the session has not been restored yet, this may be empty, even if `is_signed_in()` return true.

The following data is included in this dictionary:

- `id`: The user's id as given by Google.
- `name`: The user's full name.
- `email`: The user's email.
- `profile_pic`: A URL to the user's profile picture if there's any.
- `identity_token`: Raw JWT provided by Google. Can be used by servers to validate user identity.
- `access_token`: OAuth2 access token provided by Google.
- `access_token_expiration`: An ISO 8601 date string with the expiration time for the access token. You can use Godot's [`Time.get_datetime_dict_from_datetime_string()`](https://docs.godotengine.org/en/stable/classes/class_time.html#class-time-method-get-datetime-dict-from-datetime-string) function to decode this string if needed.
- `refresh_token`: OAuth2 refresh token to exchange for new access tokens.
- `granted_scopes`: An array of strings listing the actual scopes granted by the user.
- `jwt`: The decoded data from the identity token (without any signature validation) as `Dictionary[String, String]`.

**`restore_signin() -> void`**

Attempts to restore a previous sign-in without user interaction. This can be done when the app just starts up to make sure the user is still signed in.

The results are returned via the `restore_completed` signal.

**`sign_out() -> void`**

Signs out the current user by removing the data from the keychain.

**`disconnect_user() -> void`**

Disconnects the user, revoking all OAuth2 grants made to the app. This can be used to completely unlink the user's Google account from the app. If you just want a logout function, use `sign_out()` instead.

This methods performs a request to revoke the grants. The result of the operation arrives via the `disconnection_completed` signal.

### Signals

**`signin_completed(data: Dictionary, error: String)`**

Emitted after the signin process is completed after calling `initiate_signin()`. If the process was successful, the user data will be filled in the dictionary while the `error` string will be empty.

If there was any error, the message will be sent in the `error` parameter and the `data` dictionary will be empty.

The user data has the same format described in the `get_current_user()` function description.

> [!NOTE]
> The error message is returned from what the underlying library gives. Sometimes this error might be `"unknown"` in case something unexpected happen. It's not safe to show this as a result for the user. This is valid for the other signals too.

**`restore_completed(data: Dictionary, error: String)`**

Emitted when the sign-in session restore is completed after calling `restore_signin`. In case of success, the data will be filled with user information (see function `get_current_user()` for the data format) and the error string will be empty.

In case of error, the data will be empty and the error string will contain some information about the error.

**`disconnection_completed(state: String)`**

Emitted when the disconnection process is complete after calling `disconnect_user()`. There's no data associated with this process, so it will only return an error string which will be empty in case everything went correctly.

## Installation

Get the ZIP package from Releases and extract on your project in the `ios/plugins` folder (you'll have to create it first). It will create a `google_signin` folder there with frameworks and the needed `.gdip` file so Godot can recognize the plugin.

On the Export dialog, enable `Google Sign In` on the `Plugins` section.

> [!IMPORTANT]
> You need first to create an OAuth client ID (and likely a server client ID as well) in the Google Cloud Console, as described in the [Sign in with Google for iOS documentation](https://developers.google.com/identity/sign-in/ios/start-integrating#get_an_oauth_client_id).

Enable the advanced settings in the export dialog and add this to the `Additional Plist Content` to properly configure your client ID:

```xml
<key>GIDClientID</key>
<string>YOUR_IOS_CLIENT_ID</string>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>YOUR_DOT_REVERSED_IOS_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

If you're doing backend authentication, you also need your server client ID which you can also add to this field:

```xml
<key>GIDServerClientID</key>
<string>YOUR_SERVER_CLIENT_ID</string>
```

For more information, check the [Sign in with Google for iOS library documentation](https://developers.google.com/identity/sign-in/ios/start-integrating#configure_app_project) which also has some other optional configuration you might need.

## Building

Make sure you initialize the Git submodules so that the Godot source is downloaded:

```
$ git submodule update --init --recursive
```

Then you need to start compilation of Godot to generate the headers. Easiest way to do so is to run the included script:

```
$ ./scripts/generate_headers.sh
```

This will run Godot compilation for 20 seconds then cancel it, which should be enough to generate all headers. If you face build errors because of missing headers, try running this again.

Install the library dependencies using [CocoaPods](https://cocoapods.org/):

```
$ pod install
```

This will create a project and workspace with all dependencies. Make sure you open the workspace on Xcode, not just the project. From there you can build the project as usual.

### Installation after building

If you want to generate the files for using on your project, just run the release script:

```
$ ./scripts/make_release.sh
```

You can inspect the script to understand what commands are being called.

In short, what this does is:

- Create an archive of this plugin (for debug and release).
- Create an archive of the `GoogleSignIn` dependency, which brings all of its dependencies together.
- Create an xcframework for this plugin (again for debug and release).
- Move the xcframework the `bin/google_signin` folder.
- Move all `*.framework` dependencies from the `GoogleSignIn` archive to the `bin/google_signin` folder.
- Copy the plugin configuration file `google_signin.gdip` to the `bin/google_signin` folder.
- Zips the folder for distribution.

You can use the `bin/google_signin` folder in your project's `ios/plugins` folder to install it.

### Updating for debug

If you already have the plugin installed and want to test your changes, you only need to update the `google_signin.debug.xcframework` file. You do need to recreate the archive (which actually recompiles the library) before creating the xcframework.

Then you can move the xcframework to your project replacing the old one. If you don't want to re-export the Xcode project, you can also replace the xcframework in the previously generated project and run from there.
