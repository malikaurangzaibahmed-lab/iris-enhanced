"""
UI COMPARISON: Faculty vs Student Dashboard

Current Status:
✓ Both have RefreshIndicator
✓ Both use CustomScrollView with slivers
✓ Both have GlassCard headers
✓ Both have day selectors
✓ Both use _ClassCard for schedule display

Key Differences to Align:

FACULTY DASHBOARD:
- Header shows: Greeting + Date + Teacher Name selector
- Has: Insight Card, Day Selector, Schedule Header, Class Cards
- Color theme: Purple (0xFF8B5CF6)

STUDENT DASHBOARD:
- Header shows: Greeting + Date + Batch selector
- Has: Filters (_scheduleFilter for live/upcoming)
- Has: Better visual structure with gradient backgrounds
- Color theme: Indigo (0xFF6366F1)

RECOMMENDATIONS FOR FACULTY UI REBUILD:
1. Add filtering capabilities (option to filter by day/batch)
2. Consistency in visual styling and spacing
3. Update header layout to match student's pattern more closely
4. Consider adding more visual feedback/animations
5. Align color gradients and spacing

What specifically should we match?
- Just the visual styling/colors?
- The entire layout structure?
- The functionality (filters, etc.)?
"""

print(__doc__)
