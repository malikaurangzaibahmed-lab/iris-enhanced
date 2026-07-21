package com.iris.ui.components

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.iris.ui.theme.IrisTokens

@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 20.dp,
    borderAlpha: Float = 0.15f,
    content: @Composable BoxScope.() -> Unit
) {
    Box(
        modifier = modifier
            .shadow(
                elevation = 8.dp,
                shape = RoundedCornerShape(cornerRadius),
                clip = false,
                ambientColor = Color.Black.copy(alpha = 0.05f),
                spotColor = Color.Black.copy(alpha = 0.1f)
            )
            .clip(RoundedCornerShape(cornerRadius))
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        Color.White.copy(alpha = 0.12f),
                        Color.White.copy(alpha = 0.04f)
                    )
                )
            )
            .border(
                width = 1.dp,
                brush = Brush.verticalGradient(
                    colors = listOf(
                        Color.White.copy(alpha = borderAlpha),
                        Color.White.copy(alpha = borderAlpha * 0.4f)
                    )
                ),
                shape = RoundedCornerShape(cornerRadius)
            ),
        content = content
    )
}

@Composable
fun IrisGlassSwitch(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    val trackWidth = 50.dp
    val trackHeight = 28.dp
    val thumbSize = 22.dp
    
    val thumbOffset by animateDpAsState(
        targetValue = if (checked) trackWidth - thumbSize - 3.dp else 3.dp
    )
    
    val activeColor = IrisTokens.brand
    val inactiveColor = Color.White.copy(alpha = 0.15f)
    
    Box(
        modifier = modifier
            .width(trackWidth)
            .height(trackHeight)
            .clip(RoundedCornerShape(radiusFull = true))
            .background(
                brush = Brush.verticalGradient(
                    colors = if (checked) {
                        listOf(activeColor.copy(alpha = 0.85f), activeColor.copy(alpha = 0.65f))
                    } else {
                        listOf(inactiveColor.copy(alpha = 0.15f), inactiveColor.copy(alpha = 0.05f))
                    }
                )
            )
            .border(
                width = 1.dp,
                color = Color.White.copy(alpha = if (checked) 0.3f else 0.1f),
                shape = RoundedCornerShape(radiusFull = true)
            )
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) {
                onCheckedChange(!checked)
            },
        contentAlignment = Alignment.CenterStart
    ) {
        Box(
            modifier = Modifier
                .offset(x = thumbOffset)
                .size(thumbSize)
                .shadow(
                    elevation = 4.dp,
                    shape = RoundedCornerShape(radiusFull = true)
                )
                .clip(RoundedCornerShape(radiusFull = true))
                .background(
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            Color.White,
                            Color.White.copy(alpha = 0.9f)
                        )
                    )
                )
        )
    }
}
