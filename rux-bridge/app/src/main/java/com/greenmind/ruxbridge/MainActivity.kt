package com.greenmind.ruxbridge

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView

class MainActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // Auto-start bridge service
        startService(Intent(this, BridgeService::class.java))

        // Hiện IP
        val ip = getLocalIpAddress()
        findViewById<TextView>(R.id.tvStatus).text =
            "🌿 Greenmind Bridge\nĐang chạy tại:\nhttp://$ip:8080"

        // Nút test
        findViewById<Button>(R.id.btnSpeak).setOnClickListener {
            startService(Intent(this, BridgeService::class.java))
        }
    }

    private fun getLocalIpAddress(): String {
        try {
            val en = java.net.NetworkInterface.getNetworkInterfaces()
            while (en.hasMoreElements()) {
                val intf = en.nextElement()
                val enumIpAddr = intf.inetAddresses
                while (enumIpAddr.hasMoreElements()) {
                    val inetAddress = enumIpAddr.nextElement()
                    if (!inetAddress.isLoopbackAddress && inetAddress is java.net.Inet4Address) {
                        return inetAddress.hostAddress ?: "unknown"
                    }
                }
            }
        } catch (e: Exception) { }
        return "unknown"
    }
}
