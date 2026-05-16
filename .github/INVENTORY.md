# IRIS Customization System - Complete Inventory

## What's Available

### 🤖 Specialized Agents (4 Total)

#### Flutter UI Agent
- **File**: `.github/agents/flutter-ui-agent.md`
- **Applies to**: `lib/screens/**`, `lib/widgets/**`, `lib/themes/**`
- **Use when**: Building widgets, creating screens, animations, theming
- **Provides**: Best practices, responsive design patterns, performance optimization

#### Dart Backend Agent  
- **File**: `.github/agents/dart-backend-agent.md`
- **Applies to**: `lib/services/**`, `lib/models/**`, `lib/providers/**`, `lib/utils/**`
- **Use when**: Creating services, models, state management, utilities
- **Provides**: Design patterns, error handling, testability guidelines

#### Firebase Operations Agent
- **File**: `.github/agents/firebase-ops-agent.md`
- **Applies to**: `firestore.rules`, `firestore.indexes.json`, `firebase.json`, Firebase services
- **Use when**: Firestore setup, security rules, auth, cloud functions
- **Provides**: Query optimization, security patterns, deployment guidelines

#### Android Native Agent
- **File**: `.github/agents/android-native-agent.md`
- **Applies to**: `android/**/*.kt`, `android_liquid_glass_view/**`
- **Use when**: Android widgets, Kotlin code, platform channels
- **Provides**: Widget patterns, native integration, optimization tips

### 📚 Domain Skills (3 Total)

#### IRIS Architecture Skill
- **Location**: `.github/skills/iris-architecture/SKILL.md`
- **Coverage**: System overview, data flow, components, patterns
- **Use when**: Understanding overall structure, planning features, learning design
- **Provides**: Architecture diagrams, component descriptions, integration points

#### Performance Profiling Skill
- **Location**: `.github/skills/performance-profiling/SKILL.md`
- **Coverage**: Profiling workflows, common issues, optimization techniques
- **Use when**: Debugging slowness, optimizing performance, reducing memory
- **Provides**: Diagnostic steps, code patterns, benchmarking tools

#### Documentation Standards Skill
- **Location**: `.github/skills/documentation-standards/SKILL.md`
- **Coverage**: Code docs, README templates, synchronization strategies
- **Use when**: Writing documentation, updating docs, ensuring sync with code
- **Provides**: Templates, examples, audit checklists

### 📋 File Instructions (3 Total)

#### Widgets Instructions
- **File**: `.github/instructions/widgets.instructions.md`
- **Applies to**: `lib/widgets/**/*.dart`
- **Provides**: Const constructors, theme support, responsive design, testing

#### Services Instructions
- **File**: `.github/instructions/services.instructions.md`
- **Applies to**: `lib/services/**/*.dart`
- **Provides**: DI patterns, error handling, testability, documentation

#### Firebase Instructions
- **File**: `.github/instructions/firebase.instructions.md`
- **Applies to**: `firestore.rules`, `firestore.indexes.json`, Firebase configs
- **Provides**: Security patterns, index requirements, deployment steps

### 🔍 Automated Analysis

#### Code Analysis Hook
- **File**: `.github/hooks/iris-code-analysis.json`
- **Checks**: Dartdoc coverage, memory leaks, performance issues, security, patterns
- **Triggers**: Before tool use for code changes
- **Provides**: Issue detection, pattern matching, validation rules

## Organization Structure

```
.github/
├── AGENTS.md                              ← Master agent documentation
├── QUICK_START.md                         ← Getting started guide
├── agents/
│   ├── flutter-ui-agent.md
│   ├── dart-backend-agent.md
│   ├── firebase-ops-agent.md
│   └── android-native-agent.md
├── skills/
│   ├── iris-architecture/
│   │   └── SKILL.md
│   ├── performance-profiling/
│   │   └── SKILL.md
│   └── documentation-standards/
│       └── SKILL.md
├── instructions/
│   ├── widgets.instructions.md
│   ├── services.instructions.md
│   └── firebase.instructions.md
└── hooks/
    └── iris-code-analysis.json

Root Level:
├── copilot-instructions.md                ← Project-wide guidance
└── [This file]
```

## Quick Reference Matrix

| Component | Type | Location | Usage |
|-----------|------|----------|-------|
| Flutter UI | Agent | `.github/agents/flutter-ui-agent.md` | `/flutter-ui` |
| Dart Backend | Agent | `.github/agents/dart-backend-agent.md` | `/dart-backend` |
| Firebase Ops | Agent | `.github/agents/firebase-ops-agent.md` | `/firebase-ops` |
| Android Native | Agent | `.github/agents/android-native-agent.md` | `/android-native` |
| IRIS Architecture | Skill | `.github/skills/iris-architecture/` | Search or `/iris-architecture` |
| Performance | Skill | `.github/skills/performance-profiling/` | Search or `/performance-profiling` |
| Documentation | Skill | `.github/skills/documentation-standards/` | Search or `/documentation-standards` |
| Widgets | Instructions | `.github/instructions/widgets.instructions.md` | Auto-applied to `lib/widgets/` |
| Services | Instructions | `.github/instructions/services.instructions.md` | Auto-applied to `lib/services/` |
| Firebase | Instructions | `.github/instructions/firebase.instructions.md` | Auto-applied to Firebase files |
| Code Analysis | Hooks | `.github/hooks/iris-code-analysis.json` | Auto-triggered on changes |

