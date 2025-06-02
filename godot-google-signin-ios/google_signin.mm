#include "google_signin.h"

#include "core/object/class_db.h"
#include "core/variant/dictionary.h"

#include "app_delegate.h"
#import "jwt_decode.h"

@import GoogleSignIn;

@implementation JWT_Decode

+ (NSDictionary *) decodeWithToken:(NSString *)token {
	NSArray *segments = [token componentsSeparatedByString:@"."];

	if ([segments count] != 3) {
		return nil;
	}

	NSString *payloadSeg = segments[1];

	// Decode and parse payload JSON
	NSString *string = [[payloadSeg stringByReplacingOccurrencesOfString:@"-" withString:@"+"]
						stringByReplacingOccurrencesOfString:@"_" withString:@"/"];

	int size = [string length] % 4;
	NSMutableString *segment = [[NSMutableString alloc] initWithString:string];
	for (int i = 0; i < size; i++) {
		[segment appendString:@"="];
	}

	NSData *jsonData = [[NSData alloc] initWithBase64EncodedString:segment options:0];

	NSError *error;

	NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:&error];

	return payload;
}

@end

void GodotGoogleSignIn::_bind_methods() {
	ClassDB::bind_method(D_METHOD("initiate_signin", "hint", "additional_scopes"), &GodotGoogleSignIn::initiate_signin, String(), TypedArray<String>());
	ClassDB::bind_method(D_METHOD("is_signed_in"), &GodotGoogleSignIn::is_signed_in);
	ClassDB::bind_method(D_METHOD("get_current_user"), &GodotGoogleSignIn::get_current_user);
	ClassDB::bind_method(D_METHOD("restore_signin"), &GodotGoogleSignIn::restore_signin);
	ClassDB::bind_method(D_METHOD("sign_out"), &GodotGoogleSignIn::sign_out);
	ClassDB::bind_method(D_METHOD("disconnect_user"), &GodotGoogleSignIn::disconnect_user);

	ADD_SIGNAL(MethodInfo("signin_completed", PropertyInfo(Variant::DICTIONARY, "data"), PropertyInfo(Variant::STRING, "error")));
	ADD_SIGNAL(MethodInfo("restore_completed", PropertyInfo(Variant::DICTIONARY, "data"), PropertyInfo(Variant::STRING, "error")));
	ADD_SIGNAL(MethodInfo("disconnection_completed", PropertyInfo(Variant::STRING, "error")));
}

static Dictionary dict_from_user(GIDGoogleUser *user) {
	if (user == nil) {
		return Dictionary();
	}

	Dictionary jwt_dict;
	NSString *raw_jwt = user.idToken.tokenString;

	NSDictionary *jwt = [JWT_Decode decodeWithToken:raw_jwt];
	if (jwt != nil) {
		for (NSString *key in jwt) {
			NSString *value = [NSString stringWithFormat:@"%@", jwt[key]];
			jwt_dict[key.UTF8String] = value.UTF8String;
		}
	}

	NSISO8601DateFormatter *dateFormatter = [[NSISO8601DateFormatter alloc] init];

	Array granted_scopes;

	for (NSString *scope in user.grantedScopes) {
		granted_scopes.push_back(scope.UTF8String);
	}

	Dictionary data;
	data["id"] = user.userID.UTF8String;
	data["name"] = user.profile.name.UTF8String;
	data["email"] = user.profile.email.UTF8String;
	data["profile_pic"] = [user.profile hasImage] ? [user.profile imageURLWithDimension:320].absoluteString.UTF8String : "";
	data["identity_token"] = raw_jwt.UTF8String;
	data["access_token"] = user.accessToken.tokenString.UTF8String;
	data["access_token_expiration"] = [dateFormatter stringFromDate:user.accessToken.expirationDate].UTF8String;
	data["refresh_token"] = user.refreshToken.tokenString.UTF8String;
	data["granted_scopes"] = granted_scopes;
	data["jwt"] = jwt_dict;

	return data;
}

void GodotGoogleSignIn::initiate_signin(String hint, TypedArray<String> additional_scopes) {
	NSString *nshint = [NSString stringWithUTF8String:hint.utf8().get_data()];

	NSMutableArray<NSString *> *scopes = [NSMutableArray arrayWithCapacity:additional_scopes.size()];

	for (String str : additional_scopes) {
		[scopes addObject:[NSString stringWithUTF8String:str.utf8().get_data()]];
	}

	[GIDSignIn.sharedInstance signInWithPresentingViewController:(UIViewController *)AppDelegate.viewController hint:nshint
												additionalScopes:scopes completion:^(GIDSignInResult * _Nullable signInResult, NSError * _Nullable error) {

		if (error) {
			NSString *err_str = [NSString stringWithFormat:@"%@", error.localizedDescription];
			call_deferred("emit_signal", "signin_completed", Dictionary(), err_str.UTF8String);
			return;
		}
		if (signInResult == nil) {
			call_deferred("emit_signal", "signin_completed", Dictionary(), "unknown");
			return;
		}


		[signInResult.user refreshTokensIfNeededWithCompletion:^(GIDGoogleUser * _Nullable user,
																 NSError * _Nullable error) {

			if (error) {
				NSString *err_str = [NSString stringWithFormat:@"%@", error.localizedDescription];
				call_deferred("emit_signal", "signin_completed", Dictionary(), err_str.UTF8String);
				return;
			}
			if (signInResult == nil) {
				call_deferred("emit_signal", "signin_completed", Dictionary(), "failed_refresh");
				return;
			}

			call_deferred("emit_signal", "signin_completed", dict_from_user(user), "");
		}];
	}];
}

bool GodotGoogleSignIn::is_signed_in() {
	return [GIDSignIn.sharedInstance hasPreviousSignIn];
}

Dictionary GodotGoogleSignIn::get_current_user() {
	return dict_from_user([GIDSignIn.sharedInstance currentUser]);
}

void GodotGoogleSignIn::restore_signin() {
	[GIDSignIn.sharedInstance restorePreviousSignInWithCompletion:^(GIDGoogleUser * _Nullable user, NSError * _Nullable error) {
		if (error) {
			NSString *err_str = [NSString stringWithFormat:@"%@", error.localizedDescription];
			call_deferred("emit_signal", "restore_completed", Dictionary(), [err_str cStringUsingEncoding:NSUTF8StringEncoding]);
			return;
		}
		if (user == nil) {
			call_deferred("emit_signal", "restore_completed", Dictionary(), "unknown");
			return;
		}

		call_deferred("emit_signal", "restore_completed", dict_from_user(user), "");
	}];
}

void GodotGoogleSignIn::sign_out() {
	[GIDSignIn.sharedInstance signOut];
}

void GodotGoogleSignIn::disconnect_user() {
	[GIDSignIn.sharedInstance disconnectWithCompletion:^(NSError * _Nullable error) {
		if (error) {
			NSString *err_str = [NSString stringWithFormat:@"%@", error.localizedDescription];
			call_deferred("emit_signal", "disconnection_completed", [err_str cStringUsingEncoding:NSUTF8StringEncoding]);
		} else {
			call_deferred("emit_signal", "disconnection_completed", "");
		}
	}];
}
