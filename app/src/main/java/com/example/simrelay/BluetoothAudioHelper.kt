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
                        val headset = proxy as BluetoothHeadset
                        bluetoothHeadset = headset
                        val count = headset.connectedDevices?.size ?: 0
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
            var recorderRef: AudioRecord? = null
            var socketRef: DatagramSocket? = null
            try {
                val recorder = AudioRecord(
                    MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                    sampleRate,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufferSize
                )
                recorderRef = recorder
                val socket = DatagramSocket()
                socketRef = socket
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
                try { recorderRef?.stop(); recorderRef?.release() } catch (_: Exception) {}
                try { socketRef?.close() } catch (_: Exception) {}
            }
        }

        audioScope.launch {
            var trackRef: AudioTrack? = null
            var socketRef: DatagramSocket? = null
            try {
                val track = AudioTrack(
                    AudioManager.STREAM_VOICE_CALL,
                    sampleRate,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufferSize,
                    AudioTrack.MODE_STREAM
                )
                trackRef = track
                val socket = DatagramSocket(AUDIO_PORT).apply { soTimeout = 2000 }
                socketRef = socket
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
                try { trackRef?.stop(); trackRef?.release() } catch (_: Exception) {}
                try { socketRef?.close() } catch (_: Exception) {}
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
