package com.example.simrelay

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.net.*
import android.os.Build
import android.telecom.TelecomManager
import android.telephony.SmsManager
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.PrintWriter
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket

object RelayManager {
    private var serverSocket: ServerSocket? = null
    private var currentClientSocket: Socket? = null
    private var activeWriter: PrintWriter? = null

    @Volatile var connectedPeerIp: String? = null
    var onMessageCallback: ((String) -> Unit)? = null
    var audioHelper: BluetoothAudioHelper? = null
    var discoveryHelper: AutoDiscoveryHelper? = null

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var clientReconnectJob: Job? = null
    private var heartbeatJob: Job? = null

    private var isClientMode = false
    private var wifiWatcherRegistered = false
    private const val PORT = 8888

    fun startServer(context: Context) {
        isClientMode = false
        clientReconnectJob?.cancel()

        scope.launch {
            try {
                serverSocket?.close()
                serverSocket = ServerSocket(PORT)
                logToUi("Sunucu aktif (Port $PORT). İkinci cihaz bekleniyor...")

                while (isActive) {
                    val client = serverSocket!!.accept()
                    client.soTimeout = 12000
                    currentClientSocket?.close()
                    currentClientSocket = client

                    connectedPeerIp = client.inetAddress.hostAddress
                    activeWriter = PrintWriter(client.getOutputStream(), true)
                    logToUi("İkinci cihaz bağlandı: $connectedPeerIp")

                    startHeartbeat()
                    listenSocket(context, client, isServer = true)
                }
            } catch (e: Exception) {
                logToUi("Sunucu durumu: ${e.message}")
            }
        }
    }

    fun startClientWithAutoReconnect(context: Context, initialIp: String? = null) {
        isClientMode = true
        if (!initialIp.isNullOrBlank()) {
            connectedPeerIp = initialIp
        }

        registerWifiReconnectWatcher(context.applicationContext)
        triggerClientConnectionLoop(context.applicationContext)
    }

    private fun triggerClientConnectionLoop(context: Context) {
        if (clientReconnectJob?.isActive == true) return

        clientReconnectJob = scope.launch {
            while (isActive && isClientMode) {
                val targetIp = connectedPeerIp

                if (targetIp.isNullOrBlank()) {
                    logToUi("Ana cihaz otomatik aranıyor...")
                    discoveryHelper?.startClientDiscovery()
                    delay(4000)
                    continue
                }

                try {
                    logToUi("$targetIp adresine bağlanılıyor...")
                    val socket = Socket()
                    socket.connect(InetSocketAddress(targetIp, PORT), 4000)
                    socket.soTimeout = 12000

                    currentClientSocket = socket
                    activeWriter = PrintWriter(socket.getOutputStream(), true)
                    logToUi("BAĞLANDI! Ana cihaz: $targetIp")

                    startHeartbeat()
                    listenSocket(context, socket, isServer = false)
                } catch (e: Exception) {
                    logToUi("Bağlantı yok, 3 sn içinde tekrar denenecek...")
                    discoveryHelper?.startClientDiscovery()
                    delay(3000)
                }
            }
        }
    }

    private fun startHeartbeat() {
        heartbeatJob?.cancel()
        heartbeatJob = scope.launch {
            while (isActive) {
                delay(5000)
                try {
                    val ping = JSONObject().put("type", "PING")
                    activeWriter?.println(ping.toString())
                    if (activeWriter?.checkError() == true) {
                        currentClientSocket?.close()
                        break
                    }
                } catch (e: Exception) {
                    currentClientSocket?.close()
                    break
                }
            }
        }
    }

    private suspend fun listenSocket(context: Context, socket: Socket, isServer: Boolean) {
        withContext(Dispatchers.IO) {
            try {
                val reader = BufferedReader(InputStreamReader(socket.getInputStream()))
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    val json = JSONObject(line!!)
                    if (json.optString("type") == "PING") continue

                    if (isServer) {
                        handleCommandOnServer(context, json)
                    } else {
                        handleEventOnClient(json)
                    }
                }
            } catch (e: Exception) {
                logToUi("Bağlantı koptu! Otomatik yeniden bağlanma devrede...")
            } finally {
                heartbeatJob?.cancel()
                audioHelper?.stopUdpAudioStream()
                try { socket.close() } catch (_: Exception) {}
            }
        }
    }

    private fun registerWifiReconnectWatcher(context: Context) {
        if (wifiWatcherRegistered) return
        wifiWatcherRegistered = true

        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .build()

        cm.registerNetworkCallback(request, object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                if (isClientMode) {
                    logToUi("Wi-Fi ağı algılandı, ana cihaz aranıyor...")
                    discoveryHelper?.startClientDiscovery()
                }
            }
        })
    }

    private fun handleCommandOnServer(context: Context, json: JSONObject) {
        when (json.optString("action")) {
            "SEND_SMS" -> {
                val num = json.getString("number")
                val msg = json.getString("message")
                val smsManager = context.getSystemService(SmsManager::class.java)
                smsManager.sendTextMessage(num, null, msg, null, null)
                logToUi("Komut -> SMS Gönderildi: $num")
            }
            "MAKE_CALL" -> {
                val num = json.getString("number")
                val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$num")).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
                connectedPeerIp?.let { audioHelper?.startUdpAudioStream(it) }
                logToUi("Komut -> Numara Aranıyor: $num")
            }
            "ANSWER_CALL" -> {
                answerIncomingCall(context)
                connectedPeerIp?.let { audioHelper?.startUdpAudioStream(it) }
            }
            "END_CALL" -> {
                endActiveCall(context)
                audioHelper?.stopUdpAudioStream()
            }
        }
    }

    private fun handleEventOnClient(json: JSONObject) {
        val type = json.optString("type")
        val sender = json.optString("sender")
        val content = json.optString("content")

        logToUi("[$type] $sender: $content")

        if (type == "CALL" && content == "ACTIVE") {
            connectedPeerIp?.let { audioHelper?.startUdpAudioStream(it) }
        } else if (type == "CALL" && content == "ENDED") {
            audioHelper?.stopUdpAudioStream()
        }
    }

    fun sendPacket(json: JSONObject) {
        scope.launch {
            activeWriter?.println(json.toString())
        }
    }

    fun sendEventFromServer(type: String, sender: String, content: String) {
        val json = JSONObject().apply {
            put("type", type)
            put("sender", sender)
            put("content", content)
        }
        sendPacket(json)
        logToUi("Aktarıldı -> [$type] $sender: $content")
    }

    @SuppressLint("MissingPermission")
    fun answerIncomingCall(context: Context) {
        val tm = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        tm.acceptRingingCall()
        logToUi("Çağrı yanıtlandı.")
    }

    @SuppressLint("MissingPermission")
    fun endActiveCall(context: Context) {
        val tm = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            tm.endCall()
            logToUi("Çağrı sonlandırıldı.")
        }
    }

    private fun logToUi(msg: String) {
        CoroutineScope(Dispatchers.Main).launch {
            onMessageCallback?.invoke(msg)
        }
    }
}
