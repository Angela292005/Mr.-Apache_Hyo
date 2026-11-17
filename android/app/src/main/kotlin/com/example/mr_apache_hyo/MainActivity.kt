package com.example.mr_apache_hyo

import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.biometric.BiometricManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val biometricSetupChannel = "com.mrapache/biometric_setup"
    private val biometricEnrollmentRequestCode = 7001
    private var enrollmentResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            biometricSetupChannel
        ).setMethodCallHandler { call, result ->
            if (call.method != "openBiometricEnrollment") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            if (enrollmentResult != null) {
                result.error("enrollment_in_progress", "Biometric setup is already open.", null)
                return@setMethodCallHandler
            }

            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                Intent(Settings.ACTION_BIOMETRIC_ENROLL).apply {
                    putExtra(
                        Settings.EXTRA_BIOMETRIC_AUTHENTICATORS_ALLOWED,
                        BiometricManager.Authenticators.BIOMETRIC_STRONG or
                            BiometricManager.Authenticators.BIOMETRIC_WEAK
                    )
                }
            } else {
                Intent(Settings.ACTION_SECURITY_SETTINGS)
            }

            try {
                enrollmentResult = result
                startActivityForResult(intent, biometricEnrollmentRequestCode)
            } catch (error: Exception) {
                enrollmentResult = null
                result.error("enrollment_unavailable", error.message, null)
            }
        }
    }

    @Deprecated("Deprecated in Android, retained for the enrollment settings result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == biometricEnrollmentRequestCode) {
            enrollmentResult?.success(true)
            enrollmentResult = null
        }
    }
}
