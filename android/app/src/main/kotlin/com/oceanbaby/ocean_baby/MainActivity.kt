package com.oceanbaby.ocean_baby

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ocean_baby/notifications"
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    OceanBabyNotificationListener.setSink(this@MainActivity, events)
                }

                override fun onCancel(arguments: Any?) {
                    OceanBabyNotificationListener.clearSink()
                }
            }
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ocean_baby/notification_permission"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isEnabled" -> result.success(isNotificationListenerEnabled())
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ocean_baby/file_picker"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFile" -> pickFile(call.arguments as? Map<*, *>, result)
                "pickImages" -> pickImages(call.arguments as? Map<*, *>, result)
                "saveFile" -> saveFile(call.arguments as? Map<*, *>, result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ocean_baby/app_directories"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getApplicationSupportDirectory" -> result.success(filesDir.absolutePath)
                "getApplicationDocumentsDirectory" -> {
                    val directory = File(filesDir, "documents")
                    if (!directory.exists()) {
                        directory.mkdirs()
                    }
                    result.success(directory.absolutePath)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Uses the platform document picker result callback.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {
            REQUEST_PICK_FILE -> handlePickedFile(resultCode, data)
            REQUEST_PICK_IMAGES -> handlePickedImages(resultCode, data)
            REQUEST_SAVE_FILE -> handleSavedFile(resultCode, data)
            else -> super.onActivityResult(requestCode, resultCode, data)
        }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        val expected = ComponentName(this, OceanBabyNotificationListener::class.java)
        return enabledListeners.split(":").any { flattened ->
            ComponentName.unflattenFromString(flattened) == expected
        }
    }

    private fun pickFile(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("busy", "已有文件选择正在进行", null)
            return
        }
        pendingPickResult = result
        val mimeTypes = (arguments?.get("mimeTypes") as? List<*>)
            ?.filterIsInstance<String>()
            ?.filter { it.isNotBlank() }
            .orEmpty()
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = if (mimeTypes.size == 1) mimeTypes.first() else "*/*"
            if (mimeTypes.size > 1) {
                putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
            }
        }
        startActivityForResult(intent, REQUEST_PICK_FILE)
    }

    private fun pickImages(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("busy", "已有文件选择正在进行", null)
            return
        }
        pendingPickResult = result
        val allowMultiple = arguments?.get("allowMultiple") as? Boolean ?: true
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, allowMultiple)
        }
        startActivityForResult(intent, REQUEST_PICK_IMAGES)
    }

    private fun saveFile(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (pendingSaveResult != null) {
            result.error("busy", "已有文件保存正在进行", null)
            return
        }
        val fileName = arguments?.get("fileName") as? String
        val bytes = arguments?.get("bytes") as? ByteArray
        val mimeType = arguments?.get("mimeType") as? String ?: "application/octet-stream"
        if (fileName.isNullOrBlank() || bytes == null) {
            result.error("invalid_arguments", "缺少文件名或文件内容", null)
            return
        }
        pendingSaveResult = result
        pendingSaveBytes = bytes
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        startActivityForResult(intent, REQUEST_SAVE_FILE)
    }

    private fun handlePickedFile(resultCode: Int, data: Intent?) {
        val result = pendingPickResult ?: return
        pendingPickResult = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }
        val uri = data?.data
        if (uri == null) {
            result.success(null)
            return
        }
        result.success(readPickedFile(uri))
    }

    private fun handlePickedImages(resultCode: Int, data: Intent?) {
        val result = pendingPickResult ?: return
        pendingPickResult = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(emptyList<Map<String, Any>>())
            return
        }
        val files = mutableListOf<Map<String, Any>>()
        val clipData = data?.clipData
        if (clipData != null) {
            for (index in 0 until clipData.itemCount) {
                val uri = clipData.getItemAt(index).uri ?: continue
                files.add(readPickedFile(uri))
            }
        } else {
            data?.data?.let { files.add(readPickedFile(it)) }
        }
        result.success(files)
    }

    private fun handleSavedFile(resultCode: Int, data: Intent?) {
        val result = pendingSaveResult ?: return
        val bytes = pendingSaveBytes
        pendingSaveResult = null
        pendingSaveBytes = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }
        val uri = data?.data
        if (uri == null || bytes == null) {
            result.error("save_failed", "无法保存文件", null)
            return
        }
        runCatching {
            contentResolver.openOutputStream(uri)?.use { output ->
                output.write(bytes)
            } ?: error("Output stream is null")
        }.onSuccess {
            result.success(uri.toString())
        }.onFailure {
            result.error("save_failed", "无法保存文件", it.message)
        }
    }

    private fun readPickedFile(uri: Uri): Map<String, Any> {
        val bytes = contentResolver.openInputStream(uri)?.use { input ->
            input.readBytes()
        } ?: ByteArray(0)
        return mapOf(
            "name" to displayName(uri),
            "bytes" to bytes,
        )
    }

    private fun displayName(uri: Uri): String {
        val cursor = contentResolver.query(
            uri,
            arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )
        cursor?.use {
            val nameIndex = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
            if (nameIndex >= 0 && it.moveToFirst()) {
                return it.getString(nameIndex)
            }
        }
        val extension = MimeTypeMap.getSingleton()
            .getExtensionFromMimeType(contentResolver.getType(uri))
        return if (extension.isNullOrBlank()) "未命名文件" else "未命名文件.$extension"
    }

    companion object {
        private const val REQUEST_PICK_FILE = 1001
        private const val REQUEST_PICK_IMAGES = 1002
        private const val REQUEST_SAVE_FILE = 1003
    }
}
