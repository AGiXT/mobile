package dev.agixt.wear

import android.content.Intent
import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Service that listens for messages from the phone app via the Wearable Data Layer API.
 * This receives chat responses and status updates from the phone.
 */
class DataLayerListenerService : WearableListenerService() {
    
    companion object {
        private const val TAG = "DataLayerListener"
        
        // Message paths - must match the phone app
        const val PATH_CHAT_RESPONSE = "/chat_response"
        const val PATH_STATUS = "/status"
        const val PATH_VOICE_INPUT = "/voice_input"
        const val PATH_TTS_COMPLETE = "/tts_complete"
        const val PATH_ERROR = "/error"
        
        // Broadcast actions for local communication
        const val ACTION_CHAT_RESPONSE = "dev.agixt.wear.CHAT_RESPONSE"
        const val ACTION_STATUS_UPDATE = "dev.agixt.wear.STATUS_UPDATE"
        const val ACTION_ERROR = "dev.agixt.wear.ERROR"
        
        const val EXTRA_RESPONSE_TEXT = "response_text"
        const val EXTRA_STATUS = "status"
        const val EXTRA_ERROR_MESSAGE = "error_message"
    }
    
    override fun onMessageReceived(messageEvent: MessageEvent) {
        super.onMessageReceived(messageEvent)
        
        Log.d(TAG, "Message received: ${messageEvent.path}")
        
        when (messageEvent.path) {
            PATH_CHAT_RESPONSE -> handleChatResponse(messageEvent)
            PATH_STATUS -> handleStatusUpdate(messageEvent)
            PATH_TTS_COMPLETE -> handleTtsComplete(messageEvent)
            PATH_ERROR -> handleError(messageEvent)
            else -> Log.w(TAG, "Unknown message path: ${messageEvent.path}")
        }
    }
    
    private fun handleChatResponse(messageEvent: MessageEvent) {
        val responseText = String(messageEvent.data, Charsets.UTF_8)
        Log.d(TAG, "Chat response received: ${responseText.take(100)}...")
        
        // Broadcast to the activity
        val intent = Intent(ACTION_CHAT_RESPONSE).apply {
            putExtra(EXTRA_RESPONSE_TEXT, responseText)
            setPackage(packageName)
        }
        sendBroadcast(intent)
    }
    
    private fun handleStatusUpdate(messageEvent: MessageEvent) {
        val status = String(messageEvent.data, Charsets.UTF_8)
        Log.d(TAG, "Status update: $status")
        
        val intent = Intent(ACTION_STATUS_UPDATE).apply {
            putExtra(EXTRA_STATUS, status)
            setPackage(packageName)
        }
        sendBroadcast(intent)
    }
    
    private fun handleTtsComplete(messageEvent: MessageEvent) {
        Log.d(TAG, "TTS complete notification received")
        // Could trigger vibration or UI update to indicate TTS finished on phone
    }
    
    private fun handleError(messageEvent: MessageEvent) {
        val errorMessage = String(messageEvent.data, Charsets.UTF_8)
        Log.e(TAG, "Error from phone: $errorMessage")
        
        val intent = Intent(ACTION_ERROR).apply {
            putExtra(EXTRA_ERROR_MESSAGE, errorMessage)
            setPackage(packageName)
        }
        sendBroadcast(intent)
    }
}
