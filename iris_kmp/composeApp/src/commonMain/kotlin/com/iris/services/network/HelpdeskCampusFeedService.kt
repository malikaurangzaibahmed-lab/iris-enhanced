package com.iris.services.network

object HelpdeskCampusFeedService {
    private var memoryCache: List<CampusNotice> = emptyList()

    fun filterByKeywords(items: List<CampusNotice>, keywords: List<String>): List<CampusNotice> {
        val lowered = keywords.map { it.lowercase() }
        return items.filter { notice ->
            val haystack = notice.searchable
            lowered.any { haystack.contains(it) }
        }.sortedByDescending { it.createdAtIso ?: "" }
    }
}
