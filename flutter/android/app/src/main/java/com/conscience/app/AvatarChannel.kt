package com.conscience.app

import android.content.Context
import android.content.Intent
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Method channel behind the Flutter "Cast" screen: list the persona assets that
 * ship in the APK, pick one, and hear a sample line without waiting for a real
 * screen-time event.
 *
 * Register from MainActivity:
 *   AvatarChannel.register(engine.dartExecutor.binaryMessenger, this)
 */
object AvatarChannel {

    private const val CHANNEL = "conscience/avatars"

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "list" -> result.success(
                    AvatarPersona.listIds(context).mapNotNull { id ->
                        runCatching {
                            val persona = AvatarPersona.load(context, id)
                            mapOf(
                                "id" to persona.id,
                                "name" to persona.name,
                                "tone" to persona.tone,
                                "maxLinesPerDay" to persona.maxLinesPerDay.toString()
                            )
                        }.getOrNull()
                    }
                )

                "selected" -> result.success(MessageEngine.selectedAvatarId(context))

                "select" -> {
                    val id = call.argument<String>("id")
                    if (id.isNullOrBlank()) {
                        result.error("bad_args", "id is required", null)
                    } else {
                        MessageEngine.selectAvatar(context, id)
                        LocalBroadcastManager.getInstance(context).sendBroadcast(
                            Intent(ConscienceAccessibilityService.ACTION_PERSONA_CHANGED)
                        )
                        result.success(null)
                    }
                }

                "sampleLine" -> {
                    val id = call.argument<String>("id") ?: MessageEngine.selectedAvatarId(context)
                    val stageName = call.argument<String>("stage") ?: AvatarStage.IMPATIENT.name
                    val stage = runCatching { AvatarStage.valueOf(stageName.uppercase()) }
                        .getOrDefault(AvatarStage.IMPATIENT)
                    val persona = AvatarPersona.loadOrDefault(context, id)
                    val engine = MessageEngine(persona, MessageEngine.prefs(context))
                    result.success(engine.sampleLine(stage))
                }

                "mute" -> {
                    val persona = AvatarPersona.loadOrDefault(context, MessageEngine.selectedAvatarId(context))
                    val engine = MessageEngine(persona, MessageEngine.prefs(context))
                    val minutes = call.argument<Int>("minutes") ?: 30
                    engine.muteFor(minutes * 60_000L)
                    result.success(null)
                }

                "muteStatus" -> {
                    val persona = AvatarPersona.loadOrDefault(context, MessageEngine.selectedAvatarId(context))
                    val engine = MessageEngine(persona, MessageEngine.prefs(context))
                    result.success(engine.mutedUntil())
                }

                else -> result.notImplemented()
            }
        }
    }
}
