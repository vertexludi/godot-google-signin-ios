#ifndef GODOT_GOOGLE_SIGNIN_H
#define GODOT_GOOGLE_SIGNIN_H

#include "core/object/ref_counted.h"
#include "core/string/ustring.h"
#include "core/variant/typed_array.h"

class GodotGoogleSignIn : public RefCounted {
	GDCLASS(GodotGoogleSignIn, RefCounted)

	static void _bind_methods();

public:
	void initiate_signin(String hint = String(), TypedArray<String> additional_scopes = TypedArray<String>());
	bool is_signed_in();
	Dictionary get_current_user();
	void restore_signin();
	void sign_out();
	void disconnect_user();
};

#endif // GODOT_GOOGLE_SIGNIN_H
