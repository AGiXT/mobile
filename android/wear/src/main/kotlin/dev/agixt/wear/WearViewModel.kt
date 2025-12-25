package dev.agixt.wear

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.google.android.gms.wearable.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

sealed class WearUiState {
    object Idle : WearUiState()
    object Listening : WearUiState()
    object Processing : WearUiState()
    data class Response(val text: String) : WearUiState()
    data class Error(val message: String) : WearUiState()
}

class WearViewModel(application: Application) : AndroidViewModel(application) {
    
    companion object {
        private const val TAG = "WearViewModel"
        private const val VOICE_INPUT_PATH = "/voice_input"
        private const val CHAT_RESPONSE_PATH = "/chat_response"
        private const val STATUS_PATH = "/status"
    }
    
    private val _uiState = MutableStateFlow<WearUiState>(WearUiState.Idle)
    val uiState: StateFlow<WearUiState> = _uiState.asStateFlow()
    
    private val _messages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val messages: StateFlow<List<ChatMessage>> = _messages.asStateFlow()
    
    private val _isPhoneConnected = MutableStateFlow(false)
    val isPhoneConnected: StateFlow<Boolean> = _isPhoneConnected.asStateFlow()
    
    private val messageClient: MessageClient = Wearable.getMessageClient(application)
    private val nodeClient: NodeClient = Wearable.getNodeClient(application)
    private val capabilityClient: CapabilityClient = Wearable.getCapabilityClient(application)
    
    init {
        checkPhoneConnection()
    }
    
    private fun checkPhoneConnection() {
        viewModelScope.launch {
            try {
                val nodes = nodeClient.connectedNodes.await()
                _isPhoneConnected.value = nodes.isNotEmpty()
                Log.d(TAG, "Connected nodes: ${nodes.size}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to check phone connection", e)
                _isPhoneConnected.value = false
            }
        }
    }
    
    fun startVoiceInput() {
        _uiState.value = WearUiState.Listening
        // The actual voice input is triggered via VoiceInputActivity
        // This is called when user taps the mic button
        viewModelScope.launch {
            try {
                // We'll use the Android speech recognizer intent
                // This triggers the voice input activity
            } catch (e: Exception) {
                _uiState.value = WearUiState.Error("Voice input failed")
            }
        }
    }
    
    fun onVoiceInput(text: String) {
        viewModelScope.launch {
            _uiState.value = WearUiState.Processing
            
            // Add user message to list
            val userMessage = ChatMessage(text = text, isUser = true)
            _messages.value = _messages.value + userMessage
            
            // Send to phone for processing
            try {
                val result = sendMessageToPhone(text)
                if (result) {
                    // Response will come back via DataLayerListenerService
                    Log.d(TAG, "Message sent to phone successfully")
                } else {
                    _uiState.value = WearUiState.Error("Phone not connected")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send message to phone", e)
                _uiState.value = WearUiState.Error("Failed to connect to phone")
            }
        }
    }
    
    fun onResponseReceived(response: String) {
        viewModelScope.launch {
            // Add AI response to messages
            val aiMessage = ChatMessage(text = response, isUser = false)
            _messages.value = _messages.value + aiMessage
            
            _uiState.value = WearUiState.Response(response)
        }
    }
    
    fun dismiss() {
        _uiState.value = WearUiState.Idle
    }
    
    fun setListening() {
        _uiState.value = WearUiState.Listening
    }
    
    fun setError(message: String) {
        _uiState.value = WearUiState.Error(message)
    }
    
    private suspend fun sendMessageToPhone(text: String): Boolean {
        return try {
            val nodes = nodeClient.connectedNodes.await()
            if (nodes.isEmpty()) {
                Log.w(TAG, "No connected nodes found")
                return false
            }
            
            // Send to all connected nodes (typically just the phone)
            var sent = false
            for (node in nodes) {
                try {
                    messageClient.sendMessage(
                        node.id,
                        VOICE_INPUT_PATH,
                        text.toByteArray(Charsets.UTF_8)
                    ).await()
                    Log.d(TAG, "Message sent to node: ${node.displayName}")
                    sent = true
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to send to node ${node.displayName}", e)
                }
            }
            sent
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get connected nodes", e)
            false
        }
    }
    
    suspend fun getConnectedPhoneNode(): Node? {
        return try {
            val nodes = nodeClient.connectedNodes.await()
            nodes.firstOrNull { it.isNearby }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get phone node", e)
            null
        }
    }
}
