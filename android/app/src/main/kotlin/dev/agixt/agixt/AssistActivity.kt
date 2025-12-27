package dev.agixt.agixt

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log

/**
 * Activity that handles digital assistant intents.
 * This activity is launched when:
 * - User selects AGiXT as the default digital assistant
 * - User long-presses the home button
 * - User triggers the assistant via voice ("Hey Google" replacement)
 * - User triggers assist from search key
 */
class AssistActivity : Activity() {
    
    companion object {
        private const val TAG = "AssistActivity"
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "AssistActivity launched with action: ${intent?.action}")
        
        // Handle the assistant intent
        handleAssistIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        intent?.let { handleAssistIntent(it) }
    }
    
    private fun handleAssistIntent(intent: Intent) {
        val action = intent.action
        Log.d(TAG, "Handling assist intent: $action")
        
        // Create intent to launch MainActivity with voice input flag
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            // Preserve the original action for MainActivity to handle
            putExtra("assist_action", action)
            putExtra("start_voice_input", true)
            
            // Pass along any query text if available
            intent.getStringExtra(Intent.EXTRA_ASSIST_CONTEXT)?.let {
                putExtra("assist_context", it)
            }
            
            // Pass the referrer if available
            intent.getStringExtra(Intent.EXTRA_REFERRER)?.let {
                putExtra("assist_referrer", it)
            }
            
            // Handle voice-specific intents
            when (action) {
                Intent.ACTION_VOICE_COMMAND,
                Intent.ACTION_ASSIST,
                "android.intent.action.VOICE_ASSIST" -> {
                    putExtra("voice_mode", true)
                }
                Intent.ACTION_SEARCH_LONG_PRESS -> {
                    putExtra("from_long_press", true)
                    putExtra("voice_mode", true)
                }
            }
            
            // Clear task flags to ensure clean launch
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        
        startActivity(mainIntent)
        
        // Finish this activity so it doesn't stay in the back stack
        finish()
    }
}
