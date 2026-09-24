# Graph Report - claude_notch  (2026-09-24)

## Corpus Check
- 10 files · ~16,182 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 142 nodes · 253 edges · 11 communities (9 shown, 2 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 3 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6fe288d4`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]

## God Nodes (most connected - your core abstractions)
1. `AppDelegate` - 18 edges
2. `SessionWatcher` - 18 edges
3. `UsageStore` - 13 edges
4. `LocalLogScanner` - 10 edges
5. `ClaudeNotch` - 10 edges
6. `String` - 9 edges
7. `SessionAlert` - 8 edges
8. `Date` - 8 edges
9. `ModelUsage` - 8 edges
10. `FileState` - 8 edges

## Surprising Connections (you probably didn't know these)
- `UsageStore` --inherits--> `ObservableObject`  [EXTRACTED]
  Sources/ClaudeNotch/UsageStore.swift →   _Bridges community 1 → community 4_
- `SessionAlert` --implements--> `Equatable`  [EXTRACTED]
  Sources/ClaudeNotch/SessionWatcher.swift →   _Bridges community 8 → community 4_
- `SessionWatcher` --references--> `Void`  [EXTRACTED]
  Sources/ClaudeNotch/SessionWatcher.swift → Sources/ClaudeNotch/SessionWatcher.swift  _Bridges community 8 → community 1_

## Import Cycles
- None detected.

## Communities (11 total, 2 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.16
Nodes (20): AlertContent, color(), countdown(), ExpandedContent, formatTokens(), ModelBreakdown, NotchView, Ring (+12 more)

### Community 1 - "Community 1"
Cohesion: 0.09
Nodes (23): Any, Bool, CGSize, AppDelegate, NotchPanel, NotchState, DispatchWorkItem, Notification (+15 more)

### Community 2 - "Community 2"
Cohesion: 0.14
Nodes (13): Aggiornamento, Avvisi di fine sessione, ClaudeNotch, Come funziona, Cosa fa, Disinstallazione, Installazione, Nota (+5 more)

### Community 3 - "Community 3"
Cohesion: 0.25
Nodes (7): CGRect, ContentHeightKey, NotchShape, Path, PreferenceKey, Shape, CGFloat

### Community 4 - "Community 4"
Cohesion: 0.17
Nodes (20): FileResult, FileState, LocalLogScanner, LocalStats, ModelUsage, Record, TokenStats, UsageStore (+12 more)

### Community 5 - "Community 5"
Cohesion: 0.40
Nodes (4): CGColor, NSColor, mix(), CGFloat

### Community 8 - "Community 8"
Cohesion: 0.23
Nodes (11): SessionAlert, SessionWatcher, FSEventStreamRef, MainActor, Sendable, Any, Bool, String (+3 more)

## Knowledge Gaps
- **40 isolated node(s):** `enabledMcpjsonServers`, `enableAllProjectMcpServers`, `NSColor`, `CGFloat`, `CGColor` (+35 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NotchView` connect `Community 0` to `Community 1`?**
  _High betweenness centrality (0.279) - this node is a cross-community bridge._
- **Why does `SessionWatcher` connect `Community 8` to `Community 1`?**
  _High betweenness centrality (0.207) - this node is a cross-community bridge._
- **What connects `enabledMcpjsonServers`, `enableAllProjectMcpServers`, `NSColor` to the rest of the system?**
  _40 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.09032258064516129 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._