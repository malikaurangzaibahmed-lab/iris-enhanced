package com.iris.core.models

expect object TimeProvider {
    fun getCurrentYear(): Int
    fun getCurrentMonth(): Int
    fun getCurrentWeekday(): Int
    fun getCurrentHour(): Int
    fun getCurrentMinute(): Int
}
