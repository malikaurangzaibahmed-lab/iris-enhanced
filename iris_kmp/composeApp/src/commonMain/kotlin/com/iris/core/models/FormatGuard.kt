package com.iris.core.models

import kotlin.math.max
import kotlin.math.min

object FormatGuard {
    private val timeSplit = Regex("[:.]")
    private val roomNoise = Regex("\\(\\d+\\)")

    fun sanitizeRoom(raw: String): String {
        val cleaned = raw.replace(roomNoise, "").trim()
        return if (cleaned.isEmpty()) raw.trim() else cleaned
    }

    fun toDecimalTime(raw: String): Double {
        val parts = raw.trim().split(timeSplit)
        if (parts.size < 2) return 0.0
        var hour = parts[0].toIntOrNull() ?: 0
        val minute = parts[1].toIntOrNull() ?: 0

        // Handle 12-hour format: times 1:00-4:30 are PM (university hours 8:30 AM - 4:30 PM)
        if (hour in 1..4) {
            hour += 12
        }

        return hour + (minute / 60.0)
    }

    fun dayIndex(dayName: String): Int {
        return when (dayName.lowercase()) {
            "monday" -> 1
            "tuesday" -> 2
            "wednesday" -> 3
            "thursday" -> 4
            "friday" -> 5
            "saturday" -> 6
            "sunday" -> 7
            else -> 1
        }
    }

    fun normalizeDay(dayIndex: Int): String {
        val days = listOf(
            "Monday",
            "Tuesday",
            "Wednesday",
            "Thursday",
            "Friday",
            "Saturday",
            "Sunday"
        )
        val idx = max(1, min(7, dayIndex)) - 1
        return days[idx]
    }

    fun formatDecimalTime(decimal: Double): String {
        var hour = decimal.toInt()
        val minutes = ((decimal - hour) * 60).toInt()

        var period = "AM"
        if (hour >= 12) {
            period = "PM"
            if (hour > 12) hour -= 12
        }
        if (hour == 0) hour = 12

        val hourStr = hour.toString().padStart(2, '0')
        val minStr = minutes.toString().padStart(2, '0')
        return "$hourStr:$minStr $period"
    }

    fun formatTeacherName(name: String): String {
        var raw = name.trim()
        if (raw.isEmpty() || raw.lowercase() == "unknown" || raw.lowercase() == "tbd") {
            return if (raw.isEmpty()) "Unknown" else raw
        }

        // 1. Separate common titles/prefixes
        val prefixRegex = Regex("^\\s*(dr|prof|engr|mr|ms|mrs|sir|mam|lecturer)\\b\\.?\\s*", RegexOption.IGNORE_CASE)
        var foundPrefix: String? = null
        val prefixMatch = prefixRegex.find(raw)
        if (prefixMatch != null) {
            val matchedText = prefixMatch.groupValues[1].lowercase()
            foundPrefix = when (matchedText) {
                "dr" -> "Dr."
                "prof" -> "Prof."
                "engr" -> "Engr."
                "mr" -> "Mr."
                "ms" -> "Ms."
                "mrs" -> "Mrs."
                "sir" -> "Sir"
                "mam" -> "Mam"
                "lecturer" -> "Lecturer"
                else -> matchedText.replaceFirstChar { it.uppercase() } + "."
            }
            raw = raw.substring(prefixMatch.range.last + 1).trim()
        }

        // 2. Title Case the remaining parts and sanitize double spaces
        val words = raw.split(Regex("\\s+"))
        val formattedWords = words.filter { it.isNotEmpty() }.map { word ->
            val cleanWord = word.replace(".", "")
            if (cleanWord.length == 1) {
                cleanWord.uppercase() + "."
            } else {
                cleanWord.lowercase().replaceFirstChar { it.uppercase() }
            }
        }
        var processedName = formattedWords.joinToString(" ")

        // Clean up initials spaces: e.g. "M.Hassan" -> "M. Hassan"
        val initialsRegex = Regex("\\b([A-Z])\\.\\s*([A-Z])\\.?")
        processedName = processedName.replace(initialsRegex) { matchResult ->
            "${matchResult.groupValues[1]}. ${matchResult.groupValues[2]}."
        }

        // Ensure single initials followed by word have space: "M.Hassan" -> "M. Hassan"
        val missingSpaceRegex = Regex("\\b([A-Z])\\.(?=[A-Za-z]{2,})")
        processedName = processedName.replace(missingSpaceRegex) { matchResult ->
            "${matchResult.groupValues[1]}. "
        }

        processedName = processedName.replace(Regex("\\.+"), ".").replace(Regex("\\s+"), " ").trim()

        return if (foundPrefix != null) "$foundPrefix $processedName" else processedName
    }

    fun truncateTeacherName(name: String, maxLength: Int = 18): String {
        val formatted = formatTeacherName(name)
        if (formatted.length <= maxLength) {
            return formatted
        }

        val prefixRegex = Regex("^\\s*(Dr\\.|Prof\\.|Engr\\.|Mr\\.|Ms\\.|Mrs\\.|Sir|Mam|Lecturer)\\s*")
        var prefix: String? = null
        var rawName = formatted
        val prefixMatch = prefixRegex.find(formatted)
        if (prefixMatch != null) {
            prefix = prefixMatch.value
            rawName = formatted.substring(prefixMatch.range.last + 1).trim()
        }

        val words = rawName.split(" ")
        if (words.size <= 2) {
            val combined = if (prefix != null) "$prefix$rawName" else rawName
            if (combined.length <= maxLength) return combined
            return combined.take(maxLength - 3) + "..."
        }

        val firstWord = words.first()
        val lastWord = words.last()
        val middleInitials = mutableListOf<String>()

        for (i in 1 until words.size - 1) {
            val w = words[i]
            if (w.endsWith(".") && w.length <= 2) {
                middleInitials.add(w)
            } else {
                middleInitials.add(w.first().toString().uppercase() + ".")
            }
        }

        val middleStr = middleInitials.joinToString(" ")
        var shortened = "$firstWord $middleStr $lastWord"
        if (prefix != null) {
            shortened = "$prefix$shortened"
        }

        if (shortened.length <= maxLength) {
            return shortened
        }

        val firstInitial = firstWord.first().toString().uppercase() + "."
        shortened = "$firstInitial $lastWord"
        if (prefix != null) {
            shortened = "$prefix$shortened"
        }

        if (shortened.length <= maxLength) {
            return shortened
        }

        return shortened.take(maxLength - 3) + "..."
    }
}
