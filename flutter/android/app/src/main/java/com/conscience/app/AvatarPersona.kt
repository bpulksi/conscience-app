package com.conscience.app

import android.content.Context
import org.json.JSONObject

/**
 * A personality is data, not code. Everything that makes an avatar feel
 * different lives in assets/avatars/<id>/persona.json:
 * tone, per-stage lines, threshold overrides and cadence.
 */
data class AvatarPersona(
    val id: String,
    val name: String,
    val tone: String,
    val voiceId: String,
    val animations: Map<AvatarStage, String>,
    val thresholds: Map<AvatarStage, Float>,
    val lines: Map<AvatarStage, List<String>>,
    val minGapSeconds: Int,
    val maxLinesPerDay: Int,
    val bubbleSeconds: Int
) {
    fun linesFor(stage: AvatarStage): List<String> = lines[stage].orEmpty()

    fun animationFor(stage: AvatarStage): String =
        animations[stage] ?: animations[AvatarStage.ZEN] ?: FALLBACK_ANIMATION

    /** Stage for a fraction of the daily limit already used (0.0 - 1.0+). */
    fun stageFor(usedFraction: Float): AvatarStage = when {
        usedFraction >= threshold(AvatarStage.ENOUGH) -> AvatarStage.ENOUGH
        usedFraction >= threshold(AvatarStage.FURIOUS) -> AvatarStage.FURIOUS
        usedFraction >= threshold(AvatarStage.IMPATIENT) -> AvatarStage.IMPATIENT
        else -> AvatarStage.ZEN
    }

    private fun threshold(stage: AvatarStage): Float = when (stage) {
        AvatarStage.ENOUGH -> thresholds[AvatarStage.ENOUGH] ?: 1.00f
        AvatarStage.FURIOUS -> thresholds[AvatarStage.FURIOUS] ?: 0.75f
        AvatarStage.IMPATIENT -> thresholds[AvatarStage.IMPATIENT] ?: 0.25f
        AvatarStage.ZEN -> 0f
    }

    companion object {
        const val FALLBACK_ANIMATION = "avatars/brain/zen.json"
        const val DEFAULT_AVATAR_ID = "coach"

        /** The shipped brain artwork for a stage, used until a persona has its own. */
        fun fallbackAnimation(stage: AvatarStage): String = when (stage) {
            AvatarStage.ZEN -> "avatars/brain/zen.json"
            AvatarStage.IMPATIENT -> "avatars/brain/impatient.json"
            AvatarStage.FURIOUS, AvatarStage.ENOUGH -> "avatars/brain/furious.json"
        }
        private const val ROOT = "avatars"

        /** All avatar ids that actually ship a persona.json. */
        fun listIds(context: Context): List<String> =
            (context.assets.list(ROOT) ?: emptyArray())
                .filter { id -> hasPersona(context, id) }
                .sorted()

        private fun hasPersona(context: Context, id: String): Boolean =
            (context.assets.list("$ROOT/$id") ?: emptyArray()).contains("persona.json")

        fun load(context: Context, id: String): AvatarPersona {
            val json = context.assets.open("$ROOT/$id/persona.json")
                .bufferedReader().use { it.readText() }
            return parse(JSONObject(json))
        }

        /** Load the selected avatar, falling back to the default, then to a built-in persona. */
        fun loadOrDefault(context: Context, id: String?): AvatarPersona {
            val candidates = listOfNotNull(id, DEFAULT_AVATAR_ID).distinct()
            for (candidate in candidates) {
                runCatching { return load(context, candidate) }
            }
            val available = listIds(context)
            if (available.isNotEmpty()) {
                runCatching { return load(context, available.first()) }
            }
            return builtInDefault()
        }

        fun parse(root: JSONObject): AvatarPersona {
            val id = root.optString("id", "unknown")

            val animations = linkedMapOf<AvatarStage, String>()
            root.optJSONObject("animations")?.let { anim ->
                for (stage in AvatarStage.values()) {
                    val key = stage.name.lowercase()
                    if (anim.has(key)) animations[stage] = anim.getString(key)
                }
            }

            val thresholds = linkedMapOf<AvatarStage, Float>()
            root.optJSONObject("thresholds")?.let { t ->
                for (stage in AvatarStage.values()) {
                    val key = stage.name.lowercase()
                    if (t.has(key)) thresholds[stage] = t.getDouble(key).toFloat()
                }
            }

            val lines = linkedMapOf<AvatarStage, List<String>>()
            root.optJSONObject("lines")?.let { l ->
                for (stage in AvatarStage.values()) {
                    val key = stage.name.lowercase()
                    val arr = l.optJSONArray(key) ?: continue
                    val stageLines = ArrayList<String>(arr.length())
                    for (i in 0 until arr.length()) {
                        val line = arr.optString(i, "").trim()
                        if (line.isNotEmpty()) stageLines.add(line)
                    }
                    if (stageLines.isNotEmpty()) lines[stage] = stageLines
                }
            }

            val cadence = root.optJSONObject("cadence")

            return AvatarPersona(
                id = id,
                name = root.optString("name", id.replaceFirstChar { it.uppercase() }),
                tone = root.optString("tone", ""),
                voiceId = root.optString("voiceId", ""),
                animations = animations,
                thresholds = thresholds,
                lines = lines,
                minGapSeconds = cadence?.optInt("minGapSeconds", 180) ?: 180,
                maxLinesPerDay = cadence?.optInt("maxLinesPerDay", 6) ?: 6,
                bubbleSeconds = cadence?.optInt("bubbleSeconds", 6) ?: 6
            )
        }

        private fun builtInDefault() = AvatarPersona(
            id = DEFAULT_AVATAR_ID,
            name = "Coach",
            tone = "firm",
            voiceId = "",
            animations = emptyMap(),
            thresholds = emptyMap(),
            lines = mapOf(
                AvatarStage.ZEN to listOf("Keep it short."),
                AvatarStage.IMPATIENT to listOf("That's a lot of your day. Close it."),
                AvatarStage.FURIOUS to listOf("Enough. Put the phone down."),
                AvatarStage.ENOUGH to listOf("Limit hit.")
            ),
            minGapSeconds = 180,
            maxLinesPerDay = 6,
            bubbleSeconds = 6
        )
    }
}
