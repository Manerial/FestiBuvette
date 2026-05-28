package com.jcbpartner.festi_buvette_app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.jcbpartner.festi_buvette_app/file_saver"
    private val requestCodeCreateFile = 42

    private var pendingResult: MethodChannel.Result? = null
    private var pendingContent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "saveJsonFile") {
                    pendingResult = result
                    pendingContent = call.argument<String>("content") ?: ""
                    val fileName = call.argument<String>("fileName") ?: "file.json"
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_TITLE, fileName)
                    }
                    startActivityForResult(intent, requestCodeCreateFile)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == requestCodeCreateFile) {
            val result = pendingResult
            val content = pendingContent
            pendingResult = null
            pendingContent = null

            if (resultCode == Activity.RESULT_OK) {
                val uri: Uri? = data?.data
                if (uri != null && content != null) {
                    try {
                        contentResolver.openOutputStream(uri)?.use { stream ->
                            stream.write(content.toByteArray(Charsets.UTF_8))
                        }
                        result?.success(true)
                    } catch (e: Exception) {
                        result?.error("WRITE_ERROR", e.message, null)
                    }
                } else {
                    result?.success(false)
                }
            } else {
                result?.success(false)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