## Feature Summary

### ✅ What Each Component Provides

#### Agents Provide:
- Domain-specific expertise and best practices
- Code patterns and real examples
- Task checklists for completeness
- Common issues and solutions
- Integration with project structure

#### Skills Provide:
- Deep knowledge on complex topics
- Diagnostic and debugging procedures
- Optimization strategies
- Templates and guides
- Testing methodologies

#### Instructions Provide:
- Context-aware guidance
- Auto-applied to relevant files
- Requirements and checklist items
- Example implementations
- Anti-patterns to avoid

#### Analysis Hooks Provide:
- Automated issue detection
- Pattern validation
- Documentation checking
- Performance antipattern detection
- Security rule verification

## Getting Started Paths

### Path 1: Build a Feature (Quick)
1. Identify component type (UI/Service/Firebase/Native)
2. Use corresponding agent for guidance
3. Auto-applied instructions validate your work
4. Code analysis hooks check for issues
5. ✅ Feature complete with best practices

### Path 2: Understand the System (Learning)
1. Start with `/iris-architecture` skill
2. Read AGENTS.md for overview
3. Explore `.github/` directory structure
4. Try one agent for a small task
5. ✅ System understanding + practical experience

### Path 3: Optimize Performance (Debugging)
1. Use `/performance-profiling` skill for diagnosis
2. Follow optimization procedures
3. Apply patterns from dart-backend or flutter-ui agents
4. Verify with DevTools
5. ✅ Performance improved with confidence

### Path 4: Document Work (Completion)
1. Use `/documentation-standards` skill for guidance
2. Follow dartdoc comment patterns
3. Update relevant markdown docs
4. Use widgets/services/firebase instructions to verify
5. ✅ Documentation complete and accurate

## Integration with Existing Tools

### Works With:
- ✅ VS Code built-in search and navigation
- ✅ Copilot chat for questions
- ✅ Flutter DevTools for profiling
- ✅ Firebase Console for management
- ✅ Git workflows and version control
- ✅ Dart analyzer and linter
- ✅ Android Studio for native code

### Complements:
- ✅ Project README.md
- ✅ ARCHITECTURE.md system overview
- ✅ IMPLEMENTATION_ROADMAP.md progress tracking
- ✅ Existing test suite
- ✅ Firebase configuration

## Key Benefits

### 🎯 For Development Speed
- Pre-written patterns for common tasks
- Reduced context switching
- Faster decision making
- Consistent code quality

### 📚 For Learning
- Domain-specific guidance at point of need
- Real examples from codebase
- Best practices documented
- Architecture understanding

### 🔍 For Quality
- Automated issue detection
- Consistency across team
- Documentation stays in sync
- Performance optimization guidance

### 🚀 For Scaling
- Onboarding new developers (use AGENTS.md)
- Maintaining code standards
- Knowledge preservation
- Process documentation

## Customization Options

### Easy Additions
Could add similar agents for:
- Testing & debugging
- DevOps & deployment
- Database operations
- API design

Could add similar skills for:
- Security best practices
- Testing strategies
- Deployment procedures
- Troubleshooting guide

### Advanced Customization
- Add MCP servers for external tools
- Create custom analysis plugins
- Build automated refactoring tools
- Implement AI-assisted code review

## Files to Consult

**First time setup?**
→ Read `.github/QUICK_START.md`

**Want agent overview?**
→ Read `.github/AGENTS.md`

**Need project context?**
→ Read `copilot-instructions.md`

**Understanding architecture?**
→ Search `/iris-architecture` skill

**Debugging issues?**
→ Check relevant agent + `/performance-profiling` skill

**Writing code?**
→ Let auto-applied instructions guide you

## Success Metrics

You'll know it's working when:
- ✅ Code follows consistent patterns
- ✅ Documentation stays synchronized
- ✅ Performance issues caught early
- ✅ New features implemented faster
- ✅ Onboarding new devs is smoother
- ✅ Team follows best practices
- ✅ Code quality improved
- ✅ Issues prevented proactively

## Support & Maintenance

### Keeping It Updated
- Update agents as patterns evolve
- Refresh skills when learning new techniques
- Add instructions for new file types
- Adjust analysis hooks based on needs

### Getting Help
- Ask agents about themselves
- Check AGENTS.md matrix for agent selection
- Use skills for deep-dive topics
- Reference instructions for specific files

---

**This customization system is now live and ready to help with your IRIS project! 🚀**

Start with a task, pick the right agent or skill, and enjoy specialized guidance throughout development.
