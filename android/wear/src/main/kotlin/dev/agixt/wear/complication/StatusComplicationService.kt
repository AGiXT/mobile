package dev.agixt.wear.complication

import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import androidx.wear.watchface.complications.data.*
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceService
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import dev.agixt.wear.R
import dev.agixt.wear.VoiceInputActivity

/**
 * Complication data source that provides a shortcut to AGiXT voice input
 * directly from watch face complications.
 */
class StatusComplicationService : ComplicationDataSourceService() {
    
    override fun getPreviewData(type: ComplicationType): ComplicationData? {
        return when (type) {
            ComplicationType.SHORT_TEXT -> createShortTextComplication("AGiXT")
            ComplicationType.LONG_TEXT -> createLongTextComplication("AGiXT", "Tap to ask")
            ComplicationType.MONOCHROMATIC_IMAGE -> createIconComplication()
            ComplicationType.SMALL_IMAGE -> createSmallImageComplication()
            else -> null
        }
    }
    
    override fun onComplicationRequest(
        request: ComplicationRequest,
        listener: ComplicationRequestListener
    ) {
        val complicationData = when (request.complicationType) {
            ComplicationType.SHORT_TEXT -> createShortTextComplication("Ask")
            ComplicationType.LONG_TEXT -> createLongTextComplication("AGiXT", "Tap to speak")
            ComplicationType.MONOCHROMATIC_IMAGE -> createIconComplication()
            ComplicationType.SMALL_IMAGE -> createSmallImageComplication()
            else -> null
        }
        
        listener.onComplicationData(complicationData)
    }
    
    private fun createShortTextComplication(text: String): ShortTextComplicationData {
        return ShortTextComplicationData.Builder(
            text = PlainComplicationText.Builder(text).build(),
            contentDescription = PlainComplicationText.Builder("Ask AGiXT").build()
        )
            .setMonochromaticImage(
                MonochromaticImage.Builder(
                    Icon.createWithResource(this, R.drawable.ic_mic)
                ).build()
            )
            .setTapAction(createTapAction())
            .build()
    }
    
    private fun createLongTextComplication(title: String, text: String): LongTextComplicationData {
        return LongTextComplicationData.Builder(
            text = PlainComplicationText.Builder(text).build(),
            contentDescription = PlainComplicationText.Builder("Ask AGiXT").build()
        )
            .setTitle(PlainComplicationText.Builder(title).build())
            .setMonochromaticImage(
                MonochromaticImage.Builder(
                    Icon.createWithResource(this, R.drawable.ic_mic)
                ).build()
            )
            .setTapAction(createTapAction())
            .build()
    }
    
    private fun createIconComplication(): MonochromaticImageComplicationData {
        return MonochromaticImageComplicationData.Builder(
            monochromaticImage = MonochromaticImage.Builder(
                Icon.createWithResource(this, R.drawable.ic_mic)
            ).build(),
            contentDescription = PlainComplicationText.Builder("Ask AGiXT").build()
        )
            .setTapAction(createTapAction())
            .build()
    }
    
    private fun createSmallImageComplication(): SmallImageComplicationData {
        return SmallImageComplicationData.Builder(
            smallImage = SmallImage.Builder(
                Icon.createWithResource(this, R.drawable.ic_mic),
                SmallImageType.ICON
            ).build(),
            contentDescription = PlainComplicationText.Builder("Ask AGiXT").build()
        )
            .setTapAction(createTapAction())
            .build()
    }
    
    private fun createTapAction(): PendingIntent {
        val intent = Intent(this, VoiceInputActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
