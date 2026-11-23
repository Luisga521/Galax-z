package org.galaxz.app

import android.content.Context
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.provider.OpenableColumns
import java.nio.ByteOrder

/** Any sound file Android can decode, as mono samples at its own rate, at most `most` seconds (`Sampler.sound` on iOS). */
object SoundFile {
    class Decoded(val samples: FloatArray, val rate: Int, val name: String)

    fun read(context: Context, uri: Uri, most: Double = 120.0): Decoded {
        val ex = MediaExtractor()
        ex.setDataSource(context, uri, null)
        try {
            val track = (0 until ex.trackCount).firstOrNull { ex.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true }
                ?: error("no sound in it")
            ex.selectTrack(track)
            val format = ex.getTrackFormat(track)
            val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            format.setInteger(MediaFormat.KEY_PCM_ENCODING, AudioFormat.ENCODING_PCM_FLOAT)
            codec.configure(format, null, null, 0)
            codec.start()
            var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var encoding = AudioFormat.ENCODING_PCM_16BIT
            var out = FloatArray(1 shl 16)
            var n = 0
            val info = MediaCodec.BufferInfo()
            var inputDone = false
            try {
                while (true) {
                    if (!inputDone) {
                        val i = codec.dequeueInputBuffer(10_000)
                        if (i >= 0) {
                            val size = ex.readSampleData(codec.getInputBuffer(i)!!, 0)
                            if (size < 0) { codec.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM); inputDone = true }
                            else { codec.queueInputBuffer(i, 0, size, ex.sampleTime, 0); ex.advance() }
                        }
                    }
                    val o = codec.dequeueOutputBuffer(info, 10_000)
                    if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        val f = codec.outputFormat
                        rate = f.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        channels = f.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        encoding = if (f.containsKey(MediaFormat.KEY_PCM_ENCODING)) f.getInteger(MediaFormat.KEY_PCM_ENCODING) else AudioFormat.ENCODING_PCM_16BIT
                    } else if (o >= 0) {
                        val b = codec.getOutputBuffer(o)!!.order(ByteOrder.nativeOrder())
                        b.position(info.offset); b.limit(info.offset + info.size)
                        val c = maxOf(1, channels)
                        val want = (most * rate).toInt()
                        if (encoding == AudioFormat.ENCODING_PCM_FLOAT) {
                            val f = b.asFloatBuffer()
                            while (f.remaining() >= c && n < want) {
                                var s = 0f; repeat(c) { s += f.get() }
                                if (n == out.size) out = out.copyOf(out.size * 2)
                                out[n++] = s / c
                            }
                        } else {
                            val sh = b.asShortBuffer()
                            while (sh.remaining() >= c && n < want) {
                                var s = 0f; repeat(c) { s += sh.get() / 32768f }
                                if (n == out.size) out = out.copyOf(out.size * 2)
                                out[n++] = s / c
                            }
                        }
                        codec.releaseOutputBuffer(o, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0 || n >= (most * rate).toInt()) break
                    }
                }
            } finally {
                codec.stop(); codec.release()
            }
            return Decoded(out.copyOf(n), rate, name(context, uri))
        } finally {
            ex.release()
        }
    }

    /** The file's name without its kind: what the kit is called. */
    private fun name(context: Context, uri: Uri): String {
        val shown = context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0) else null
        } ?: uri.lastPathSegment ?: "FILE"
        return shown.substringBeforeLast('.')
    }
}
