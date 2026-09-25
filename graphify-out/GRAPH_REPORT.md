# Graph Report - claude_notch  (2026-09-25)

## Corpus Check
- 11 files · ~18,623 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 177 nodes · 325 edges · 13 communities (11 shown, 2 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 3 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `7c2add1d`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]

## God Nodes (most connected - your core abstractions)
1. `AppDelegate` - 18 edges
2. `SessionWatcher` - 18 edges
3. `UsageStore` - 13 edges
4. `EarContent` - 12 edges
5. `LocalLogScanner` - 10 edges
6. `ClaudeNotch` - 10 edges
7. `String` - 9 edges
8. `String` - 8 edges
9. `ExpandedContent` - 8 edges
10. `SessionAlert` - 8 edges

## Surprising Connections (you probably didn't know these)
- `UsageStore` --inherits--> `ObservableObject`  [EXTRACTED]
  Sources/ClaudeNotch/UsageStore.swift →   _Bridges community 1 → community 4_
- `GlassSection` --references--> `View`  [EXTRACTED]
  Sources/ClaudeNotch/Settings.swift →   _Bridges community 0 → community 6_
- `EarsRow` --references--> `CGFloat`  [EXTRACTED]
  Sources/ClaudeNotch/NotchView.swift → Sources/ClaudeNotch/NotchView.swift  _Bridges community 0 → community 3_
- `SessionAlert` --implements--> `Equatable`  [EXTRACTED]
  Sources/ClaudeNotch/SessionWatcher.swift →   _Bridges community 8 → community 4_
- `SessionAlert` --implements--> `Identifiable`  [EXTRACTED]
  Sources/ClaudeNotch/SessionWatcher.swift →   _Bridges community 8 → community 6_

## Import Cycles
- None detected.

## Communities (13 total, 2 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.14
Nodes (25): AlertContent, color(), countdown(), EarsRow, EarView, ExpandedContent, formatTokens(), formatTokensShort() (+17 more)

### Community 1 - "Community 1"
Cohesion: 0.11
Nodes (19): Any, Bool, CGSize, AppDelegate, NotchPanel, NotchState, DispatchWorkItem, Notification (+11 more)

### Community 2 - "Community 2"
Cohesion: 0.13
Nodes (14): Aggiornamento, Avvisi di fine sessione, ClaudeNotch, Come funziona, Cosa fa, Disinstallazione, Impostazioni, Installazione (+6 more)

### Community 3 - "Community 3"
Cohesion: 0.24
Nodes (8): CGRect, ContentHeightKey, EarWidthKey, NotchShape, Path, PreferenceKey, Shape, CGFloat

### Community 4 - "Community 4"
Cohesion: 0.19
Nodes (18): FileResult, FileState, LocalLogScanner, LocalStats, ModelUsage, Record, TokenStats, UsageStore (+10 more)

### Community 5 - "Community 5"
Cohesion: 0.40
Nodes (4): CGColor, NSColor, mix(), CGFloat

### Community 6 - "Community 6"
Cohesion: 0.11
Nodes (24): CaseIterable, EarContent, none, session, todayTokens, topModel, week, weekTokens (+16 more)

### Community 7 - "Community 7"
Cohesion: 0.40
Nodes (4): UNNotification, UNNotificationPresentationOptions, UNUserNotificationCenter, Void

### Community 8 - "Community 8"
Cohesion: 0.22
Nodes (12): SessionAlert, SessionWatcher, Data, FSEventStreamRef, MainActor, Sendable, Any, Bool (+4 more)

## Knowledge Gaps
- **49 isolated node(s):** `enabledMcpjsonServers`, `enableAllProjectMcpServers`, `NSColor`, `CGFloat`, `CGColor` (+44 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppDelegate` connect `Community 1` to `Community 7`?**
  _High betweenness centrality (0.166) - this node is a cross-community bridge._
- **Why does `NotchView` connect `Community 0` to `Community 1`?**
  _High betweenness centrality (0.163) - this node is a cross-community bridge._
- **What connects `enabledMcpjsonServers`, `enableAllProjectMcpServers`, `NSColor` to the rest of the system?**
  _49 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.14193548387096774 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.11384615384615385 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.13333333333333333 - nodes in this community are weakly interconnected._
- **Should `Community 6` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._