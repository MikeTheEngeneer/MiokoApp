package com.miketheengeneer.miokoapp

import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Только в отладочной сборке (flutter run): экран не гаснет, пока
        // приложение открыто, — телефон не блокируется и отладка не отваливается.
        // В релизе флага debuggable нет, и экран гаснет как обычно.
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}
