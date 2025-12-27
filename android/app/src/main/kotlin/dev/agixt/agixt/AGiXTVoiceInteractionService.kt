package dev.agixt.agixt

import android.os.Bundle
import android.service.voice.VoiceInteractionService
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService
import android.util.Log
import android.content.Intent

/**
 * VoiceInteractionService implementation for AGiXT.
 * This service enables AGiXT to be selected as the default digital assistant.
 * 
 * When enabled as the default assistant, this service handles:
 * - Long-press home button
 * - "Hey Google" replacement (if configured)
 * - Assistant hardware button (on some devices)
 * - Swipe from corner gestures (Android 10+)
 */
class AGiXTVoiceInteractionService : VoiceInteractionService() {
    
    companion object {
        private const val TAG = "AGiXTVoiceService"
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "AGiXT Voice Interaction Service created")
    }
    
    override fun onReady() {
        super.onReady()
        Log.d(TAG, "AGiXT Voice Interaction Service ready")
    }
    
    override fun onShutdown() {
        Log.d(TAG, "AGiXT Voice Interaction Service shutdown")
        super.onShutdown()
    }
}

/**
 * Session service that creates voice interaction sessions.
 */
class AGiXTVoiceInteractionSessionService : VoiceInteractionSessionService() {
    
    companion object {
        private const val TAG = "AGiXTVoiceSession"
    }
    
    override fun onNewSession(args: Bundle?): VoiceInteractionSession {
        Log.d(TAG, "Creating new voice interaction session")
        return AGiXTVoiceInteractionSession(this)
    }
}

/**
 * The actual voice interaction session that handles user interactions.
 */
class AGiXTVoiceInteractionSession(context: android.content.Context) : VoiceInteractionSession(context) {
    
    companion object {
        private const val TAG = "AGiXTSession"
    }
    
    override fun onShow(args: Bundle?, showFlags: Int) {
        super.onShow(args, showFlags)
        Log.d(TAG, "Voice interaction session shown, flags: $showFlags")
        
        // Launch the main app with voice input mode
        val intent = Intent(context, MainActivity::class.java).apply {
            putExtra("start_voice_input", true)
            putExtra("voice_mode", true)
            putExtra("from_assistant", true)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        context.startActivity(intent)
        
        // Hide the session UI since we're using our own app UI
        hide()
    }
    
    override fun onHide() {
        Log.d(TAG, "Voice interaction session hidden")
        super.onHide()
    }
    
    override fun onHandleAssist(state: AssistState) {
        super.onHandleAssist(state)
        Log.d(TAG, "Handling assist request")
        
        // Launch MainActivity with assist mode
        val intent = Intent(context, MainActivity::class.java).apply {
            putExtra("start_voice_input", true)
            putExtra("voice_mode", true)
            putExtra("from_assistant", true)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        context.startActivity(intent)
        hide()
    }
}
