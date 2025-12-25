package dev.agixt.agixt

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger
import com.google.android.gms.wearable.*
import com.google.android.gms.tasks.Tasks
import kotlinx.coroutines.*

/**
 * Handles Pixel Watch / Wear OS connectivity via the Wearable Data Layer API
 * Provides voice input (mic), TTS output, and message display on the watch
 */
class WatchHandler(
    private val context: Context,
    private val binaryMessenger: BinaryMessenger
) : DataClient.OnDataChangedListener,
    MessageClient.OnMessageReceivedListener,
    CapabilityClient.OnCapabilityChangedListener {
    
    private val TAG = "WatchHandler"
    private val CHANNEL = "dev.agixt.agixt/watch"
    
    // Capability and path constants
    private val AGIXT_WATCH_CAPABILITY = "agixt_watch"
    private val PATH_VOICE_COMMAND = "/voice_command"
    private val PATH_VOICE_INPUT = "/voice_input"  // From Wear OS app
    private val PATH_CHAT_RESPONSE = "/chat_response"  // Response to Wear OS app
    private val PATH_TTS_REQUEST = "/tts_request"
    private val PATH_DISPLAY_MESSAGE = "/display_message"
    private val PATH_START_RECORDING = "/start_recording"
    private val PATH_STOP_RECORDING = "/stop_recording"
    private val PATH_AUDIO_DATA = "/audio_data"
    private val PATH_CONNECTION_STATUS = "/connection_status"
    private val PATH_ERROR = "/error"
    
    private lateinit var methodChannel: MethodChannel
    private var connectedNodeId: String? = null
    private var connectedNodeName: String? = null
    private var isConnected = false
    
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    fun initialize() {
        methodChannel = MethodChannel(binaryMessenger, CHANNEL)
        
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    setupWearableConnection()
                    result.success(true)
                }
                "isConnected" -> {
                    result.success(isConnected)
                }
                "isWatchConnected" -> {
                    // Return full connection info for Flutter
                    scope.launch {
                        checkWatchConnection()
                        withContext(Dispatchers.Main) {
                            result.success(mapOf(
                                "connected" to isConnected,
                                "watchId" to connectedNodeId,
                                "watchName" to connectedNodeName
                            ))
                        }
                    }
                }
                "getConnectedWatchName" -> {
                    result.success(connectedNodeName)
                }
                "startRecording" -> {
                    scope.launch {
                        val success = sendMessageToWatch(PATH_START_RECORDING, byteArrayOf())
                        withContext(Dispatchers.Main) {
                            result.success(success)
                        }
                    }
                }
                "stopRecording" -> {
                    scope.launch {
                        val success = sendMessageToWatch(PATH_STOP_RECORDING, byteArrayOf())
                        withContext(Dispatchers.Main) {
                            result.success(success)
                        }
                    }
                }
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    scope.launch {
                        val success = sendMessageToWatch(PATH_TTS_REQUEST, text.toByteArray())
                        withContext(Dispatchers.Main) {
                            result.success(success)
                        }
                    }
                }
                "stopSpeaking" -> {
                    scope.launch {
                        val success = sendMessageToWatch(PATH_TTS_REQUEST, "STOP".toByteArray())
                        withContext(Dispatchers.Main) {
                            result.success(success)
                        }
                    }
                }
                "displayMessage" -> {
                    val message = call.argument<String>("message") ?: ""
                    val duration = call.argument<Int>("duration") ?: 5000
                    val messageData = "$duration|$message"
                    scope.launch {
                        val success = sendMessageToWatch(PATH_DISPLAY_MESSAGE, messageData.toByteArray())
                        withContext(Dispatchers.Main) {
                            result.success(success)
                        }
                    }
                }
                "sendChatResponse" -> {
                    // Send chat response to Wear OS app
                    val response = call.argument<String>("response") ?: ""
                    val nodeId = call.argument<String>("nodeId")
                    scope.launch {
                        val success = if (nodeId != null) {
                            sendMessageToNode(nodeId, PATH_CHAT_RESPONSE, response.toByteArray(Charsets.UTF_8))
                        } else {
                            sendMessageToWatch(PATH_CHAT_RESPONSE, response.toByteArray(Charsets.UTF_8))
                        }
                        withContext(Dispatchers.Main) {
                            result.success(success)
                        }
                    }
                }
                "sendErrorToWatch" -> {
                    // Send error message to Wear OS app
                    val errorMessage = call.argument<String>("message") ?: "An error occurred"
                    val nodeId = call.argument<String>("nodeId")
                    scope.launch {
                        val success = if (nodeId != null) {
                            sendMessageToNode(nodeId, PATH_ERROR, errorMessage.toByteArray(Charsets.UTF_8))
                        } else {
                            sendMessageToWatch(PATH_ERROR, errorMessage.toByteArray(Charsets.UTF_8))
                        }
                        withContext(Dispatchers.Main) {
                            result.success(success)
                        }
                    }
                }
                "checkConnection" -> {
                    scope.launch {
                        checkWatchConnection()
                        withContext(Dispatchers.Main) {
                            result.success(isConnected)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun setupWearableConnection() {
        try {
            // Register listeners
            Wearable.getDataClient(context).addListener(this)
            Wearable.getMessageClient(context).addListener(this)
            Wearable.getCapabilityClient(context).addListener(
                this,
                AGIXT_WATCH_CAPABILITY
            )
            
            // Check for existing connections
            scope.launch {
                checkWatchConnection()
            }
            
            Log.i(TAG, "Wearable connection setup complete")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up wearable connection: ${e.message}")
        }
    }
    
    private suspend fun checkWatchConnection() {
        try {
            // First try capability-based discovery (watches with our app)
            val capabilityInfo = Tasks.await(
                Wearable.getCapabilityClient(context)
                    .getCapability(AGIXT_WATCH_CAPABILITY, CapabilityClient.FILTER_REACHABLE)
            )
            
            updateConnectedNode(capabilityInfo)
            
            if (!isConnected) {
                // Fall back to checking all connected nodes
                val nodes = Tasks.await(Wearable.getNodeClient(context).connectedNodes)
                if (nodes.isNotEmpty()) {
                    // Pick the nearest node (or first available)
                    val node = nodes.firstOrNull { it.isNearby } ?: nodes.first()
                    connectedNodeId = node.id
                    connectedNodeName = node.displayName
                    isConnected = true
                    
                    withContext(Dispatchers.Main) {
                        notifyConnectionStatus(true, node.displayName)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking watch connection: ${e.message}")
            isConnected = false
            connectedNodeId = null
            connectedNodeName = null
        }
    }
    
    private fun updateConnectedNode(capabilityInfo: CapabilityInfo) {
        val nodes = capabilityInfo.nodes
        
        if (nodes.isEmpty()) {
            if (isConnected) {
                isConnected = false
                connectedNodeId = null
                connectedNodeName = null
                notifyConnectionStatus(false, null)
            }
            return
        }
        
        // Pick the best node (nearest or first)
        val node = nodes.firstOrNull { it.isNearby } ?: nodes.first()
        
        if (connectedNodeId != node.id) {
            connectedNodeId = node.id
            connectedNodeName = node.displayName
            isConnected = true
            notifyConnectionStatus(true, node.displayName)
        }
    }
    
    private fun notifyConnectionStatus(connected: Boolean, nodeName: String?) {
        methodChannel.invokeMethod("onConnectionChanged", mapOf(
            "connected" to connected,
            "nodeName" to nodeName
        ))
    }
    
    private suspend fun sendMessageToWatch(path: String, data: ByteArray): Boolean {
        val nodeId = connectedNodeId
        if (nodeId == null) {
            Log.w(TAG, "No watch connected, cannot send message")
            return false
        }
        
        return sendMessageToNode(nodeId, path, data)
    }
    
    private suspend fun sendMessageToNode(nodeId: String, path: String, data: ByteArray): Boolean {
        return try {
            Tasks.await(
                Wearable.getMessageClient(context).sendMessage(nodeId, path, data)
            )
            Log.d(TAG, "Message sent to node $nodeId: $path")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error sending message to node: ${e.message}")
            false
        }
    }
    
    // DataClient.OnDataChangedListener
    override fun onDataChanged(dataEvents: DataEventBuffer) {
        for (event in dataEvents) {
            if (event.type == DataEvent.TYPE_CHANGED) {
                val dataItem = event.dataItem
                val path = dataItem.uri.path
                
                Log.d(TAG, "Data changed: $path")
                
                when (path) {
                    PATH_AUDIO_DATA -> {
                        // Audio data received from watch
                        val dataMap = DataMapItem.fromDataItem(dataItem).dataMap
                        val audioData = dataMap.getByteArray("audio")
                        
                        if (audioData != null) {
                            methodChannel.invokeMethod("onAudioReceived", mapOf(
                                "audio" to audioData
                            ))
                        }
                    }
                }
            }
        }
    }
    
    // MessageClient.OnMessageReceivedListener
    override fun onMessageReceived(messageEvent: MessageEvent) {
        val path = messageEvent.path
        val data = messageEvent.data
        
        Log.d(TAG, "Message received: $path")
        
        when (path) {
            PATH_VOICE_COMMAND -> {
                // Voice command transcription from watch
                val transcription = String(data)
                methodChannel.invokeMethod("onVoiceCommand", mapOf(
                    "transcription" to transcription
                ))
            }
            PATH_VOICE_INPUT -> {
                // Voice input from Wear OS app - forward to Flutter for processing
                val text = String(data, Charsets.UTF_8)
                Log.d(TAG, "Voice input from watch: $text")
                methodChannel.invokeMethod("onWatchVoiceInput", mapOf(
                    "text" to text,
                    "nodeId" to messageEvent.sourceNodeId
                ))
            }
            PATH_AUDIO_DATA -> {
                // Raw audio data from watch mic
                methodChannel.invokeMethod("onAudioReceived", mapOf(
                    "audio" to data
                ))
            }
            PATH_CONNECTION_STATUS -> {
                // Connection status update from watch
                val status = String(data)
                val connected = status == "connected"
                if (connected != isConnected) {
                    isConnected = connected
                    notifyConnectionStatus(connected, connectedNodeName)
                }
            }
        }
    }
    
    // CapabilityClient.OnCapabilityChangedListener
    override fun onCapabilityChanged(capabilityInfo: CapabilityInfo) {
        Log.d(TAG, "Capability changed: ${capabilityInfo.name}")
        updateConnectedNode(capabilityInfo)
    }
    
    fun destroy() {
        try {
            Wearable.getDataClient(context).removeListener(this)
            Wearable.getMessageClient(context).removeListener(this)
            Wearable.getCapabilityClient(context).removeListener(this)
            scope.cancel()
        } catch (e: Exception) {
            Log.e(TAG, "Error cleaning up watch handler: ${e.message}")
        }
    }
}
