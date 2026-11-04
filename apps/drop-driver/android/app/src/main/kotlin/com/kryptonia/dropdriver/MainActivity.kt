package com.kryptonia.dropdriver

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterFragmentActivity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.content.Context
import android.os.Bundle

class MainActivity: FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "trip_tracking",
                "Trip Tracking",
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Tracking driver location"

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

}