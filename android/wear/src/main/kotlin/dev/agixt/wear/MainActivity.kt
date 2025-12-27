package dev.agixt.wear

import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Warning
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.wear.compose.material.*
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.items
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState

class MainActivity : ComponentActivity() {
    
    companion object {
        private const val TAG = "MainActivity"
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate started")
        
        try {
            setContent {
                AGiXTWearApp()
            }
            Log.d(TAG, "setContent completed")
        } catch (e: Exception) {
            Log.e(TAG, "Error in setContent", e)
        }
    }
    
    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume")
    }
    
    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy")
    }
}

@Composable
fun AGiXTWearApp() {
    // ViewModel is initialized safely - errors are caught in the ViewModel itself
    val viewModel: WearViewModel = viewModel()
    val uiState by viewModel.uiState.collectAsState()
    val messages by viewModel.messages.collectAsState()
    val context = LocalContext.current
    
    // Function to launch voice input
    val launchVoiceInput = {
        val intent = Intent(context, VoiceInputActivity::class.java)
        context.startActivity(intent)
    }
    
    MaterialTheme {
        Scaffold(
            timeText = { TimeText() },
            vignette = { Vignette(vignettePosition = VignettePosition.TopAndBottom) }
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black),
                contentAlignment = Alignment.Center
            ) {
                when (uiState) {
                    is WearUiState.Idle -> IdleScreen(
                        onTapToSpeak = launchVoiceInput,
                        messages = messages
                    )
                    is WearUiState.Listening -> ListeningScreen()
                    is WearUiState.Processing -> ProcessingScreen()
                    is WearUiState.Response -> ResponseScreen(
                        response = (uiState as WearUiState.Response).text,
                        onDismiss = { viewModel.dismiss() }
                    )
                    is WearUiState.Error -> ErrorScreen(
                        message = (uiState as WearUiState.Error).message,
                        onRetry = launchVoiceInput
                    )
                }
            }
        }
    }
}

@Composable
fun IdleScreen(
    onTapToSpeak: () -> Unit,
    messages: List<ChatMessage>
) {
    val listState = rememberScalingLazyListState()
    
    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        state = listState,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Voice input button at top
        item {
            Spacer(modifier = Modifier.height(32.dp))
            CompactChip(
                onClick = onTapToSpeak,
                label = { Text("Tap to speak") },
                icon = {
                    Icon(
                        imageVector = Icons.Default.Mic,
                        contentDescription = "Microphone"
                    )
                },
                colors = ChipDefaults.primaryChipColors()
            )
        }
        
        // Hint text
        item {
            Text(
                text = "Or say \"Computer\"",
                style = MaterialTheme.typography.caption2,
                color = Color.Gray,
                textAlign = TextAlign.Center
            )
        }
        
        // Recent messages
        if (messages.isNotEmpty()) {
            item {
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "Recent",
                    style = MaterialTheme.typography.caption1,
                    color = Color.Gray
                )
            }
            
            items(messages.takeLast(5)) { message ->
                MessageCard(message)
            }
        }
        
        item {
            Spacer(modifier = Modifier.height(32.dp))
        }
    }
}

@Composable
fun MessageCard(message: ChatMessage) {
    val backgroundColor = if (message.isUser) Color(0xFF1A73E8) else Color(0xFF303030)
    
    Card(
        onClick = {},
        backgroundPainter = CardDefaults.cardBackgroundPainter(
            startBackgroundColor = backgroundColor,
            endBackgroundColor = backgroundColor
        ),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp)
    ) {
        Text(
            text = message.text,
            style = MaterialTheme.typography.body2,
            maxLines = 3,
            modifier = Modifier.padding(8.dp)
        )
    }
}

@Composable
fun ListeningScreen() {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        CircularProgressIndicator(
            indicatorColor = Color(0xFF1A73E8),
            trackColor = Color.DarkGray,
            strokeWidth = 4.dp
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "Listening...",
            style = MaterialTheme.typography.title3,
            color = Color.White
        )
    }
}

@Composable
fun ProcessingScreen() {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        CircularProgressIndicator(
            indicatorColor = Color(0xFF34A853),
            trackColor = Color.DarkGray,
            strokeWidth = 4.dp
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "Processing...",
            style = MaterialTheme.typography.title3,
            color = Color.White
        )
    }
}

@Composable
fun ResponseScreen(
    response: String,
    onDismiss: () -> Unit
) {
    val listState = rememberScalingLazyListState()
    
    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        state = listState,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        item {
            Spacer(modifier = Modifier.height(32.dp))
        }
        
        item {
            Card(
                onClick = onDismiss,
                backgroundPainter = CardDefaults.cardBackgroundPainter(
                    startBackgroundColor = Color(0xFF303030),
                    endBackgroundColor = Color(0xFF303030)
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp)
            ) {
                Text(
                    text = response,
                    style = MaterialTheme.typography.body1,
                    color = Color.White,
                    modifier = Modifier.padding(12.dp)
                )
            }
        }
        
        item {
            Spacer(modifier = Modifier.height(8.dp))
            CompactChip(
                onClick = onDismiss,
                label = { Text("OK") },
                colors = ChipDefaults.secondaryChipColors()
            )
        }
        
        item {
            Spacer(modifier = Modifier.height(32.dp))
        }
    }
}

@Composable
fun ErrorScreen(
    message: String,
    onRetry: () -> Unit
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier.padding(16.dp)
    ) {
        Icon(
            imageVector = Icons.Default.Warning,
            contentDescription = "Error",
            tint = Color(0xFFEA4335),
            modifier = Modifier.size(32.dp)
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = message,
            style = MaterialTheme.typography.body2,
            color = Color.White,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(16.dp))
        CompactChip(
            onClick = onRetry,
            label = { Text("Retry") },
            colors = ChipDefaults.primaryChipColors()
        )
    }
}

data class ChatMessage(
    val text: String,
    val isUser: Boolean,
    val timestamp: Long = System.currentTimeMillis()
)
