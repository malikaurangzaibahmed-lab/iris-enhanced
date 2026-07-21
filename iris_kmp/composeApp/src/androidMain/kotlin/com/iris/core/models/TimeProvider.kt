package com.iris.core.models

import java.util.Calendar

actual object TimeProvider {
    actual fun getCurrentYear(): Int = Calendar.getInstance().get(Calendar.YEAR)
    actual fun getCurrentMonth(): Int = Calendar.getInstance().get(Calendar.MONTH) + 1
    actual fun getCurrentWeekday(): Int {
        val day = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
        return when (day) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 3
            Calendar.THURSDAY -> 4
            Calendar.FRIDAY -> 5
            Calendar.SATURDAY -> 6
            Calendar.SUNDAY -> 7
            else -> 1
        }
    }
    actual fun getCurrentHour(): Int = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
    actual fun getCurrentMinute(): Int = Calendar.getInstance().get(Calendar.MINUTE)
}
