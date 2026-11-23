package org.galaxz.app

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.max
import kotlin.math.min

/**
 * The design tokens and the controls of the app's panels (`App/Face.swift`, `App/DotText.swift`): near-black, off-white ink,
 * one yellow, monospaced type; cards, capsule buttons, segmented pickers, sliders and switches drawn as iOS draws them.
 */
object Face {
    const val background = 0xFF0C0C0D.toInt()
    const val panel = 0xFF161618.toInt()
    const val ink = 0xFFEDEBE6.toInt()
    const val yellow = 0xFFFFD23F.toInt()
    const val green = 0xFF2FD18B.toInt()
    const val red = 0xFFFF4A2E.toInt()
    const val drums = 0xFFFF5A36.toInt()

    fun ink(alpha: Double) = Color.argb((alpha * 255).toInt(), 0xED, 0xEB, 0xE6)
    fun alpha(c: Int, a: Double) = (c and 0xFFFFFF) or ((a * 255).toInt() shl 24)

    val mono: Typeface = Typeface.MONOSPACE
    val monoBold: Typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
    val monoMedium: Typeface = Typeface.create(Typeface.create("monospace", Typeface.NORMAL), 500, false)

    fun Context.dp(v: Number) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics)
    fun Context.px(v: Number) = dp(v).toInt()

    /** `Face.mono(size, weight)`, tracked as SwiftUI's `.tracking(t)` does (points between letters). */
    fun text(c: Context, s: String, size: Float, bold: Boolean = false, alpha: Double = 1.0, tracking: Float = 0f, color: Int = ink): TextView =
        TextView(c).apply {
            text = s
            typeface = if (bold) monoBold else mono
            setTextSize(TypedValue.COMPLEX_UNIT_SP, size)
            setTextColor(alpha(color, alpha))
            if (tracking > 0) letterSpacing = tracking / size
            includeFontPadding = false
            setLineSpacing(0f, 1.18f)
        }

    /** A card: the panel colour, rounded 14, 18 in, its rows 10 apart. */
    fun card(c: Context): LinearLayout = LinearLayout(c).apply {
        orientation = LinearLayout.VERTICAL
        background = GradientDrawable().apply { setColor(panel); cornerRadius = c.dp(14) }
        val p = c.px(18)
        setPadding(p, p, p, p)
        dividerDrawable = GradientDrawable().apply { setSize(1, c.px(10)) }
        showDividers = LinearLayout.SHOW_DIVIDER_MIDDLE
    }

    fun column(c: Context, gap: Number): LinearLayout = LinearLayout(c).apply {
        orientation = LinearLayout.VERTICAL
        dividerDrawable = GradientDrawable().apply { setSize(1, c.px(gap)) }
        showDividers = LinearLayout.SHOW_DIVIDER_MIDDLE
    }

    fun row(c: Context, gap: Number): LinearLayout = LinearLayout(c).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        dividerDrawable = GradientDrawable().apply { setSize(c.px(gap), 1) }
        showDividers = LinearLayout.SHOW_DIVIDER_MIDDLE
    }

    fun grow(v: View) = v.apply { layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f) }

    /** `PillButton`: a capsule, outlined, or filled when given a colour. */
    fun pill(c: Context, s: String, fill: Int? = null, click: () -> Unit): TextView = text(c, s, 11f, bold = true, tracking = 2f,
        color = if (fill == null) ink else background).apply {
        setPadding(c.px(14), c.px(8), c.px(14), c.px(8))
        maxLines = 1
        background = GradientDrawable().apply {
            cornerRadius = c.dp(100)
            if (fill != null) setColor(fill) else { setColor(0); setStroke(max(1, c.px(1)), ink(0.3)) }
        }
        isClickable = true
        setOnClickListener { click() }
        setOnTouchListener { v, e ->
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> v.animate().scaleX(0.94f).scaleY(0.94f).setDuration(80).start()
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> v.animate().scaleX(1f).scaleY(1f).setDuration(200).start()
            }
            false
        }
    }

    fun enable(v: View, on: Boolean) { v.isEnabled = on; v.alpha = if (on) 1f else 0.4f }

    /** A light: a small round dot. */
    fun light(c: Context, color: Int, size: Number = 8): View = View(c).apply {
        background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(color) }
        layoutParams = LinearLayout.LayoutParams(c.px(size), c.px(size))
    }
}

