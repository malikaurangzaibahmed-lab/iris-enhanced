package com.iris.services.systems

import com.iris.core.models.*
import kotlin.math.max
import kotlin.math.min
import kotlin.math.abs

class RoomOccupancyService {
    private val rooms = mutableMapOf<String, Room>()
    private val departments = mutableMapOf<String, Department>()

    fun registerDepartment(departmentId: String, departmentName: String) {
        departments[departmentId] = Department(
            id = departmentId,
            name = departmentName,
            registeredAtIso = ""
        )
    }

    fun registerRoom(roomId: String, building: String, capacity: Int, amenities: List<String>) {
        rooms[roomId] = Room(
            id = roomId,
            building = building,
            capacity = capacity,
            amenities = amenities,
            registeredAtIso = ""
        )
    }

    fun registerRoomModel(room: Room) {
        rooms[room.id] = room
    }

    fun getAvailableRoomsNow(allSessions: List<ClassSession>): List<RoomAvailability> {
        val weekday = TimeProvider.getCurrentWeekday()
        val currentHour = TimeProvider.getCurrentHour() + (TimeProvider.getCurrentMinute() / 60.0)

        val rawAvailability = mutableListOf<RoomAvailability>()
        for (room in rooms.values) {
            val occupyingSessions = allSessions.filter { s ->
                s.room == room.id &&
                s.dayIndex == weekday &&
                s.safeStartVal <= currentHour &&
                currentHour < s.safeEndVal
            }

            if (occupyingSessions.isEmpty()) {
                val nextSession = getNextSession(room.id, allSessions, weekday, currentHour)
                rawAvailability.add(
                    RoomAvailability(
                        roomId = room.id,
                        building = room.building,
                        capacity = room.capacity,
                        amenities = room.amenities,
                        isAvailable = true,
                        occupiedUntil = null,
                        nextSessionAt = nextSession?.safeStartVal,
                        nextSessionSubject = nextSession?.subject,
                        minutesFreeUntilNextSession = nextSession?.let {
                            ((it.safeStartVal - currentHour) * 60).toInt()
                        },
                        studyScore = 0.0
                    )
                )
            } else {
                val session = occupyingSessions.first()
                rawAvailability.add(
                    RoomAvailability(
                        roomId = room.id,
                        building = room.building,
                        capacity = room.capacity,
                        amenities = room.amenities,
                        isAvailable = false,
                        occupiedUntil = session.safeEndVal,
                        occupiedBy = session.subject,
                        occupiedByTeacher = session.teacher,
                        minutesFreeUntilNextSession = ((session.safeEndVal - currentHour) * 60).toInt(),
                        studyScore = 0.0
                    )
                )
            }
        }

        val availability = rawAvailability.map { a ->
            if (!a.isAvailable) return@map a
            val room = rooms[a.roomId] ?: return@map a
            val nextSession = getNextSession(room.id, allSessions, weekday, currentHour)
            a.copy(studyScore = calculateStudyScore(room, nextSession, rawAvailability))
        }

        return availability.sortedByDescending { it.studyScore }
    }

    fun getRoomAvailabilityAt(
        allSessions: List<ClassSession>,
        targetHour: Double,
        dayIndex: Int
    ): List<RoomAvailability> {
        val rawAvailability = mutableListOf<RoomAvailability>()
        for (room in rooms.values) {
            val occupyingSessions = allSessions.filter { s ->
                s.room == room.id &&
                s.dayIndex == dayIndex &&
                s.safeStartVal <= targetHour &&
                targetHour < s.safeEndVal
            }

            val isAvailable = occupyingSessions.isEmpty()
            val nextSession = if (isAvailable) getNextSession(room.id, allSessions, dayIndex, targetHour) else null

            rawAvailability.add(
                RoomAvailability(
                    roomId = room.id,
                    building = room.building,
                    capacity = room.capacity,
                    amenities = room.amenities,
                    isAvailable = isAvailable,
                    occupiedUntil = if (isAvailable) null else occupyingSessions.first().safeEndVal,
                    nextSessionAt = nextSession?.safeStartVal,
                    nextSessionSubject = nextSession?.subject,
                    minutesFreeUntilNextSession = nextSession?.let {
                        ((it.safeStartVal - targetHour) * 60).toInt()
                    },
                    studyScore = 0.0
                )
            )
        }

        val availability = rawAvailability.map { a ->
            if (!a.isAvailable) return@map a
            val room = rooms[a.roomId] ?: return@map a
            val nextSession = getNextSession(room.id, allSessions, dayIndex, targetHour)
            a.copy(studyScore = calculateStudyScore(room, nextSession, rawAvailability))
        }

        return availability.sortedByDescending { it.studyScore }
    }

    fun getAvailableRoomsForTimeRange(
        allSessions: List<ClassSession>,
        dayIndex: Int,
        startTime: Double,
        endTime: Double
    ): List<String> {
        val availableRooms = mutableListOf<String>()

        for (room in rooms.values) {
            val conflicts = allSessions.filter { s ->
                s.room == room.id &&
                s.dayIndex == dayIndex &&
                !(s.safeEndVal <= startTime || s.safeStartVal >= endTime)
            }

            if (conflicts.isEmpty()) {
                availableRooms.add(room.id)
            }
        }

        return availableRooms
    }

