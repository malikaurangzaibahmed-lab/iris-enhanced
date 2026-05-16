# IRIS AI Customization System - Quick Start

## What's Been Set Up

Your IRIS project now has a **comprehensive AI customization system** with specialized agents, skills, hooks, and file instructions to help you throughout development.

### 📂 Structure
```
.github/
├── agents/                    # 4 specialized agents
├── skills/                    # 3 domain skills  
├── instructions/              # 3 file-specific guidelines
├── hooks/                     # Automated code analysis
├── AGENTS.md                  # Agent documentation
└── 👈 You are here
```

### 🤖 Components Created

#### **4 Specialized Agents** (use with `/` prefix in chat)

1. **`/flutter-ui`** - Widget development, screens, animations
2. **`/dart-backend`** - Services, models, state management
3. **`/firebase-ops`** - Firestore, auth, cloud functions
4. **`/android-native`** - Kotlin, Android widgets, platform channels

Each agent has:
- ✅ Specialized knowledge and best practices
- ✅ Code patterns and examples
- ✅ Checklists for completeness
- ✅ Common issues & solutions

#### **3 Domain Skills** (use with skill search)

1. **`iris-architecture`** - System design, data flow, components
2. **`performance-profiling`** - Performance optimization, debugging
3. **`documentation-standards`** - Code docs, keeping docs in sync

#### **3 File Instructions** (auto-applied)

1. **`widgets.instructions.md`** - Applied to `lib/widgets/**`
2. **`services.instructions.md`** - Applied to `lib/services/**`
3. **`firebase.instructions.md`** - Applied to `firestore.rules`, Firebase files

#### **Automated Code Analysis** 

Hook checks for:
- ✅ Missing dartdoc comments
- ✅ Memory leak patterns (unclean streams)
- ✅ Performance antipatterns (ListView vs ListView.builder)
- ✅ Security issues (Firestore rules, auth)
- ✅ Const constructor usage
- ✅ Error handling completeness
- ✅ Documentation synchronization
- ✅ Firestore index requirements

---

## How to Use

### 🎯 Step 1: Identify Your Task

**What are you working on?**

| If you're... | Use agent | Use skill |
|---|---|---|
| Building UI widgets | `/flutter-ui` | - |
| Creating services/models | `/dart-backend` | - |
| Setting up Firestore | `/firebase-ops` | - |
| Writing Android code | `/android-native` | - |
| Understanding architecture | - | `/iris-architecture` |
| Optimizing performance | - | `/performance-profiling` |
| Writing documentation | - | `/documentation-standards` |

### 🎯 Step 2: Choose Your Approach

#### **Option A: Use an Agent** (Most tasks)
```
/flutter-ui Create a responsive class card widget with dark mode support
```

The agent will:
- Provide specialized guidance
- Share code patterns from IRIS
- Include checklist for your task
- Link to relevant documentation

#### **Option B: Use a Skill** (Complex topics)
```
/performance-profiling I think my timetable screen is slow
```

The skill will:
- Help you diagnose the issue
- Provide profiling instructions
- Show optimization techniques
- Include before/after examples

#### **Option C: Auto-Applied Instructions** (File-specific)
When you work on `lib/widgets/my_widget.dart`, you'll automatically get guidance on:
- Const constructors
- Theme support
- Responsive design
- Testing requirements

### 🎯 Step 3: Follow the Guidance

Each agent/skill provides:
1. **Context** - What to focus on
2. **Patterns** - Proven code examples
3. **Checklist** - Completeness criteria
4. **Links** - Related documentation

---

## Example Workflows

### Workflow 1: Add a New Widget
```
1. Use /flutter-ui agent
   ↓
2. Follow widget best practices (const, theme, responsive)
   ↓
3. Auto-applied widgets.instructions.md checks your code
   ↓
4. ✅ Done with high-quality widget
```

### Workflow 2: Create Timetable Service
```
1. Use /dart-backend agent
   ↓
2. Follow service patterns (DI, error handling, docs)
   ↓
3. Auto-applied services.instructions.md validates
   ↓
4. ✅ Done with tested, documented service
```

### Workflow 3: Set Up Firestore
```
1. Use /firebase-ops agent
   ↓
2. Write secure rules and indexes
   ↓
3. Auto-applied firebase.instructions.md verifies
   ↓
4. ✅ Done with secure, optimized Firestore
```

### Workflow 4: Debug Performance Issue
```
1. Use /performance-profiling skill
   ↓
2. Profile with provided tools/commands
   ↓
3. Apply specific optimization from skill
   ↓
4. ✅ Issue resolved with measurable improvement
```

