package org.galaxz.app

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.Toast
import java.io.File

/** The OP-Z's screen, whole window; settings come over it (`App/Root.swift`). */
class MainActivity : Activity() {
    companion object { private const val OPEN_SOUND = 7 }
    private lateinit var dots: DotView
    private lateinit var link: MidiLink
    private lateinit var sound: Sound
    private lateinit var usb: UsbRole
    /** Offered once each time the phone becomes the cable's device. */
    private var usbOffered = false
    private val main = Handler(Looper.getMainLooper())
    private val prefs by lazy { getSharedPreferences("galaxz", MODE_PRIVATE) }
    private lateinit var frame: FrameLayout

    override fun onCreate(saved: Bundle?) {
        super.onCreate(saved)
        copyPackageFiles()
        // `adb shell am start -n org.galaxz.app/.MainActivity --ez demo true`: the demo OP-Z, as `-demo` on iOS
        Core.start(filesDir.absolutePath, intent.getBooleanExtra("demo", prefs.getBoolean("demo", false)))
        // backups where a computer sees them over USB (Android › data › org.galaxz.app › files › Backups)
        Core.command("backups", File(getExternalFilesDir(null) ?: filesDir, "Backups").absolutePath)

        dots = DotView(this) { act(it) }
        dots.look = look()
        frame = FrameLayout(this)
        frame.setBackgroundColor(0xFF000000.toInt())
        frame.addView(dots, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        // dots to the edge, but clear of the camera and the gesture bar, as on an iPhone
        frame.setOnApplyWindowInsetsListener { v, insets ->
            val i = insets.getInsetsIgnoringVisibility(WindowInsets.Type.displayCutout() or WindowInsets.Type.systemGestures())
            val c = insets.getInsetsIgnoringVisibility(WindowInsets.Type.displayCutout())
            v.setPadding(c.left, c.top, c.right, maxOf(c.bottom, i.bottom / 2))
            insets
        }
        setContentView(frame)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        immersive()

        sound = Sound(this, prefs) { soundChanged() }
        sound.allowed = { checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED }
        sound.askPermission = { requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 2) }
        sound.start()
        sound.tellChops()
        link = MidiLink(this) { lineChanged() }
        usb = UsbRole(this) { usbChanged() }
        link.bluetoothAllowed = hasBluetooth()
        link.start()
        usb.start()
        if (!hasBluetooth() && !prefs.getBoolean("askedBluetooth", false)) askBluetooth()
        lineChanged()
    }

    override fun onDestroy() {
        usb.stop()
        sound.stop()
        link.stop()
        super.onDestroy()
    }

