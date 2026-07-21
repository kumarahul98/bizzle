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

        /**
         * The permission-controller's app-permissions screen.
         *
         * A RAW STRING, not a `Settings.*` constant, because there is no public
         * one. `Settings.ACTION_APP_PERMISSIONS` — which the Phase 36 plan
         * named — does not exist in the public SDK; it is `@SystemApi` and
         * hidden, and referencing it does not compile (verified against
         * android-36's android.jar, which exposes
         * ACTION_APPLICATION_DETAILS_SETTINGS and
         * ACTION_MANAGE_APPLICATIONS_SETTINGS but nothing for app permissions).
         *
         * Using an unsupported action is not a shortcut here — it is the only
         * route to that page, and it is exactly why the fallback below is
         * mandatory rather than defensive. On any device or OEM skin where this
         * does not resolve, App Info is what the user gets.
         */
        const val ACTION_MANAGE_APP_PERMISSIONS =
            "android.intent.action.MANAGE_APP_PERMISSIONS"

        /** Package-name extra read by [ACTION_MANAGE_APP_PERMISSIONS]. */
        const val EXTRA_PACKAGE_NAME = "android.intent.extra.PACKAGE_NAME"
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
     * [ACTION_MANAGE_APP_PERMISSIONS] opens the app's *permissions page*, one
     * level deeper than ACTION_APPLICATION_DETAILS_SETTINGS (App Info) — which
     * is where the "Open settings" CTA used to land despite claiming otherwise.
     * Deep-linking further, straight to the Location toggle, is not achievable
     * on any Android version, and a vendor-specific intent would be fragile
     * across the OEM range this app targets.
     *
     * **The fallback is mandatory (T-36-01), not defensive padding**, and doubly
     * so given the primary action is not public API (see its declaration). It
     * is not guaranteed to resolve on every OEM skin, and an uncaught
     * ActivityNotFoundException would crash the app at exactly the moment the
     * user is already blocked by a denied permission — the worst possible time
     * to take the app away from them. Both startActivity calls are guarded; if
     * neither resolves this returns false and the caller surfaces the failure
     * rather than the process dying.
     *
     * Both the data URI and the package-name extra are set: the permissions
     * screen has read the package from either depending on Android version, and
     * setting both costs nothing while a wrong guess costs the whole deep-link.
     */
    private fun openAppPermissions(): Boolean {
        val appUri: Uri = Uri.fromParts("package", packageName, null)

        try {
            startActivity(
                Intent(ACTION_MANAGE_APP_PERMISSIONS).apply {
                    data = appUri
                    putExtra(EXTRA_PACKAGE_NAME, packageName)
                }
            )
            return true
        } catch (_: ActivityNotFoundException) {
            // Fall through to App Info — see the mandatory-fallback note above.
        }

        return try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = appUri
                }
            )
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }
}
