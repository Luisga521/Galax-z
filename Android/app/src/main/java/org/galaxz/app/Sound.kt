package org.galaxz.app

import android.content.Context
import android.content.SharedPreferences
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Handler
import android.os.Looper

/**
 * Where the OP-Z is heard: from itself, or over the cable from this phone (`App/AudioOut.swift`). Its sound is only passed
 * on: nothing is recorded. Over Bluetooth there is no choice, for Bluetooth MIDI carries no sound.
 */
class Sound(context: Context, private val prefs: SharedPreferences, private val changed: () -> Unit) {
    sealed interface State {
        data object Off : State
        data object Waiting : State
        data class Playing(val to: String) : State
        data class Failed(val why: String) : State
    }

    private val audio = context.getSystemService(AudioManager::class.java)
    private val main = Handler(Looper.getMainLooper())
    private var cable = false
    private var run = 0

    /** Through this phone (true) or from the OP-Z itself. */
    var here = prefs.getBoolean("soundHere", false)
        set(v) { if (v != field) { field = v; prefs.edit().putBoolean("soundHere", v).apply(); apply() } }
    var volume = prefs.getFloat("soundVolume", 0.8f)
        set(v) { field = v; prefs.edit().putFloat("soundVolume", v).apply(); Core.soundVolume(v) }
    var state: State = State.Off
        private set(v) { if (v != field) { field = v; tellChops(); changed() } }
    /** Asked for when the microphone permission is missing: Android calls any sound coming in a microphone. */
    var askPermission: () -> Unit = {}
    var allowed: () -> Boolean = { false }

    /** What the screen says in its corner: null when there is no choice (no cable). */
    val line: String?
        get() = if (!cable) null else when (state) {
            is State.Playing -> "OUT PHONE"
            is State.Failed -> "OUT ?"
            else -> if (here) "OUT ..." else "OUT OP-Z"
        }

    val explained: String
        get() = when (val s = state) {
            State.Off -> if (here) "Waits for the OP-Z on a cable: Bluetooth carries no sound." else "The OP-Z plays from its own speaker or headphones."
            State.Waiting -> "Starting…"
            is State.Playing -> "The OP-Z's sound comes over the cable and plays here: ${s.to}."
            is State.Failed -> s.why
        }

    fun toggle() { here = !here }

    /** An OP-Z is there over USB, or not. */
    fun cable(on: Boolean) {
        if (on == cable) return
        cable = on
        apply()
        changed()
    }

    private val devices = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(added: Array<out AudioDeviceInfo>) { tellChops(); restart() }
        override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>) { tellChops(); restart() }
    }
    private var watching = false

    fun start() { if (!watching) { audio.registerAudioDeviceCallback(devices, main); watching = true } }

    fun stop() {
        if (watching) { audio.unregisterAudioDeviceCallback(devices); watching = false }
        run += 1
        main.removeCallbacksAndMessages(null)
        Core.soundStop()
    }

    /** Now and then: a device went from under it. */
    fun tick() { if (state is State.Playing && !Core.soundAlive()) restart() }

    /** Devices came or went: once it is quiet, from the start. */
    private fun restart() {
        if (!here || !cable) return
        main.removeCallbacks(again)
        main.postDelayed(again, 400)
    }
    private val again = Runnable { apply() }

    fun apply() {
        run += 1
        main.removeCallbacksAndMessages(null)
        Core.soundStop()
        if (!here || !cable) { state = State.Off; changed(); return }
        if (!allowed()) {
            state = State.Failed("Allow Galax-z the microphone: that is what Android calls any sound coming in. Only the OP-Z's is used, and nothing is kept.")
            askPermission()
            return
        }
        state = State.Waiting
        attempt(run, 0)
    }

    /** The cable's sound side can show up after its MIDI side: a few tries, half a second apart. */
    private fun attempt(me: Int, n: Int) {
        if (me != run) return
        val why = try1()
        if (why == null) return
        if (n < 11 && why.second) main.postDelayed({ attempt(me, n + 1) }, 500)
        else state = State.Failed(why.first)
    }

    /** Starts it, or says why not (and whether waiting may help). */
    private fun try1(): Pair<String, Boolean>? {
        val ins = audio.getDevices(AudioManager.GET_DEVICES_INPUTS).filter { it.type in USB }
        val opz = ins.firstOrNull { isOPZ(it) } ?: ins.singleOrNull()
            ?: return "The OP-Z's sound is not on the cable. Take the cable out and put it in again, with the OP-Z switched on." to true
        // this phone's own: what is plugged in or linked first, then its speaker. Never the OP-Z: that would go round.
        val outs = audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).filter { it.type !in USB }
        val to = PREFERRED.firstNotNullOfOrNull { t -> outs.firstOrNull { it.type == t } }
            ?: return "There is nothing to play it on." to false
        val r = Core.soundStart(opz.id, to.id, volume)
        if (r.isNotEmpty()) return r to false
        playing = to.id
        state = State.Playing(name(to))
        return null
    }

    /** The sampler's devices: its output is this phone's own while the OP-Z plays through it (heard together), else Android's choice. */
    fun tellChops() {
        val ins = audio.getDevices(AudioManager.GET_DEVICES_INPUTS)
        val usb = ins.filter { it.type in USB }
        val opz = usb.firstOrNull { isOPZ(it) } ?: usb.singleOrNull()
        val mic = ins.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_MIC }
        val out = (state as? State.Playing)?.let { playing }
        Core.chopsDevices(out ?: 0, mic?.id ?: 0, opz?.id ?: 0, allowed())
    }
    private var playing = 0

    private fun isOPZ(d: AudioDeviceInfo) = d.productName.toString().lowercase().replace('–', '-').replace('‑', '-').contains("op-z")

    private fun name(d: AudioDeviceInfo) = when (d.type) {
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "its speaker"
        else -> d.productName.toString().ifBlank { "headphones" }
    }

    companion object {
        private val USB = setOf(AudioDeviceInfo.TYPE_USB_DEVICE, AudioDeviceInfo.TYPE_USB_HEADSET, AudioDeviceInfo.TYPE_USB_ACCESSORY)
        private val PREFERRED = listOf(
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES, AudioDeviceInfo.TYPE_WIRED_HEADSET, AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP, AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
        )
    }
}
