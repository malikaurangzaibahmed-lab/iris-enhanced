package com.iris.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.dp

object IrisTokens {
    val brand = Color(0xFF007AFF)
    val brandLight = Color(0xFF58A1FF)
    val brandDark = Color(0xFF0056B3)
    val surfaceDark = Color(0xFF000000)
    val surfaceLightElevated = Color(0xFFFFFFFF)
    val brandGradient = listOf(brand, brandLight)

    val sunsetGradient = listOf(
        Color(0xFFFF6B9D),
        Color(0xFFC239B3)
    )
    val oceanGradient = listOf(
        Color(0xFF00C9FF),
        Color(0xFF92FE9D)
    )
    val successGradient = listOf(
        Color(0xFF00E5A0),
        Color(0xFF00D9F5)
    )

    val surfaceLight = Color(0xFFF2F2F7)
    val surfaceDarkElevated = Color(0xFF1C1C1E)

    val success = Color(0xFF00E5A0)
    val successDark = Color(0xFF00D9F5)
    val warning = Color(0xFFFFB800)
    val warningDark = Color(0xFFFF8A00)
    val error = Color(0xFFFF6B6B)
    val errorDark = Color(0xFFFF4757)
    val info = Color(0xFF5B7FFF)

    val purple = Color(0xFF8B6EFF)
    val purpleLight = Color(0xFFB794F6)
    val blue = Color(0xFF5B9EFF)
    val blueLight = Color(0xFF8BB5FF)
    val pink = Color(0xFFFF6B9D)
    val pinkLight = Color(0xFFFFB3C6)
    val teal = Color(0xFF00D9F5)
    val tealLight = Color(0xFF7FEFFF)

    val space4 = 4.dp
    val space8 = 8.dp
    val space12 = 12.dp
    val space16 = 16.dp
    val space20 = 20.dp
    val space24 = 24.dp
    val space28 = 28.dp
    val space32 = 32.dp
    val space40 = 40.dp
    val space48 = 48.dp
    val space56 = 56.dp
    val space64 = 64.dp

    val radius8 = 8.dp
    val radius12 = 12.dp
    val radius16 = 16.dp
    val radius20 = 20.dp
    val radius24 = 24.dp
    val radius28 = 28.dp
    val radius32 = 32.dp
    val radius36 = 36.dp
    val radiusFull = 9999.dp

    val cardRadius = RoundedCornerShape(20.dp)
    val buttonRadius = RoundedCornerShape(14.dp)
    val chipRadius = RoundedCornerShape(10.dp)
}
