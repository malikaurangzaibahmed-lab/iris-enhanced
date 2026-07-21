package com.iris.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.iris.ui.components.GlassCard
import com.iris.ui.components.IrisGlassSwitch

@Composable
fun SettingsScreen(
    selectedBatch: String,
    onBatchChange: (String) -> Unit,
    isDarkMode: Boolean,
    onDarkModeToggle: (Boolean) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Text(
                text = "Portal Settings",
                fontSize = 24.sp,
                color = Color.White,
                fontWeight = FontWeight.Bold
            )
        }

        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Current Batch Selection",
                        fontSize = 12.sp,
                        color = Color.White.copy(alpha = 0.5f)
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = selectedBatch,
                        fontSize = 18.sp,
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }

        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier.padding(16.dp).fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Dark Theme",
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
                        )
                        Text(
                            text = "Enable system-wide obsidian dark mode.",
                            color = Color.White.copy(alpha = 0.5f),
                            fontSize = 12.sp
                        )
                    }
                    IrisGlassSwitch(
                        checked = isDarkMode,
                        onCheckedChange = onDarkModeToggle
                    )
                }
            }
        }

        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "System OTA Updates",
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "Check and sync latest timetable revisions directly.",
                        color = Color.White.copy(alpha = 0.5f),
                        fontSize = 12.sp
                    )
                }
            }
        }
    }
}
