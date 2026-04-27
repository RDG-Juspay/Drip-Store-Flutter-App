package com.drip.drip_store

// FlutterFragmentActivity is required (instead of FlutterActivity) so that
// the Juspay HyperCheckout SDK can use Android Fragments for its payment sheet
// and correctly handle onActivityResult for 3DS / deep-link redirects.
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
