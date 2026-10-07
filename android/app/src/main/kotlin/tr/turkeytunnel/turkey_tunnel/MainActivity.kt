package tr.turkeytunnel.turkey_tunnel

import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.webkit.WebSettings
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "turkey_tunnel/shell").setMethodCallHandler { call, result ->
            if (call.method != "tuneWebView") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            window.decorView.post {
                disableWebViewDarkening(window.decorView)
                result.success(null)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun disableWebViewDarkening(view: View) {
        if (view is WebView) {
            val settings = view.settings
            settings.useWideViewPort = true
            settings.loadWithOverviewMode = true
            settings.domStorageEnabled = true
            settings.javaScriptEnabled = true
            // setForceDark() is a no-op (and logs a warning) on Android 13+,
            // where algorithmic darkening is the switch that matters.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                settings.isAlgorithmicDarkeningAllowed = false
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                settings.forceDark = WebSettings.FORCE_DARK_OFF
            }
            view.setBackgroundColor(android.graphics.Color.WHITE)
            return
        }
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                disableWebViewDarkening(view.getChildAt(i))
            }
        }
    }
}
