package com.iris.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.iris.ui.components.GlassCard
import com.iris.ui.theme.IrisTokens

data class ToolItem(
    val title: String,
    val description: String,
    val color: Color
)

@Composable
fun ToolsScreen(
    onNavigateToTool: (String) -> Unit
) {
    val tools = listOf(
        ToolItem("CGPA Planner", "Calculate target grades and forecast semester progress.", IrisTokens.brand),
        ToolItem("Room Finder", "Locate empty classrooms and quiet study spaces.", IrisTokens.success),
        ToolItem("Portal Sync", "Instantly synchronize grades, files, and attendance.", IrisTokens.warning),
        ToolItem("Faculty Directory", "Access email addresses and office locations.", IrisTokens.purple)
    )

    Column(
        modifier = Modifier.fillMaxSize().padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "Resources & Tools",
            fontSize = 24.sp,
            color = Color.White,
            fontWeight = FontWeight.Bold
        )

        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.weight(1f)
        ) {
            items(tools.size) { index ->
                val tool = tools[index]
                GlassCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(150.dp)
                        .clickable { onNavigateToTool(tool.title) }
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.SpaceBetween
                    ) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .background(
                                    brush = Brush.verticalGradient(
                                        listOf(tool.color, tool.color.copy(alpha = 0.6f))
                                    ),
                                    shape = RoundedCornerShape(10.dp)
                                )
                        )
                        Column {
                            Text(
                                text = tool.title,
                                color = Color.White,
                                fontWeight = FontWeight.Bold,
                                fontSize = 15.sp
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = tool.description,
                                color = Color.White.copy(alpha = 0.5f),
                                fontSize = 11.sp,
                                lineHeight = 14.sp
                            )
                        }
                    }
                }
            }
        }
    }
}
