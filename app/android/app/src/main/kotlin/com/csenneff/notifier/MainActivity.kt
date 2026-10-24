package com.csenneff.notifier

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts Flutter and exposes AlertNotifier and the FCM token over a method
 * channel. Also relays events to Dart: notification taps (the launching intent
 * is read once via `initialAlertId`, later taps arrive through [onNewIntent]
 * as `opened`), pushes received while open (`received`), and token rotations
 * (`token`).
 */
class MainActivity : FlutterActivity(), NotifierMessagingService.Listener {

    private lateinit var channel: MethodChannel
    private val notifier by lazy { AlertNotifier(applicationContext) }
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notifier.ensureChannels()

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    notifier.show(
                        id = call.argument<String>("id")!!,
                        system = call.argument<String>("system")!!,
                        level = AlertNotifier.Level.parse(call.argument<String>("level")),
                        title = call.argument<String>("title")!!,
                        postedAt = System.currentTimeMillis(),
                    )
                    result.success(null)
                }
                "requestPermission" -> requestPermission(result)
                "fcmToken" -> FirebaseMessaging.getInstance().token
                    .addOnSuccessListener { result.success(it) }
                    .addOnFailureListener { result.error("fcm", it.message, null) }
                "initialAlertId" -> {
                    result.success(intent.getStringExtra(AlertNotifier.EXTRA_ALERT_ID))
                    // Consumed: a rotation or re-attach shouldn't reopen it.
                    intent.removeExtra(AlertNotifier.EXTRA_ALERT_ID)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onStart() {
        super.onStart()
        NotifierMessagingService.listener = this
    }

    override fun onStop() {
        if (NotifierMessagingService.listener === this) {
            NotifierMessagingService.listener = null
        }
        super.onStop()
    }

    override fun onAlertReceived(id: String) {
        channel.invokeMethod("received", id)
    }

    override fun onTokenChanged(token: String) {
        channel.invokeMethod("token", token)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra(AlertNotifier.EXTRA_ALERT_ID)?.let {
            channel.invokeMethod("opened", it)
        }
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        pendingPermission = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISSION_REQUEST) return
        pendingPermission?.success(
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED,
        )
        pendingPermission = null
    }

    companion object {
        private const val CHANNEL = "com.csenneff.notifier/notifications"
        private const val PERMISSION_REQUEST = 1001
    }
}
