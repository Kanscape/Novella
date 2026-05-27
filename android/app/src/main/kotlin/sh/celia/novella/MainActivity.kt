package sh.celia.novella

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // 强制内容延伸到系统栏区域（消除黑色背景）
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "novella/system_ui",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "restoreDefault" -> {
                    val lightSystemBars =
                        call.argument<Boolean>("lightSystemBars") ?: true
                    restoreDefaultSystemUi(lightSystemBars)
                    result.success(null)
                }
                "applyReader" -> {
                    val showStatusBar = call.argument<Boolean>("showStatusBar") ?: false
                    applyReaderSystemUi(showStatusBar)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun restoreDefaultSystemUi(lightSystemBars: Boolean) {
        configureTransparentSystemBars()
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_DEFAULT
        controller.isAppearanceLightStatusBars = lightSystemBars
        controller.isAppearanceLightNavigationBars = lightSystemBars
        controller.show(WindowInsetsCompat.Type.systemBars())
    }

    private fun applyReaderSystemUi(showStatusBar: Boolean) {
        configureTransparentSystemBars()
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        controller.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE

        if (showStatusBar) {
            controller.show(WindowInsetsCompat.Type.statusBars())
            controller.hide(WindowInsetsCompat.Type.navigationBars())
        } else {
            controller.hide(WindowInsetsCompat.Type.systemBars())
        }
    }

    private fun configureTransparentSystemBars() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
    }
}