---

## Key Features

### ✨ Smart Guidance
- Agents understand your file location
- Recommendations adapt to context
- Auto-applied instructions catch common mistakes

### 📚 Documentation Always in Sync
- Code examples are from IRIS codebase
- Patterns reflect actual usage
- Instructions change with codebase

### 🔍 Automated Code Analysis
- Detects missing dartdoc
- Catches memory leak patterns
- Validates Firestore security
- Suggests performance improvements

### 🎓 Learning Path
- Start with specific agents
- Deepen knowledge with skills
- Learn patterns from instructions
- Reference master documentation

---

## Master Documentation

### Quick Links
- **[AGENTS.md](.github/AGENTS.md)** - All agents explained
- **[copilot-instructions.md](copilot-instructions.md)** - Project overview
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System design

### Skills (Search or Link)
- **iris-architecture** - Data flow, components, patterns
- **performance-profiling** - Performance optimization guide
- **documentation-standards** - Docs best practices

---

## Tips & Tricks

### 💡 Pro Tips

1. **Use agents for specific tasks**
   ```
   ❌ Too vague: "Help me with the app"
   ✅ Better: "Create a reminder notification widget" + /flutter-ui
   ```

2. **Combine agent + skill for complex issues**
   ```
   /dart-backend + /iris-architecture (for context)
   ```

3. **Check file instructions first**
   - Auto-applied when editing `lib/widgets/` files
   - Provides context-specific guidance

4. **Reference the AGENTS.md when stuck**
   - Shows which agent handles what
   - Selection matrix helps choose
   - Troubleshooting guide included

### 🚀 Quick Start Commands

```bash
# Get started with each agent
/flutter-ui Create a new screen
/dart-backend Create a new service
/firebase-ops Set up Firestore
/android-native Create Android widget

# Deep dive into specific areas
/iris-architecture  # Understand system
/performance-profiling  # Optimize app
/documentation-standards  # Write docs
```

---

## Next Steps

### Immediate (Today)
1. ✅ Read [.github/AGENTS.md](.github/AGENTS.md) for agent overview
2. ✅ Try one agent for a task you're working on
3. ✅ Notice auto-applied instructions on relevant files

### Soon (This Week)
1. ✅ Use `/iris-architecture` to understand data flow
2. ✅ Try `/performance-profiling` if you have speed concerns
3. ✅ Use `/documentation-standards` for docs work

### Ongoing
1. ✅ Use appropriate agent for each task type
2. ✅ Reference skills for deep topics
3. ✅ Keep documentation updated (skill guides you)
4. ✅ Let code analysis catch issues

---

## Customization Levels

### Level 1: Basic (What you have)
- ✅ 4 specialized agents
- ✅ 3 domain skills
- ✅ 3 file instructions
- ✅ Automated analysis

### Level 2: Enhanced (Optional)
Could add:
- More specialized agents (Testing, DevOps, etc.)
- Custom prompts for common tasks
- Team guidelines and standards
- Git hooks for automated checks

### Level 3: Advanced (Future)
Could add:
- MCP servers for external tools
- Custom analysis plugins
- AI-assisted code review
- Automated refactoring

---

## Troubleshooting

### "Agent not responding to my task"
→ Check if task fits agent's domain in AGENTS.md → Try different agent or skill

### "Getting generic advice instead of IRIS-specific"
→ Provide more context → Reference IRIS architecture → Use `/iris-architecture` first

### "Instructions conflict with my workflow"
→ They're guidelines, not rules → Adapt as needed → Update if better pattern found

### "Can't find the right agent"
→ Check AGENTS.md selection matrix → Use `/iris-architecture` for overview

---

## Support

Need help using the system?

1. **Check [.github/AGENTS.md](.github/AGENTS.md)** - Comprehensive agent guide
2. **Review example workflows** above - Real-world patterns
3. **Use /iris-architecture skill** - Understand system better
4. **Ask the agents directly** - They know themselves best

---

## Success Indicators

You're using the system well when:
- ✅ You consistently use agents matching your file type
- ✅ Code follows patterns from agent guidance
- ✅ Documentation stays in sync with code
- ✅ Performance is optimized per guidelines
- ✅ New team members use AGENTS.md to onboard
- ✅ Auto-analysis catches issues early
- ✅ Features are implemented faster with guidance

---

**Welcome to the IRIS AI Customization System! 🚀**

Start with a task, pick an agent, and let's build something great together.
