# IRIS KMP Architecture Guidelines & Code Conversion Map

This document outlines how files in the Flutter/Dart codebase map to Kotlin components in this Kotlin Multiplatform (KMP) + Compose Multiplatform setup.

---

## 📁 Source Package Structure

All shared logic and UI resides in `:composeApp/src/commonMain/kotlin/com/iris/`:

```
com/iris/
│
├── core/             # Core memory, data structures, and state controllers
│   ├── models/       # Data representation (ClassSession, BatchKey, etc.)
│   ├── tokens/       # HSL Color Tokens, Gradients, and Typography styles
│   └── brain/        # OmniBrain state machine and query routers
│
├── services/         # Scrapers, API clients, local DB persistence, and notifications
│   ├── network/      # Ktor REST API Client & sync engines
│   ├── parser/       # Timetable HTML & PDF parsing engines
│   └── systems/      # Foreground service trackers and widgets triggers
│
└── ui/               # Declarative Compose UI screens and layouts
    ├── components/   # GlassCard, GlassSwitch, DashboardDock, Buttons
    ├── theme/        # Material3 color systems, gradients, and custom painters
    └── screens/      # PortalSync, AcademicsHub, DepartmentClasses, AboutSettings
```

---

## 🔄 Core Class Mapping Table

Use the following reference map to locate Dart files and their equivalent Kotlin targets:

| Dart File & Class | Kotlin Class Target | Migration Details & Libraries |
| :--- | :--- | :--- |
| `UniversityMemory` | `com.iris.core.UniversityMemory` | Uses Kotlinx Serialization to parse JSON database instead of raw Dart JSON maps. |
| `OmniBrain` | `com.iris.core.OmniBrain` | Shared Kotlin class utilizing Coroutines Flow/StateFlow for state emissions. |
| `ClassSession` | `com.iris.core.models.ClassSession` | standard Kotlin data class annotated with `@Serializable`. |
| `HelpdeskCampusFeedService` | `com.iris.services.network.HelpdeskClient` | Built using **Ktor HTTP Client** utilizing okhttp (Android) and darwin (iOS) engines. |
| `GlassSurface` | `com.iris.ui.components.GlassSurface` | Implemented via custom Compose `Modifier.drawWithContent` implementing frosted backdrop blur constraints. |
| `IrisGlassSwitch` | `com.iris.ui.components.IrisGlassSwitch` | Custom Compose widget with sliding animation states handled by `animateDpAsState` and canvas-drawn circles. |

---

## ⚡ Async, Threading & Signals

1. **State Management**:
   Replace Dart signals or `ValueNotifier` with **Kotlin StateFlow / SharedFlow**:
   ```kotlin
   // Example Flow inside OmniBrain
   private val _memoryState = MutableStateFlow<UniversityMemory?>(null)
   val memoryState: StateFlow<UniversityMemory?> = _memoryState.asStateFlow()
   ```

2. **Threading**:
   Replace Dart `Future` with Kotlin **Coroutines** using `suspend` functions, executing heavy parsing tasks on `Dispatchers.Default`:
   ```kotlin
   suspend fun parseTimetablePdf(pdfBytes: ByteArray): List<ClassSession> = withContext(Dispatchers.Default) {
       // High performance parsing logic here
   }
   ```
