package dev.agixt.wear

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.speech.RecognizerIntent
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.NodeClient
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.*
import kotlinx.coroutines.tasks.await

/**
 * Activity that handles voice input using Android's built-in speech recognizer.
 * This is launched when the user taps the voice input button or says the wake word.
 */
class VoiceInputActivity : ComponentActivity() {
    
    companion object {
        private const val TAG = "VoiceInputActivity"
        const val EXTRA_PROMPT = "extra_prompt"
        private const val PATH_VOICE_INPUT = "/voice_input"
    }
    
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private lateinit var messageClient: MessageClient
    private lateinit var nodeClient: NodeClient
    
    private val speechRecognizerLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val spokenText = result.data
                ?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                ?.firstOrNull()
            
            if (!spokenText.isNullOrBlank()) {
                Log.d(TAG, "Recognized text: $spokenText")
                // Send to phone
                sendToPhone(spokenText)
            } else {
                Log.w(TAG, "No speech recognized")
                finish()
            }
        } else {
            Log.w(TAG, "Speech recognition cancelled or failed: ${result.resultCode}")
            finish()
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        messageClient = Wearable.getMessageClient(this)
        nodeClient = Wearable.getNodeClient(this)
        
        // Get optional prompt from intent
        val prompt = intent.getStringExtra(EXTRA_PROMPT) ?: getString(R.string.voice_prompt)
        
        // Launch the speech recognizer
        launchSpeechRecognizer(prompt)
    }
    
    private fun launchSpeechRecognizer(prompt: String) {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            // Enable hands-free auto-send - critical for skipping the checkmark
            putExtra("android.speech.extra.DICTATION_MODE", true)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false) // Disable partial to avoid multiple callbacks
            // Shorter silence timeout for faster response
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1500L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 500L)
            // Wear-specific: prefer offline recognition for speed
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            // Calling package helps with context
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
        }
        
        try {
            Log.d(TAG, "Launching speech recognizer with auto-send")
            speechRecognizerLauncher.launch(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Speech recognizer not available", e)
            finish()
        }
    }
    
    private fun sendToPhone(text: String) {
        scope.launch {
            try {
                val nodes = nodeClient.connectedNodes.await()
                Log.d(TAG, "Found ${nodes.size} connected nodes")
                
                if (nodes.isEmpty()) {
                    Log.w(TAG, "No connected nodes")
                    finish()
                    return@launch
                }
                
                for (node in nodes) {
                    try {
                        messageClient.sendMessage(
                            node.id,
                            PATH_VOICE_INPUT,
                            text.toByteArray(Charsets.UTF_8)
                        ).await()
                        Log.d(TAG, "Message sent to ${node.displayName}")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to send to ${node.displayName}", e)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error sending message", e)
            } finally {
                finish()
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }
}
