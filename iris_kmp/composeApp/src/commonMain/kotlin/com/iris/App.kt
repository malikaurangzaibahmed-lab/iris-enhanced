package com.iris

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.iris.core.brain.OmniBrain
import com.iris.ui.components.GlassCard
import com.iris.ui.screens.DashboardScreen
import com.iris.ui.screens.SettingsScreen
import com.iris.ui.screens.TimetableScreen
import com.iris.ui.screens.ToolsScreen
import com.iris.ui.theme.IrisTokens

@Composable
fun App(brain: OmniBrain) {
    var currentTab by remember { mutableStateOf("Dashboard") }
    var selectedBatch by remember { mutableStateOf("FA21-BCS-6-A") }
    var isDarkMode by remember { mutableStateOf(true) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                brush = Brush.verticalGradient(
                    colors = if (isDarkMode) {
                        listOf(Color(0xFF0F0C20), Color(0xFF05020F))
                    } else {
                        listOf(Color(0xFFF2F4F8), Color(0xFFE2E6EF))
                    }
                )
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .navigationBarsPadding()
                .statusBarsPadding()
        ) {
            Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
                when (currentTab) {
                    "Dashboard" -> DashboardScreen(brain, selectedBatch, isDarkMode)
                    "Timetable" -> TimetableScreen(brain, selectedBatch)
                    "Tools" -> ToolsScreen(onNavigateToTool = {})
                    "Settings" -> SettingsScreen(
                        selectedBatch = selectedBatch,
                        onBatchChange = { selectedBatch = it },
                        isDarkMode = isDarkMode,
                        onDarkModeToggle = { isDarkMode = it }
                    )
                }
            }

            // High Fidelity Frosted Bottom Dock
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 12.dp),
                contentAlignment = Alignment.Center
            ) {
                GlassCard(
                    cornerRadius = 24.dp,
                    borderAlpha = 0.2f,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 12.dp, horizontal = 16.dp),
                        horizontalArrangement = Arrangement.SpaceAround,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        val tabs = listOf("Dashboard", "Timetable", "Tools", "Settings")
                        tabs.forEach { tab ->
                            val isSelected = currentTab == tab
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(12.dp))
                                    .clickable { currentTab = tab }
                                    .padding(horizontal = 14.dp, vertical = 8.dp)
                            ) {
                                Text(
                                    text = tab.take(4),
                                    color = if (isSelected) IrisTokens.brand else Color.White.copy(alpha = 0.5f),
                                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                    fontSize = 13.sp
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
