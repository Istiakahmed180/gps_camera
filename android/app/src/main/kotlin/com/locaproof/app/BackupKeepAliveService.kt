package com.locaproof.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Keeps Locaproof running while it finishes a Google Drive backup after
 * the user leaves the app. Phones such as OPPO, Realme and OnePlus freeze
 * a closed app within seconds and cut its internet; a foreground service
 * with its notification is what they leave alone. Dart stops it when the
 * backup is done; it also stops itself after [MAX_MS].
 */
class BackupKeepAliveService : Service() {
    private val main = Handler(Looper.getMainLooper())
    private val stopSelfRunnable = Runnable { stopSelf() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Backing up to Google Drive"
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: ""
        createChannel(this, intent?.getStringExtra(EXTRA_CHANNEL) ?: "Backup")
        val open = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_backup)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setProgress(0, 0, true)
            .setContentIntent(open)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .build()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // Not allowed now (e.g. started too late): nothing to keep alive.
            stopSelf()
            return START_NOT_STICKY
        }
        main.removeCallbacks(stopSelfRunnable)
        main.postDelayed(stopSelfRunnable, MAX_MS)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        main.removeCallbacks(stopSelfRunnable)
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL_ID = "drive_backup"
        private const val NOTIFICATION_ID = 4107
        private const val MAX_MS = 10 * 60 * 1000L
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_CHANNEL = "channel"

        private fun createChannel(context: Context, name: String) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_LOW)
                    .apply { setShowBadge(false) },
            )
        }

        /** Starts it; false when Android does not allow it right now. */
        fun start(context: Context, title: String, text: String, channel: String): Boolean = try {
            ContextCompat.startForegroundService(
                context,
                Intent(context, BackupKeepAliveService::class.java)
                    .putExtra(EXTRA_TITLE, title)
                    .putExtra(EXTRA_TEXT, text)
                    .putExtra(EXTRA_CHANNEL, channel),
            )
            true
        } catch (e: Exception) {
            false
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, BackupKeepAliveService::class.java))
        }
    }
}
