---
name: iris-agents
---

# IRIS Custom Agents

This document describes all custom agents available for the IRIS project. Use the appropriate agent for your task to get specialized guidance and recommendations.

## Agent Directory

### 1. Flutter UI Agent
**Use when**: Building widgets, creating screens, implementing animations, handling theming

**Focus areas**:
- Widget development and architecture
- Responsive design patterns
- Theme switching (light/dark mode)
- Animation implementation
- Material Design guidelines
- Widget performance optimization

**Files it applies to**:
- `lib/screens/**/*.dart`
- `lib/widgets/**/*.dart`
- `lib/themes/**/*.dart`

**Key commands**:
```
/flutter-ui <task description>
```

**Example tasks**:
- "Create a responsive timetable widget that supports dark mode"
- "Implement smooth scroll animation for class list"
- "Fix widget rebuild performance issue"

---

### 2. Dart Backend Agent  
**Use when**: Implementing services, creating models, managing state, writing utilities

**Focus areas**:
- Service layer architecture
- Data model design and serialization
- State management with Provider
- Business logic implementation
- Error handling and logging
- Performance optimization

**Files it applies to**:
- `lib/services/**/*.dart`
- `lib/models/**/*.dart`
- `lib/providers/**/*.dart`
- `lib/utils/**/*.dart`

**Key commands**:
```
/dart-backend <task description>
```

**Example tasks**:
- "Create a timetable service with caching"
- "Design student model with Firestore serialization"
- "Set up state management for authentication"
- "Implement error handling for API calls"

---

### 3. Firebase Operations Agent
**Use when**: Setting up Firestore, writing security rules, implementing auth, deploying functions

**Focus areas**:
- Firestore database design
- Security rules implementation
- Authentication flows
- Cloud Functions deployment
- Query optimization and indexing
- Firebase configuration

**Files it applies to**:
- `firestore.rules`
- `firestore.indexes.json`
- `firebase.json`
- `lib/services/firebase*.dart`

**Key commands**:
```
/firebase-ops <task description>
```

**Example tasks**:
- "Set up Firestore security rules for student data"
- "Create composite indexes for timetable queries"
- "Implement Firebase Auth sign-up flow"
- "Deploy Cloud Function for timetable synchronization"

---

### 4. Android Native Agent
**Use when**: Building Android widgets, writing Kotlin code, handling platform channels

**Focus areas**:
- Android AppWidget development
- Kotlin best practices
- Platform channel communication (Flutter ↔ Android)
- Native integration
- Gradle configuration
- APK optimization

**Files it applies to**:
- `android/**/*.kt`
- `android/**/*.kts`
- `android_liquid_glass_view/**`

**Key commands**:
```
/android-native <task description>
```

**Example tasks**:
- "Create homescreen widget for today's classes"
- "Set up platform channel for widget updates"
- "Optimize Android build size"
- "Implement widget update service"

---

## Special Purpose Agents (External)

### Explore Agent
**Use when**: Quick codebase exploration, understanding structure, finding patterns

**Usage**:
```
@Explore Find how timetable data flows through the app (quick)
```

**Thoroughness levels**:
- `quick` - Basic search and overview
- `medium` - Detailed analysis of key files
- `thorough` - Comprehensive investigation

---

### Clanker Agent
**Use when**: Complex, multi-step code changes with validation

**Usage**:
```
@Clanker Refactor services to use dependency injection pattern
```

---

## Skill vs Agent vs Instructions

### Use an **Agent** (/command) when:
- Need specialized guidance for a task
- Want domain-specific best practices
- Working with related files across the project
- Need to understand patterns and architecture

### Use a **Skill** (/skill_name) when:
- Need deep domain knowledge
- Building complex features
- Troubleshooting specific issues
- Want complete workflow documentation

**Available skills**:
- `/iris-architecture` - System design and data flow
- `/performance-profiling` - Performance optimization
- `/documentation-standards` - Code and docs standards

### Use **File Instructions** when:
- Working on specific file types
- Need local guidelines for a feature area
- File pattern auto-applies instructions

**Auto-applied instructions**:
- `widgets.instructions.md` - Applied to `lib/widgets/**`
- `services.instructions.md` - Applied to `lib/services/**`
- `firebase.instructions.md` - Applied to Firebase files

---

## Workflow Examples

### Building a New Feature: Student Filtering

