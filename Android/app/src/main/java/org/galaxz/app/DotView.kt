package org.galaxz.app

import android.annotation.SuppressLint
import android.content.Context
import android.opengl.GLES30.*
import android.opengl.GLSurfaceView
import android.view.Choreographer
import android.view.MotionEvent
import java.nio.ByteBuffer
import java.nio.ByteOrder
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * The screen: the stage's dots on the GPU, each a round light (`App/DotDisplay.swift` and `App/DotShaders.swift`, in
 * OpenGL ES). A frame is drawn only while something moves; a still picture costs nothing.
 */
@SuppressLint("ViewConstructor")
class DotView(context: Context, private val action: (Int) -> Unit) : GLSurfaceView(context), Choreographer.FrameCallback {
    /** How the matrix looks (Settings › Screen). */
    data class Look(val fineness: Int = 240, val glow: Double = 0.8, val afterglow: Double = 0.3)

    @Volatile var look = Look()
        set(v) { field = v; queueEvent { renderer.relayout() }; changed() }

    /** Something is over it: let go of what is held, draw nothing. */
    var covered = false
        set(v) { if (v != field) { field = v; if (v) { Core.letGo(); fingers.clear() }; changed() } }

    /** Where the dots are, in px: whole pixels a dot, the rest round the edge. */
    private data class Layout(val w: Int, val h: Int, val pitch: Int, val ox: Int, val oy: Int, val pxW: Int, val pxH: Int)
    @Volatile private var layout = Layout(1, 1, 6, 0, 0, 1, 1)
    private val renderer = Renderer()
    private var movedAt = 0L
    private var ticking = false
    private val density = resources.displayMetrics.density

    init {
        setEGLContextClientVersion(3)
        setEGLConfigChooser(8, 8, 8, 8, 0, 0)
        preserveEGLContextOnPause = true
        setRenderer(renderer)
        renderMode = RENDERMODE_WHEN_DIRTY
        isFocusable = true
        contentDescription = "Galax-z"
    }

    // when to draw ---------------------------------------------------------------------------------------------------

    /** Something to show: every frame of the display until it is still again. */
    fun changed() {
        movedAt = System.nanoTime()
        if (!ticking && !covered) { ticking = true; Choreographer.getInstance().postFrameCallback(this) }
    }

    override fun doFrame(frameTimeNanos: Long) {
        // after the last change: long enough for the afterglow to go out, then rest until something changes
        if (covered || (renderer.still && System.nanoTime() - movedAt > 1_200_000_000L)) { ticking = false; return }
        renderer.aim = frameTimeNanos
        requestRender()
        Choreographer.getInstance().postFrameCallback(this)
    }

    override fun onDetachedFromWindow() {
        Choreographer.getInstance().removeFrameCallback(this)
        ticking = false
        super.onDetachedFromWindow()
    }

    // touch ----------------------------------------------------------------------------------------------------------

    private val fingers = HashMap<Int, Int>()             // pointer → the stage's finger
    private val starts = HashMap<Int, FloatArray>()       // pointer → where a tap or a swipe began
    private var nextFinger = 0

