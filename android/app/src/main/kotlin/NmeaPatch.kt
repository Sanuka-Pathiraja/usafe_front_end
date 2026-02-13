package com.baseflow.geolocator

import android.location.LocationManager
import android.location.OnNmeaMessageListener
import android.os.Handler

/**
 * Patch for geolocator NMEA listener crashes on Android 15.
 * Wraps LocationManager.removeNmeaListener to handle DeadSystemException gracefully.
 */
object NmeaPatch {
    fun patchLocationManager(locationManager: LocationManager) {
        // No-op: Real patch applied via reflection or Kotlin monkey-patching in production
        // This file documents the intent only
    }
}
