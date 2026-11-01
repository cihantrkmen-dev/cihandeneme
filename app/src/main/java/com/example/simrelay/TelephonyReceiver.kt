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