/** The matrix's type in the panels: the same glyphs (drawn by the Swift side), a round dot each (`DotText`). */
class DotText(context: Context, text: String, private val font: Int = 1, private val dot: Float = 2f, color: Int = Face.ink) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
    private var dots: IntArray = Core.dotText(text, font)
    private val px = context.resources.displayMetrics.density * dot

    var text: String = text
        set(v) { if (v != field) { field = v; dots = Core.dotText(v, font); requestLayout(); invalidate() } }
    var color: Int
        get() = paint.color
        set(v) { paint.color = v; invalidate() }

    override fun onMeasure(w: Int, h: Int) = setMeasuredDimension((dots[0] * px).toInt() + 1, (dots[1] * px).toInt() + 1)

    override fun onDraw(c: Canvas) {
        val w = dots[0]; val h = dots[1]
        val r = px * 0.42f
        for (y in 0 until h) for (x in 0 until w) if (dots[2 + y * w + x] != 0) c.drawCircle((x + 0.5f) * px, (y + 0.5f) * px, r, paint)
    }
}

/** A segmented picker as iOS draws one in the dark: a grey track, the chosen part lighter. */
@SuppressLint("ViewConstructor")
class Segmented(context: Context, labels: List<String>, chosen: Int, private val small: Boolean = false, private val changed: (Int) -> Unit) :
    LinearLayout(context) {
    private val parts = labels.mapIndexed { i, s ->
        TextView(context).apply {
            text = s
            gravity = Gravity.CENTER
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            setTextSize(TypedValue.COMPLEX_UNIT_SP, if (small) 11f else 13f)
            typeface = Typeface.create(Typeface.DEFAULT, 500, false)
            setTextColor(Face.ink)
            setPadding(context.resources.displayMetrics.density.toInt() * 6, 0, context.resources.displayMetrics.density.toInt() * 6, 0)
            layoutParams = LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f)
            setOnClickListener { if (selected != i) { select(i); changed(i) } }
        }
    }
    var selected = chosen; private set

    init {
        val d = context.resources.displayMetrics.density
        background = GradientDrawable().apply { setColor(0x3D767680); cornerRadius = 9 * d }
        val p = (2 * d).toInt()
        setPadding(p, p, p, p)
        minimumHeight = (32 * d).toInt()
        for (t in parts) addView(t)
        select(chosen)
    }

    fun select(i: Int) {
        selected = i
        val d = context.resources.displayMetrics.density
        parts.forEachIndexed { k, t ->
            t.background = if (k == i) GradientDrawable().apply { setColor(0xFF636366.toInt()); cornerRadius = 7 * d } else null
        }
    }
}

/** A slider as iOS draws one, tinted: a thin track, the part behind the knob in its colour, a white round knob. */
class Slider(context: Context, private val from: Float, private val to: Float, value: Float, private val tint: Int = Face.yellow,
             private val changed: (Float) -> Unit) : View(context) {
    var value = value.coerceIn(from, to); private set
    private val d = context.resources.displayMetrics.density
    private val track = Paint(Paint.ANTI_ALIAS_FLAG)
    private val knob = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; setShadowLayer(3 * d, 0f, 1 * d, 0x40000000) }

    init {
        setLayerType(LAYER_TYPE_SOFTWARE, null)          // for the knob's shadow
        minimumHeight = (34 * d).toInt()
    }

    override fun onMeasure(w: Int, h: Int) = setMeasuredDimension(MeasureSpec.getSize(w), (34 * d).toInt())

    override fun onDraw(c: Canvas) {
        val r = 13.5f * d
        val y = height / 2f
        val x0 = r
        val x1 = width - r
        val at = x0 + (x1 - x0) * (value - from) / (to - from)
        track.color = 0xFF3A3A3C.toInt()
        c.drawRoundRect(RectF(x0, y - 2 * d, x1, y + 2 * d), 2 * d, 2 * d, track)
        track.color = tint
        c.drawRoundRect(RectF(x0, y - 2 * d, at, y + 2 * d), 2 * d, 2 * d, track)
        c.drawCircle(at, y, r, knob)
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(e: MotionEvent): Boolean {
        val r = 13.5f * d
        val t = ((e.x - r) / (width - 2 * r)).coerceIn(0f, 1f)
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                parent?.requestDisallowInterceptTouchEvent(true)
                value = from + (to - from) * t
                invalidate()
                changed(value)
            }
        }
        return true
    }
}