    private fun dotX(x: Float) = ((x - layout.ox) / layout.pitch).toInt()
    private fun dotY(y: Float) = ((y - layout.oy) / layout.pitch).toInt()

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(e: MotionEvent): Boolean {
        val i = e.actionIndex
        val id = e.getPointerId(i)
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                val x = dotX(e.getX(i)); val y = dotY(e.getY(i))
                nextFinger += 1
                if (Core.grab(nextFinger, x, y)) fingers[id] = nextFinger else starts[id] = floatArrayOf(e.getX(i), e.getY(i))
            }
            MotionEvent.ACTION_MOVE -> for (k in 0 until e.pointerCount) {
                val f = fingers[e.getPointerId(k)] ?: continue
                Core.drag(f, dotX(e.getX(k)), dotY(e.getY(k)))
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP -> {
                val x = e.getX(i); val y = e.getY(i)
                val f = fingers.remove(id)
                if (f != null) Core.release(f, dotX(x), dotY(y))
                else starts.remove(id)?.let { (sx, sy) ->
                    val dx = x - sx; val dy = y - sy
                    if (abs(dx) > 48 * density && abs(dx) > 2 * abs(dy)) Core.turn(if (dx < 0) 1 else -1)      // a swipe: the next page
                    else if (hypot(dx, dy) < 16 * density) {
                        val what = Core.tap(dotX(x), dotY(y))
                        if (what != 0) action(what)
                        if (what == 0) performClick()
                    }
                }
            }
            MotionEvent.ACTION_CANCEL -> {
                for (f in fingers.values) Core.release(f, -1000, -1000)
                fingers.clear(); starts.clear()
            }
        }
        (context as? MainActivity)?.pump()
        changed()
        return true
    }

    override fun performClick(): Boolean { super.performClick(); return true }

    // the GPU ----------------------------------------------------------------------------------------------------------

    private inner class Renderer : GLSurfaceView.Renderer {
        @Volatile var still = false
        @Volatile var aim = 0L
        private var lastTime = 0.0
        private var pixels: ByteBuffer = ByteBuffer.allocateDirect(4)
        private var afterglow = 0; private var blur = 0; private var screen = 0
        private var dots = 0
        private val light = IntArray(2); private val blurred = IntArray(2)
        private val fbo = IntArray(4)
        private var texW = 0; private var texH = 0
        private var frame = 0
        private var halfFloat = false

        override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
            val ext = glGetString(GL_EXTENSIONS) ?: ""
            halfFloat = ext.contains("GL_EXT_color_buffer_half_float") || ext.contains("GL_EXT_color_buffer_float")
            afterglow = program(AFTERGLOW); blur = program(BLUR); screen = program(SCREEN)
            val vao = IntArray(1); glGenVertexArrays(1, vao, 0); glBindVertexArray(vao[0])
            texW = 0; texH = 0
        }

        override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
            layout = layout.copy(pxW = width, pxH = height)
            relayout()
        }

        /** Whole pixels a dot, so every dot is exactly alike; never so few across that a page cannot be laid out. */
        fun relayout() {
            val (_, _, _, _, _, pxW, pxH) = layout
            if (pxW <= 8 || pxH <= 8) return
            var pitch = max(3, (min(pxW, pxH).toDouble() / look.fineness).roundToInt())
            while (pxW / pitch < 200 && pitch > 3) pitch -= 1
            val w = min(1600, pxW / pitch); val h = min(1600, pxH / pitch)
            layout = Layout(w, h, pitch, (pxW - w * pitch) / 2, (pxH - h * pitch) / 2, pxW, pxH)
            post { changed() }
        }

        private fun sized(w: Int, h: Int) {
            if (w == texW && h == texH) return
            if (texW != 0) {
                glDeleteTextures(1, intArrayOf(dots), 0); glDeleteTextures(2, light, 0); glDeleteTextures(2, blurred, 0)
                glDeleteFramebuffers(4, fbo, 0)
            }
            texW = w; texH = h; frame = 0
            pixels = ByteBuffer.allocateDirect(w * h * 4).order(ByteOrder.nativeOrder())
            dots = texture(w, h, GL_RGBA8, GL_RGBA, GL_UNSIGNED_BYTE, GL_NEAREST)
            val (inner, type) = if (halfFloat) GL_RGBA16F to GL_HALF_FLOAT else GL_RGBA8 to GL_UNSIGNED_BYTE
            for (k in 0..1) light[k] = texture(w, h, inner, GL_RGBA, type, GL_NEAREST)
            for (k in 0..1) blurred[k] = texture(w, h, inner, GL_RGBA, type, GL_LINEAR)
            glGenFramebuffers(4, fbo, 0)
            for ((k, t) in listOf(light[0], light[1], blurred[0], blurred[1]).withIndex()) {
                glBindFramebuffer(GL_FRAMEBUFFER, fbo[k])
                glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, t, 0)
                glClearColor(0f, 0f, 0f, 1f); glClear(GL_COLOR_BUFFER_BIT)      // nothing to glow after
            }
            glBindFramebuffer(GL_FRAMEBUFFER, 0)
        }

        override fun onDrawFrame(gl: GL10?) {
            val l = layout
            if (l.w < 2 || l.h < 2) return
            sized(l.w, l.h)
            val now = (if (aim > 0) aim else System.nanoTime()) / 1e9
            val dt = if (lastTime == 0.0) 1.0 / 120 else min(0.1, max(0.001, now - lastTime))
            lastTime = now
            val flags = Core.frame(pixels, l.w, l.h, now, dt)
            still = flags and 1 != 0
            glBindTexture(GL_TEXTURE_2D, dots)
            glPixelStorei(GL_UNPACK_ALIGNMENT, 4)
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, l.w, l.h, GL_RGBA, GL_UNSIGNED_BYTE, pixels)

            val before = frame % 2; val next = (frame + 1) % 2
            val lk = look
            val decay = if (frame < 2 || lk.afterglow <= 0) 0f else 0.5.pow(dt / (0.012 + lk.afterglow * 0.06)).toFloat()
            frame += 1

            glViewport(0, 0, l.w, l.h)
            // this frame's lights, or what is left of the last one's
            glBindFramebuffer(GL_FRAMEBUFFER, fbo[next])
            glUseProgram(afterglow)
            bind(afterglow, "dots", 0, dots); bind(afterglow, "before", 1, light[before])
            glUniform1f(glGetUniformLocation(afterglow, "decay"), decay)
            glDrawArrays(GL_TRIANGLES, 0, 3)
            // the light that spills, a blur each way
            glUseProgram(blur)
            glBindFramebuffer(GL_FRAMEBUFFER, fbo[2])
            bind(blur, "src", 0, light[next]); glUniform2i(glGetUniformLocation(blur, "d"), 1, 0)
            glDrawArrays(GL_TRIANGLES, 0, 3)
            glBindFramebuffer(GL_FRAMEBUFFER, fbo[3])
            bind(blur, "src", 0, blurred[0]); glUniform2i(glGetUniformLocation(blur, "d"), 0, 1)
            glDrawArrays(GL_TRIANGLES, 0, 3)
            // every dot a round light on dark glass
            glBindFramebuffer(GL_FRAMEBUFFER, 0)
            glViewport(0, 0, l.pxW, l.pxH)
            glUseProgram(screen)
            bind(screen, "lights", 0, light[next]); bind(screen, "bloom", 1, blurred[1])
            glUniform2f(glGetUniformLocation(screen, "origin"), l.ox.toFloat(), l.oy.toFloat())
            glUniform1f(glGetUniformLocation(screen, "pitch"), l.pitch.toFloat())
            glUniform1f(glGetUniformLocation(screen, "glow"), (lk.glow * 0.42).toFloat())
            glUniform1f(glGetUniformLocation(screen, "unlit"), 0.0046f)
            glUniform2f(glGetUniformLocation(screen, "size"), l.w.toFloat(), l.h.toFloat())
            glUniform1f(glGetUniformLocation(screen, "screenH"), l.pxH.toFloat())
            glDrawArrays(GL_TRIANGLES, 0, 3)
        }

        private fun bind(p: Int, name: String, unit: Int, tex: Int) {
            glActiveTexture(GL_TEXTURE0 + unit)
            glBindTexture(GL_TEXTURE_2D, tex)
            glUniform1i(glGetUniformLocation(p, name), unit)
        }

        private fun texture(w: Int, h: Int, inner: Int, format: Int, type: Int, filter: Int): Int {
            val t = IntArray(1)
            glGenTextures(1, t, 0)
            glBindTexture(GL_TEXTURE_2D, t[0])
            glTexImage2D(GL_TEXTURE_2D, 0, inner, w, h, 0, format, type, null)
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter)
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filter)
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
            return t[0]
        }

        private fun program(fragment: String): Int {
            fun shader(type: Int, src: String): Int {
                val s = glCreateShader(type)
                glShaderSource(s, src); glCompileShader(s)
                val ok = IntArray(1); glGetShaderiv(s, GL_COMPILE_STATUS, ok, 0)
                check(ok[0] != 0) { "shader: " + glGetShaderInfoLog(s) }
                return s
            }
            val p = glCreateProgram()
            glAttachShader(p, shader(GL_VERTEX_SHADER, WHOLE_SCREEN)); glAttachShader(p, shader(GL_FRAGMENT_SHADER, fragment))
            glLinkProgram(p)
            val ok = IntArray(1); glGetProgramiv(p, GL_LINK_STATUS, ok, 0)
            check(ok[0] != 0) { "program: " + glGetProgramInfoLog(p) }
            return p
        }
    }

    companion object {
        // The matrix's shaders: App/DotShaders.swift in GLSL. Three small passes at one texel a dot (afterglow, then a
        // blur each way) and one over the screen that draws every dot as a round light on dark glass.
        private const val WHOLE_SCREEN = """#version 300 es
void main() {
    vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
    gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}"""
        private const val AFTERGLOW = """#version 300 es
precision highp float;
uniform sampler2D dots;
uniform sampler2D before;
uniform float decay;
out vec4 o;
void main() {
    ivec2 p = ivec2(gl_FragCoord.xy);
    vec3 now = pow(texelFetch(dots, p, 0).rgb, vec3(1.55));
    vec3 left = texelFetch(before, p, 0).rgb * decay;
    o = vec4(max(now, left - 0.0004), 1.0);
}"""
        private const val BLUR = """#version 300 es
precision highp float;
uniform sampler2D src;
uniform ivec2 d;
out vec4 o;
void main() {
    float w[5] = float[5](0.204, 0.180, 0.124, 0.066, 0.028);
    ivec2 p = ivec2(gl_FragCoord.xy);
    ivec2 last = textureSize(src, 0) - 1;
    vec3 sum = texelFetch(src, p, 0).rgb * w[0];
    for (int i = 1; i < 5; i++) {
        sum += texelFetch(src, clamp(p + d * i, ivec2(0), last), 0).rgb * w[i];
        sum += texelFetch(src, clamp(p - d * i, ivec2(0), last), 0).rgb * w[i];
    }
    o = vec4(sum, 1.0);
}"""
        private const val SCREEN = """#version 300 es
precision highp float;
uniform sampler2D lights;
uniform sampler2D bloom;
uniform vec2 origin;
uniform float pitch, glow, unlit, screenH;
uniform vec2 size;
out vec4 o;
void main() {
    vec2 at = vec2(gl_FragCoord.x, screenH - gl_FragCoord.y);       // from the top, as the dots are
    vec2 g = (at - origin) / pitch, cell = floor(g);
    bool inside = all(greaterThanEqual(cell, vec2(0.0))) && all(lessThan(cell, size));
    vec3 light = inside ? texelFetch(lights, ivec2(cell), 0).rgb : vec3(0.0);
    float d = length((g - cell - 0.5) * pitch);
    float level = clamp(sqrt(max(light.r, max(light.g, light.b))), 0.0, 1.0);
    float r = pitch * (0.315 + 0.125 * level);
    float cover = clamp(r - d + 0.5, 0.0, 1.0);
    float core = 1.0 + 0.22 * level * clamp(1.0 - d / max(r, 0.001), 0.0, 1.0);    // a hot middle
    vec3 c = light * cover * core;
    c += unlit * (inside ? 1.0 : 0.0) * clamp(pitch * 0.3 - d + 0.5, 0.0, 1.0) * (1.0 - level);
    c += texture(bloom, g / size).rgb * glow;
    c = clamp(c / (c * 0.10 + 1.0), 0.0, 1.0);
    // a little noise, so dark glows do not band
    float n = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
    o = vec4(pow(c, vec3(1.0 / 2.2)) + n / 340.0, 1.0);
}"""
    }
}
