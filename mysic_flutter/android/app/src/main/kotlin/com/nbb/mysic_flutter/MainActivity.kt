package com.nbb.mysic_flutter

import android.content.Intent
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceFragmentActivity() {
    private var safFileHandler: SafFileHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 注册 SAF 文件处理器
        safFileHandler = SafFileHandler.register(flutterEngine, this)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        // 将结果传递给 SafFileHandler
        safFileHandler?.onActivityResult(requestCode, resultCode, data)
    }
}
