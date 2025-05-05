package com.healthcare.healthcare

import android.content.Intent
import android.speech.RecognizerIntent
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.ArrayList

class MainActivity : FlutterActivity() {
    private val CHANNEL = "speech_to_text_channel"
    private val SPEECH_REQUEST_CODE = 100

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startSpeechRecognition") {
                startSpeechRecognition(result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun startSpeechRecognition(result: MethodChannel.Result) {
        speechRecognitionResult = result
        
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Speak now")
        }

        try {
            startActivityForResult(intent, SPEECH_REQUEST_CODE)
        } catch (e: Exception) {
            result.error("SPEECH_RECOGNITION_ERROR", e.message, null)
            speechRecognitionResult = null
        }
    }

    private var speechRecognitionResult: MethodChannel.Result? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == SPEECH_REQUEST_CODE && resultCode == RESULT_OK) {
            val results = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
            val spokenText = results?.get(0) ?: ""
            
            speechRecognitionResult?.success(spokenText)
            speechRecognitionResult = null
        } else if (requestCode == SPEECH_REQUEST_CODE) {
            speechRecognitionResult?.error("SPEECH_RECOGNITION_CANCELLED", "Speech recognition cancelled or failed", null)
            speechRecognitionResult = null
        }
    }
} 