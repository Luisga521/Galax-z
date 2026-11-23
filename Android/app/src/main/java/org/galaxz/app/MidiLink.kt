package org.galaxz.app

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.midi.MidiDevice
import android.media.midi.MidiDeviceInfo
import android.media.midi.MidiInputPort
import android.media.midi.MidiManager
import android.media.midi.MidiOutputPort
import android.media.midi.MidiReceiver
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.PriorityQueue
import java.util.concurrent.Executor

/**
 * The OP-Z over Android's MIDI service: a USB-C cable first (the phone is the host), else Bluetooth. What the core
 * says goes out by `pump()`, short messages at their time; what the OP-Z says goes straight into the core.
 * `App/Live.swift`'s scan and `OPZLink/MIDITransport.swift` on iOS.
 */
class MidiLink(private val context: Context, private val changed: () -> Unit) {
    private val main = Handler(Looper.getMainLooper())
    private val midi = context.getSystemService(MidiManager::class.java)
    private var device: MidiDevice? = null
    private var info: MidiDeviceInfo? = null
    private var output: MidiOutputPort? = null
    private val sender = Sender()
    private var opening = false
    var bluetoothState = "idle"; private set
    var name: String? = null; private set
    var overBluetooth = false; private set

    /** Bluetooth may look for the OP-Z (the permission is granted and the user has not turned it off). */
    var bluetoothAllowed = false
        set(v) { field = v; scan() }

    private val callback = object : MidiManager.DeviceCallback() {
        override fun onDeviceAdded(d: MidiDeviceInfo) = scan()
        override fun onDeviceRemoved(d: MidiDeviceInfo) {
            if (d.id == info?.id) close()
            scan()
        }
    }

