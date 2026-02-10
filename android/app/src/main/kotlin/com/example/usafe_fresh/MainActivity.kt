package com.example.usafe_fresh

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
	private val channelName = "usafe/config"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				if (call.method == "getGoogleMapsApiKey") {
					val key = getGoogleMapsApiKey()
					result.success(key)
				} else {
					result.notImplemented()
				}
			}
	}

	private fun getGoogleMapsApiKey(): String? {
		return try {
			val info = applicationContext.packageManager.getApplicationInfo(
				applicationContext.packageName,
				PackageManager.GET_META_DATA
			)
			val raw = info.metaData?.getString("com.google.android.geo.API_KEY")
			if (raw.isNullOrBlank()) null else raw
		} catch (e: Exception) {
			null
		}
	}
}