/** A switch as iOS draws one: a capsule, its colour when on, a white knob that slides. */
class Toggle(context: Context, on: Boolean, private val tint: Int = Face.yellow, private val changed: (Boolean) -> Unit) : View(context) {
    var on = on; private set
    private var at = if (on) 1f else 0f
    private val d = context.resources.displayMetrics.density
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val knob = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; setShadowLayer(3 * d, 0f, 1.5f * d, 0x40000000) }

    init {
        setLayerType(LAYER_TYPE_SOFTWARE, null)
        setOnClickListener { set(!this.on, true) }
    }

    fun set(v: Boolean, tell: Boolean = false) {
        if (v == on) return
        on = v
        ValueAnimator.ofFloat(at, if (v) 1f else 0f).apply {
            duration = 220
            addUpdateListener { at = it.animatedValue as Float; invalidate() }
        }.start()
        if (tell) changed(v)
    }

    override fun onMeasure(w: Int, h: Int) = setMeasuredDimension((51 * d).toInt(), (31 * d).toInt())

    override fun onDraw(c: Canvas) {
        val w = width.toFloat(); val h = height.toFloat()
        val off = 0xFF39393D.toInt()
        paint.color = blend(off, tint, at)
        c.drawRoundRect(RectF(0f, 0f, w, h), h / 2, h / 2, paint)
        val r = h / 2 - 2 * d
        c.drawCircle(h / 2 + (w - h) * at, h / 2, r, knob)
    }

    private fun blend(a: Int, b: Int, t: Float): Int {
        fun ch(s: Int) = ((a shr s and 255) + ((b shr s and 255) - (a shr s and 255)) * t).toInt() shl s
        return (0xFF shl 24) or ch(16) or ch(8) or ch(0)
    }
}

/** Lays its children out in rows, as many as fit (SwiftUI's adaptive grid, or a line that wraps). */
class Flow(context: Context, private val gapX: Int, private val gapY: Int, private val columnMin: Int = 0) : ViewGroup(context) {
    override fun onMeasure(ws: Int, hs: Int) {
        val width = MeasureSpec.getSize(ws)
        val cols = if (columnMin > 0) max(1, (width + gapX) / (columnMin + gapX)) else 0
        val cell = if (cols > 0) (width - gapX * (cols - 1)) / cols else 0
        var x = 0; var y = 0; var line = 0; var i = 0
        for (k in 0 until childCount) {
            val v = getChildAt(k)
            if (v.visibility == GONE) continue
            if (cols > 0) v.measure(MeasureSpec.makeMeasureSpec(cell, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED))
            else v.measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.AT_MOST), MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED))
            val wrap = if (cols > 0) i > 0 && i % cols == 0 else x > 0 && x + v.measuredWidth > width
            if (wrap) { x = 0; y += line + gapY; line = 0 }
            x += v.measuredWidth + gapX
            line = max(line, v.measuredHeight)
            i++
        }
        setMeasuredDimension(width, y + line)
    }

    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        val width = r - l
        val cols = if (columnMin > 0) max(1, (width + gapX) / (columnMin + gapX)) else 0
        var x = 0; var y = 0; var line = 0; var i = 0
        for (k in 0 until childCount) {
            val v = getChildAt(k)
            if (v.visibility == GONE) continue
            val wrap = if (cols > 0) i > 0 && i % cols == 0 else x > 0 && x + v.measuredWidth > width
            if (wrap) { x = 0; y += line + gapY; line = 0 }
            v.layout(x, y, x + v.measuredWidth, y + v.measuredHeight)
            x += v.measuredWidth + gapX
            line = max(line, v.measuredHeight)
            i++
        }
    }
}

/** Something narrower than the screen, in its middle (`.frame(maxWidth:)` then `.frame(maxWidth: .infinity)`). */
class Middle(context: Context, private val most: Int, child: View) : FrameLayout(context) {
    init { addView(child, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT, Gravity.CENTER_HORIZONTAL)) }
    override fun onMeasure(ws: Int, hs: Int) {
        val w = MeasureSpec.getSize(ws)
        val inner = min(w, most)
        getChildAt(0).measure(MeasureSpec.makeMeasureSpec(inner, MeasureSpec.EXACTLY), hs)
        setMeasuredDimension(w, getChildAt(0).measuredHeight)
    }
    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        val c = getChildAt(0); val x = ((r - l) - c.measuredWidth) / 2
        c.layout(x, 0, x + c.measuredWidth, c.measuredHeight)
    }
}
