package com.example.rtc_probe

import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        // RTCProbe native bridge: exposes the OS network path to Flutter.
        // The only Android-native addition; WebRTC itself lives inside the
        // flutter_webrtc plugin's prebuilt binaries.
        MethodChannel(engine.dartExecutor.binaryMessenger, "rtc_probe/network_info")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrentPath" -> result.success(readNetworkPath())
                    else -> result.notImplemented()
                }
            }
    }

    private fun readNetworkPath(): Map<String, Any?> {
        val manager = getSystemService(ConnectivityManager::class.java) ?: return unavailable()
        val network = manager.activeNetwork ?: return mapOf(
            "interfaceType" to "none",
            "isExpensive" to true,
            "isConstrained" to false,
            "source" to "kotlin-connectivity"
        )
        val caps = manager.getNetworkCapabilities(network) ?: return unavailable()

        val type = when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            else -> "unknown"
        }
        return mapOf(
            "interfaceType" to type,
            // A network is "expensive" when it is metered.
            "isExpensive" to !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED),
            "isConstrained" to false, // no direct ConnectivityManager equivalent
            "source" to "kotlin-connectivity"
        )
    }

    private fun unavailable(): Map<String, Any?> = mapOf(
        "interfaceType" to "unavailable",
        "isExpensive" to false,
        "isConstrained" to false,
        "source" to "unavailable"
    )
}
