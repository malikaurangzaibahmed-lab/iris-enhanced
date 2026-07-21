package com.iris.services.network

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*

enum class HelpdeskCampusFeedSource { LIVE, CACHE, BACKUP, NONE }

@Serializable
data class CampusNotice(
    val id: String,
    val title: String,
    val detail: String,
    val createdBy: String,
    val createdAtIso: String? = null
) {
    val searchable: String
        get() = "${title.lowercase()} ${detail.lowercase()} ${createdBy.lowercase()}"

    companion object {
        fun fromJsonObject(json: JsonObject): CampusNotice {
            return CampusNotice(
                id = json["_id"]?.jsonPrimitive?.contentOrNull ?: json["id"]?.jsonPrimitive?.contentOrNull ?: "",
                title = json["title"]?.jsonPrimitive?.contentOrNull ?: "",
                detail = json["detail"]?.jsonPrimitive?.contentOrNull ?: "",
                createdBy = json["createdBy"]?.jsonPrimitive?.contentOrNull ?: "",
                createdAtIso = json["createdAt"]?.jsonPrimitive?.contentOrNull
            )
        }
    }

    fun toJsonObject(): JsonObject {
        return buildJsonObject {
            put("_id", id)
            put("title", title)
            put("detail", detail)
            put("createdBy", createdBy)
            if (createdAtIso != null) {
                put("createdAt", createdAtIso)
            }
        }
    }
}

data class CampusNoticePayload(
    val items: List<CampusNotice>,
    val source: HelpdeskCampusFeedSource
)