    fun detectRoomConflicts(allSessions: List<ClassSession>): List<RoomConflict> {
        val conflicts = mutableListOf<RoomConflict>()
        val sessionsByRoom = allSessions.groupBy { it.room }

        for (sessions in sessionsByRoom.values) {
            for (i in sessions.indices) {
                for (j in (i + 1) until sessions.size) {
                    val s1 = sessions[i]
                    val s2 = sessions[j]

                    if (s1.dayIndex == s2.dayIndex &&
                        !(s1.safeEndVal <= s2.safeStartVal || s2.safeEndVal <= s1.safeStartVal)
                    ) {
                        val overlapStart = maxOf(s1.safeStartVal, s2.safeStartVal)
                        val overlapEnd = minOf(s1.safeEndVal, s2.safeEndVal)
                        val overlapMin = ((overlapEnd - overlapStart) * 60).toInt()
                        conflicts.add(
                            RoomConflict(
                                room = s1.room,
                                session1 = s1,
                                session2 = s2,
                                overlapMinutes = overlapMin,
                                severity = calculateConflictSeverity(s1, s2)
                            )
                        )
                    }
                }
            }
        }

        return conflicts
    }

    fun getRoomHeatmap(roomId: String, allSessions: List<ClassSession>): Map<String, Double> {
        val heatmap = mutableMapOf<String, Double>()
        val days = listOf("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
        val hours = listOf(
            "08:00", "09:00", "10:00", "11:00", "12:00", "13:00",
            "14:00", "15:00", "16:00", "17:00", "18:00"
        )

        for (day in days) {
            for (hour in hours) {
                heatmap["$day-$hour"] = 0.0
            }
        }

        for (session in allSessions) {
            if (session.room == roomId && session.dayIndex in 1..5) {
                val day = days[session.dayIndex - 1]
                val startHour = session.safeStartVal.toInt()
                val baseName = "$day-${startHour.toString().padStart(2, '0')}:00"
                heatmap[baseName] = (heatmap[baseName] ?: 0.0) + 1.0
            }
        }

        return heatmap
    }

    fun getSmartRecommendation(
        allSessions: List<ClassSession>,
        userSchedule: List<ClassSession>,
        proximityPreference: Int
    ): RoomRecommendation {
        val weekday = TimeProvider.getCurrentWeekday()
        val currentHour = TimeProvider.getCurrentHour() + (TimeProvider.getCurrentMinute() / 60.0)
        val available = getAvailableRoomsNow(allSessions)

        if (available.isEmpty()) {
            return RoomRecommendation(
                recommended = null,
                reason = "No study spaces available right now",
                alternatives = emptyList()
            )
        }

        val nextUserClass = userSchedule
            .filter { s -> s.dayIndex == weekday && s.safeStartVal > currentHour }
            .minByOrNull { it.safeStartVal }

        val scored = available.map { room ->
            var score = room.studyScore
            score += (room.minutesFreeUntilNextSession ?: 60).toDouble() * 0.5

            if (nextUserClass != null) {
                score += proximityPreference.toDouble() * 0.01
            }

            score += room.amenities.size * 5.0
            room to score
        }.sortedByDescending { it.second }

        val best = scored.first().first
        val alternatives = scored.drop(1).take(2).map { it.first }

        var reason = "Currently available"
        best.minutesFreeUntilNextSession?.let { free ->
            reason = if (free > 120) {
                "Available for a long study session"
            } else {
                "Free for the next $free minutes"
            }
        }

        if (best.studyScore > 85) {
            reason += " • Ideal for focused study"
        }

        return RoomRecommendation(
            recommended = best,
            reason = reason,
            alternatives = alternatives
        )
    }

    private fun getNextSession(
        roomId: String,
        allSessions: List<ClassSession>,
        dayIndex: Int,
        currentHour: Double
    ): ClassSession? {
        return allSessions
            .filter { s -> s.room == roomId && s.dayIndex == dayIndex && s.safeStartVal > currentHour }
            .minByOrNull { it.safeStartVal }
    }

    private fun calculateStudyScore(
        room: Room,
        nextSession: ClassSession?,
        allAvailability: List<RoomAvailability>
    ): Double {
        var score = 100.0
        val currentHour = TimeProvider.getCurrentHour() + (TimeProvider.getCurrentMinute() / 60.0)

        if (nextSession != null) {
            val freeMinutes = (nextSession.safeStartVal - currentHour) * 60
            when {
                freeMinutes < 30 -> score -= 40.0
                freeMinutes < 60 -> score -= 20.0
                else -> score += 10.0
            }
        } else {
            score += 20.0
        }

        val buildingOccupancy = allAvailability.count { it.building == room.building && !it.isAvailable }
        val buildingTotal = allAvailability.count { it.building == room.building }

        if (buildingTotal > 0) {
            val density = buildingOccupancy.toDouble() / buildingTotal
            score -= (density * 30.0)
        }

        if (room.amenities.contains("AC")) score += 15.0
        if (room.amenities.contains("PC")) score += 10.0
        if (room.amenities.contains("Internet")) score += 5.0

        return score.coerceIn(0.0, 100.0)
    }

    private fun calculateConflictSeverity(s1: ClassSession, s2: ClassSession): String {
        val overlapStart = max(s1.safeStartVal, s2.safeStartVal)
        val overlapEnd = min(s1.safeEndVal, s2.safeEndVal)
        val overlap = overlapEnd - overlapStart
        return when {
            overlap >= 0.5 -> "HIGH"
            overlap >= 0.25 -> "MEDIUM"
            else -> "LOW"
        }
    }
}
