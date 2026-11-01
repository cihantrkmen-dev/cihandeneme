
#!/bin/bash
set -e

echo "Klasör yapısı oluşturuluyor..."
mkdir -p .github/workflows
mkdir -p app/src/main/java/com/example/simrelay
mkdir -p app/src/main/res/layout

# 1. settings.gradle
cat << 'EOF' > settings.gradle
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "SIMRelay"
include ':app'
EOF

# 2. build.gradle (Project)
cat << 'EOF' > build.gradle
plugins {
    id 'com.android.application' version '8.2.2' apply false
    id 'org.jetbrains.kotlin.android' version '1.9.22' apply false
}
EOF

# 3. gradle.properties (AndroidX uyumluluğu için zorunlu)
cat << 'EOF' > gradle.properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
EOF

# 4. app/build.gradle
cat << 'EOF' > app/build.gradle
plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
}

android {
    namespace 'com.example.simrelay'
    compileSdk 34

    defaultConfig {
        applicationId "com.example.simrelay"
        minSdk 26
        targetSdk 34
        versionCode 1
        versionName "1.0"
    }

    buildTypes {
        release {
            minifyEnabled false
        }
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = '17'
    }
}

dependencies {
    implementation 'androidx.core:core-ktx:1.12.0'
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.11.0'
    implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3'
}
EOF

# 5. .github/workflows/build.yml
cat << 'EOF' > .github/workflows/build.yml
name: Android APK Builder

