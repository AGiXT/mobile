package dev.agixt.agixt

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger
import java.util.Locale

/**
 * Handles wake word detection using Android's SpeechRecognizer
 * Listens for "computer" keyword to trigger voice input
 */
class WakeWordHandler(
    private val context: Context,
    private val binaryMessenger: BinaryMessenger
) {
    private val TAG = "WakeWordHandler"
    private val CHANNEL = "dev.agixt.agixt/wake_word"
    
    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private var isPaused = false
    private var wakeWord = "computer"
    private var sensitivity = 0.5f
    private lateinit var methodChannel: MethodChannel
    
    fun initialize() {
        methodChannel = MethodChannel(binaryMessenger, CHANNEL)
        
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val word = call.argument<String>("wakeWord") ?: "computer"
                    val sens = call.argument<Double>("sensitivity")?.toFloat() ?: 0.5f
                    wakeWord = word.lowercase()
                    sensitivity = sens
                    setupSpeechRecognizer()
                    result.success(true)
                }
                "startListening" -> {
                    startListening()
                    result.success(true)
                }
                "stopListening" -> {
                    stopListening()
                    result.success(true)
                }
                "pause" -> {
                    pause()
                    result.success(true)
                }
                "resume" -> {
                    resume()
                    result.success(true)
                }
                "setWakeWord" -> {
                    wakeWord = (call.argument<String>("wakeWord") ?: "computer").lowercase()
                    result.success(true)
                }
                "setSensitivity" -> {
                    sensitivity = call.argument<Double>("sensitivity")?.toFloat() ?: 0.5f
                    result.success(true)
                }
                "isAvailable" -> {
                    result.success(SpeechRecognizer.isRecognitionAvailable(context))
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun setupSpeechRecognizer() {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            Log.e(TAG, "Speech recognition not available on this device")
            return
        }
        
        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
        
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                Log.d(TAG, "Ready for speech")
            }
            
            override fun onBeginningOfSpeech() {
                Log.d(TAG, "Beginning of speech")
            }
            
            override fun onRmsChanged(rmsdB: Float) {
                // Audio level changed - could be used for UI feedback
            }
            
            override fun onBufferReceived(buffer: ByteArray?) {
                // Not typically used
            }
            
            override fun onEndOfSpeech() {
                Log.d(TAG, "End of speech")
            }
            
            override fun onError(error: Int) {
                val errorMessage = when (error) {
                    SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
                    SpeechRecognizer.ERROR_CLIENT -> "Client side error"
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
                    SpeechRecognizer.ERROR_NETWORK -> "Network error"
                    SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
                    SpeechRecognizer.ERROR_NO_MATCH -> "No match found"
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognizer busy"
                    SpeechRecognizer.ERROR_SERVER -> "Server error"
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Speech timeout"
                    else -> "Unknown error"
                }
                Log.d(TAG, "Error: $errorMessage ($error)")
                
                // Restart listening if still enabled and not paused
                if (isListening && !isPaused && error != SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) {
                    // Small delay before restarting to avoid rapid cycling
                    android.os.Handler(context.mainLooper).postDelayed({
                        if (isListening && !isPaused) {
                            startRecognition()
                        }
                    }, 500)
                }
            }
            
            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val confidences = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
                
                Log.d(TAG, "Results: $matches")
                
                if (matches != null) {
                    for ((index, match) in matches.withIndex()) {
                        val confidence = confidences?.getOrNull(index) ?: 0.5f
                        val matchLower = match.lowercase()
                        
                        // Check if wake word is detected with sufficient confidence
                        // Adjust threshold based on sensitivity setting
                        val threshold = 1.0f - sensitivity
                        
                        if (matchLower.contains(wakeWord) && confidence >= threshold) {
                            Log.i(TAG, "Wake word '$wakeWord' detected! Confidence: $confidence")
                            
                            // Notify Flutter
                            methodChannel.invokeMethod("onWakeWordDetected", mapOf(
                                "wakeWord" to wakeWord,
                                "confidence" to confidence.toDouble(),
                                "transcript" to match
                            ))
                            
                            // Pause listening while user is speaking
                            pause()
                            return
                        }
                    }
                }
                
                // Continue listening if wake word wasn't detected
                if (isListening && !isPaused) {
                    startRecognition()
                }
            }
            
            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                
                if (matches != null) {
                    for (match in matches) {
                        val matchLower = match.lowercase()
                        if (matchLower.contains(wakeWord)) {
                            Log.d(TAG, "Partial wake word detection: $match")
                            // Could send partial detection event if needed
                        }
                    }
                }
            }
            
            override fun onEvent(eventType: Int, params: Bundle?) {
                Log.d(TAG, "Event: $eventType")
            }
        })
    }
    
    private fun startListening() {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            Log.e(TAG, "Speech recognition not available")
            return
        }
        
        isListening = true
        isPaused = false
        startRecognition()
    }
    
    private fun startRecognition() {
        if (speechRecognizer == null) {
            setupSpeechRecognizer()
        }
        
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            // Shorter silence timeouts for wake word detection
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1000)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1500)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1000)
        }
        
        try {
            speechRecognizer?.startListening(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting recognition: ${e.message}")
        }
    }
    
    private fun stopListening() {
        isListening = false
        isPaused = false
        speechRecognizer?.stopListening()
        speechRecognizer?.cancel()
    }
    
    private fun pause() {
        isPaused = true
        speechRecognizer?.stopListening()
        speechRecognizer?.cancel()
    }
    
    private fun resume() {
        if (isListening) {
            isPaused = false
            startRecognition()
        }
    }
    
    fun destroy() {
        stopListening()
        speechRecognizer?.destroy()
        speechRecognizer = null
    }
}
