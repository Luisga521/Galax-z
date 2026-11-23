package org.galaxz.app

import java.nio.ByteBuffer

/** The shared Swift code (`Android/core`): the OP-Z's session and the screens. Any thread; it holds its own lock. */
object Core {
    init { System.loadLibrary("GalaxzAndroid") }

    /** Actions a tap can ask for (`Stage.Action`). */
    const val HUB = 1
    const val SETTINGS = 2
    const val PAIR = 3
    const val SOUND = 4

    @JvmStatic external fun start(folder: String, demo: Boolean)
    @JvmStatic external fun tick(): Boolean
    @JvmStatic external fun frame(pixels: ByteBuffer, w: Int, h: Int, time: Double, dt: Double): Int
    @JvmStatic external fun midiIn(data: ByteArray, offset: Int, count: Int, timeNs: Long)
    @JvmStatic external fun connected(name: String?, bluetooth: Boolean)
    @JvmStatic external fun drainOut(out: ByteBuffer): Int
    @JvmStatic external fun tap(x: Int, y: Int): Int
    @JvmStatic external fun holds(x: Int, y: Int): Boolean
    @JvmStatic external fun grab(id: Int, x: Int, y: Int): Boolean
    @JvmStatic external fun drag(id: Int, x: Int, y: Int)
    @JvmStatic external fun release(id: Int, x: Int, y: Int)
    @JvmStatic external fun letGo()
    @JvmStatic external fun turn(by: Int)
    @JvmStatic external fun setPage(page: Int)
    @JvmStatic external fun selectTrack(by: Int)
    @JvmStatic external fun useDemo(on: Boolean)
    @JvmStatic external fun isDemo(): Boolean
    @JvmStatic external fun reload()
    @JvmStatic external fun linkLine(line: String, hint: String)
    @JvmStatic external fun spoken(): String
    @JvmStatic external fun setOut(line: String?)

    // the OP-Z's sound through this phone: "" when it plays, else why not
    @JvmStatic external fun soundStart(input: Int, output: Int, volume: Float): String
    @JvmStatic external fun soundStop()
    @JvmStatic external fun soundVolume(volume: Float)
    @JvmStatic external fun soundAlive(): Boolean

    // the chops: the devices to use, what the sampler wants (1 a file, 2 the microphone), a file decoded, a word to say
    @JvmStatic external fun chopsDevices(output: Int, mic: Int, opz: Int, allowed: Boolean)
    @JvmStatic external fun chopsRequests(): Int
    @JvmStatic external fun chopsOpen(samples: FloatArray, rate: Int, name: String)
    @JvmStatic external fun chopsTell(line: String)

    // Settings, the key test, LEARN: JSON out (`Settings.swift`), a word and an argument in
    @JvmStatic external fun query(what: String): String
    @JvmStatic external fun command(what: String, arg: String): String
    @JvmStatic external fun controllerIn(name: String, data: ByteArray, offset: Int, count: Int)
    /** The matrix's type: [width, height, 1 for each lit dot]. Fonts: 0 tiny, 1 small, 2 big, 3 huge. */
    @JvmStatic external fun dotText(text: String, font: Int): IntArray
}
