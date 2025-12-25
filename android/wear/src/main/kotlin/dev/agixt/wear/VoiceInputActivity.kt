package dev.agixt.wear

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.speech.RecognizerIntent
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.lifecycle.ViewModelProvider

/**
 * Activity that handles voice input using Android's built-in speech recognizer.
 * This is launched when the user taps the voice input button or says the wake word.
 */
class VoiceInputActivity : ComponentActivity() {
    
    companion object {
        private const val TAG = "VoiceInputActivity"
        const val EXTRA_PROMPT = "extra_prompt"
    }
    
    private lateinit var viewModel: WearViewModel
    
    private val speechRecognizerLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val spokenText = result.data
                ?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                ?.firstOrNull()
            
            if (!spokenText.isNullOrBlank()) {
                Log.d(TAG, "Recognized text: $spokenText")
                viewModel.onVoiceInput(spokenText)
            } else {
                Log.w(TAG, "No speech recognized")
                viewModel.setError("No speech recognized")
            }
        } else {
            Log.w(TAG, "Speech recognition cancelled or failed: ${result.resultCode}")
            viewModel.dismiss()
        }
        finish()
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        viewModel = ViewModelProvider(this)[WearViewModel::class.java]
        
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
            // Use partial results for faster response
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        }
        
        try {
            speechRecognizerLauncher.launch(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Speech recognizer not available", e)
            viewModel.setError("Speech recognition not available")
            finish()
        }
    }
}
