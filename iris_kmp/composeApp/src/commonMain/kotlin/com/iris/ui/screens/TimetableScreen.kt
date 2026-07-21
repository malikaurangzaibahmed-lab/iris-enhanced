package com.iris.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.iris.core.brain.OmniBrain
import com.iris.ui.components.GlassCard
import com.iris.ui.theme.IrisTokens

@Composable
fun TimetableScreen(
    brain: OmniBrain,
    selectedBatch: String
) {
    var selectedDayIndex by remember { mutableStateOf(1) } // 1 = Monday
    val days = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

    val schedule = brain.scheduleFor(selectedBatch)
    val daySchedule = schedule.filter { it.dayIndex == selectedDayIndex }

    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "Class Timetable",
            fontSize = 24.sp,
            color = Color.White,
            fontWeight = FontWeight.Bold
        )

        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            items(days.size) { index ->
                val dayName = days[index]
                val dayNum = index + 1
                val isSelected = selectedDayIndex == dayNum

                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(
                            if (isSelected) IrisTokens.brand else Color.White.copy(alpha = 0.08f)
                        )
                        .clickable { selectedDayIndex = dayNum }
                        .padding(horizontal = 16.dp, vertical = 10.dp)
                ) {
                    Text(
                        text = dayName,
                        color = if (isSelected) Color.White else Color.White.copy(alpha = 0.6f),
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp
                    )
                }
            }
        }

        LazyColumn(
            modifier = Modifier.weight(1f).fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (daySchedule.isEmpty()) {
                item {
                    GlassCard(modifier = Modifier.fillMaxWidth()) {
                        Box(
                            modifier = Modifier.padding(32.dp).fillMaxWidth(),
                            contentAlignment = Alignment.Center
                        ) {
                            Text("No classes scheduled for today", color = Color.White.copy(alpha = 0.5f))
                        }
                    }
                }
            } else {
                items(daySchedule.size) { index ->
                    val session = daySchedule[index]
                    GlassCard(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    text = session.subject,
                                    fontSize = 16.sp,
                                    color = Color.White,
                                    fontWeight = FontWeight.Bold,
                                    modifier = Modifier.weight(1f)
                                )
                                Box(
                                    modifier = Modifier
                                        .background(Color.White.copy(alpha = 0.1f), RoundedCornerShape(8.dp))
                                        .padding(horizontal = 8.dp, vertical = 4.dp)
                                ) {
                                    Text(session.room, color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "${session.startTime} - ${session.endTime}",
                                fontSize = 13.sp,
                                color = Color.White.copy(alpha = 0.7f)
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = session.teacher,
                                fontSize = 12.sp,
                                color = Color.White.copy(alpha = 0.5f)
                            )
                        }
                    }
                }
            }
        }
    }
}
