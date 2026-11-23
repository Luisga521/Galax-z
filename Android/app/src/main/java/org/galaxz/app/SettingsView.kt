package org.galaxz.app

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.PopupMenu
import android.widget.ScrollView
import android.widget.TextView
import org.galaxz.app.Face.dp
import org.galaxz.app.Face.px
import org.json.JSONObject
import java.text.DateFormat
import java.util.Date

/** Everything that is not the OP-Z's screen, in one place (`App/SettingsScreen.swift`): GENERAL, LEARN, GALAX-Z OS. */
@SuppressLint("ViewConstructor")
class SettingsView(context: Context, private val host: Host, tab: Int) : FrameLayout(context) {
    /** What the screen asks of the app around it. */
    interface Host {
        val sound: Sound
        var look: DotView.Look
        fun close()
        fun keyTest()
        fun share(path: String)
        fun web(url: String)
        val backups: String
        val diagnostics: String
        val byline: String
        val usb: UsbRole
    }

    private val main = Handler(Looper.getMainLooper())
    private val compact = resources.configuration.screenWidthDp < 600
    private val body = FrameLayout(context)
    private var refresh: () -> Unit = {}
    private val tabs = listOf("GENERAL", "LEARN", "GALAX-Z OS")

    init {
        setBackgroundColor(Face.background)
        isClickable = true                                  // nothing goes through to the dots
        val top = Face.row(context, 14).apply {
            val side = context.px(if (compact) 14 else 26)
            setPadding(side, context.px(14), side, context.px(10))
        }
        if (!compact) top.addView(DotText(context, "SETTINGS", font = 2, dot = 1.8f))
        val picker = Segmented(context, tabs, tab) { show(it) }
        top.addView(Face.grow(picker))
        top.addView(Face.pill(context, "DONE", Face.yellow) { host.close() })
        val all = Face.column(context, 0)
        all.addView(Middle(context, context.px(1180), top))
        all.addView(body, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        addView(all)
        show(tab)
    }

    private val tick = object : Runnable {
        override fun run() { refresh(); main.postDelayed(this, 500) }
    }

    override fun onAttachedToWindow() { super.onAttachedToWindow(); main.post(tick) }
    override fun onDetachedFromWindow() { main.removeCallbacks(tick); Core.command("learnOff", ""); super.onDetachedFromWindow() }

    private fun show(tab: Int) {
        body.removeAllViews()
        Core.command("learnOff", "")
        val scroll = ScrollView(context).apply { isFillViewport = true; isVerticalScrollBarEnabled = false }
        val (content, r) = when (tab) {
            0 -> general()
            1 -> learn()
            else -> os()
        }
        refresh = r
        scroll.addView(Middle(context, context.px(if (tab == 1) 1000 else 860), content))
        body.addView(scroll)
        r()
    }

    private fun section(s: String) = DotText(context, s, font = 0, dot = 2f, color = Face.yellow).apply {
        setPadding(0, context.px(8), 0, 0)
    }

    private fun label(s: String) = Face.text(context, s, 9f, alpha = 0.5, tracking = 2f)
    private fun detail(s: String) = Face.text(context, s, 11f, alpha = 0.55)
    private fun title(s: String) = Face.text(context, s, 13f, bold = true, tracking = 2f)

    /** A slider with its name before it, 90 wide. */
    private fun slider(name: String, value: Float, to: Float, changed: (Float) -> Unit): View = Face.row(context, 14).apply {
        addView(label(name).apply { layoutParams = LinearLayout.LayoutParams(context.px(90), ViewGroup.LayoutParams.WRAP_CONTENT) })
        addView(Face.grow(Slider(context, 0f, to, value, changed = changed)))
    }

    /** A card: what it is, said under its name, and its control at the end (under it on a phone, when it is wide). */
    private fun row(title: String, detail: String, below: Boolean = false, vararg controls: View): Pair<View, TextView> {
        val text = Face.column(context, 5)
        text.addView(title(title))
        val d = detail(detail)
        text.addView(d)
        val c = Face.card(context)
        if (below) {
            c.addView(text)
            c.addView(Face.row(context, 16).apply { controls.forEach { addView(it) } })
        } else {
            c.addView(Face.row(context, 16).apply { addView(Face.grow(text)); controls.forEach { addView(it) } })
        }
        return c to d
    }

    // GENERAL ----------------------------------------------------------------------------------------------------------

    private fun general(): Pair<View, () -> Unit> {
        val v = Face.column(context, 16).apply { val p = context.px(26); setPadding(p, p, p, p) }
        val sound = host.sound
        // SCREEN
        v.addView(section("SCREEN"))
        v.addView(Face.card(context).apply {
            addView(label("DOTS"))
            val fine = listOf(190, 240, 300)
            addView(Segmented(context, listOf("BOLD", "CLASSIC", "FINE"), fine.indexOf(host.look.fineness).coerceAtLeast(1)) {
                host.look = host.look.copy(fineness = fine[it])
            })
            addView(slider("GLOW", host.look.glow.toFloat(), 1.5f) { host.look = host.look.copy(glow = it.toDouble()) })
            addView(slider("AFTERGLOW", host.look.afterglow.toFloat(), 1.5f) { host.look = host.look.copy(afterglow = it.toDouble()) })
        })
        // SOUND
        v.addView(section("SOUND"))
        val volume = slider("VOLUME", sound.volume, 1f) { sound.volume = it }
        val soundLight = Face.light(context, Face.ink(0.2))
        val soundText = detail("")
        v.addView(Face.card(context).apply {
            addView(label("PLAY THROUGH"))
            addView(Segmented(context, listOf("OP-Z", "THIS PHONE"), if (sound.here) 1 else 0) { sound.here = it == 1 })
            addView(volume)
            addView(Face.row(context, 10).apply { addView(soundLight); addView(Face.grow(soundText)) })
        })
        // OP-Z
        v.addView(section("OP-Z"))
        val demo = Toggle(context, false) { Core.command("demo", if (it) "1" else "0"); context.getSharedPreferences("galaxz", 0).edit().putBoolean("demo", it).apply() }
        v.addView(row("DEMO OP-Z", "A pretend OP-Z playing a song: every screen works with no unit attached.", false, demo).first)
        val auto = Toggle(context, false) { Core.command("autoBackup", if (it) "1" else "0") }
        val autoBox = Face.column(context, 6).apply {
            gravity = Gravity.END
            addView(label("AUTOMATIC").apply { alpha = 0.9f })
            addView(auto)
        }
        val backUp = Face.pill(context, "BACK UP NOW") { Core.command("backUpNow", "") }
        val (backupCard, backupText) = row("BACKUPS", "", compact, autoBox, backUp)
        v.addView(backupCard)
        val (usbCard, usbText) = row("USB", "", false, Face.pill(context, "USB SETTINGS") { host.usb.openPreferences() })
        v.addView(usbCard)
        v.addView(row("KEY TEST", "Finds keys that double-trigger: every press timed from its MIDI note.", false,
            Face.pill(context, "OPEN") { host.keyTest() }).first)
        // LINK CHECK
        val check = Face.card(context)
        val checkTitle = title("LINK CHECK")
        val checkText = detail("")
        val items = Flow(context, context.px(16), context.px(9), context.px(if (compact) 280 else 330))
        var saved: String? = null
        val savedText = Face.text(context, "", 10f, alpha = 0.5)
        val share = Face.pill(context, "SHARE") { saved?.let { host.share(it) } }.apply { visibility = View.GONE }
        check.addView(Face.column(context, 12).apply { addView(checkTitle); addView(checkText); addView(items) })
        check.addView(Face.row(context, 12).apply {
            addView(Face.pill(context, "SAVE") {
                val r = Core.command("saveCheck", host.diagnostics)
                if (r.startsWith("!")) { savedText.text = r.drop(1); saved = null }
                else { saved = r; savedText.text = "In Galax-z › Diagnostics: " + r.substringAfterLast('/') }
                share.visibility = if (saved != null) View.VISIBLE else View.GONE
            })
            addView(share)
            addView(Face.grow(savedText))
        })
        v.addView(check)
        // KEYS, CREDITS
        v.addView(section("KEYS"))
        v.addView(detail("With a keyboard: 1–0 pages · ← → turn · ↑ ↓ track · , settings"))
        v.addView(section("CREDITS"))
        v.addView(credits())
        v.addView(Face.text(context, "Galax-z is not affiliated with teenage engineering. OP-Z is their trademark. Galax-z OS is installed at your own risk.",
            10f, alpha = 0.35).apply { setPadding(0, context.px(8), 0, 0) })

        val refresh = {
            val g = JSONObject(Core.query("general"))
            demo.set(g.optBoolean("demo"))
            auto.set(g.optBoolean("autoBackup"))
            // sound
            volume.visibility = if (sound.here) View.VISIBLE else View.GONE
            soundText.text = sound.explained
            (soundLight.background as android.graphics.drawable.GradientDrawable).setColor(when (sound.state) {
                is Sound.State.Playing -> Face.green
                is Sound.State.Failed -> Face.red
                Sound.State.Waiting -> Face.yellow
                Sound.State.Off -> Face.ink(0.2)
            })
            // backups
            val running = g.optBoolean("running")
            backUp.text = if (running) "BACKING UP…" else "BACK UP NOW"
            Face.enable(backUp, !running && !g.optBoolean("demo") && g.optBoolean("connected"))
            var line = "Copies the OP-Z's 10 projects and sound settings, reading only: seconds by cable, minutes over Bluetooth. " +
                "In ${host.backups}, laid out like the OP-Z's disk: put one back in content mode."
            g.optString("backup").takeIf { it.isNotEmpty() }?.let { line += "\n$it" }
            if (g.has("newest")) {
                val f = DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT)
                val t = DateFormat.getTimeInstance(DateFormat.SHORT)
                line += "\nNEWEST: ${f.format(Date(g.getLong("newest")))} · STILL MATCHED ${t.format(Date(g.getLong("checked")))} · ${g.getInt("kept")} KEPT"
            } else if (g.optBoolean("looked")) line += "\nNONE YET ON THIS DEVICE."
            backupText.text = line
            // which side of the cable
            usbText.text = if (host.usb.asDevice) "This phone is the cable's device now" +
                    (if (host.usb.functions.isNotEmpty()) " (offering ${host.usb.functions.uppercase()})" else "") +
                    ". For the OP-Z, the phone has to be in charge: touch Android's USB notification and choose USB CONTROLLED BY: THIS DEVICE."
                else if (g.optString("over") == "USB") "This phone is in charge of the cable, and the OP-Z is on it."
                else "Plug the OP-Z in with a USB-C cable. When this phone takes charge (Android says CHARGING CONNECTED DEVICE), Galax-z opens by itself; when Android asks what the USB is for, the OP-Z took charge instead: plug it in again. A USB-C OTG adapter and a USB-A to USB-C cable put the phone in charge every time."
            // link check
            val c = g.getJSONObject("check")
            val on = c.getBoolean("on")
            checkText.text = if (!on) "What Galax-z hears from your OP-Z, once there is one."
                else if (c.getInt("missing") == 0) "Everything the screen follows has come."
                else "Set off what is not lit yet, with this open. SAVE keeps it as a file: it says what came and what did not."
            val list = c.getJSONArray("items")
            if (items.childCount != list.length()) {
                items.removeAllViews()
                repeat(list.length()) {
                    items.addView(Face.row(context, 10).apply {
                        addView(Face.light(context, 0)); addView(Face.text(context, "", 10f, bold = true, tracking = 1f))
                        addView(Face.text(context, "", 10f, alpha = 0.45).apply { maxLines = 1 })
                    })
                }
            }
            for (i in 0 until list.length()) {
                val it = list.getJSONObject(i); val n = it.getInt("count")
                val r = items.getChildAt(i) as LinearLayout
                (r.getChildAt(0).background as android.graphics.drawable.GradientDrawable)
                    .setColor(if (n > 0) Face.green else Face.ink(if (it.getBoolean("optional")) 0.1 else 0.25))
                (r.getChildAt(1) as TextView).apply { text = it.getString("name"); alpha = if (n > 0) 0.95f else 0.6f }
                (r.getChildAt(2) as TextView).text = if (n > 0) "$n" else it.getString("how")
            }
        }
        return v to refresh
    }

