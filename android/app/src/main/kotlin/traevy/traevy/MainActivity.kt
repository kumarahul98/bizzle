package traevy.traevy

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Phase 36 (D-03): hosts the app's single platform MethodChannel.
 *
 * Only for the handful of operations that genuinely need the Android Activity.
 * Right now that is one: opening THIS app's permission list.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        // Must match kPlatformChannelName / kOpenAppPermissionsMethod in
        // lib/config/constants.dart.
        const val CHANNEL = "traevy/platform"
        const val METHOD_OPEN_APP_PERMISSIONS = "openAppPermissions"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    METHOD_OPEN_APP_PERMISSIONS ->
                        result.success(openAppPermissions())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Open this app's permission list, and return whether a screen was shown.
     *
     * ACTION_APP_PERMISSIONS (API 23+) is as close as public API gets: it opens
     * the app's *permissions page*, one level deeper than
     * ACTION_APPLICATION_DETAILS_SETTINGS (App Info) — which is where the "Open
     * settings" CTA used to land despite claiming otherwise. Deep-linking
     * further, straight to the Location toggle, is not achievable through
     * public API on any Android version, and a vendor-specific intent would be
     * fragile across the OEM range this app targets.
     *
     * **The fallback is mandatory (T-36-01), not defensive padding.**
     * ACTION_APP_PERMISSIONS is not guaranteed to resolve on every OEM skin,
     * and an uncaught ActivityNotFoundException would crash the app at exactly
     * the moment the user is already blocked by a denied permission — the worst
     * possible time to take the app away from them. Both startActivity calls
     * are guarded; if neither resolves this returns false and the caller
     * surfaces the failure rather than the process dying.
     */
    private fun openAppPermissions(): Boolean {
        val appUri: Uri = Uri.fromParts("package", packageName, null)

        try {
            startActivity(Intent(Settings.ACTION_APP_PERMISSIONS).setData(appUri))
            return true
        } catch (_: ActivityNotFoundException) {
            // Fall through to App Info — see the mandatory-fallback note above.
        }

        return try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).setData(appUri)
            )
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }
}
