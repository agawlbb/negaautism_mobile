package org.negaautism.mobileapp

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private var exportResult: MethodChannel.Result? = null
    private var exportBytes: ByteArray? = null
    private val exportRequest = 6201

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.negaautism.mobileapp/documents")
            .setMethodCallHandler { call, result ->
                if (call.method != "savePdf") { result.notImplemented(); return@setMethodCallHandler }
                if (exportResult != null) { result.error("busy", "A document export is already open.", null); return@setMethodCallHandler }
                val bytes = call.argument<ByteArray>("bytes")
                val filename = call.argument<String>("filename")
                if (bytes == null || bytes.size < 5 || bytes.size > 15 * 1024 * 1024 ||
                    String(bytes.copyOfRange(0, 5), Charsets.US_ASCII) != "%PDF-" ||
                    filename == null || !Regex("^[a-zA-Z0-9_-]+\\.pdf$").matches(filename)) {
                    result.error("invalid", "The PDF could not be exported.", null); return@setMethodCallHandler
                }
                exportResult = result
                exportBytes = bytes
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_TITLE, filename)
                    }
                    startActivityForResult(intent, exportRequest)
                } catch (error: Exception) {
                    exportResult = null; exportBytes = null
                    result.error("unavailable", "A document location could not be opened.", null)
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != exportRequest) return
        val result = exportResult ?: return
        val bytes = exportBytes
        exportResult = null; exportBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) { result.success(false); return }
        Thread {
            try {
                val stream = contentResolver.openOutputStream(uri, "w") ?: throw IllegalStateException()
                stream.use { it.write(bytes) }
                runOnUiThread { result.success(true) }
            } catch (error: Exception) {
                runOnUiThread { result.error("write_failed", "The PDF could not be saved. Choose another location.", null) }
            }
        }.start()
    }
}
