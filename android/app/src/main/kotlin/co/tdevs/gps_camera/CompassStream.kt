package co.tdevs.gps_camera

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import io.flutter.plugin.common.EventChannel
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.sqrt

/**
 * Streams the direction the back camera faces, in degrees from magnetic
 * north, using the fused rotation-vector sensor. When the phone is held
 * nearly flat the camera points at the ground, so the direction of the
 * phone's top edge is used instead.
 *
 * Each event is a map: `degrees` (0–360, magnetic), `accuracy` (estimated
 * error in degrees, or -1 when unknown) and `flat` (true when the top
 * edge was used).
 */
class CompassStream(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val sensors = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val sensor: Sensor? = sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    private var sink: EventChannel.EventSink? = null
    private val matrix = FloatArray(9)

    // Smoothed east/north components, so the reading doesn't jitter.
    private var east = 0.0
    private var north = 0.0
    private var primed = false
    private var lastSent = 0L
    private var lastDegrees = -1.0
    private var statusAccuracy = -1.0

    val available: Boolean get() = sensor != null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val s = sensor
        if (s == null) {
            events.error("unavailable", "This phone has no compass sensor", null)
            return
        }
        sink = events
        primed = false
        sensors.registerListener(this, s, SensorManager.SENSOR_DELAY_UI)
    }

    override fun onCancel(arguments: Any?) {
        sensors.unregisterListener(this)
        sink = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        statusAccuracy = when (accuracy) {
            SensorManager.SENSOR_STATUS_ACCURACY_HIGH -> 10.0
            SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM -> 20.0
            SensorManager.SENSOR_STATUS_ACCURACY_LOW -> 45.0
            else -> 180.0
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        val out = sink ?: return
        SensorManager.getRotationMatrixFromVector(matrix, event.values)
        // World frame: x east, y north, z up. The back camera looks along
        // the device's -z axis; the top edge is the device's +y axis.
        var e = -matrix[2].toDouble()
        var n = -matrix[5].toDouble()
        var flat = false
        if (hypot(e, n) < 0.35) {
            e = matrix[1].toDouble()
            n = matrix[4].toDouble()
            flat = true
        }
        val length = sqrt(e * e + n * n)
        if (length < 1e-6) return
        e /= length
        n /= length

        if (!primed) {
            east = e
            north = n
            primed = true
        } else {
            east += 0.25 * (e - east)
            north += 0.25 * (n - north)
        }
        var degrees = Math.toDegrees(atan2(east, north))
        if (degrees < 0) degrees += 360.0

        val now = SystemClock.elapsedRealtime()
        val changed = lastDegrees < 0 || angleDiff(degrees, lastDegrees) >= 0.5
        // Send changes at most 10 times a second, and a fresh reading every
        // half second even when still, so a photo never sees a stale value.
        val due = now - lastSent >= 500
        if (now - lastSent < 100 || !(changed || due)) return
        lastSent = now
        lastDegrees = degrees

        // values[4] is the sensor's own heading error estimate (radians).
        // Some phones always report 0, which means "no estimate", not
        // "perfect"; then the sensor's accuracy status is used.
        val estimate = if (event.values.size > 4 && event.values[4] > 0) {
            Math.toDegrees(event.values[4].toDouble())
        } else {
            statusAccuracy
        }
        out.success(mapOf("degrees" to degrees, "accuracy" to estimate, "flat" to flat))
    }

    private fun angleDiff(a: Double, b: Double): Double {
        val d = Math.abs(a - b) % 360.0
        return if (d > 180) 360 - d else d
    }

    companion object {
        /** Magnetic declination at a place: true = magnetic + declination. */
        fun declination(latitude: Double, longitude: Double, altitude: Double): Double =
            GeomagneticField(
                latitude.toFloat(),
                longitude.toFloat(),
                altitude.toFloat(),
                System.currentTimeMillis(),
            ).declination.toDouble()
    }
}
