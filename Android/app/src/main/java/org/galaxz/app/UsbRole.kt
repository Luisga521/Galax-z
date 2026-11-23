package org.galaxz.app

import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.provider.Settings

/**
 * Which side of the USB cable this phone is on. The OP-Z (with Galax-z OS v6, a host for keyboards) and a phone can each be
 * either; when the OP-Z takes charge, the phone becomes its device and offers "File transfer / USB tethering / MIDI / PTP",
 * and the OP-Z is no MIDI device to it. An app cannot swap the roles (Android keeps that to itself): this sees it happen,
 * and opens the place where the person can ("USB controlled by: This device").
 */
class UsbRole(private val context: Context, private val changed: () -> Unit) {
    /** The phone is a USB device: something on the cable is in charge of it. */
    var asDevice = false; private set
    /** What it offers that something, as Android names it (mtp, ptp, midi, rndis), or "" for charging only. */
    var functions = ""; private set

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            val connected = i.getBooleanExtra("connected", false)
            val f = listOf("mtp", "ptp", "midi", "rndis", "ncm").filter { i.getBooleanExtra(it, false) }.joinToString(" ")
            if (connected == asDevice && f == functions) return
            asDevice = connected
            functions = f
            changed()
        }
    }

    fun start() { context.registerReceiver(receiver, IntentFilter(USB_STATE)) }      // sticky: the state now comes at once
    fun stop() { runCatching { context.unregisterReceiver(receiver) } }

    /** As near Android's USB preferences ("USB controlled by") as an app may go: Connected devices, else Settings. */
    fun openPreferences() {
        // the USB page itself needs MANAGE_USB (seen on a Pixel: "Permission Denial"); Connected devices is one touch from it
        val tries = listOf(
            Intent().setClassName("com.android.settings", "com.android.settings.Settings\$ConnectedDeviceDashboardActivity"),
            Intent(Settings.ACTION_SETTINGS),
        )
        for (t in tries) {
            try { context.startActivity(t.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); return } catch (_: ActivityNotFoundException) {} catch (_: SecurityException) {}
        }
    }

    companion object { const val USB_STATE = "android.hardware.usb.action.USB_STATE" }
}
