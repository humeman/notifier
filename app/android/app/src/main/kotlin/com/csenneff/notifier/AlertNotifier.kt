package com.csenneff.notifier

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationChannelGroup
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.Icon
import android.os.Build
import android.text.SpannableStringBuilder
import android.text.Spanned

/**
 * Builds and posts alert notifications. The single place that decides how an
 * alert looks in the shade, used both by the Flutter test page (through
 * MainActivity's method channel) and, later, by the FCM service.
 */
class AlertNotifier(private val context: Context) {

    enum class Level(
        val channelId: String,
        val channelName: String,
        val importance: Int,
        val prefix: String?,
        val color: Int,
        val smallIcon: Int,
        val category: String,
        // Android 17 semantic colour for the title prefix; see [title].
        val semanticStyle: Int,
    ) {
        INFO(
            "alerts_info", "Info", NotificationManager.IMPORTANCE_DEFAULT,
            prefix = null,
            color = 0xFF7CC8FF.toInt(),
            smallIcon = R.drawable.ic_stat_info,
            category = Notification.CATEGORY_STATUS,
            semanticStyle = Notification.SEMANTIC_STYLE_INFO,
        ),
        WARNING(
            "alerts_warning", "Warnings", NotificationManager.IMPORTANCE_HIGH,
            prefix = "Warning",
            color = 0xFFFFC24B.toInt(),
            smallIcon = R.drawable.ic_stat_warning,
            category = Notification.CATEGORY_STATUS,
            semanticStyle = Notification.SEMANTIC_STYLE_CAUTION,
        ),
        ERROR(
            "alerts_error", "Errors", NotificationManager.IMPORTANCE_HIGH,
            prefix = "Error",
            color = 0xFFFF6B6B.toInt(),
            smallIcon = R.drawable.ic_stat_error,
            category = Notification.CATEGORY_ERROR,
            semanticStyle = Notification.SEMANTIC_STYLE_DANGER,
        );

        companion object {
            /** Missing or unknown levels are Info, matching the API default. */
            fun parse(value: String?): Level =
                entries.firstOrNull { it.name.equals(value, ignoreCase = true) } ?: INFO
        }
    }

    private val manager = context.getSystemService(NotificationManager::class.java)

    /**
     * One channel per level, so sound/vibration/DND can be tuned per level
     * from Android's settings. Idempotent; channel settings the user changed
     * survive re-creation.
     */
    fun ensureChannels() {
        manager.createNotificationChannelGroup(NotificationChannelGroup(GROUP_ID, "Alerts"))
        manager.createNotificationChannels(
            Level.entries.map { level ->
                NotificationChannel(level.channelId, level.channelName, level.importance).apply {
                    group = GROUP_ID
                    enableLights(true)
                    lightColor = level.color
                    if (level == Level.ERROR) {
                        enableVibration(true)
                        vibrationPattern = longArrayOf(0, 250, 150, 250, 150, 500)
                    }
                }
            },
        )
    }

    fun show(id: String, system: String, level: Level, title: String, postedAt: Long) {
        ensureChannels()

        val notification = Notification.Builder(context, level.channelId)
            .setSmallIcon(level.smallIcon)
            .setColor(level.color)
            .setLargeIcon(monogram(system, level))
            .setContentTitle(title(system, level))
            .setContentText(title)
            .setStyle(Notification.BigTextStyle().bigText(title))
            .setCategory(level.category)
            .setWhen(postedAt)
            .setShowWhen(true)
            .setAutoCancel(true)
            .setGroup(groupKey(system))
            .setContentIntent(openIntent(id))
            .build()

        manager.notify(id.hashCode(), notification)
        postGroupSummary(system, level)
    }

    /**
     * "Error: homelab". The prefix also carries Android 17's semantic colour
     * annotation, which the system applies where it supports it (currently
     * promoted/Live Update surfaces) and otherwise ignores.
     */
    private fun title(system: String, level: Level): CharSequence {
        val prefix = level.prefix ?: return system
        val text = SpannableStringBuilder()
        if (Build.VERSION.SDK_INT >= 37) {
            text.append(
                "$prefix:",
                Notification.createSemanticStyleAnnotation(level.semanticStyle),
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
            )
        } else {
            text.append("$prefix:")
        }
        return text.append(' ').append(system)
    }

    /**
     * Bundles a system's alerts together once there's more than one. Android
     * needs an explicit summary notification for the group to collapse.
     */
    private fun postGroupSummary(system: String, level: Level) {
        val summary = Notification.Builder(context, level.channelId)
            .setSmallIcon(level.smallIcon)
            .setColor(level.color)
            .setSubText(system)
            .setGroup(groupKey(system))
            .setGroupSummary(true)
            .setGroupAlertBehavior(Notification.GROUP_ALERT_CHILDREN)
            .setAutoCancel(true)
            .setContentIntent(openIntent(null))
            .build()
        manager.notify(groupKey(system).hashCode(), summary)
    }

    private fun openIntent(alertId: String?): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (alertId != null) putExtra(EXTRA_ALERT_ID, alertId)
        }
        return PendingIntent.getActivity(
            context,
            alertId?.hashCode() ?: 0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * Circle with the system's initial, ringed in the level's colour, as the
     * large icon. Warnings and errors also get the level glyph as a corner
     * badge: Android 17's shade shows the app icon rather than the small icon,
     * so this is where the level is visible at a glance.
     */
    private fun monogram(system: String, level: Level): Icon {
        val size = 192
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val half = size / 2f

        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFF1B1B1F.toInt() }
        canvas.drawCircle(half, half, half, fill)
        val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = level.color
            style = Paint.Style.STROKE
            strokeWidth = size * 0.05f
        }
        canvas.drawCircle(half, half, half - ring.strokeWidth / 2, ring)

        val letter = system.firstOrNull()?.uppercase() ?: "?"
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = level.color
            textSize = size * 0.46f
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
        }
        val badged = level != Level.INFO
        // Nudged up-left when badged, so the badge doesn't sit on the letter.
        val cx = if (badged) half - size * 0.06f else half
        val cy = if (badged) half - size * 0.04f else half
        val baseline = cy - (text.descent() + text.ascent()) / 2
        canvas.drawText(letter, cx, baseline, text)

        if (badged) {
            val badgeR = size * 0.21f
            val bx = size - badgeR
            val by = size - badgeR
            // Background-coloured gap, then the level-coloured disc.
            val gap = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFF0A0A0B.toInt() }
            canvas.drawCircle(bx, by, badgeR, gap)
            val disc = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = level.color }
            canvas.drawCircle(bx, by, badgeR - size * 0.025f, disc)
            context.getDrawable(level.smallIcon)!!.mutate().apply {
                setTint(0xFF0A0A0B.toInt())
                val g = (badgeR * 0.62f).toInt()
                setBounds((bx - g).toInt(), (by - g).toInt(), (bx + g).toInt(), (by + g).toInt())
                draw(canvas)
            }
        }
        return Icon.createWithBitmap(bitmap)
    }

    private fun groupKey(system: String) = "system:$system"

    companion object {
        const val EXTRA_ALERT_ID = "alert_id"
        private const val GROUP_ID = "alerts"
    }
}
