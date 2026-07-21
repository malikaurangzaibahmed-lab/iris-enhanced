package com.iris.core.models

import platform.Foundation.NSCalendar
import platform.Foundation.NSDate
import platform.Foundation.NSCalendarUnitYear
import platform.Foundation.NSCalendarUnitMonth
import platform.Foundation.NSCalendarUnitWeekday
import platform.Foundation.NSCalendarUnitHour
import platform.Foundation.NSCalendarUnitMinute

actual object TimeProvider {
    actual fun getCurrentYear(): Int {
        val calendar = NSCalendar.currentCalendar
        return calendar.component(NSCalendarUnitYear, fromDate = NSDate()).toInt()
    }
    actual fun getCurrentMonth(): Int {
        val calendar = NSCalendar.currentCalendar
        return calendar.component(NSCalendarUnitMonth, fromDate = NSDate()).toInt()
    }
    actual fun getCurrentWeekday(): Int {
        val calendar = NSCalendar.currentCalendar
        val day = calendar.component(NSCalendarUnitWeekday, fromDate = NSDate()).toInt()
        return when (day) {
            2 -> 1 // Monday
            3 -> 2 // Tuesday
            4 -> 3 // Wednesday
            5 -> 4 // Thursday
            6 -> 5 // Friday
            7 -> 6 // Saturday
            1 -> 7 // Sunday
            else -> 1
        }
    }
    actual fun getCurrentHour(): Int {
        val calendar = NSCalendar.currentCalendar
        return calendar.component(NSCalendarUnitHour, fromDate = NSDate()).toInt()
    }
    actual fun getCurrentMinute(): Int {
        val calendar = NSCalendar.currentCalendar
        return calendar.component(NSCalendarUnitMinute, fromDate = NSDate()).toInt()
    }
}
