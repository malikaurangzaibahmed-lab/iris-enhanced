package com.iris.core.brain

import kotlinx.serialization.Serializable

@Serializable
data class CgpaCourse(
    val name: String,
    val credits: Double,
    val grade: String
) {
    val gradePoint: Double
        get() = CgpaCalculator.gradePoints[grade] ?: 0.0
}

object CgpaCalculator {
    val gradePoints = mapOf(
        "A" to 4.0,
        "A-" to 3.67,
        "B+" to 3.33,
        "B" to 3.00,
        "B-" to 2.67,
        "C+" to 2.33,
        "C" to 2.00,
        "C-" to 1.67,
        "D+" to 1.33,
        "D" to 1.00,
        "F" to 0.0
    )

    fun calculateGpa(courses: List<CgpaCourse>): Double {
        var qualityPoints = 0.0
        var totalCredits = 0.0
        for (course in courses) {
            if (course.credits <= 0) continue
            qualityPoints += course.credits * course.gradePoint
            totalCredits += course.credits
        }
        return if (totalCredits > 0) qualityPoints / totalCredits else 0.0
    }
}