1. **Plan architecture** → Use `/iris-architecture` skill
2. **Design data model** → Use `/dart-backend` agent
3. **Build filter UI** → Use `/flutter-ui` agent
4. **Add Firestore filtering** → Use `/firebase-ops` agent
5. **Optimize performance** → Use `/performance-profiling` skill
6. **Document** → Use `/documentation-standards` skill

### Debugging Slow Timetable Load

1. **Profile with tools** → Use `/performance-profiling` skill
2. **Optimize queries** → Use `/firebase-ops` agent
3. **Cache results** → Use `/dart-backend` agent
4. **Verify UI performance** → Use `/flutter-ui` agent

### Creating Android Widget

1. **Design widget layout** → Use `/android-native` agent
2. **Implement Kotlin code** → Use `/android-native` agent
3. **Set up Flutter integration** → Use `/dart-backend` agent
4. **Test communication** → Use `/android-native` agent

---

## Agent Communication

### When to Escalate Between Agents

```
Flutter UI Agent ←→ Dart Backend Agent
        ↓                    ↓
   State Management    Business Logic

        ↓                    ↓
     Providers ←→ Services
        
                     ↓
              Firebase Operations Agent
                     
                     ↓
              Android Native Agent
```

**Example escalation flow**:
- Start: "Build class reminder widget"
- Flutter UI creates widget component
- Needs state → Escalate to Dart Backend
- State needs data → Escalate to Firebase Operations
- Firebase needs to sync → Back to Dart Backend
- Widget needs to update → Back to Flutter UI

---

## Best Practices

### 1. Start with the Right Agent
- Check file location
- Identify primary concern
- Use matching agent

### 2. Provide Context
```
❌ Poor: "Fix the widget"
✅ Good: "ClassCard widget is rebuilding too often, causing jank on scroll"
```

### 3. Use Skills for Deep Dives
```
❌ Agent alone: "Why is my app slow?"
✅ With skill: "Why is my app slow? (Use /performance-profiling)"
```

### 4. Chain Tasks Logically
- Don't jump between agents randomly
- Follow data flow through layers
- Return to UI after backend changes

### 5. Reference Documentation
- Link to relevant docs/skills
- Use example code patterns
- Verify against standards

---

## Agent Selection Matrix

| Task | Agent | Skill | Instructions |
|------|-------|-------|--------------|
| Create widget | flutter-ui | - | widgets |
| Design model | dart-backend | iris-architecture | - |
| Firestore query | firebase-ops | iris-architecture | firebase |
| Android widget | android-native | - | - |
| Performance issue | any + | performance-profiling | - |
| Code standards | - | documentation-standards | specific |
| API design | dart-backend | iris-architecture | - |
| Error handling | dart-backend | iris-architecture | services |
| Theme support | flutter-ui | - | widgets |
| Data flow | - | iris-architecture | - |
| Memory leak | dart-backend + | performance-profiling | - |
| Security rules | firebase-ops | - | firebase |

---

## Troubleshooting

### Agent Not Responding to Your Task

**Reasons**:
1. Task outside agent's domain → Try different agent
2. Vague request → Add more context/examples
3. Multiple concerns → Break into smaller tasks

**Solution**: Ask the agent directly, or switch agents

### Agent Recommendation Seems Wrong

**Check**:
1. Is this really the best domain?
2. Could multiple agents help?
3. Should I use a skill first?

**Solution**: Use `/iris-architecture` to understand flow, then retry

### Need Guidance Across Multiple Agents

**Solution**:
1. Start with `/iris-architecture` skill
2. Identify which agent handles each part
3. Work through agents in data flow order
4. Use `/documentation-standards` at the end

---

## Creating New Agents

To add a new custom agent to IRIS:

1. Determine scope (file types it applies to)
2. Create `.github/agents/name.agent.md` file
3. Add `name` and `description` in frontmatter
4. Document responsibilities and best practices
5. Include code patterns and checklists
6. Update this AGENTS.md with new entry
7. Consider related skills needed

Example frontmatter:
```yaml
---
name: testing-agent
description: "Specialized agent for writing and running tests. Use when: creating unit tests, widget tests, debugging flaky tests, or improving test coverage."
applyTo: "test/**/*.dart"
---
```

---

## Quick Reference

```
Tasks → Agents:
├─ "Build widget" → flutter-ui
├─ "Create service" → dart-backend
├─ "Set up Firestore" → firebase-ops
├─ "Make Android widget" → android-native
├─ "Slow performance?" → /performance-profiling
├─ "Understand flow?" → /iris-architecture
└─ "Update docs?" → /documentation-standards
```
