package dev.agixt.agixt

import android.content.Intent
import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * WearableListenerService that receives messages from the Wear OS app.
 * This service runs even when the app is in the background, ensuring
 * voice commands from the watch are always received.
 */
class WearableMessageService : WearableListenerService() {
    
    companion object {
        private const val TAG = "WearableMessageService"
        
        // Message paths - must match the Wear OS app
        const val PATH_VOICE_INPUT = "/voice_input"
        const val PATH_VOICE_COMMAND = "/voice_command"
        const val PATH_AUDIO_DATA = "/audio_data"
        const val PATH_CONNECTION_STATUS = "/connection_status"
        
        // Broadcast actions for local communication
        const val ACTION_VOICE_INPUT = "dev.agixt.agixt.VOICE_INPUT"
        const val EXTRA_TEXT = "text"
        const val EXTRA_NODE_ID = "node_id"
    }
    
    override fun onMessageReceived(messageEvent: MessageEvent) {
        super.onMessageReceived(messageEvent)
        
        Log.d(TAG, "Message received from watch: ${messageEvent.path}")
        
        when (messageEvent.path) {
            PATH_VOICE_INPUT -> handleVoiceInput(messageEvent)
            PATH_VOICE_COMMAND -> handleVoiceCommand(messageEvent)
            PATH_AUDIO_DATA -> handleAudioData(messageEvent)
            PATH_CONNECTION_STATUS -> handleConnectionStatus(messageEvent)
            else -> Log.w(TAG, "Unknown message path: ${messageEvent.path}")
        }
    }
    
    private fun handleVoiceInput(messageEvent: MessageEvent) {
        val text = String(messageEvent.data, Charsets.UTF_8)
        val nodeId = messageEvent.sourceNodeId
        
        Log.d(TAG, "Voice input from watch ($nodeId): $text")
        
        // Broadcast to the app (WatchHandler will pick this up if running)
        val intent = Intent(ACTION_VOICE_INPUT).apply {
            putExtra(EXTRA_TEXT, text)
            putExtra(EXTRA_NODE_ID, nodeId)
            setPackage(packageName)
        }
        sendBroadcast(intent)
        
        // Also try to launch the main activity if app is not running
        // This ensures the voice input gets processed
        try {
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra(EXTRA_TEXT, text)
                putExtra(EXTRA_NODE_ID, nodeId)
                action = ACTION_VOICE_INPUT
            }
            startActivity(launchIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch activity for voice input", e)
        }
    }
    
    private fun handleVoiceCommand(messageEvent: MessageEvent) {
        // Legacy voice command handling
        val transcription = String(messageEvent.data, Charsets.UTF_8)
        Log.d(TAG, "Voice command from watch: $transcription")
        
        val intent = Intent(ACTION_VOICE_INPUT).apply {
            putExtra(EXTRA_TEXT, transcription)
            putExtra(EXTRA_NODE_ID, messageEvent.sourceNodeId)
            setPackage(packageName)
        }
        sendBroadcast(intent)
    }
    
    private fun handleAudioData(messageEvent: MessageEvent) {
        Log.d(TAG, "Audio data received: ${messageEvent.data.size} bytes")
        // Audio data handling would go here if needed
    }
    
    private fun handleConnectionStatus(messageEvent: MessageEvent) {
        val status = String(messageEvent.data, Charsets.UTF_8)
        Log.d(TAG, "Connection status from watch: $status")
    }
}