    /** Opened again by a plugged-in OP-Z: look for it now. */
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        if (::link.isInitialized) link.scan()
    }

    override fun onResume() {
        super.onResume()
        dots.onResume()
        immersive()
        if (::link.isInitialized) { link.bluetoothAllowed = hasBluetooth(); lineChanged() }      // back from Android's settings
        tick.run()
    }

    override fun onPause() {
        main.removeCallbacks(tick)
        dots.onPause()
        super.onPause()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) immersive()
    }

    private fun immersive() {
        window.insetsController?.let {
            it.hide(WindowInsets.Type.systemBars())
            it.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
    }

    /** The session's heartbeat: what is due to the OP-Z, the demo's answers, a new picture when something changed. */
    private val tick = object : Runnable {
        override fun run() {
            if (Core.tick()) dots.changed()
            pump()
            sound.tick()
            chopsAsked(Core.chopsRequests())
            main.postDelayed(this, 16)
        }
    }

    fun pump() = link.pump()

    /** The package's own files, out of the APK to where the Swift side reads them. */
    private fun copyPackageFiles() {
        for (name in listOf("engines.json", "demo-session.json")) {
            val to = File(filesDir, name)
            assets.open(name).use { input -> to.outputStream().use { input.copyTo(it) } }
        }
    }

    // what a tap asks for ----------------------------------------------------------------------------------------------

    private fun act(what: Int) {
        when (what) {
            Core.SETTINGS -> settings(0)
            Core.HUB -> settings(2)
            Core.PAIR -> if (hasBluetooth()) { link.bluetoothAllowed = true; link.scan() } else askBluetooth()
            Core.SOUND -> sound.toggle()
        }
        pump()
    }

    /** What to do while there is no OP-Z, said under the name. */
    private fun lineChanged() {
        if (!::link.isInitialized) return
        sound.cable(link.name != null && !link.overBluetooth && !Core.isDemo())
        val s = link.bluetoothState
        val line = when {
            link.name == null && ::usb.isInitialized && usb.asDevice -> "THIS PHONE IS THE USB DEVICE · LET IT TAKE CHARGE"
            s.startsWith("linking") -> "LINKING " + s.removePrefix("linking ").uppercase()
            s == "off" -> "BLUETOOTH IS OFF · OR PLUG IN A CABLE"
            s == "unauthorized" -> (if (Build.VERSION.SDK_INT >= 31) "ALLOW NEARBY DEVICES" else "ALLOW LOCATION") + " FOR GALAX-Z · OR PLUG IN A CABLE"
            s == "searching" -> "LOOKING FOR YOUR OP-Z · OR PLUG IN A CABLE"
            else -> "PLUG IN YOUR OP-Z WITH A USB-C CABLE"
        }
        Core.linkLine(line, "")     // no second line: a phone held upright is too narrow for it
        dots.changed()
    }

    // the cable: which side is in charge ------------------------------------------------------------------------------

    private fun usbChanged() {
        lineChanged()
        if (!usb.asDevice) { usbOffered = false; return }
        // a moment for the OP-Z to show up the other way round before saying anything
        main.postDelayed({
            if (usb.asDevice && link.name == null && !usbOffered && over == null) { usbOffered = true; cover(usbCard()) }
        }, 1500)
    }

    /** The phone ended up as the cable's device: what that means, and the way out. */
    private fun usbCard(): android.view.View {
        val c = this
        fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
        val card = Face.card(c).apply {
            addView(Face.text(c, "THIS PHONE IS THE USB DEVICE", 13f, bold = true, tracking = 2f))
            addView(Face.text(c, "Something on the cable took charge of it" + (if (usb.functions.isNotEmpty()) " (this phone offers it ${usb.functions.uppercase()})" else "") +
                ". If that is your OP-Z, Galax-z cannot see it this way round: the phone has to be in charge.\n\n" +
                "Pull down Android's notifications, touch the one about USB, and choose USB CONTROLLED BY: THIS DEVICE. " +
                "Or take the cable out and put it in again: the OP-Z and this phone can each take charge, and who does can differ " +
                "each time. Android says CHARGING CONNECTED DEVICE when the phone is in charge, CHARGING THIS DEVICE when the OP-Z is.\n\n" +
                "To have it right every time: a USB-C OTG adapter (USB-C plug, USB-A socket) on the phone and a USB-A to USB-C cable " +
                "to the OP-Z. The adapter puts the phone in charge, always.", 11f, alpha = 0.7))
            addView(Face.row(c, 12).apply {
                addView(Face.pill(c, "OK", Face.yellow) { cover(null) })
                addView(Face.pill(c, "SETTINGS") { cover(null); usb.openPreferences() })
            })
        }
        return FrameLayout(c).apply {
            setBackgroundColor(0xCC000000.toInt())
            isClickable = true
            addView(card, FrameLayout.LayoutParams(minOf(dp(520), resources.displayMetrics.widthPixels - dp(32)), ViewGroup.LayoutParams.WRAP_CONTENT, android.view.Gravity.CENTER))
        }
    }

    // the chops: a file to open, the microphone to allow ---------------------------------------------------------------

    private fun chopsAsked(what: Int) {
        if (what and 2 != 0) requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 3)
        if (what and 1 != 0) {
            dots.covered = true
            startActivityForResult(android.content.Intent(android.content.Intent.ACTION_OPEN_DOCUMENT)
                .addCategory(android.content.Intent.CATEGORY_OPENABLE).setType("audio/*"), OPEN_SOUND)
        }
    }

    @Deprecated("the platform's own, with no library")
    override fun onActivityResult(code: Int, result: Int, data: android.content.Intent?) {
        super.onActivityResult(code, result, data)
        if (code != OPEN_SOUND) return
        dots.covered = false
        val uri = data?.data ?: return
        Core.chopsTell("READING THE FILE")
        Thread {
            try {
                val d = SoundFile.read(this, uri)
                Core.chopsOpen(d.samples, d.rate, d.name)
            } catch (e: Exception) {
                Core.chopsTell("THAT FILE CANNOT BE READ")
            }
            main.post { dots.changed() }
        }.start()
    }

    /** Where the OP-Z is heard, in the screen's corner; a word when it could not be done. */
    private var told: Sound.State? = null
    private fun soundChanged() {
        Core.setOut(sound.line)
        val s = sound.state
        if (s is Sound.State.Failed && s != told) Toast.makeText(this, s.why, Toast.LENGTH_LONG).show()
        if (s is Sound.State.Playing && s != told) Toast.makeText(this, sound.explained, Toast.LENGTH_SHORT).show()
        told = s
        dots.changed()
    }

    // Bluetooth permission ---------------------------------------------------------------------------------------------

    /** Android 12 and later ask for "nearby devices"; Android 11 for location, which a Bluetooth search needed there. */
    private val bluetoothPermissions = if (Build.VERSION.SDK_INT >= 31)
        arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)

    private fun hasBluetooth() = bluetoothPermissions.all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }

    private fun askBluetooth() {
        prefs.edit().putBoolean("askedBluetooth", true).apply()
        requestPermissions(bluetoothPermissions, 1)
    }

    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(code, permissions, results)
        if (code == 2) { sound.tellChops(); if (sound.allowed()) sound.apply(); return }
        if (code == 3) { sound.tellChops(); if (sound.allowed()) Core.chopsTell("ALLOWED: TOUCH START AGAIN"); return }
        link.bluetoothAllowed = hasBluetooth()
        lineChanged()
    }

    // settings, the key test: over the dots ------------------------------------------------------------------------

    private fun look() = DotView.Look(prefs.getInt("fineness", 240), prefs.getFloat("glow", 0.8f).toDouble(),
                                      prefs.getFloat("afterglow", 0.3f).toDouble())

    private var over: android.view.View? = null

    private fun cover(v: android.view.View?) {
        over?.let { frame.removeView(it) }
        over = v
        if (v != null) frame.addView(v, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        dots.covered = v != null
        immersive()
    }

    private val host = object : SettingsView.Host {
        override val sound get() = this@MainActivity.sound
        override var look: DotView.Look
            get() = look()
            set(v) {
                prefs.edit().putInt("fineness", v.fineness).putFloat("glow", v.glow.toFloat()).putFloat("afterglow", v.afterglow.toFloat()).apply()
                dots.look = v
            }
        override fun close() = cover(null)
        override fun keyTest() = cover(KeyTestView(this@MainActivity) { cover(null) })
        override fun share(path: String) {
            val text = runCatching { File(path).readText() }.getOrDefault("")
            startActivity(android.content.Intent.createChooser(android.content.Intent(android.content.Intent.ACTION_SEND)
                .setType("text/plain").putExtra(android.content.Intent.EXTRA_SUBJECT, File(path).name).putExtra(android.content.Intent.EXTRA_TEXT, text), "Share the link check"))
        }
        override fun web(url: String) { runCatching { startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(url))) } }
        override val backups get() = "Android › data › org.galaxz.app › files › Backups (over USB from a computer)"
        override val diagnostics get() = File(getExternalFilesDir(null) ?: filesDir, "Diagnostics").absolutePath
        override val byline get() = getString(R.string.byline)
        override val usb get() = this@MainActivity.usb
    }

    private fun settings(tab: Int = 0) = cover(SettingsView(this, host, tab))

    @Deprecated("the platform's own, with no library")
    override fun onBackPressed() {
        if (over != null) cover(null) else @Suppress("DEPRECATION") super.onBackPressed()
    }

    // a keyboard, if there is one: as on the iPad ---------------------------------------------------------------------

    override fun onKeyDown(code: Int, e: KeyEvent): Boolean {
        when (code) {
            KeyEvent.KEYCODE_DPAD_RIGHT -> Core.turn(1)
            KeyEvent.KEYCODE_DPAD_LEFT -> Core.turn(-1)
            KeyEvent.KEYCODE_DPAD_DOWN -> Core.selectTrack(1)
            KeyEvent.KEYCODE_DPAD_UP -> Core.selectTrack(-1)
            KeyEvent.KEYCODE_COMMA -> settings()
            in KeyEvent.KEYCODE_0..KeyEvent.KEYCODE_9 -> Core.setPage((code - KeyEvent.KEYCODE_0 + 9) % 10)
            else -> return super.onKeyDown(code, e)
        }
        dots.changed()
        return true
    }
}
