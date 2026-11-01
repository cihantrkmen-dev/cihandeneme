package com.example.simrelay

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import org.json.JSONObject

class MainActivity : AppCompatActivity() {

    private lateinit var tvLogs: TextView
    private lateinit var audioHelper: BluetoothAudioHelper
    private lateinit var discoveryHelper: AutoDiscoveryHelper

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        tvLogs = findViewById(R.id.tvLogs)
        val etServerIp = findViewById<EditText>(R.id.etServerIp)
        val etTargetNumber = findViewById<EditText>(R.id.etTargetNumber)
        val etSmsMessage = findViewById<EditText>(R.id.etSmsMessage)

        requestRequiredPermissions()

        audioHelper = BluetoothAudioHelper(this) { logMsg -> appendLog(logMsg) }
        RelayManager.audioHelper = audioHelper
        RelayManager.onMessageCallback = { logMsg -> appendLog(logMsg) }

        discoveryHelper = AutoDiscoveryHelper(
            context = this,
            onLog = { logMsg -> appendLog(logMsg) },
            onServerFound = { foundIp ->
                etServerIp.setText(foundIp)
                RelayManager.connectedPeerIp = foundIp
            }
        )
        RelayManager.discoveryHelper = discoveryHelper

        val serviceIntent = Intent(this, RelayForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }

        findViewById<Button>(R.id.btnStartServer).setOnClickListener {
            RelayManager.startServer(this)
            discoveryHelper.startServerAnnouncement(8888)
        }

        findViewById<Button>(R.id.btnConnectClient).setOnClickListener {
            val manualIp = etServerIp.text.toString().trim()
            discoveryHelper.startClientDiscovery()
            RelayManager.startClientWithAutoReconnect(this, manualIp)
        }

        findViewById<Button>(R.id.btnToggleBtSco).setOnClickListener {
            audioHelper.toggleBluetoothSco()
        }

        findViewById<Button>(R.id.btnAnswerCall).setOnClickListener {
            RelayManager.sendPacket(JSONObject().put("action", "ANSWER_CALL"))
        }
        findViewById<Button>(R.id.btnEndCall).setOnClickListener {
            RelayManager.sendPacket(JSONObject().put("action", "END_CALL"))
            audioHelper.stopUdpAudioStream()
        }

        findViewById<Button>(R.id.btnSendSms).setOnClickListener {
            val json = JSONObject().apply {
                put("action", "SEND_SMS")
                put("number", etTargetNumber.text.toString())
                put("message", etSmsMessage.text.toString())
            }
            RelayManager.sendPacket(json)
            appendLog("SMS komutu gönderildi.")
        }

        findViewById<Button>(R.id.btnMakeCall).setOnClickListener {
            val json = JSONObject().apply {
                put("action", "MAKE_CALL")
                put("number", etTargetNumber.text.toString())
            }
            RelayManager.sendPacket(json)
            RelayManager.connectedPeerIp?.let { ip -> audioHelper.startUdpAudioStream(ip) }
            appendLog("Arama komutu gönderildi.")
        }
    }

    private fun appendLog(msg: String) {
        tvLogs.append("• $msg\n")
    }

    private fun requestRequiredPermissions() {
        val perms = mutableListOf(
            Manifest.permission.RECEIVE_SMS,
            Manifest.permission.SEND_SMS,
            Manifest.permission.READ_PHONE_STATE,
            Manifest.permission.READ_CALL_LOG,
            Manifest.permission.ANSWER_PHONE_CALLS,
            Manifest.permission.CALL_PHONE,
            Manifest.permission.RECORD_AUDIO
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            perms.add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            perms.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        ActivityCompat.requestPermissions(this, perms.toTypedArray(), 101)
    }
}
