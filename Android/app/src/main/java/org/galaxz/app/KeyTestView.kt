package org.galaxz.app

import android.annotation.SuppressLint
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import org.galaxz.app.Face.dp
import org.galaxz.app.Face.px
import org.json.JSONArray
import org.json.JSONObject

/** Finds the OP-Z's double-triggering keys: every press timed from its MIDI note (`App/KeyTestScreen.swift`). */
@SuppressLint("ViewConstructor")
class KeyTestView(context: Context, private val done: () -> Unit) : FrameLayout(context) {
    private val main = Handler(Looper.getMainLooper())
    private val status = Face.text(context, "", 11f, bold = true, tracking = 2f)
    private val statusLight = Face.light(context, Face.ink(0.4))
    private val window = Face.text(context, "", 13f, bold = true)
    private val copy: TextView
    private val hint = Face.text(context, "", 12f, alpha = 0.6)
    private val warning = Face.text(context, "⚠ THE OP-Z IS PLAYING: ITS OWN NOTES COUNT AS PRESSES. PRESS STOP.", 11f, bold = true, tracking = 1.5f, color = Face.yellow)
    private val stats = Flow(context, context.px(34), context.px(12))
    private val keys = Keys(context)
    private val log = Flow(context, context.px(28), context.px(8), context.px(320))
    private var copied = 0L
    private var report = ""