    private fun credits(): View {
        val c = Face.card(context)
        val more = Face.text(context, "", 10f, alpha = 0.7).apply { setTextIsSelectable(true); visibility = View.GONE }
        var open = false
        lateinit var button: TextView
        button = Face.pill(context, "READ") {
            open = !open
            button.text = if (open) "CLOSE" else "READ"
            if (open && more.text.isEmpty()) more.text = listOf("THIRD_PARTY.md", "LICENSE")
                .mapNotNull { runCatching { context.assets.open(it).bufferedReader().readText() }.getOrNull() }.joinToString("\n\n")
            more.visibility = if (open) View.VISIBLE else View.GONE
        }
        val text = Face.column(context, 5)
        text.addView(title(if (host.byline.isBlank()) "CREDITS AND LICENCES" else "GALAX-Z · " + host.byline.uppercase()))
        text.addView(detail("Built on OP-FREE by Lourens Smit and the op-z-engines contributors (MIT). The piano is made from the Salamander Grand by Alexander Holm (CC BY 3.0)."))
        c.addView(Face.row(context, 16).apply { addView(Face.grow(text)); addView(button) })
        c.addView(more)
        return c
    }

    // LEARN ------------------------------------------------------------------------------------------------------------

    private fun learn(): Pair<View, () -> Unit> {
        val v = Face.column(context, 16).apply { setPadding(context.px(20), context.px(16), context.px(20), context.px(16)) }
        val families = listOf("SOUND", "MIX", "PERFORM", "CHOPS", "PATTERNS", "KEYS")
        var family = 0
        var track: Int? = null
        val devices = Face.text(context, "", 12f, bold = true)
        val waiting = Face.text(context, "", 11f)
        val last = Face.text(context, "", 10f, alpha = 0.45)
        v.addView(Face.column(context, 8).apply { addView(devices); addView(waiting); addView(last) })
        val grid = Flow(context, context.px(8), context.px(8), context.px(150))
        val trackPick = Face.pill(context, "THE SELECTED TRACK") {}.apply { setTextColor(Face.yellow) }
        val learnedHead = Face.row(context, 8).apply {
            setPadding(0, context.px(8), 0, 0)
            addView(Face.grow(title("LEARNED")))
            addView(Face.pill(context, "FORGET ALL") { Core.command("forgetAll", "") })
        }
        val learned = Face.column(context, 8)
        lateinit var refresh: () -> Unit
        v.addView(Segmented(context, families, 0, small = true) { family = it; trackPick.visibility = if (it < 2) View.VISIBLE else View.GONE; grid.removeAllViews(); refresh() })
        v.addView(LinearLayout(context).apply { addView(trackPick) })
        v.addView(grid)
        v.addView(learnedHead)
        v.addView(learned)
        trackPick.setOnClickListener {
            val names = JSONObject(Core.query("learn:0")).getJSONArray("tracks")
            PopupMenu(context, trackPick).apply {
                menu.add(0, 0, 0, "THE SELECTED TRACK")
                for (i in 0 until 16) menu.add(0, i + 1, i + 1, "${i + 1} ${names.getString(i)}")
                setOnMenuItemClickListener { m ->
                    track = if (m.itemId == 0) null else m.itemId - 1
                    trackPick.text = m.title
                    grid.removeAllViews(); refresh(); true
                }
            }.show()
        }
        refresh = {
            val l = JSONObject(Core.query("learn:$family:${track ?: ""}"))
            val ds = l.getJSONArray("devices")
            devices.text = if (ds.length() == 0) "No controller is connected. Plug one into this phone, or pair it over Bluetooth MIDI."
                else (0 until ds.length()).joinToString(" · ") { ds.getString(it) }
            val w = l.getString("waiting")
            waiting.text = w.ifEmpty { "Touch what you want to control, then move a knob or press a pad." }
            waiting.setTextColor(if (w.isEmpty()) Face.ink(0.55) else Face.yellow)
            last.text = l.getString("last"); last.visibility = if (last.text.isEmpty()) View.GONE else View.VISIBLE
            val ts = l.getJSONArray("targets")
            if (grid.childCount != ts.length()) {
                grid.removeAllViews()
                for (i in 0 until ts.length()) {
                    grid.addView(Face.column(context, 4).apply {
                        setPadding(context.px(10), context.px(10), context.px(10), context.px(10))
                        addView(Face.text(context, "", 11f, bold = true).apply { maxLines = 1 })
                        addView(Face.text(context, "", 9f).apply { maxLines = 1 })
                        setOnClickListener { Core.command("learn", "$family,${track ?: ""},$i"); refresh() }
                    })
                }
            }
            for (i in 0 until ts.length()) {
                val t = ts.getJSONObject(i); val b = grid.getChildAt(i) as LinearLayout
                val on = t.getBoolean("on"); val has = t.getString("learned")
                b.background = android.graphics.drawable.GradientDrawable().apply {
                    cornerRadius = context.dp(8)
                    setColor(if (on) Face.alpha(Face.yellow, 0.25) else Face.ink(if (has.isEmpty()) 0.05 else 0.12))
                    if (on) setStroke(context.px(1.5), Face.yellow)
                }
                (b.getChildAt(0) as TextView).text = t.getString("name")
                (b.getChildAt(1) as TextView).apply { text = has.ifEmpty { "not learned" }; alpha = if (has.isEmpty()) 0.35f else 0.8f }
            }
            val es = l.getJSONArray("entries")
            learnedHead.visibility = if (es.length() > 0) View.VISIBLE else View.GONE
            learned.removeAllViews()
            for (i in 0 until es.length()) {
                val e = es.getJSONObject(i)
                learned.addView(Face.row(context, 12).apply {
                    setPadding(context.px(10), context.px(10), context.px(10), context.px(10))
                    background = android.graphics.drawable.GradientDrawable().apply { cornerRadius = context.dp(8); setColor(Face.ink(0.05)) }
                    addView(Face.grow(Face.column(context, 3).apply {
                        addView(Face.text(context, e.getString("target"), 12f, bold = true))
                        addView(Face.text(context, e.getString("control"), 10f, alpha = 0.55))
                    }))
                    if (e.getBoolean("ways")) addView(Segmented(context, listOf("KNOB", "ENDLESS"), if (e.getBoolean("relative")) 1 else 0, small = true) {
                        Core.command("way", "$i," + if (it == 1) "relative" else "absolute")
                    }, LinearLayout.LayoutParams(context.px(150), context.px(30)))
                    addView(Face.pill(context, "FORGET") { Core.command("forget", "$i"); refresh() })
                })
            }
        }
        return v to refresh
    }

