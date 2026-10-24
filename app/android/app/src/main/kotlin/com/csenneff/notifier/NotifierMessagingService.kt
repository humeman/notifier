package com.csenneff.notifier

import android.os.Handler
import android.os.Looper
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Receives the function's data-only pushes and renders them with
 * [AlertNotifier]. Runs without a Flutter engine, which is why rendering is
 * native rather than in Dart.
 */
class NotifierMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val id = data["id"] ?: return
        AlertNotifier(applicationContext).show(
            id = id,
            system = data["system"] ?: "unknown",
            level = AlertNotifier.Level.parse(data["level"]),
            title = data["title"] ?: "",
            postedAt = message.sentTime.takeIf { it > 0 } ?: System.currentTimeMillis(),
        )
        // Lets an open inbox refresh; a no-op when the app isn't running.
        Handler(Looper.getMainLooper()).post { listener?.onAlertReceived(id) }
    }

    override fun onNewToken(token: String) {
        // Re-registered with the API on the next app launch (the app always
        // registers its current token at startup), or right away if it's open.
        Handler(Looper.getMainLooper()).post { listener?.onTokenChanged(token) }
    }

    interface Listener {
        fun onAlertReceived(id: String)
        fun onTokenChanged(token: String)
    }

    companion object {
        /** Set by MainActivity while it's alive. */
        @Volatile
        var listener: Listener? = null
    }
}