    init {
        setBackgroundColor(Face.background)
        isClickable = true
        Core.command("keyTestOpen", "")
        val v = Face.column(context, 20).apply { setPadding(context.px(26), context.px(22), context.px(26), context.px(22)) }
        // the bar: its name, what it listens to, the window, and what to do (in rows that wrap on a phone)
        val bar = Flow(context, context.px(16), context.px(12))
        bar.addView(Face.column(context, 3).apply {
            addView(DotText(context, "KEY TEST", font = 2, dot = 2f))
            addView(Face.text(context, "DOUBLE TRIGGERS", 9f, alpha = 0.45, tracking = 3f).apply { setPadding(0, context.px(4), 0, 0) })
        })
        bar.addView(Face.row(context, 8).apply {
            setPadding(context.px(10), context.px(5), context.px(12), context.px(5))
            background = android.graphics.drawable.GradientDrawable().apply { cornerRadius = context.dp(100); setStroke(context.px(1), Face.ink(0.18)) }
            addView(statusLight); addView(status)
        })
        bar.addView(Face.row(context, 6).apply {
            addView(Face.text(context, "WINDOW", 9f, alpha = 0.5, tracking = 2f))
            addView(Face.pill(context, "−") { Core.command("keyTestWindow", "-0.005"); refresh() })
            addView(window.apply { minWidth = context.px(62); gravity = android.view.Gravity.CENTER })
            addView(Face.pill(context, "+") { Core.command("keyTestWindow", "0.005"); refresh() })
        })
        copy = Face.pill(context, "COPY REPORT") {
            (context.getSystemService(ClipboardManager::class.java)).setPrimaryClip(ClipData.newPlainText("Galax-z key test", report))
            copied = System.currentTimeMillis()
            refresh()
        }
        bar.addView(Face.row(context, 8).apply {
            addView(Face.pill(context, "RESET") { Core.command("keyTestReset", ""); refresh() })
            addView(copy)
            addView(Face.pill(context, "DONE", Face.yellow) { done() })
        })
        v.addView(bar)
        v.addView(hint)
        v.addView(warning)
        v.addView(stats)
        v.addView(keys, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, context.px(300)))
        v.addView(Face.column(context, 8).apply { addView(Face.text(context, "LATEST PRESSES", 9f, alpha = 0.45, tracking = 2f)); addView(log) })
        addView(ScrollView(context).apply { addView(v); isVerticalScrollBarEnabled = false })
    }

    private val tick = object : Runnable { override fun run() { refresh(); main.postDelayed(this, 100) } }
    override fun onAttachedToWindow() { super.onAttachedToWindow(); main.post(tick) }
    override fun onDetachedFromWindow() { main.removeCallbacks(tick); Core.command("keyTestClose", ""); super.onDetachedFromWindow() }

    private fun refresh() {
        val k = JSONObject(Core.query("keytest"))
        val demo = k.getBoolean("demo"); val device = k.getString("device")
        val listening = demo || device.isNotEmpty()
        status.text = if (demo) "DEMO PRESSES" else if (device.isEmpty()) "NO OP-Z" else "LISTENING · ${k.getString("over")} · ${device.uppercase()}"
        (statusLight.background as android.graphics.drawable.GradientDrawable).setColor(if (listening) Face.yellow else Face.ink(0.4))
        window.text = "${k.getInt("window")} MS"
        val presses = k.getInt("presses")
        report = k.getString("report")
        copy.text = if (System.currentTimeMillis() - copied < 1500) "COPIED" else "COPY REPORT"
        Face.enable(copy, presses > 0)
        hint.text = when {
            demo -> "Demo: pretend presses across the keyboard; three keys bounce now and then, so you can see what a double looks like."
            device.isEmpty() -> "Connect your OP-Z first, by cable or Bluetooth."
            presses == 0 -> "Press STOP on the OP-Z, then press every key a few times at a steady pace. A key that fires twice inside " +
                "the window is a double trigger. Nothing arriving? Turn MIDI out on: hold TEMPO + SCREEN and press 3."
            else -> "Keep going: press each key 10–20 times. Keys turn red when they bounce. COPY REPORT keeps the numbers for tuning the debounce fix."
        }
        warning.visibility = if (k.getBoolean("playing")) View.VISIBLE else View.GONE
        // the numbers
        val s = mutableListOf("PRESSES" to "$presses" to Face.ink,
            "DOUBLES" to "${k.getInt("doubles")}" to (if (k.getInt("doubles") > 0) Face.drums else Face.ink),
            "KEYS THAT BOUNCE" to "${k.getInt("bouncing")}" to (if (k.getInt("bouncing") > 0) Face.drums else Face.ink),
            "FASTEST REPEAT" to (if (k.has("fastest")) "${k.getInt("fastest")} MS" else "—") to Face.ink)
        if (k.has("channel")) s += "LISTENING ON" to "CH ${k.getInt("channel") + 1}" to Face.ink
        if (k.getInt("ignored") > 0) s += "OTHER CHANNELS" to "${k.getInt("ignored")}" to Face.ink(0.5)
        if (stats.childCount != s.size) {
            stats.removeAllViews()
            repeat(s.size) { stats.addView(Face.column(context, 2).apply { addView(Face.text(context, "", 9f, alpha = 0.45, tracking = 2f)); addView(Face.text(context, "", 28f).apply { typeface = Face.monoMedium }) }) }
        }
        s.forEachIndexed { i, (lv, color) ->
            val c = stats.getChildAt(i) as LinearLayout
            (c.getChildAt(0) as TextView).text = lv.first
            (c.getChildAt(1) as TextView).apply { text = lv.second; setTextColor(color) }
        }
        keys.show(k.getJSONArray("keys"), k.getInt("firstNote"))
        // the latest presses, newest first
        val l = k.getJSONArray("log")
        if (log.childCount != l.length()) {
            log.removeAllViews()
            repeat(l.length()) {
                log.addView(Face.row(context, 12).apply {
                    addView(Face.text(context, "", 12f, bold = true).apply { layoutParams = LinearLayout.LayoutParams(context.px(40), -2) })
                    addView(Face.text(context, "", 11f).apply { layoutParams = LinearLayout.LayoutParams(context.px(84), -2) })
                    addView(Face.text(context, "", 11f, alpha = 0.5).apply { layoutParams = LinearLayout.LayoutParams(context.px(100), -2) })
                    addView(Face.text(context, "DOUBLE", 10f, bold = true, color = Face.background).apply {
                        setPadding(context.px(6), context.px(1), context.px(6), context.px(1))
                        background = android.graphics.drawable.GradientDrawable().apply { cornerRadius = context.dp(100); setColor(Face.drums) }
                    })
                })
            }
        }
        for (i in 0 until l.length()) {
            val p = l.getJSONObject(i); val r = log.getChildAt(i) as LinearLayout; val d = p.getBoolean("double")
            val color = if (d) Face.drums else Face.ink
            (r.getChildAt(0) as TextView).apply { text = p.getString("name"); setTextColor(color) }
            (r.getChildAt(1) as TextView).apply { text = if (p.has("gap")) "+${p.getInt("gap")} MS" else "—"; setTextColor(color) }
            (r.getChildAt(2) as TextView).apply { text = if (p.has("held")) "HELD ${p.getInt("held")} MS" else ""; setTextColor(Face.alpha(color, 0.5)) }
            r.getChildAt(3).visibility = if (d) View.VISIBLE else View.INVISIBLE
        }
    }

    /** Two octaves from F like the OP-Z's keys: 14 white keys, the 10 black value keys over them. */
    private class Keys(context: Context) : View(context) {
        private val white = intArrayOf(0, 2, 4, 6, 7, 9, 11)
        private val black = intArrayOf(1, 3, 5, 8, 10)
        private val blackAfter = intArrayOf(0, 1, 2, 4, 5)
        private val d = context.resources.displayMetrics.density
        private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
        private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
        private val type = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = Face.mono; textAlign = Paint.Align.CENTER }
        private var keys = JSONArray()
        private var first = 53
        private val flashAt = HashMap<Int, Long>()
        private val lastPresses = HashMap<Int, Int>()

        fun show(k: JSONArray, firstNote: Int) {
            for (i in 0 until k.length()) {
                val o = k.getJSONObject(i); val n = o.getInt("note"); val p = o.getInt("presses")
                if ((lastPresses[n] ?: p) < p) flashAt[n] = System.currentTimeMillis()
                lastPresses[n] = p
            }
            keys = k; first = firstNote
            invalidate()
        }

        private fun key(note: Int): JSONObject? {
            for (i in 0 until keys.length()) if (keys.getJSONObject(i).getInt("note") == note) return keys.getJSONObject(i)
            return null
        }

        override fun onDraw(c: Canvas) {
            val gap = 6 * d
            val w = (width - gap * 13) / 14
            for (i in 0 until 14) cell(c, first + 12 * (i / 7) + white[i % 7], RectF(i * (w + gap), 0f, i * (w + gap) + w, height.toFloat()), false, null)
            for (k in 0 until 10) {
                val after = blackAfter[k % 5] + 7 * (k / 5); val bw = w * 0.66f
                val x = (after + 1) * (w + gap) - gap / 2 - bw / 2
                cell(c, first + 12 * (k / 5) + black[k % 5], RectF(x, 0f, x + bw, height * 0.55f), true, (k + 1) % 10)
            }
            if (flashAt.values.any { System.currentTimeMillis() - it < 400 }) postInvalidateOnAnimation()
        }

        private fun cell(c: Canvas, note: Int, r: RectF, isBlack: Boolean, value: Int?) {
            val o = key(note)
            val presses = o?.getInt("presses") ?: 0; val doubles = o?.getInt("doubles") ?: 0
            val rad = 10 * d
            fill.color = if (isBlack) 0xFF050506.toInt() else Face.panel
            c.drawRoundRect(r, rad, rad, fill)
            if (doubles > 0) { fill.color = Face.alpha(Face.drums, 0.28); c.drawRoundRect(r, rad, rad, fill) }
            val since = System.currentTimeMillis() - (flashAt[note] ?: 0)
            if (since < 370) { fill.color = Face.alpha(Face.yellow, 0.55 * (1 - since / 370.0)); c.drawRoundRect(r, rad, rad, fill) }
            line.color = if (doubles > 0) Face.drums else Face.ink(if (isBlack) 0.22 else 0.12)
            line.strokeWidth = (if (doubles > 0) 1.5f else 1f) * d
            c.drawRoundRect(r, rad, rad, line)
            var y = r.bottom - 10 * d
            type.textSize = 9 * d; type.color = Face.ink(0.5)
            c.drawText(value?.toString() ?: name(note), r.centerX(), y, type)
            y -= 13 * d
            type.textSize = 12 * d; type.color = Face.ink(if (presses > 0) 0.9 else 0.3)
            c.drawText(if (presses > 0) "$presses" else "·", r.centerX(), y, type)
            if (doubles > 0) {
                y -= 17 * d
                val t = "×$doubles"; type.textSize = 11 * d; type.typeface = Face.monoBold
                val tw = type.measureText(t) + 10 * d
                fill.color = Face.drums
                c.drawRoundRect(RectF(r.centerX() - tw / 2, y - 11 * d, r.centerX() + tw / 2, y + 4 * d), 8 * d, 8 * d, fill)
                type.color = Face.background; c.drawText(t, r.centerX(), y, type); type.typeface = Face.mono
            }
        }

        private fun name(n: Int) = listOf("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")[n % 12] + (n / 12 - 1)
    }
}
