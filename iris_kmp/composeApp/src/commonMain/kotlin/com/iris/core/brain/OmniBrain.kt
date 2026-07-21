package com.iris.core.brain

import com.iris.core.models.ClassSession
import com.iris.core.models.LectureDuration
import com.iris.core.models.TimeProvider
import com.iris.core.models.UniversityMemory
import kotlin.math.abs
import kotlin.random.Random

data class TemporalInsight(
    val headline: String,
    val subline: String,
    val isLive: Boolean,
    val timeInfo: String? = null,
    val teacherInfo: String? = null,
    val isUrgent: Boolean = false,
    val subject: String? = null,
    val room: String? = null,
    val startTime: String? = null
)

data class TeacherScheduleEntry(
    val dayIndex: Int,
    val startTime: String,
    val endTime: String,
    val subject: String,
    val room: String,
    val batch: String,
    val isLive: Boolean = false,
    val isUpcoming: Boolean = false
) {
    val dayName: String
        get() {
            val days = listOf("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
            return if (dayIndex in 1..7) days[dayIndex - 1] else "Day $dayIndex"
        }
}

data class TeacherLocatorResult(
    val teacherName: String,
    val status: String, // 'live', 'today', 'scheduled', 'not_found'
    val statusText: String,
    val liveSession: TeacherScheduleEntry? = null,
    val todaySessions: List<TeacherScheduleEntry> = emptyList(),
    val weeklySchedule: Map<Int, List<TeacherScheduleEntry>> = emptyMap(),
    val allRooms: List<String> = emptyList(),
    val allSubjects: List<String> = emptyList()
)

data class FreeSlot(
    val dayIndex: Int,
    val startTime: Double,
    val endTime: Double
) {
    val dayName: String
        get() {
            val days = listOf("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
            return if (dayIndex in 1..7) days[dayIndex - 1] else "Day $dayIndex"
        }

    fun timeRangeString(): String {
        val startHour = startTime.toInt()
        val startMin = ((startTime - startHour) * 60).toInt()
        val endHour = endTime.toInt()
        val endMin = ((endTime - endHour) * 60).toInt()
        return "${startHour.toString().padStart(2, '0')}:${startMin.toString().padStart(2, '0')} - ${endHour.toString().padStart(2, '0')}:${endMin.toString().padStart(2, '0')}"
    }
}

data class MakeupSlotSuggestion(
    val dayIndex: Int,
    val startTime: Double,
    val endTime: Double,
    val durationHours: Double,
    val availableRooms: List<String>? = null
) {
    val dayName: String
        get() {
            val days = listOf("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
            return if (dayIndex in 1..7) days[dayIndex - 1] else "Day $dayIndex"
        }

    fun timeRangeString(): String {
        return "${format12Hour(startTime)} - ${format12Hour(endTime)}"
    }

    private fun format12Hour(time: Double): String {
        val hour24 = time.toInt().coerceIn(0, 23)
        val min = ((time - hour24) * 60).toInt().coerceIn(0, 59)
        val hour12 = if (hour24 == 0) 12 else if (hour24 > 12) hour24 - 12 else hour24
        val period = if (hour24 >= 12) "PM" else "AM"
        return "$hour12:${min.toString().padStart(2, '0')} $period"
    }
}

data class BatchVitalMetrics(
    val dayProgress: Double,
    val completedClasses: Int,
    val totalClassesToday: Int,
    val remainingClasses: Int,
    val attendanceHealth: Double
)

class OmniBrain(val memory: UniversityMemory) {

    fun scheduleFor(batch: String): List<ClassSession> {
        return memory.byBatch()[batch] ?: emptyList()
    }

    fun scheduleForTeacher(teacherName: String): List<ClassSession> {
        val name = teacherName.trim().lowercase()
        return memory.sessions.filter { it.teacher.trim().lowercase() == name }
    }

    fun getMergedConsecutiveSessions(schedule: List<ClassSession>): List<ClassSession> {
        if (schedule.isEmpty()) return emptyList()

        val sorted = schedule.sortedBy { it.safeStartVal }
        val merged = mutableListOf<ClassSession>()
        var current: ClassSession? = null

        for (session in sorted) {
            if (current == null) {
                current = session
                continue
            }

            if (current.isConsecutiveWith(session)) {
                current = ClassSession(
                    id = current.id,
                    batchKey = current.batchKey,
                    dayIndex = current.dayIndex,
                    startTime = current.startTime,
                    endTime = session.endTime,
                    subject = current.subject,
                    teacher = current.teacher,
                    room = current.room
                )
            } else {
                merged.add(current)
                current = session
            }
        }

        if (current != null) {
            merged.add(current)
        }

        return merged
    }

    fun getVitalMetrics(batch: String): BatchVitalMetrics {
        val schedule = scheduleFor(batch)
        val weekday = TimeProvider.getCurrentWeekday()
        val today = schedule.filter { it.dayIndex == weekday }
        val currentT = TimeProvider.getCurrentHour() + (TimeProvider.getCurrentMinute() / 60.0)

        if (today.isEmpty()) {
            return BatchVitalMetrics(
                dayProgress = 0.0,
                completedClasses = 0,
                totalClassesToday = 0,
                remainingClasses = 0,
                attendanceHealth = 1.0
            )
        }

        val mergedToday = getMergedConsecutiveSessions(today)
        val completed = mergedToday.filter { LectureDuration.getActualEndTime(it) <= currentT }.size
        val total = mergedToday.size
        val remaining = mergedToday.filter { it.safeStartVal > currentT }.size

        val dayProgress = if (total > 0) completed.toDouble() / total else 0.0
        val seedDay = TimeProvider.getCurrentWeekday()
        val attendanceHealth = 0.85 + (Random(seedDay).nextDouble() * 0.12)

        return BatchVitalMetrics(
            dayProgress = dayProgress,
            completedClasses = completed,
            totalClassesToday = total,
            remainingClasses = remaining,
            attendanceHealth = attendanceHealth
        )
    }

    fun getMergedSession(session: ClassSession, allSessions: List<ClassSession>): ClassSession {
        val sameDaySessions = allSessions
            .filter { s -> s.dayIndex == session.dayIndex && s.isSameLectureAs(session) }
            .sortedBy { it.safeStartVal }

        if (sameDaySessions.isEmpty()) return session

        val blocks = mutableListOf<List<ClassSession>>()
        var currentBlock = mutableListOf<ClassSession>()

        for (s in sameDaySessions) {
            if (currentBlock.isEmpty()) {
                currentBlock.add(s)
            } else {
                val last = currentBlock.last()
                if (abs(s.safeStartVal - last.actualEndVal) < 0.01) {
                    currentBlock.add(s)
                } else {
                    blocks.add(currentBlock)
                    currentBlock = mutableListOf(s)
                }
            }
        }
        if (currentBlock.isNotEmpty()) {
            blocks.add(currentBlock)
        }

        for (block in blocks) {
            val containsSession = block.any { s ->
                s.id == session.id || (s.safeStartVal == session.safeStartVal && s.safeEndVal == session.safeEndVal)
            }
            if (containsSession) {
                return ClassSession(
                    id = block.first().id,
                    batchKey = block.first().batchKey,
                    dayIndex = block.first().dayIndex,
                    startTime = block.first().startTime,
                    endTime = block.last().endTime,
                    subject = block.first().subject,
                    teacher = block.first().teacher,
                    room = block.first().room
                )
            }
        }

        return session
    }
}
