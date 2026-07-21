package com.iris.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.iris.core.brain.OmniBrain
import com.iris.ui.components.GlassCard
import com.iris.ui.theme.IrisTokens

@Composable
fun DashboardScreen(
    brain: OmniBrain,
    selectedBatch: String,
    isDark: Boolean
) {
    val metrics = brain.getVitalMetrics(selectedBatch)
    val todaySchedule = brain.scheduleFor(selectedBatch)

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Column {
                Text(
                    text = "Welcome Back",
                    fontSize = 14.sp,
                    color = Color.White.copy(alpha = 0.5f),
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = "Student Portal Sync",
                    fontSize = 24.sp,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            }
        }

        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text(
                        text = "Attendance Health",
                        fontSize = 14.sp,
                        color = Color.White.copy(alpha = 0.7f),
                        fontWeight = FontWeight.Medium
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "${(metrics.attendanceHealth * 100).toInt()}%",
                        fontSize = 32.sp,
                        color = Color.White,
                        fontWeight = FontWeight.ExtraBold
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Calculated across today's academic schedule",
                        fontSize = 12.sp,
                        color = Color.White.copy(alpha = 0.5f)
                    )
                }
            }
        }

        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                GlassCard(modifier = Modifier.weight(1f)) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("Today's Classes", color = Color.White.copy(alpha = 0.7f), fontSize = 12.sp)
                        Text("${metrics.totalClassesToday}", color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                    }
                }
                GlassCard(modifier = Modifier.weight(1f)) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("Completed", color = Color.White.copy(alpha = 0.7f), fontSize = 12.sp)
                        Text("${metrics.completedClasses}", color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }

        item {
            Text(
                text = "Today's Schedule",
                fontSize = 16.sp,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 8.dp)
            )
        }

        if (todaySchedule.isEmpty()) {
            item {
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Box(
                        modifier = Modifier.padding(24.dp).fillMaxWidth(),
                        contentAlignment = Alignment.Center
                    ) {
                        Text("No classes scheduled for today", color = Color.White.copy(alpha = 0.5f))
                    }
                }
            }
        } else {
            items(todaySchedule.size) { index ->
                val session = todaySchedule[index]
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
                                    .background(
                                        brush = Brush.horizontalGradient(IrisTokens.brandGradient),
                                        shape = RoundedCornerShape(8.dp)
                                    )
                                    .padding(horizontal = 8.dp, vertical = 4.dp)
                            ) {
                                Text(session.room, color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "${session.startTime} - ${session.endTime} • ${session.teacher}",
                            fontSize = 13.sp,
                            color = Color.White.copy(alpha = 0.7f)
                        )
                    }
                }
            }
        }
    }
}
