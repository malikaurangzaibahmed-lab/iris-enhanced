package com.iris.core.models

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*
import kotlin.math.abs

@Serializable
data class BatchKey(
    val batch: String,
    val program: String,
    val semester: Int,
    val section: String,
    val intake: String
) {
    val dynamicSemester: Int get() = calculateSemester(intake)

    companion object {
        fun calculateSemester(intake: String): Int {
            val currentYear = TimeProvider.getCurrentYear()
            val currentMonth = TimeProvider.getCurrentMonth()
            
            if (intake.length < 4) return 1
            val term = intake.substring(0, 2).uppercase()
            val yearSuffix = intake.substring(2, 4)
            val yearShort = yearSuffix.toIntOrNull() ?: return 1
            val intakeYear = 2000 + yearShort

            var intakeIndex = intakeYear * 2
            if (term == "FA") {
                intakeIndex += 1
            }

            var currentIndex = currentYear * 2
            if (currentMonth >= 8) {
                currentIndex += 1
            }

            val sem = currentIndex - intakeIndex + 1
            return sem.coerceIn(1, 8)
        }

        fun parse(batch: String): BatchKey {
            val parts = batch.split("-")
            if (parts.size < 3) {
                return BatchKey(
                    batch = batch,
                    program = if (parts.isNotEmpty()) parts.first() else "UNKNOWN",
                    semester = 0,
                    section = if (parts.size > 1) parts[1] else "A",
                    intake = if (parts.isNotEmpty()) parts.first() else "NA"
                )
            }

            val intake = parts[0]
            val program = parts[1]
            val semesterText = parts[2]
            
            val digitRegex = Regex("\\d+")
            val digitMatch = digitRegex.find(semesterText)?.value
            val semester = semesterText.toIntOrNull() ?: digitMatch?.toIntOrNull() ?: 0
            
            val section = if (parts.size >= 4) parts[3] else parts[2]
            return BatchKey(
                batch = batch,
                program = program,
                semester = semester,
                section = section,
                intake = intake
            )
        }
    }
}

@Serializable
data class ClassSession(
    val id: String,
    val batchKey: BatchKey,
    val dayIndex: Int,
    val startTime: String,
    val endTime: String,
    val subject: String,
    val teacher: String,
    val room: String
) {
    val safeStartVal: Double get() = FormatGuard.toDecimalTime(startTime)
    val safeEndVal: Double get() = FormatGuard.toDecimalTime(endTime)

    val isOneHourLecture: Boolean
        get() = subject.lowercase().contains("(1 hr)") ||
                subject.lowercase().contains("(1hr)") ||
                subject.lowercase().contains("1 hr)")

    val actualEndVal: Double
        get() = if (isOneHourLecture) safeStartVal + 1.0 else safeEndVal

    fun isLive(): Boolean {
        val currentT = TimeProvider.getCurrentHour() + (TimeProvider.getCurrentMinute() / 60.0)
        return dayIndex == TimeProvider.getCurrentWeekday() && currentT >= safeStartVal && currentT < actualEndVal
    }

    fun isConsecutiveWith(other: ClassSession): Boolean {
        return dayIndex == other.dayIndex &&
                subject == other.subject &&
                teacher == other.teacher &&
                room == other.room &&
                abs(actualEndVal - other.safeStartVal) < 0.01
    }

    fun isSameLectureAs(other: ClassSession): Boolean {
        return dayIndex == other.dayIndex &&
                subject == other.subject &&
                teacher == other.teacher &&
                room == other.room
    }

    companion object {
        fun fromJsonObject(json: JsonObject): ClassSession {
            val batchStr = (json["batch"]?.jsonPrimitive?.contentOrNull 
                ?: json["class_name"]?.jsonPrimitive?.contentOrNull 
                ?: json["section"]?.jsonPrimitive?.contentOrNull 
                ?: "UNKNOWN")
            val batchKey = BatchKey.parse(batchStr)

            var start = "00:00"
            var end = "00:00"

            if (json["start"] != null && json["end"] != null) {
                start = json["start"]?.jsonPrimitive?.content ?: "00:00"
                end = json["end"]?.jsonPrimitive?.content ?: "00:00"
            } else {
                val timeStr = (json["time"]?.jsonPrimitive?.contentOrNull 
                    ?: json["period"]?.jsonPrimitive?.contentOrNull 
                    ?: "")
                if (timeStr.isNotEmpty()) {
                    val parts = timeStr.split("-")
                    if (parts.size >= 2) {
                        start = parts[0].trim()
                        end = parts[1].trim()
                    } else if (parts.isNotEmpty()) {
                        start = parts[0].trim()
                    }
                }
            }

            val dayStr = (json["day"]?.jsonPrimitive?.contentOrNull 
                ?: json["weekday"]?.jsonPrimitive?.contentOrNull 
                ?: "Monday")
            val subjectStr = (json["subject"]?.jsonPrimitive?.contentOrNull 
                ?: json["course"]?.jsonPrimitive?.contentOrNull 
                ?: json["title"]?.jsonPrimitive?.contentOrNull 
                ?: "Unknown")
            val teacherStr = (json["teacher"]?.jsonPrimitive?.contentOrNull 
                ?: json["instructor"]?.jsonPrimitive?.contentOrNull 
                ?: json["staff"]?.jsonPrimitive?.contentOrNull 
                ?: "Unknown")
            val roomStr = (json["room"]?.jsonPrimitive?.contentOrNull 
                ?: json["location"]?.jsonPrimitive?.contentOrNull 
                ?: "TBD")

            val id = json["id"]?.jsonPrimitive?.contentOrNull ?: "${batchKey.batch}-$dayStr-$start"

            return ClassSession(
                id = id,
                batchKey = batchKey,
                dayIndex = FormatGuard.dayIndex(dayStr),
                startTime = start,
                endTime = end,
                subject = subjectStr,
                teacher = FormatGuard.formatTeacherName(teacherStr),
                room = FormatGuard.sanitizeRoom(roomStr)
            )
        }
    }
}

