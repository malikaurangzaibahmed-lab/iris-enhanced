# IRIS - Kotlin Multiplatform (KMP) Standalone Codebase

This is a standalone, independent Kotlin Multiplatform (KMP) + Compose Multiplatform project for the IRIS Student Companion application.

## 🚀 Getting Started

You can open the `/iris_kmp` directory directly in **Android Studio (Koala+)** or **IntelliJ IDEA** as a standalone project.

### Project Structure

* `/composeApp/src/commonMain/kotlin` - Shared declarative UI widgets and core business models/parsers.
* `/composeApp/src/androidMain` - Native Android entry point (`MainActivity`, resources, manifest).
* `/composeApp/src/iosMain` - Native iOS compilation framework bindings.

### Prerequisites

1. **JDK 17** set as your default compiler JVM.
2. **Android SDK** configured in your environment or via a local `local.properties` file:
   ```properties
   sdk.dir=C\:\\Users\\MALIK\\AppData\\Local\\Android\\Sdk
   ```
