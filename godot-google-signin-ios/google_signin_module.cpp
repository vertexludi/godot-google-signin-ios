#include "google_signin_module.h"

#include "google_signin.h"

#include "core/object/class_db.h"

void register_google_signin_types() {
	GDREGISTER_CLASS(GodotGoogleSignIn);
}

void unregister_google_signin_types() {}
