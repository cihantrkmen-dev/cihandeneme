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