class UniversityMemory(val sessions: List<ClassSession>) {
    val allBatches: List<String>
        get() {
            val batches = sessions.map { it.batchKey.batch }.toSet().toList()
            return batches.sorted()
        }

    fun byBatch(): Map<String, List<ClassSession>> {
        return sessions.groupBy { it.batchKey.batch }
    }

    fun byProgram(program: String): Map<String, List<ClassSession>> {
        return sessions.filter { it.batchKey.program == program }.groupBy { it.batchKey.batch }
    }

    fun programs(): List<String> {
        return sessions.map { it.batchKey.program }.toSet().toList().sorted()
    }

    fun semesters(program: String): List<Int> {
        return sessions.filter { it.batchKey.program == program }.map { it.batchKey.semester }.toSet().toList().sorted()
    }

    fun sections(program: String, semester: Int): List<String> {
        return sessions.filter { it.batchKey.program == program && it.batchKey.semester == semester }
            .map { it.batchKey.section }.toSet().toList().sorted()
    }
}

@Serializable
data class Room(
    val id: String,
    val building: String,
    val capacity: Int,
    val amenities: List<String>,
    val registeredAtIso: String
)

data class Department(
    val id: String,
    val name: String,
    val registeredAtIso: String
)

data class RoomAvailability(
    val roomId: String,
    val building: String,
    val capacity: Int,
    val amenities: List<String>,
    val isAvailable: Boolean,
    val occupiedUntil: Double? = null,
    val occupiedBy: String? = null,
    val occupiedByTeacher: String? = null,
    val nextSessionAt: Double? = null,
    val nextSessionSubject: String? = null,
    val minutesFreeUntilNextSession: Int? = null,
    val studyScore: Double
)

data class RoomConflict(
    val room: String,
    val session1: ClassSession,
    val session2: ClassSession,
    val overlapMinutes: Int,
    val severity: String
)

data class RoomRecommendation(
    val recommended: RoomAvailability?,
    val reason: String,
    val alternatives: List<RoomAvailability>
)

object LectureDuration {
    fun getActualDuration(session: ClassSession): Double {
        return abs(session.safeEndVal - session.safeStartVal)
    }
    fun getActualEndTime(session: ClassSession): Double {
        return session.safeEndVal
    }
}