on:
  push:
    branches: [ "main", "master" ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Kodu İndir
        uses: actions/checkout@v4

      - name: JDK 17 Kur
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Gradle Kur
        uses: gradle/actions/setup-gradle@v3
        with:
          gradle-version: '8.5'

      - name: Debug APK Derle
        run: gradle assembleDebug --no-daemon

      - name: APK Dosyasını Yükle
        uses: actions/upload-artifact@v4
        with:
          name: SimRelay-APK
          path: app/build/outputs/apk/debug/app-debug.apk
EOF

# 6. AndroidManifest.xml
cat << 'EOF' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />

    <uses-permission android:name="android.permission.RECEIVE_SMS" />
    <uses-permission android:name="android.permission.SEND_SMS" />
    <uses-permission android:name="android.permission.READ_PHONE_STATE" />
    <uses-permission android:name="android.permission.READ_CALL_LOG" />
    <uses-permission android:name="android.permission.ANSWER_PHONE_CALLS" />
    <uses-permission android:name="android.permission.CALL_PHONE" />

    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application
        android:allowBackup="true"
        android:label="SIM Relay"
        android:supportsRtl="true"
        android:theme="@style/Theme.AppCompat.Light.DarkActionBar">

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service
            android:name=".RelayForegroundService"
            android:enabled="true"
            android:exported="false" />

        <receiver
            android:name=".TelephonyReceiver"
            android:enabled="true"
            android:exported="true">
            <intent-filter>
                <action android:name="android.provider.Telephony.SMS_RECEIVED" />
                <action android:name="android.intent.action.PHONE_STATE" />
            </intent-filter>
        </receiver>

    </application>
</manifest>
EOF

# 7. activity_main.xml
cat << 'EOF' > app/src/main/res/layout/activity_main.xml
<?xml version="1.0" encoding="utf-8"?>
<ScrollView xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:padding="16dp">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="vertical">

        <TextView
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:text="1. CİHAZ ROLÜNÜ SEÇİN (OTOMATİK EŞLEŞME)"
            android:textStyle="bold"
            android:textSize="15sp" />

        <Button
            android:id="@+id/btnStartServer"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:text="SIM Kartlı Ana Cihaz Olarak Başlat (Sunucu)" />

        <EditText
            android:id="@+id/etServerIp"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:hint="IP Otomatik Bulunur (Veya Elle Girin)"
            android:text=""
            android:layout_marginTop="6dp" />

        <Button
            android:id="@+id/btnConnectClient"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:text="İkinci Cihaz Olarak Otomatik Bağlan (İstemci)" />

        <View
            android:layout_width="match_parent"
            android:layout_height="2dp"
            android:background="#CCCCCC"
            android:layout_marginVertical="12dp" />

        <TextView
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:text="2. BLUETOOTH HFP &amp; SES KONTROLÜ"
            android:textStyle="bold"
            android:textSize="15sp" />

        <Button
            android:id="@+id/btnToggleBtSco"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:text="Bluetooth HFP (SCO) Ses Kanalını Aç/Kapat" />

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal">

            <Button
                android:id="@+id/btnAnswerCall"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:text="Çağrıyı Aç" />

            <Button
                android:id="@+id/btnEndCall"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:text="Çağrıyı Kapat" />
        </LinearLayout>

        <View
            android:layout_width="match_parent"
            android:layout_height="2dp"
            android:background="#CCCCCC"
            android:layout_marginVertical="12dp" />

        <TextView
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:text="3. UZAKTAN ARAMA VE SMS GÖNDER"
            android:textStyle="bold"
            android:textSize="15sp" />

        <EditText
            android:id="@+id/etTargetNumber"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:hint="Telefon Numarası (Örn: 05551234567)"
            android:inputType="phone" />

        <EditText
            android:id="@+id/etSmsMessage"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:hint="SMS Mesajınız" />

        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:orientation="horizontal">

            <Button
                android:id="@+id/btnSendSms"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:text="SMS Gönder" />

            <Button
                android:id="@+id/btnMakeCall"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:text="Numarayı Ara" />
        </LinearLayout>

        <TextView
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:text="CANLI DURUM VE KAYITLAR (LOG):"
            android:textStyle="bold"
            android:layout_marginTop="12dp" />

        <TextView
            android:id="@+id/tvLogs"
            android:layout_width="match_parent"
            android:layout_height="220dp"
            android:background="#EEEEEE"
            android:padding="8dp"
            android:scrollbars="vertical"
            android:text="Sistem hazır...\n"
            android:textSize="13sp" />

    </LinearLayout>
</ScrollView>
EOF

# 8. AutoDiscoveryHelper.kt
cat << 'EOF' > app/src/main/java/com/example/simrelay/AutoDiscoveryHelper.kt
package com.example.simrelay

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import kotlinx.coroutines.*
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress

class AutoDiscoveryHelper(
    private val context: Context,
    private val onLog: (String) -> Unit,
    private val onServerFound: (String) -> Unit
) {
    private val nsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val SERVICE_NAME = "SimRelayServer"
    private val SERVICE_TYPE = "_simrelay._tcp."
    private val DISCOVERY_UDP_PORT = 8890

    private var registrationListener: NsdManager.RegistrationListener? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    @Volatile private var isServerAnnouncing = false
    @Volatile private var isClientSearching = false

    fun startServerAnnouncement(port: Int = 8888) {
        if (isServerAnnouncing) return
        isServerAnnouncing = true

        try {
            val serviceInfo = NsdServiceInfo().apply {
                serviceName = SERVICE_NAME
                serviceType = SERVICE_TYPE
                setPort(port)
            }
            registrationListener = object : NsdManager.RegistrationListener {
                override fun onServiceRegistered(info: NsdServiceInfo) {
                    logToMain("Otomatik keşif (NSD) aktif.")
                }
                override fun onRegistrationFailed(info: NsdServiceInfo, errorCode: Int) {}
                override fun onServiceUnregistered(info: NsdServiceInfo) {}
                override fun onUnregistrationFailed(info: NsdServiceInfo, errorCode: Int) {}
            }
            nsdManager.registerService(serviceInfo, NsdManager.PROTOCOL_DNS_SD, registrationListener)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        scope.launch {
            var socket: DatagramSocket? = null
            try {
                socket = DatagramSocket().apply { broadcast = true }
                val message = "SIM_RELAY_SERVER_HERE".toByteArray()
                val broadcastAddress = InetAddress.getByName("255.255.255.255")

                while (isServerAnnouncing && isActive) {
                    val packet = DatagramPacket(message, message.size, broadcastAddress, DISCOVERY_UDP_PORT)
                    socket.send(packet)
                    delay(2000)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                try { socket?.close() } catch (_: Exception) {}
            }
        }
    }

    fun startClientDiscovery() {
        if (isClientSearching) return
        isClientSearching = true

        try {
            discoveryListener = object : NsdManager.DiscoveryListener {
                override fun onDiscoveryStarted(regType: String) {}
                override fun onServiceFound(service: NsdServiceInfo) {
                    if (service.serviceType.contains("_simrelay") || service.serviceName.contains(SERVICE_NAME)) {
                        nsdManager.resolveService(service, object : NsdManager.ResolveListener {
                            override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {}
                            override fun onServiceResolved(resolvedInfo: NsdServiceInfo) {
                                resolvedInfo.host?.hostAddress?.let { ip ->
                                    reportFoundIp(ip, "NSD")
                                }
                            }
                        })
                    }
                }
                override fun onServiceLost(service: NsdServiceInfo) {}
                override fun onDiscoveryStopped(serviceType: String) {}
                override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {}
                override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {}
            }
            nsdManager.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        scope.launch {
            val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val lock = wifi.createMulticastLock("simrelay_multicast_lock").apply {
                setReferenceCounted(true)
                acquire()
            }
            var socket: DatagramSocket? = null
            try {
                socket = DatagramSocket(DISCOVERY_UDP_PORT).apply {
                    broadcast = true
                    soTimeout = 3500
                }
                val buffer = ByteArray(1024)
                val packet = DatagramPacket(buffer, buffer.size)
                socket.receive(packet)
                val msg = String(packet.data, 0, packet.length)
                if (msg == "SIM_RELAY_SERVER_HERE") {
                    packet.address.hostAddress?.let { ip ->
                        reportFoundIp(ip, "UDP Broadcast")
                    }
                }
            } catch (_: Exception) {
            } finally {
                try { socket?.close() } catch (_: Exception) {}
                if (lock.isHeld) lock.release()
                stopClientDiscovery()
            }
        }
    }

    @Synchronized
    private fun reportFoundIp(ip: String, method: String) {
        CoroutineScope(Dispatchers.Main).launch {
            onLog("Ana cihaz IP'si bulundu ($method): $ip")
            onServerFound(ip)
        }
        stopClientDiscovery()
    }

    fun stopClientDiscovery() {
        isClientSearching = false
        try {
            discoveryListener?.let { nsdManager.stopServiceDiscovery(it) }
        } catch (_: Exception) {}
        discoveryListener = null
    }

    private fun logToMain(msg: String) {
        CoroutineScope(Dispatchers.Main).launch { onLog(msg) }
    }
}
EOF

# 9. BluetoothAudioHelper.kt
cat << 'EOF' > app/src/main/java/com/example/simrelay/BluetoothAudioHelper.kt
package com.example.simrelay

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.media.*
import kotlinx.coroutines.*
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress

class BluetoothAudioHelper(private val context: Context, private val onLog: (String) -> Unit) {

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var bluetoothHeadset: BluetoothHeadset? = null
    private var isScoActive = false
    @Volatile private var isStreamingAudio = false
    private val audioScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val AUDIO_PORT = 8889

    init {
        initBluetoothHfpProfile()
    }

    @SuppressLint("MissingPermission")
    private fun initBluetoothHfpProfile() {
        try {
            val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            val adapter: BluetoothAdapter? = btManager.adapter
            adapter?.getProfileProxy(context, object : BluetoothProfile.ServiceListener {
                override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                    if (profile == BluetoothProfile.HEADSET) {
                        bluetoothHeadset = proxy as BluetoothHeadset
                        val count = bluetoothHeadset?.connectedDevices?.size ?: 0
                        onLog("Bluetooth HFP Profili Hazır. Bağlı Cihaz: $count")
                    }
                }
                override fun onServiceDisconnected(profile: Int) {
                    if (profile == BluetoothProfile.HEADSET) {
                        bluetoothHeadset = null
                    }
                }
            }, BluetoothProfile.HEADSET)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    @SuppressLint("MissingPermission")
    fun toggleBluetoothSco() {
        if (!isScoActive) {
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
            audioManager.startBluetoothSco()
            audioManager.isBluetoothScoOn = true
            isScoActive = true
            onLog("Bluetooth HFP (SCO) ses yönlendirmesi AÇILDI.")
        } else {
            audioManager.isBluetoothScoOn = false
            audioManager.stopBluetoothSco()
            audioManager.mode = AudioManager.MODE_NORMAL
            isScoActive = false
            onLog("Bluetooth HFP (SCO) ses yönlendirmesi KAPATILDI.")
        }
    }

    @SuppressLint("MissingPermission")
    fun startUdpAudioStream(targetIp: String) {
        if (isStreamingAudio) return
        isStreamingAudio = true
        onLog("Canlı ses aktarımı başladı ($targetIp:$AUDIO_PORT)")

        val sampleRate = 8000
        val bufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        ).coerceAtLeast(1024)

        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        audioManager.isSpeakerphoneOn = true

        audioScope.launch {
            var recorder: AudioRecord? = null
            var socket: DatagramSocket? = null
            try {
                recorder = AudioRecord(
                    MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                    sampleRate,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufferSize
                )
                socket = DatagramSocket()
                val address = InetAddress.getByName(targetIp)
                val buffer = ByteArray(bufferSize)

                recorder.startRecording()
                while (isStreamingAudio && isActive) {
                    val read = recorder.read(buffer, 0, buffer.size)
                    if (read > 0) {
                        socket.send(DatagramPacket(buffer, read, address, AUDIO_PORT))
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                try { recorder?.stop(); recorder?.release() } catch (_: Exception) {}
                try { socket?.close() } catch (_: Exception) {}
            }
        }

        audioScope.launch {
            var track: AudioTrack? = null
            var socket: DatagramSocket? = null
            try {
                track = AudioTrack(
                    AudioManager.STREAM_VOICE_CALL,
                    sampleRate,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufferSize,
                    AudioTrack.MODE_STREAM
                )
                socket = DatagramSocket(AUDIO_PORT).apply { soTimeout = 2000 }
                val buffer = ByteArray(bufferSize)

                track.play()
                while (isStreamingAudio && isActive) {
                    try {
                        val packet = DatagramPacket(buffer, buffer.size)
                        socket.receive(packet)
                        track.write(packet.data, 0, packet.length)
                    } catch (_: Exception) {}
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                try { track?.stop(); track?.release() } catch (_: Exception) {}
                try { socket?.close() } catch (_: Exception) {}
            }
        }
    }

    fun stopUdpAudioStream() {
        if (!isStreamingAudio) return
        isStreamingAudio = false
        audioManager.isSpeakerphoneOn = false
        audioManager.mode = AudioManager.MODE_NORMAL
        onLog("Canlı ses aktarımı durduruldu.")
    }
}
EOF

# 10. RelayManager.kt
cat << 'EOF' > app/src/main/java/com/example/simrelay/RelayManager.kt
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
EOF

# 11. TelephonyReceiver.kt
cat << 'EOF' > app/src/main/java/com/example/simrelay/TelephonyReceiver.kt
package com.example.simrelay

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.TelephonyManager

class TelephonyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Telephony.Sms.Intents.SMS_RECEIVED_ACTION -> {
                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                for (sms in messages) {
                    val sender = sms.displayOriginatingAddress ?: "Bilinmeyen"
                    val body = sms.messageBody ?: ""
                    RelayManager.sendEventFromServer("SMS", sender, body)
                }
            }
            TelephonyManager.ACTION_PHONE_STATE_CHANGED -> {
                val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
                val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER) ?: "Arama"

                when (state) {
                    TelephonyManager.EXTRA_STATE_RINGING -> {
                        RelayManager.sendEventFromServer("CALL", number, "RINGING (Çalıyor)")
                    }
                    TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                        RelayManager.sendEventFromServer("CALL", number, "ACTIVE")
                        RelayManager.connectedPeerIp?.let {
                            RelayManager.audioHelper?.startUdpAudioStream(it)
                        }
                    }
                    TelephonyManager.EXTRA_STATE_IDLE -> {
                        RelayManager.sendEventFromServer("CALL", number, "ENDED")
                        RelayManager.audioHelper?.stopUdpAudioStream()
                    }
                }
            }
        }
    }
}
EOF

# 12. RelayForegroundService.kt
cat << 'EOF' > app/src/main/java/com/example/simrelay/RelayForegroundService.kt
package com.example.simrelay

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class RelayForegroundService : Service() {
    override fun onCreate() {
        super.onCreate()
        val channelId = "sim_relay_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "SIM Aktarım Servisi",
                NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("SIM Relay Aktif")
            .setContentText("SMS, Çağrı ve Otomatik Bağlantı arka planda çalışıyor.")
            .setSmallIcon(android.R.drawable.stat_sys_phone_call)
            .build()

        startForeground(1, notification)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY
    override fun onBind(intent: Intent?): IBinder? = null
}
EOF

# 13. MainActivity.kt
cat << 'EOF' > app/src/main/java/com/example/simrelay/MainActivity.kt
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
EOF

echo "✅ Tüm proje dosyaları başarıyla oluşturuldu!"
