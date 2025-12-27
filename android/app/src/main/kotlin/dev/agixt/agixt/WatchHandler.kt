package dev.agixt.agixt

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
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
    // Audio streaming paths for TTS playback on watch
    private val PATH_AUDIO_HEADER = "/audio_header"
    private val PATH_AUDIO_CHUNK = "/audio_chunk"
    private val PATH_AUDIO_END = "/audio_end"
    
    private lateinit var methodChannel: MethodChannel
    private var connectedNodeId: String? = null
    private var connectedNodeName: String? = null
    private var isConnected = false
    
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // Broadcast receiver for WearableMessageService
    private val voiceInputReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == WearableMessageService.ACTION_VOICE_INPUT) {
                val text = intent.getStringExtra(WearableMessageService.EXTRA_TEXT)
                val nodeId = intent.getStringExtra(WearableMessageService.EXTRA_NODE_ID)
                if (!text.isNullOrEmpty()) {
                    Log.d(TAG, "Received voice input broadcast: $text (from $nodeId)")
                    sendVoiceInputToFlutter(text, nodeId)
                }
            }
        }
    }
    
    /// Handle voice input from MainActivity intent (when app wasn't running)
    fun handleVoiceInputFromIntent(text: String, nodeId: String?) {
        Log.d(TAG, "Handling voice input from intent: $text (from $nodeId)")
        sendVoiceInputToFlutter(text, nodeId)
    }
    
    private fun sendVoiceInputToFlutter(text: String, nodeId: String?) {
        try {
            methodChannel.invokeMethod("onWatchVoiceInput", mapOf(
                "text" to text,
                "nodeId" to nodeId
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Error sending voice input to Flutter", e)
        }
    }
    
    fun initialize() {
        methodChannel = MethodChannel(binaryMessenger, CHANNEL)
        
        // Register broadcast receiver for voice input from WearableMessageService
        val intentFilter = IntentFilter(WearableMessageService.ACTION_VOICE_INPUT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(voiceInputReceiver, intentFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(voiceInputReceiver, intentFilter)
        }
        
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
                "sendAudioHeader" -> {
                    // Send audio format header to watch for TTS playback
                    val sampleRate = call.argument<Int>("sampleRate") ?: 24000
                    val bitsPerSample = call.argument<Int>("bitsPerSample") ?: 16
                    val channels = call.argument<Int>("channels") ?: 1
                    val nodeId = call.argument<String>("nodeId")
                    
                    // Pack header: 4 bytes sample rate, 2 bytes bits, 2 bytes channels
                    val header = ByteArray(8)
                    header[0] = (sampleRate and 0xFF).toByte()
                    header[1] = ((sampleRate shr 8) and 0xFF).toByte()
                    header[2] = ((sampleRate shr 16) and 0xFF).toByte()
                    header[3] = ((sampleRate shr 24) and 0xFF).toByte()
                    header[4] = (bitsPerSample and 0xFF).toByte()
                    header[5] = ((bitsPerSample shr 8) and 0xFF).toByte()
                    header[6] = (channels and 0xFF).toByte()
                    header[7] = ((channels shr 8) and 0xFF).toByte()
                    
                    scope.launch {
                        val success = if (nodeId != null) {
                            sendMessageToNode(nodeId, PATH_AUDIO_HEADER, header)
                        } else {
                            sendMessageToWatch(PATH_AUDIO_HEADER, header)
                        }
                        withContext(Dispatchers.Main) {
                            result.success(success)
                        }
                    }
                }
                "sendAudioChunk" -> {
                    // Send audio PCM data chunk to watch
                    val audioData = call.argument<ByteArray>("audioData")
                    val nodeId = call.argument<String>("nodeId")
                    
                    if (audioData == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    
                    scope.launch {
                        val success = if (nodeId != null) {
                            sendMessageToNode(nodeId, PATH_AUDIO_CHUNK, audioData)
                        } else {
                            sendMessageToWatch(PATH_AUDIO_CHUNK, audioData)
                        }
                        withContext(Dispatchers.Main) {
                            result.success(success)
                        }
                    }
                }
                "sendAudioEnd" -> {
                    // Signal end of audio stream
                    val nodeId = call.argument<String>("nodeId")
                    scope.launch {
                        val success = if (nodeId != null) {
                            sendMessageToNode(nodeId, PATH_AUDIO_END, byteArrayOf())
                        } else {
                            sendMessageToWatch(PATH_AUDIO_END, byteArrayOf())
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
            context.unregisterReceiver(voiceInputReceiver)
            Wearable.getDataClient(context).removeListener(this)
            Wearable.getMessageClient(context).removeListener(this)
            Wearable.getCapabilityClient(context).removeListener(this)
            scope.cancel()
        } catch (e: Exception) {
            Log.e(TAG, "Error cleaning up watch handler: ${e.message}")
        }
    }
}
