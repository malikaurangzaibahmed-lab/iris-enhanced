---
description: "Use when working on widget files. Focus on performance, theme support, and responsive design."
applyTo: "lib/widgets/**/*.dart"
---

# Widget Development Instructions

## Requirements for Widget Files

Every widget file must:

1. **Use const constructors**
   ```dart
   class MyWidget extends StatelessWidget {
     const MyWidget({Key? key}) : super(key: key);
   }
   ```

2. **Have dartdoc comments**
   ```dart
   /// Displays a single class card in the timetable.
   /// 
   /// Shows time, subject, instructor, and location.
   /// Responds to theme changes automatically.
   class ClassCard extends StatelessWidget {
     const ClassCard({required this.classData});
   }
   ```

3. **Support both themes**
   - Use `Theme.of(context)` for colors
   - Avoid hardcoded colors
   - Test with both `Brightness.light` and `Brightness.dark`

4. **Be responsive**
   - Use `MediaQuery.of(context).size` for responsive layouts
   - Test on phone (4.5"), tablet (7"), and web (desktop)
   - Use `LayoutBuilder` for complex layouts

5. **Have associated test**
   - Create `test/widgets/[widget_name]_test.dart`
   - Test at least: builds without error, responds to taps, displays data

## Widget Checklist

- [ ] Const constructor
- [ ] Dartdoc comment
- [ ] All parameters documented
- [ ] Respects theme data
- [ ] Responsive layout
- [ ] Test file created
- [ ] No hardcoded colors or sizes
- [ ] Uses const where possible
- [ ] Handles null/empty states

## Common Widget Patterns

### State Management
```dart
// Use Provider pattern
final classProvider = Provider<Class>((ref) => Class(...));

class ClassWidget extends ConsumerWidget {
  const ClassWidget({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classData = ref.watch(classProvider);
    return Text(classData.name);
  }
}
```

### Responsive Widget
```dart
class ResponsiveClassCard extends StatelessWidget {
  const ResponsiveClassCard({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 500;
    
    return Padding(
      padding: EdgeInsets.all(isSmall ? 8 : 16),
      child: // Layout based on size
    );
  }
}
```
