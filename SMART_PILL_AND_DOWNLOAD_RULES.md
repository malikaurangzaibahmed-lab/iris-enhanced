# Smart Pill & Download Rules

## Canonical Source

- This file is a focused companion for portal behavior.
- The canonical, project-wide rules source is [IRIS_RULES.md](IRIS_RULES.md).
- Any new user-defined rule (for example, ask-before-build) must be added in [IRIS_RULES.md](IRIS_RULES.md) first, then mirrored here when relevant to smart pill/download behavior.

## Agent Workflow Rules

These are the rules you've established for how I should work with you on this project:

#### 1. **Ask Before Build**
- Never run `flutter build apk --split-per-abi` without asking for explicit approval first.
- When ready to build, ask: "Should I build to verify?"
- Wait for your confirmation before executing the build task.

#### 2. **Use Slash Commands When Useful**
- Employ "/" commands (like `/check`, `/fix`, `/test`, etc.) when they make operations clearer or more efficient.
- Only use them if they genuinely improve workflow clarity; don't force them unnecessarily.

#### 3. **Terminology**
- Refer to the upper notification overlay throughout the app as the **"smart pill"** (not just "pill" or "overlay").
- This is the unified feedback system across all app surfaces, including portal interactions.

#### 4. **Documentation**
- Maintain this rules document as the source of truth for how the project should work.
- Update it whenever new rules or constraints are added.

---

## Smart Pill Architecture

The **Smart Pill** is the unified notification/feedback overlay replacing all snackbars and legacy block UI elements across the app. It appears at the top with persistent, contextual behavior.

### Smart Pill Rules

#### 1. **Single Source of Truth**
- All portal feedback (errors, status, downloads, logins) routes through one smart pill.
- No competing snackbars, dialogs, or block overlays.
- Legacy snack bar system disabled in PortalScreen context.

#### 2. **Persistent COMSATS Header Pill**
- The portal domain name pill remains visible in collapsed header.
- Shows current portal context: "COMSATS", "Uptodown", etc.
- Never hidden, always shows which site user is on.

#### 3. **Contextual Header Actions**
- Header expands/collapses based on user interaction.
- **Collapsed state**: shows pill + back button + menu icon.
- **Expanded state**: shows pill + inline URL editor + menu icon.
- Inline URL allow users to type/paste URLs without modal interruption.

#### 4. **Autofill Visibility & Trigger**
- **Show only when**: login text field receives focus (via JS `login_focus` signal).
- **Keep visible until**: user successfully logs in (session established).
- **Placement**: collapsed header row as chip action (always visible when collapsed).
- **Focus latch**: state persists across header expand/collapse; only clears on login success.

#### 5. **Status Animation & Color**
- Pill animates when status changes (download starting, completed, error).
- Light mode Link color readability: enforced contrast for URL display.
- Smooth fade/scale transitions on state update.

---

## Download Rules

### Android System Download Path (Primary)

#### 1. **Use System DownloadManager First**
- On Android, downloads should first go through system `DownloadManager` for browser-like behavior.
- Pass browser-equivalent headers when available: `User-Agent`, `Referer`, and same-site `Cookie`.
- Show system notification and keep downloads visible in Downloads UI.
- If enqueue/start fails, fall back to in-app downloader paths.

### In-App Fast Download Path (Secondary)

#### 1. **Single Attempt Only**
- Native Dart downloader (`_downloadFileFast`) tries **once per download**.
- **No retries** in the fast path.
- Timeout: 18 seconds for connection, 75 seconds for full response.
- If it fails → immediately falls back to JS compatibility path.

#### 2. **Browser-Like Filename Handling**
- Extract filename from HTTP response headers (priority order):
  1. `Content-Disposition: filename=...` (RFC 5987 with UTF-8 decoding)
  2. URL pathname last segment (decoded)
  3. MIME type → extension mapping
  4. Fallback: `download` (with inferred extension)
- **Never output `download.bin`** unless all metadata is genuinely missing.
- Extension validation: if file already has extension (e.g., `.pdf`), keep it; else append mapped extension.

#### 3. **Host-Aware Request Headers**
- **Same-host downloads** (portal domain):
  - Include cookies (from `SharedPreferences` session)
  - Include referer = portal URL
- **Cross-host downloads** (external links like Uptodown):
  - No cookies (avoid cross-site pollution)
  - Referer = target origin (`https://uptodown.com/`)
  - Respect `CORS` + `sameSite` cookie policies

#### 4. **MIME Type → Extension Mapping**
Inject content-type aware extension resolver:
- `application/pdf` → `.pdf`
- `application/zip` → `.zip`
- `application/vnd.openxmlformats-officedocument.wordprocessingml.document` → `.docx`
- `application/vnd.ms-powerpoint` → `.ppt`
- `application/vnd.openxmlformats-officedocument.presentationml.presentation` → `.pptx`
- `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` → `.xlsx`
- `image/jpeg` → `.jpg`
- `image/png` → `.png`
- Generic fallback: empty string (no extension added if unknown)

#### 5. **Error Handling & Fallback**
- If fast path fails (timeout, 4xx, 5xx, network error):
  - **NoRetry**: error is final for native path.
  - Switch to JS fallback immediately.
- JS fallback uses XHR with same filename logic + retry attempts (up to 3 attempts, backoff delay).

### JS Fallback Path (Compatibility Mode)

#### 1. **XHR-Based Download**
- Triggered if native fast path fails.
- Takes over with same MIME/filename inference.
- Includes retry loop: max 3 attempts, exponential backoff (500ms + attempt * 650ms, capped at 2400ms).

#### 2. **Progress Reporting**
- Both native and JS paths report progress to Dart side.
- Throttled updates: only send when:
  - Percent increases by ≥4%
  - Reaches 100%
  - Or no total is available (indeterminate progress).

#### 3. **File Handling**
- Save to standard downloads directory.
- Atomic writes: download to `.part` file, rename on completion.
- Delete temp file on failure.

### Download Manager UI

#### 1. **Download Records**
- Track: filename, file path, source URL, timestamp.
- Display in manager: rich cards with metadata.

#### 2. **Manager Actions**
- **Retry Latest**: re-attempt last failed download.
- **Open**: launch file with system handler.
- **Copy Path**: copy file location to clipboard.
- **History**: show all previous downloads (most recent first).

#### 3. **User Feedback**
- Status pill shows: "Downloading…", progress %, completion message, or error.
- Completion message: "Download complete: {filename}" with Open action.
- Error message: "Download failed: {reason}" (HTTP status, timeout, network, etc.).

---

## Download Failure Investigation Checklist

When a download fails:

1. **Check fast path timeout behavior**: 18s connection + 75s response may be too short for large files or slow networks.
2. **Verify cookie session**: same-host downloads require valid portal session cookie.
3. **Check cross-host referer**: external sites (Uptodown) may reject unusual referer headers.
4. **Monitor JS fallback**: if fast path fails, ensure JS XHR takes over.
5. **Inspect network**: browser DevTools on portal WebView to see actual request/response.
6. **Test URL directly**: try downloading target URL in a standard browser to isolate IRIS vs. host issue.

---

## Summary

- **Smart Pill**: Unified, persistent, contextual feedback overlay. Header-based, no competing overlays.
- **Downloads**: Single fast attempt → JS fallback. Browser-like filenames. Host-aware headers. No generic `.bin` fallbacks.
- **Rules are user-defined**: evolve based on real-world testing and user feedback.