    /** Bluetooth switched on or off: look again. */
    private val radio = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            if (i.getIntExtra(BluetoothAdapter.EXTRA_STATE, 0) != BluetoothAdapter.STATE_ON) { stopBluetooth(); bluetoothState = "off" }
            else if (bluetoothState == "off") bluetoothState = "idle"
            scan()
        }
    }

    fun start() {
        context.registerReceiver(radio, IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED))
        if (Build.VERSION.SDK_INT >= 33) midi?.registerDeviceCallback(MidiManager.TRANSPORT_MIDI_BYTE_STREAM, Executor { main.post(it) }, callback)
        else @Suppress("DEPRECATION") midi?.registerDeviceCallback(callback, main)
        sender.start()
        scan()
    }

    fun stop() {
        for ((dev, ports) in others.values) { ports.forEach { it.close() }; dev.close() }
        others.clear()
        context.unregisterReceiver(radio)
        midi?.unregisterDeviceCallback(callback)
        stopBluetooth()
        close()
        sender.quit()
    }

    /** Devices came or went: take the OP-Z, a cable before Bluetooth; look over Bluetooth while there is none. */
    fun scan() {
        val all = (if (Build.VERSION.SDK_INT >= 33) midi?.getDevicesForTransport(MidiManager.TRANSPORT_MIDI_BYTE_STREAM)
                   else @Suppress("DEPRECATION") midi?.devices?.toSet()) ?: emptySet()
        controllers(all.filter { !isOPZ(it) })
        val opz = all.filter { isOPZ(it) }
        val best = opz.firstOrNull { it.type == MidiDeviceInfo.TYPE_USB } ?: opz.firstOrNull()
        if (best != null && info?.id != best.id && !opening && (info == null || best.type == MidiDeviceInfo.TYPE_USB)) open(best)
        if (best == null && info == null) startBluetooth() else stopBluetooth()
        changed()
    }

    private fun isOPZ(d: MidiDeviceInfo): Boolean {
        val p = d.properties
        val words = listOf(MidiDeviceInfo.PROPERTY_NAME, MidiDeviceInfo.PROPERTY_PRODUCT)
            .mapNotNull { p.getString(it) }.joinToString(" ").lowercase().replace('–', '-').replace('‑', '-')
        return words.contains("op-z")
    }

    private fun open(d: MidiDeviceInfo) {
        opening = true
        midi?.openDevice(d, { opened -> main.post { opening = false; if (opened != null) take(d, opened) } }, main)
    }

    private fun take(d: MidiDeviceInfo, opened: MidiDevice) {
        close()
        Log.i(TAG, "OP-Z ports: " + d.ports.joinToString { (if (it.type == MidiDeviceInfo.PortInfo.TYPE_INPUT) "in " else "out ") + "${it.portNumber} '${it.name}'" })
        val outIndex = d.ports.firstOrNull { it.type == MidiDeviceInfo.PortInfo.TYPE_OUTPUT }?.portNumber
        // over USB the OP-Z has two ports to send to, and nothing says which one takes the session: the one that answered
        // last time, else the first, and the next one when no answer comes (`listen`)
        inputs = d.ports.filter { it.type == MidiDeviceInfo.PortInfo.TYPE_INPUT }.map { it.portNumber }
        inAt = if (d.type == MidiDeviceInfo.TYPE_USB) prefs.getInt("opzPort", 0).coerceIn(0, maxOf(0, inputs.size - 1)) else 0
        val out = outIndex?.let { opened.openOutputPort(it) }
        val into = inputs.getOrNull(inAt)?.let { opened.openInputPort(it) }
        if (out == null || into == null) {
            Log.w(TAG, "OP-Z without both ports: in $inputs out $outIndex")
            out?.close(); into?.close(); opened.close()
            return
        }
        device = opened
        info = d
        output = out
        sender.port = into
        name = d.properties.getString(MidiDeviceInfo.PROPERTY_NAME) ?: "OP-Z"
        overBluetooth = d.type == MidiDeviceInfo.TYPE_BLUETOOTH
        heard = false
        out.connect(object : MidiReceiver() {
            override fun onSend(msg: ByteArray, offset: Int, count: Int, timestamp: Long) {
                if (!heard) for (i in offset until offset + count) if (msg[i] == 0xF0.toByte()) { heard = true; break }
                Core.midiIn(msg, offset, count, timestamp)
                pump()
            }
        })
        Core.connected(name, overBluetooth)
        stopBluetooth()
        pump()
        main.postDelayed(listen, 3000)
        changed()
    }

    private val prefs = context.getSharedPreferences("galaxz", Context.MODE_PRIVATE)
    private var inputs: List<Int> = emptyList()
    private var inAt = 0
    @Volatile private var heard = false

    /** A few seconds after the greeting: the OP-Z answered on this port (kept for next time), or try the next one. */
    private val listen = object : Runnable {
        override fun run() {
            val dev = device ?: return
            if (heard) { prefs.edit().putInt("opzPort", inAt).apply(); Log.i(TAG, "the OP-Z answers on port ${inputs.getOrNull(inAt)}"); return }
            if (inputs.size < 2) return
            inAt = (inAt + 1) % inputs.size
            Log.i(TAG, "no answer from the OP-Z: trying its port ${inputs[inAt]}")
            sender.port?.close()
            sender.port = dev.openInputPort(inputs[inAt])
            Core.connected(null, false)
            Core.connected(name, overBluetooth)          // greet it again, on the other port
            pump()
            main.postDelayed(this, 3000)
        }
    }

    private fun close() {
        main.removeCallbacks(listen)
        if (device == null) return
        output?.close()
        sender.port?.close()
        sender.port = null
        device?.close()
        device = null; info = null; output = null; name = null
        Core.connected(null, false)
        changed()
    }

    // other controllers: LEARN's keyboards, knobs and pads ----------------------------------------------------------

    private val others = HashMap<Int, Pair<MidiDevice, List<MidiOutputPort>>>()
    private val othersOpening = HashSet<Int>()

    private fun nameOf(d: MidiDeviceInfo) = d.properties.getString(MidiDeviceInfo.PROPERTY_NAME)
        ?: d.properties.getString(MidiDeviceInfo.PROPERTY_PRODUCT) ?: "MIDI ${d.id}"

    /** Listen to every MIDI device but the OP-Z (and Galax-z's own), and tell the core their names. */
    private fun controllers(now: List<MidiDeviceInfo>) {
        val wanted = now.filter { d -> d.outputPortCount > 0 && !nameOf(d).lowercase().contains("galax-z") }
        val ids = wanted.map { it.id }.toSet()
        for (id in others.keys.filter { it !in ids }) others.remove(id)?.let { (dev, ports) -> ports.forEach { it.close() }; dev.close() }
        for (d in wanted) {
            if (d.id in others || d.id in othersOpening) continue
            othersOpening += d.id
            val name = nameOf(d)
            midi?.openDevice(d, { dev ->
                othersOpening -= d.id
                if (dev == null) return@openDevice
                val ports = d.ports.filter { it.type == MidiDeviceInfo.PortInfo.TYPE_OUTPUT }.mapNotNull { dev.openOutputPort(it.portNumber) }
                for (p in ports) p.connect(object : MidiReceiver() {
                    override fun onSend(msg: ByteArray, offset: Int, count: Int, timestamp: Long) {
                        Core.controllerIn(name, msg, offset, count)
                        pump()
                    }
                })
                others[d.id] = dev to ports
            }, main)
        }
        Core.command("controllers", wanted.map { nameOf(it) }.distinct().joinToString("\n"))
    }

    // what the core has to send ---------------------------------------------------------------------------------

    private val drain = ByteBuffer.allocateDirect(1 shl 18).order(ByteOrder.LITTLE_ENDIAN)

    /** Take everything the core has to say and hand it to the sender, which keeps each message's time. */
    fun pump() = synchronized(drain) {
        while (true) {
            drain.clear()
            val n = Core.drainOut(drain)
            if (n <= 0) return
            var at = 0
            while (at + 10 <= n) {
                val ns = drain.getLong(at)
                val len = drain.getShort(at + 8).toInt() and 0xFFFF
                val bytes = ByteArray(len)
                drain.position(at + 10); drain.get(bytes); drain.position(0)
                sender.add(ns, bytes)
                at += 10 + len
            }
        }
    }

    /** One thread sends everything, in order of its time: a SysEx goes out whole before anything else. */
    private class Sender : Thread("galaxz-midi-out") {
        @Volatile var port: MidiInputPort? = null
        private class Msg(val at: Long, val seq: Long, val bytes: ByteArray)
        private val queue = PriorityQueue<Msg>(compareBy<Msg>({ it.at }, { it.seq }))
        private val lock = Object()
        private var seq = 0L
        @Volatile private var running = true

        init { isDaemon = true; priority = MAX_PRIORITY }

        fun add(at: Long, bytes: ByteArray) = synchronized(lock) {
            queue.add(Msg(if (at <= 0) 0 else at, seq++, bytes))
            lock.notifyAll()
        }

        fun quit() { running = false; synchronized(lock) { lock.notifyAll() } }

        override fun run() {
            while (running) {
                val m = synchronized(lock) { next() } ?: continue
                try { port?.send(m.bytes, 0, m.bytes.size) } catch (e: Exception) { Log.w(TAG, "send: $e") }
            }
        }

        /** The message that is due, or nil after waiting for one (holding the lock). */
        private fun next(): Msg? {
            val head = queue.peek() ?: run { lock.wait(); return null }
            val wait = head.at - System.nanoTime()
            if (wait > 200_000) { lock.wait(wait / 1_000_000, (wait % 1_000_000).toInt()); return null }
            return queue.poll()
        }
    }

    // Bluetooth ---------------------------------------------------------------------------------------------------

    private var scanning = false
    private val bluetooth get() = context.getSystemService(BluetoothManager::class.java)?.adapter

    private val found = object : ScanCallback() {
        override fun onScanResult(type: Int, r: ScanResult) {
            @SuppressLint("MissingPermission") val n = r.device.name ?: r.scanRecord?.deviceName ?: return
            if (!n.lowercase().replace('–', '-').contains("op-z") || opening || info != null) return
            stopBluetooth()
            link(r.device, n)
        }
        override fun onScanFailed(code: Int) { bluetoothState = "failed $code"; changed() }
    }

    @SuppressLint("MissingPermission")
    private fun startBluetooth() {
        if (scanning || !bluetoothAllowed) return
        val a = bluetooth ?: run { bluetoothState = "unsupported"; return }
        if (!a.isEnabled) { bluetoothState = "off"; changed(); return }
        val s = a.bluetoothLeScanner ?: return
        try {
            s.startScan(listOf(ScanFilter.Builder().setServiceUuid(ParcelUuid(MIDI_SERVICE)).build()),
                ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(), found)
            scanning = true
            bluetoothState = "searching"
        } catch (e: SecurityException) { bluetoothState = "unauthorized" }
        changed()
    }

    @SuppressLint("MissingPermission")
    private fun stopBluetooth() {
        if (!scanning) return
        scanning = false
        try { bluetooth?.bluetoothLeScanner?.stopScan(found) } catch (_: Exception) {}
        if (bluetoothState == "searching") bluetoothState = "idle"
    }

    private fun link(d: BluetoothDevice, n: String) {
        bluetoothState = "linking $n"
        opening = true
        changed()
        midi?.openBluetoothDevice(d, { opened ->
            main.post {
                opening = false
                if (opened == null) { bluetoothState = "idle"; scan(); return@post }
                take(opened.info, opened)
            }
        }, main)
    }

    companion object {
        const val TAG = "galaxz"
        /** The Bluetooth LE MIDI service. */
        val MIDI_SERVICE: java.util.UUID = java.util.UUID.fromString("03B80E5A-EDE8-4B33-A751-6CE34EC4C700")
    }
}
