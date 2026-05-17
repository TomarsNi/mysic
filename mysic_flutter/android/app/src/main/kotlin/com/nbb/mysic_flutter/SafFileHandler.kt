package com.nbb.mysic_flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// SAF (Storage Access Framework) 文件读取服务
/// 用于读取需要 SAF 授权的文件
class SafFileHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "SafFileHandler"
        private const val CHANNEL_NAME = "com.nbb.mysic_flutter/saf_file"
        private const val REQUEST_CODE_PICK_DIRECTORY = 1001

        /// 注册到 FlutterEngine，返回实例以便 MainActivity 可以调用 onActivityResult
        fun register(flutterEngine: FlutterEngine, context: Context): SafFileHandler {
            val handler = SafFileHandler(context)
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            channel.setMethodCallHandler(handler)
            return handler
        }
    }

    private var pendingResult: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickDirectory" -> handlePickDirectory(result)
            "readFile" -> handleReadFile(call, result)
            "readFileFromTree" -> handleReadFileFromTree(call, result)
            "persistUriPermission" -> handlePersistUriPermission(call, result)
            "releaseUriPermission" -> handleReleaseUriPermission(call, result)
            "hasUriPermission" -> handleHasUriPermission(call, result)
            else -> result.notImplemented()
        }
    }

    /// 打开 SAF 目录选择器
    private fun handlePickDirectory(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            result.error("UNSUPPORTED", "SAF requires Android 5.0+", null)
            return
        }

        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            }

            // 保存 result 以便在 onActivityResult 中使用
            pendingResult = result

            // 需要通过 Activity 启动
            if (context is Activity) {
                context.startActivityForResult(intent, REQUEST_CODE_PICK_DIRECTORY)
            } else {
                // 如果 context 不是 Activity，尝试从当前 Activity 获取
                val activity = context as? Activity
                if (activity != null) {
                    activity.startActivityForResult(intent, REQUEST_CODE_PICK_DIRECTORY)
                } else {
                    result.error("ERROR", "Cannot start activity for result", null)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "打开目录选择器失败", e)
            result.error("ERROR", e.message, null)
        }
    }

    /// 处理 Activity 结果（需要在 MainActivity 中调用）
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_CODE_PICK_DIRECTORY) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                pendingResult?.success(uri.toString())
            } else {
                pendingResult?.success(null)
            }
            pendingResult = null
        }
    }

    /// 读取 SAF URI 指向的文件
    private fun handleReadFile(call: MethodCall, result: MethodChannel.Result) {
        val uriString = call.argument<String>("uri")
        if (uriString == null) {
            result.error("INVALID_ARGUMENT", "URI is required", null)
            return
        }

        try {
            val uri = Uri.parse(uriString)
            val bytes = context.contentResolver.openInputStream(uri)?.use { inputStream ->
                inputStream.readBytes()
            }

            if (bytes != null) {
                Log.d(TAG, "成功读取文件: $uriString, 大小: ${bytes.size}")
                result.success(bytes)
            } else {
                Log.e(TAG, "无法打开文件流: $uriString")
                result.error("READ_ERROR", "Cannot open file stream", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "读取文件失败: $uriString", e)
            result.error("READ_ERROR", e.message, null)
        }
    }

    /// 从 SAF 树 URI 和相对路径读取文件
    private fun handleReadFileFromTree(call: MethodCall, result: MethodChannel.Result) {
        val treeUriString = call.argument<String>("treeUri")
        val relativePath = call.argument<String>("relativePath")

        if (treeUriString == null || relativePath == null) {
            result.error("INVALID_ARGUMENT", "treeUri and relativePath are required", null)
            return
        }

        try {
            val treeUri = Uri.parse(treeUriString)
            val fileUri = findFileInTree(treeUri, relativePath)

            if (fileUri == null) {
                Log.e(TAG, "文件不存在: $relativePath")
                result.error("FILE_NOT_FOUND", "File not found: $relativePath", null)
                return
            }

            val bytes = context.contentResolver.openInputStream(fileUri)?.use { inputStream ->
                inputStream.readBytes()
            }

            if (bytes != null) {
                Log.d(TAG, "成功从树读取文件: $relativePath, 大小: ${bytes.size}")
                result.success(bytes)
            } else {
                Log.e(TAG, "无法打开文件流: $relativePath")
                result.error("READ_ERROR", "Cannot open file stream", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "从树读取文件失败: $relativePath", e)
            result.error("READ_ERROR", e.message, null)
        }
    }

    /// 在 SAF 树中查找文件
    private fun findFileInTree(treeUri: Uri, relativePath: String): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return null
        }

        try {
            // relativePath 只是文件名，直接在树根目录查找
            val fileName = relativePath
            Log.d(TAG, "查找文件: fileName=$fileName, treeUri=$treeUri")

            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
                treeUri,
                DocumentsContract.getTreeDocumentId(treeUri)
            )

            val projection = arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME
            )

            // 遍历所有子文档，精确匹配文件名
            context.contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
                val idIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                val nameIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)

                Log.d(TAG, "查询到 ${cursor.count} 个文档")

                while (cursor.moveToNext()) {
                    val docId = cursor.getString(idIndex)
                    val docName = cursor.getString(nameIndex)
                    Log.d(TAG, "文档: id=$docId, name=$docName")

                    // 精确匹配文件名
                    if (docName == fileName) {
                        val fileUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
                        Log.d(TAG, "找到匹配文件: $fileName -> $fileUri")
                        return fileUri
                    }
                }
            }

            Log.d(TAG, "文件未找到: $fileName")
            return null
        } catch (e: Exception) {
            Log.e(TAG, "查找文件失败: $relativePath", e)
            return null
        }
    }

    /// 持久化 URI 权限
    private fun handlePersistUriPermission(call: MethodCall, result: MethodChannel.Result) {
        val uriString = call.argument<String>("uri")
        if (uriString == null) {
            result.error("INVALID_ARGUMENT", "URI is required", null)
            return
        }

        try {
            val uri = Uri.parse(uriString)

            context.contentResolver.takePersistableUriPermission(uri, android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)

            Log.d(TAG, "已持久化 URI 权限: $uriString")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "持久化 URI 权限失败: $uriString", e)
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }

    /// 释放 URI 权限
    private fun handleReleaseUriPermission(call: MethodCall, result: MethodChannel.Result) {
        val uriString = call.argument<String>("uri")
        if (uriString == null) {
            result.error("INVALID_ARGUMENT", "URI is required", null)
            return
        }

        try {
            val uri = Uri.parse(uriString)
            context.contentResolver.releasePersistableUriPermission(
                uri,
                android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
            )

            Log.d(TAG, "已释放 URI 权限: $uriString")
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "释放 URI 权限失败: $uriString", e)
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }

    /// 检查是否有 URI 权限
    private fun handleHasUriPermission(call: MethodCall, result: MethodChannel.Result) {
        val uriString = call.argument<String>("uri")
        if (uriString == null) {
            result.error("INVALID_ARGUMENT", "URI is required", null)
            return
        }

        try {
            val uri = Uri.parse(uriString)
            val permissions = context.contentResolver.persistedUriPermissions

            val hasPermission = permissions.any {
                it.uri == uri && it.isReadPermission
            }

            Log.d(TAG, "检查 URI 权限: $uriString, 结果: $hasPermission")
            result.success(hasPermission)
        } catch (e: Exception) {
            Log.e(TAG, "检查 URI 权限失败: $uriString", e)
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }
}
