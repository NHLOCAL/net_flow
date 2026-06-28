package com.example.net_flow

import android.app.role.RoleManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "net_flow/browser"
    private var methodChannel: MethodChannel? = null
    private var initialUrl: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        initialUrl = intent?.dataString
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        )
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialUrl" -> result.success(initialUrl)
                "isDefaultBrowserRoleAvailable" -> {
                    result.success(isBrowserRoleAvailable())
                }
                "isDefaultBrowserRoleHeld" -> {
                    result.success(isBrowserRoleHeld())
                }
                "requestDefaultBrowserRole" -> {
                    requestBrowserRole()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val url = intent.dataString ?: return
        initialUrl = url
        methodChannel?.invokeMethod("openUrl", url)
    }

    private fun isBrowserRoleAvailable(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return false
        }

        val roleManager = getSystemService(RoleManager::class.java)
        return roleManager.isRoleAvailable(RoleManager.ROLE_BROWSER)
    }

    private fun isBrowserRoleHeld(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return false
        }

        val roleManager = getSystemService(RoleManager::class.java)
        return roleManager.isRoleHeld(RoleManager.ROLE_BROWSER)
    }

    private fun requestBrowserRole() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return
        }

        val roleManager = getSystemService(RoleManager::class.java)
        if (!roleManager.isRoleAvailable(RoleManager.ROLE_BROWSER) ||
            roleManager.isRoleHeld(RoleManager.ROLE_BROWSER)
        ) {
            return
        }

        startActivity(roleManager.createRequestRoleIntent(RoleManager.ROLE_BROWSER))
    }
}
