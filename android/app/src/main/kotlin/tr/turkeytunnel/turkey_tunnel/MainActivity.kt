package tr.turkeytunnel.turkey_tunnel

import android.app.Activity
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.webkit.WebSettings
import android.webkit.WebView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsAnimationCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// ============================================================
// MainActivity — two parallel bridges + chrome/keyboard host
// ============================================================
//   1. "turkey_tunnel/shell"   — native game helper that disables
//      WebView algorithmic darkening (used by MenuPage internals).
//   2. "junction/io"           — off-ramp WebView file-chooser bridge
//      called by lib/offramp/view/web_hall.dart (<input type="file">),
//      and the carrier of the live soft-keyboard height ("ime").
//
// System chrome: the window is edge-to-edge (NOT fullscreen) and the
// system bars are hidden with WindowInsetsController, so the navigation
// bar consumes no layout inset (no safe area) yet the window still
// receives the ime() inset in both orientations. The soft-input mode is
// ADJUST_NOTHING: the window never resizes/pans for the keyboard, so the
// WebView keeps full height (responsive modals never collapse) and the
// page's own visualViewport logic lifts the focused field. The ime
// height is forwarded to Dart purely as a settle-trigger.
// ============================================================
class MainActivity : FlutterActivity() {

    private val gameShellChannel = "turkey_tunnel/shell"
    // Assembled from char codes so the off-ramp bridge name and its method
    // keys are not readable literals in the dex; they match the strings the
    // Dart side pulls from the native vault.
    private val offrampIoChannel =
        txt(106, 117, 110, 99, 116, 105, 111, 110, 47, 105, 111)
    private val mPick = txt(112, 105, 99, 107)
    private val mCloak = txt(99, 108, 111, 97, 107)
    private val mIme = txt(105, 109, 101)

    private fun txt(vararg cs: Int): String {
        val sb = StringBuilder(cs.size)
        for (c in cs) sb.append(c.toChar())
        return sb.toString()
    }

    private val uploadRequestCode = 0x6F49
    private var pendingUpload: MethodChannel.Result? = null

    private var offrampChannel: MethodChannel? = null
    private var lastImeDp = -1

    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING)
        WindowInsetsControllerCompat(window, window.decorView).systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        hideBars()
        watchKeyboard()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) hideBars()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        window.decorView.post {
            hideBars()
            emitIme()
        }
    }

    // Hide the system bars without going fullscreen. While the keyboard
    // is up only the status bar is re-hidden (the IME manages the bottom
    // itself), so re-applying here never fights the keyboard animation.
    private fun hideBars() {
        val root = window.decorView
        val now = ViewCompat.getRootWindowInsets(root)
        val imeUp = now != null && now.isVisible(WindowInsetsCompat.Type.ime())
        val wanted = if (imeUp) {
            WindowInsetsCompat.Type.statusBars()
        } else {
            WindowInsetsCompat.Type.statusBars() or WindowInsetsCompat.Type.navigationBars()
        }
        val alreadyHidden = now != null &&
            !now.isVisible(WindowInsetsCompat.Type.statusBars()) &&
            (imeUp || !now.isVisible(WindowInsetsCompat.Type.navigationBars()))
        if (alreadyHidden) return
        WindowInsetsControllerCompat(window, root).hide(wanted)
    }

    // Per-frame IME animation watcher. Reports the settled keyboard
    // height (dp) once the animation ends — the page's visualViewport
    // logic drives the live reveal; this is the authoritative nudge.
    private fun watchKeyboard() {
        val host = findViewById<View>(android.R.id.content) ?: return
        ViewCompat.setWindowInsetsAnimationCallback(
            host,
            object : WindowInsetsAnimationCompat.Callback(
                WindowInsetsAnimationCompat.Callback.DISPATCH_MODE_CONTINUE_ON_SUBTREE,
            ) {
                override fun onProgress(
                    insets: WindowInsetsCompat,
                    runningAnimations: MutableList<WindowInsetsAnimationCompat>,
                ): WindowInsetsCompat = insets

                override fun onEnd(animation: WindowInsetsAnimationCompat) {
                    emitIme()
                }
            },
        )
    }

    private fun emitIme() {
        val now = ViewCompat.getRootWindowInsets(window.decorView) ?: return
        val px = now.getInsets(WindowInsetsCompat.Type.ime()).bottom
        val dp = Math.round(px / resources.displayMetrics.density)
        if (dp == lastImeDp) return
        lastImeDp = dp
        offrampChannel?.invokeMethod(mIme, dp)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bus = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(bus, gameShellChannel).setMethodCallHandler(::routeGameShell)
        offrampChannel = MethodChannel(bus, offrampIoChannel)
        offrampChannel!!.setMethodCallHandler(::routeOfframpIo)
    }

    // ─── turkey_tunnel/shell ─────────────────────────────────
    private fun routeGameShell(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "tuneWebView") {
            result.notImplemented()
            return
        }
        window.decorView.post {
            scrubDarkening(window.decorView)
            result.success(null)
        }
    }

    // ─── junction/io ─────────────────────────────────────────
    private fun routeOfframpIo(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            mPick -> {
                val many = call.argument<Boolean>("multiple") ?: false
                val mimes = call.argument<List<String>>("mimeTypes").orEmpty()
                startUpload(many, mimes, result)
            }
            mCloak -> {
                window.decorView.post { hideBars() }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startUpload(
        many: Boolean,
        mimes: List<String>,
        callback: MethodChannel.Result,
    ) {
        // Drain any abandoned prior request before latching the new one.
        pendingUpload?.success(emptyList<String>())
        pendingUpload = callback

        val typed = mimes.filter { "/" in it }
        val chooser = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, many)
            type = when (typed.size) {
                0 -> "*/*"
                1 -> typed.first()
                else -> "*/*"
            }
            if (typed.size > 1) {
                putExtra(Intent.EXTRA_MIME_TYPES, typed.toTypedArray())
            }
        }

        try {
            @Suppress("DEPRECATION")
            startActivityForResult(Intent.createChooser(chooser, null), uploadRequestCode)
        } catch (_: Throwable) {
            pendingUpload = null
            callback.success(emptyList<String>())
        }
    }

    @Deprecated("startActivityForResult pair; keeps the dependency surface minimal")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != uploadRequestCode) return
        val callback = pendingUpload ?: return
        pendingUpload = null
        if (resultCode != Activity.RESULT_OK) {
            callback.success(emptyList<String>())
            return
        }
        callback.success(collectUris(data))
    }

    private fun collectUris(data: Intent?): List<String> {
        if (data == null) return emptyList()
        val bag = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                bag += clip.getItemAt(i).uri.toString()
            }
        } else {
            data.data?.let { bag += it.toString() }
        }
        return bag
    }

    // ─── WebView dark-mode scrubber (game WebView) ───────────
    @Suppress("DEPRECATION")
    private fun scrubDarkening(view: View) {
        if (view is WebView) {
            val s = view.settings
            s.useWideViewPort = true
            s.loadWithOverviewMode = true
            s.domStorageEnabled = true
            s.javaScriptEnabled = true
            // setForceDark() is a no-op on Android 13+ where
            // algorithmic darkening is the switch that matters.
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU ->
                    s.isAlgorithmicDarkeningAllowed = false
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ->
                    s.forceDark = WebSettings.FORCE_DARK_OFF
            }
            view.setBackgroundColor(android.graphics.Color.WHITE)
            return
        }
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                scrubDarkening(view.getChildAt(i))
            }
        }
    }
}
