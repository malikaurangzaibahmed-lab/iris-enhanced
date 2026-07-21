package com.iris.core

import com.iris.core.models.ClassSession
import com.iris.core.models.UniversityMemory
import kotlinx.serialization.json.*

object UniversityMemoryLoader {
    fun decodeTimetableJson(raw: String): List<ClassSession> {
        val json = try {
            Json.parseToJsonElement(raw)
        } catch (e: Exception) {
            return emptyList()
        }
        
        val list = mutableListOf<JsonObject>()
        if (json is JsonArray) {
            for (element in json) {
                if (element is JsonObject) {
                    list.add(element)
                }
            }
        } else if (json is JsonObject && json["sessions"] is JsonArray) {
            val sessionsArray = json["sessions"] as JsonArray
            for (element in sessionsArray) {
                if (element is JsonObject) {
                    list.add(element)
                }
            }
        }
        
        return list.map { ClassSession.fromJsonObject(it) }
    }
}
