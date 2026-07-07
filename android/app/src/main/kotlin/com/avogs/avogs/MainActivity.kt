package com.avogs.avogs

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth needs a FragmentActivity to host the biometric prompt dialog —
// plain FlutterActivity throws a "no_fragment_activity" PlatformException
// the moment BiometricService.authenticate() is called, which was getting
// silently swallowed and made biometric unlock look like a no-op.
class MainActivity : FlutterFragmentActivity()
