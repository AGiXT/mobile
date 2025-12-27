package dev.agixt.wear.tile

import android.content.Intent
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders.argb
import androidx.wear.protolayout.DimensionBuilders.dp
import androidx.wear.protolayout.DimensionBuilders.sp
import androidx.wear.protolayout.DimensionBuilders.expand
import androidx.wear.protolayout.DimensionBuilders.wrap
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import kotlinx.coroutines.*
import com.google.common.util.concurrent.ListenableFuture
import dev.agixt.wear.R
import dev.agixt.wear.VoiceInputActivity

/**
 * Tile service that provides quick access to AGiXT voice input.
 * Users can add this tile to their watch face for one-tap voice commands.
 */
class AGiXTTileService : TileService() {
    
    companion object {
        private const val RESOURCES_VERSION = "1"
        private const val ID_MIC_ICON = "mic_icon"
    }
    
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    override fun onTileRequest(requestParams: RequestBuilders.TileRequest): ListenableFuture<TileBuilders.Tile> {
        val tile = TileBuilders.Tile.Builder()
            .setResourcesVersion(RESOURCES_VERSION)
            .setTileTimeline(
                androidx.wear.protolayout.TimelineBuilders.Timeline.Builder()
                    .addTimelineEntry(
                        androidx.wear.protolayout.TimelineBuilders.TimelineEntry.Builder()
                            .setLayout(
                                LayoutElementBuilders.Layout.Builder()
                                    .setRoot(createTileLayout())
                                    .build()
                            )
                            .build()
                    )
                    .build()
            )
            .build()
        
        return com.google.common.util.concurrent.Futures.immediateFuture(tile)
    }
    
    override fun onResourcesRequest(requestParams: RequestBuilders.ResourcesRequest): ListenableFuture<androidx.wear.tiles.ResourceBuilders.Resources> {
        val resources = androidx.wear.tiles.ResourceBuilders.Resources.Builder()
            .setVersion(RESOURCES_VERSION)
            .addIdToImageMapping(
                ID_MIC_ICON,
                androidx.wear.tiles.ResourceBuilders.ImageResource.Builder()
                    .setAndroidResourceByResId(
                        androidx.wear.tiles.ResourceBuilders.AndroidImageResourceByResId.Builder()
                            .setResourceId(R.drawable.ic_mic)
                            .build()
                    )
                    .build()
            )
            .build()
        
        return com.google.common.util.concurrent.Futures.immediateFuture(resources)
    }
    
    private fun createTileLayout(): LayoutElementBuilders.LayoutElement {
        // Create a clickable modifier that launches voice input
        val clickable = ModifiersBuilders.Clickable.Builder()
            .setOnClick(
                ActionBuilders.LaunchAction.Builder()
                    .setAndroidActivity(
                        ActionBuilders.AndroidActivity.Builder()
                            .setPackageName(packageName)
                            .setClassName(VoiceInputActivity::class.java.name)
                            .build()
                    )
                    .build()
            )
            .build()
        
        return LayoutElementBuilders.Box.Builder()
            .setWidth(expand())
            .setHeight(expand())
            .setModifiers(
                ModifiersBuilders.Modifiers.Builder()
                    .setClickable(clickable)
                    .setBackground(
                        ModifiersBuilders.Background.Builder()
                            .setColor(argb(0xFF000000.toInt()))
                            .build()
                    )
                    .build()
            )
            .addContent(
                LayoutElementBuilders.Column.Builder()
                    .setWidth(wrap())
                    .setHeight(wrap())
                    .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
                    .addContent(
                        // Mic icon
                        LayoutElementBuilders.Image.Builder()
                            .setWidth(dp(48f))
                            .setHeight(dp(48f))
                            .setResourceId(ID_MIC_ICON)
                            .setColorFilter(
                                LayoutElementBuilders.ColorFilter.Builder()
                                    .setTint(argb(0xFF1A73E8.toInt()))
                                    .build()
                            )
                            .build()
                    )
                    .addContent(
                        LayoutElementBuilders.Spacer.Builder()
                            .setHeight(dp(8f))
                            .build()
                    )
                    .addContent(
                        LayoutElementBuilders.Text.Builder()
                            .setText("Ask AGiXT")
                            .setFontStyle(
                                LayoutElementBuilders.FontStyle.Builder()
                                    .setSize(sp(14f))
                                    .setColor(argb(0xFFFFFFFF.toInt()))
                                    .build()
                            )
                            .build()
                    )
                    .addContent(
                        LayoutElementBuilders.Spacer.Builder()
                            .setHeight(dp(4f))
                            .build()
                    )
                    .addContent(
                        LayoutElementBuilders.Text.Builder()
                            .setText("Tap to speak")
                            .setFontStyle(
                                LayoutElementBuilders.FontStyle.Builder()
                                    .setSize(sp(12f))
                                    .setColor(argb(0xFF888888.toInt()))
                                    .build()
                            )
                            .build()
                    )
                    .build()
            )
            .build()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
    }
}
