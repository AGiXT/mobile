package dev.agixt.wear

import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Service that listens for messages from the phone app via the Wearable Data Layer API.
 * This receives chat responses and status updates from the phone.
 * Also handles streaming TTS audio playback on the watch speaker.
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
        
        // Audio streaming paths
        const val PATH_AUDIO_HEADER = "/audio_header"
        const val PATH_AUDIO_CHUNK = "/audio_chunk"
        const val PATH_AUDIO_END = "/audio_end"
        
        // Broadcast actions for local communication
        const val ACTION_CHAT_RESPONSE = "dev.agixt.wear.CHAT_RESPONSE"
        const val ACTION_STATUS_UPDATE = "dev.agixt.wear.STATUS_UPDATE"
        const val ACTION_ERROR = "dev.agixt.wear.ERROR"
        const val ACTION_AUDIO_PLAYING = "dev.agixt.wear.AUDIO_PLAYING"
        const val ACTION_AUDIO_COMPLETE = "dev.agixt.wear.AUDIO_COMPLETE"
        
        const val EXTRA_RESPONSE_TEXT = "response_text"
        const val EXTRA_STATUS = "status"
        const val EXTRA_ERROR_MESSAGE = "error_message"
    }
    
    // Audio playback state
    private var audioTrack: AudioTrack? = null
    private var sampleRate: Int = 24000
    private var bitsPerSample: Int = 16
    private var channels: Int = 1
    
    override fun onMessageReceived(messageEvent: MessageEvent) {
        super.onMessageReceived(messageEvent)
        
        Log.d(TAG, "Message received: ${messageEvent.path}")
        
        when (messageEvent.path) {
            PATH_CHAT_RESPONSE -> handleChatResponse(messageEvent)
            PATH_STATUS -> handleStatusUpdate(messageEvent)
            PATH_TTS_COMPLETE -> handleTtsComplete(messageEvent)
            PATH_ERROR -> handleError(messageEvent)
            PATH_AUDIO_HEADER -> handleAudioHeader(messageEvent)
            PATH_AUDIO_CHUNK -> handleAudioChunk(messageEvent)
            PATH_AUDIO_END -> handleAudioEnd(messageEvent)
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
    
    /**
     * Handle audio header - contains sample rate, bits per sample, and channels.
     * Format: 8 bytes - 4 bytes sample rate (little endian), 2 bytes bits per sample, 2 bytes channels
     */
    private fun handleAudioHeader(messageEvent: MessageEvent) {
        val data = messageEvent.data
        if (data.size < 8) {
            Log.e(TAG, "Invalid audio header size: ${data.size}")
            return
        }
        
        val buffer = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN)
        sampleRate = buffer.int
        bitsPerSample = buffer.short.toInt()
        channels = buffer.short.toInt()
        
        Log.d(TAG, "Audio header: sampleRate=$sampleRate, bits=$bitsPerSample, channels=$channels")
        
        // Clean up any existing audio track
        stopAudioTrack()
        
        // Initialize AudioTrack for streaming playback
        try {
            val channelConfig = if (channels == 1) {
                AudioFormat.CHANNEL_OUT_MONO
            } else {
                AudioFormat.CHANNEL_OUT_STEREO
            }
            
            val audioFormat = when (bitsPerSample) {
                8 -> AudioFormat.ENCODING_PCM_8BIT
                16 -> AudioFormat.ENCODING_PCM_16BIT
                32 -> AudioFormat.ENCODING_PCM_FLOAT
                else -> AudioFormat.ENCODING_PCM_16BIT
            }
            
            val bufferSize = AudioTrack.getMinBufferSize(sampleRate, channelConfig, audioFormat) * 2
            
            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ASSISTANT)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(audioFormat)
                        .setSampleRate(sampleRate)
                        .setChannelMask(channelConfig)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
            
            audioTrack?.play()
            Log.d(TAG, "AudioTrack initialized and playing")
            
            // Notify UI that audio is playing
            sendBroadcast(Intent(ACTION_AUDIO_PLAYING).apply { setPackage(packageName) })
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize AudioTrack", e)
        }
    }
    
    /**
     * Handle audio chunk - raw PCM audio data to play
     */
    private fun handleAudioChunk(messageEvent: MessageEvent) {
        val audioData = messageEvent.data
        if (audioData.isEmpty()) {
            return
        }
        
        audioTrack?.let { track ->
            try {
                val written = track.write(audioData, 0, audioData.size)
                if (written < 0) {
                    Log.e(TAG, "AudioTrack write error: $written")
                } else {
                    Log.v(TAG, "Wrote ${audioData.size} bytes to AudioTrack")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error writing to AudioTrack", e)
            }
        } ?: Log.w(TAG, "Received audio chunk but AudioTrack not initialized")
    }
    
    /**
     * Handle audio end - stop playback and clean up
     */
    private fun handleAudioEnd(messageEvent: MessageEvent) {
        Log.d(TAG, "Audio stream ended")
        
        // Let the audio finish playing before stopping
        audioTrack?.let { track ->
            try {
                // Wait for buffer to drain
                track.stop()
                track.release()
                Log.d(TAG, "AudioTrack stopped and released")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping AudioTrack", e)
            }
        }
        audioTrack = null
        
        // Notify UI that audio is complete
        sendBroadcast(Intent(ACTION_AUDIO_COMPLETE).apply { setPackage(packageName) })
    }
    
    private fun stopAudioTrack() {
        audioTrack?.let { track ->
            try {
                track.stop()
                track.release()
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping existing AudioTrack", e)
            }
        }
        audioTrack = null
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopAudioTrack()
    }
}