    // GALAX-Z OS -------------------------------------------------------------------------------------------------------

    private fun os(): Pair<View, () -> Unit> {
        val v = Face.column(context, 16).apply { val p = context.px(26); setPadding(p, p, p, p) }
        v.addView(section("GALAX-Z OS"))
        v.addView(Face.card(context).apply {
            addView(title("INSTALLED FROM A MAC"))
            addView(detail("Galax-z OS is put on the OP-Z by the Mac app, over a USB-C cable, with a backup of what was there first. " +
                "This phone shows and plays the OP-Z; it never writes its OS. Everything here works without Galax-z OS: " +
                "with it, the OP-Z also tells of its tumbler, EUCLID and GROOVE pages."))
            addView(LinearLayout(context).apply { addView(Face.pill(context, "RELEASES ON GITHUB") { host.web("https://github.com/Luisga521/Galax-z/releases") }) })
        })
        v.addView(Face.card(context).apply {
            addView(title("READ THIS FIRST"))
            addView(detail("Galax-z OS replaces the operating system of your instrument, and it has only ever run on one OP-Z. You could end up with an OP-Z that does not start."))
            addView(LinearLayout(context).apply { addView(Face.pill(context, "DISCLAIMER") { host.web("https://github.com/Luisga521/Galax-z/blob/main/DISCLAIMER.md") }) })
        })
        return v to {}
    }
}
