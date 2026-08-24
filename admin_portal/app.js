/* ==========================================================================
   NEXSYNC ENTERPRISE CONTROL SPACE - 21ST.DEV OBSIDIAN CONTROLLER
   Orchestrating high-fidelity micro-interactions and bulletproof sync telemetry.
   ========================================================================== */

const DEFAULT_FIREBASE_CONFIG = {
  apiKey: "AIzaSyAAXqXhWVQs3yFiMyftafA4og8yN0LHHHE",
  authDomain: "iris-138ef.firebaseapp.com",
  projectId: "iris-138ef",
  storageBucket: "iris-138ef.firebasestorage.app",
};

let app, auth, db, storage;
let isConnected = false;
let logHistory = [];

// DOM Bindings
const authOverlay = document.getElementById('auth-overlay');
const dashboardContainer = document.getElementById('dashboard-container');
const emailInput = document.getElementById('auth-email');
const passInput = document.getElementById('auth-pass');
const loginBtn = document.getElementById('btn-login');
const logoutBtn = document.getElementById('btn-logout');
const authError = document.getElementById('auth-error');
const userMonogram = document.getElementById('user-monogram');
const btnTogglePassword = document.getElementById('btn-toggle-password');
const authConnectionBeacon = document.getElementById('auth-connection-beacon');
const beaconText = document.getElementById('connection-beacon-text');

// System Switchers
const ribbonSegments = document.querySelectorAll('.ribbon-segment');
const activePeriodDesc = document.getElementById('active-period-desc');

// Systems Logs terminal elements
const terminalOutput = document.getElementById('terminal-output');
const clearTerminalBtn = document.getElementById('btn-clear-terminal');
const searchTerminalInput = document.getElementById('terminal-search');
const filterTerminalSelect = document.getElementById('terminal-filter');
const downloadLogsBtn = document.getElementById('btn-download-logs');

// Uploader Dropzones
const timetableDropzone = document.getElementById('timetable-dropzone');
const timetableFileInput = document.getElementById('file-timetable');
const timetableFileInfo = document.getElementById('timetable-file-info');
const deployTimetableBtn = document.getElementById('btn-deploy-timetable');

const apkDropzone = document.getElementById('apk-dropzone');
const apkFileInput = document.getElementById('file-apk');
const apkFileInfo = document.getElementById('apk-file-info');
const apkVersionName = document.getElementById('apk-version-name');
const apkVersionCode = document.getElementById('apk-version-code');
const apkNotes = document.getElementById('apk-notes');
const deployApkBtn = document.getElementById('btn-deploy-apk');
const apkSwitchVisible = document.getElementById('apk-switch-visible');
const apkUrlInput = document.getElementById('apk-url-input');
const uploadProgressContainer = document.getElementById('upload-progress-container');
const uploadProgressFill = document.getElementById('upload-progress-fill');
const uploadProgressPct = document.getElementById('upload-progress-pct');

const configModal = document.getElementById('config-modal');
const showConfigBtn = document.getElementById('btn-show-config');
const closeModalBtn = document.getElementById('btn-close-modal');
const saveConfigBtn = document.getElementById('btn-save-config');
const configJsonArea = document.getElementById('firebase-config-json');

// Announcement Transceiver Elements
const broadcastSwitchVisible = document.getElementById('broadcast-switch-visible');
const broadcastMessage = document.getElementById('broadcast-message');
const btnBroadcastPush = document.getElementById('btn-broadcast-push');
const broadcastCharCount = document.getElementById('broadcast-char-count');
const presetChips = document.querySelectorAll('.preset-chip');

// Hidden compat bounds for workspace scripts
const broadcastSwitch = document.getElementById('broadcast-switch');
const broadcastingBadge = document.getElementById('broadcasting-badge');
const charRingFill = document.getElementById('char-ring-fill');

// Inactivity Session Timeouts
const timeoutModal = document.getElementById('timeout-modal');
const timeoutCountdown = document.getElementById('timeout-countdown');
const extendSessionBtn = document.getElementById('btn-extend-session');

// departures timetable analytics
const timetableAnalytics = document.getElementById('timetable-analytics');
const timetablePreviewBody = document.getElementById('timetable-preview-body');
const statSessions = document.getElementById('stat-sessions');
const statCourses = document.getElementById('stat-courses');
const statLabs = document.getElementById('stat-labs');

// Date Sheet Excel Converter Bindings
const examsDropzone = document.getElementById('exams-dropzone');
const examsFileInput = document.getElementById('file-exams');
const examsFileInfo = document.getElementById('exams-file-info');
const btnDeployMidterms = document.getElementById('btn-deploy-midterms');
const btnDeployFinals = document.getElementById('btn-deploy-finals');
const examsPreviewBody = document.getElementById('exams-preview-body');
const examsStatTotal = document.getElementById('exams-stat-total');
const examsStatBatches = document.getElementById('exams-stat-batches');
const examsStatSubjects = document.getElementById('exams-stat-subjects');
const examsAnalytics = document.getElementById('exams-analytics');

// Upload Buffers
let selectedTimetableFile = null;
let stagedTimetableFiles = [];
let selectedApkFile = null;
let parsedExams = [];
let stagedTimetablePayload = null;

// Initialize Interface Scripts
document.addEventListener('DOMContentLoaded', () => {
  setupTerminalControls();
  
  // Set up 2.5s maximum safety fallback timeout to fade the loader no matter what
  setTimeout(() => {
    const loader = document.getElementById('initial-loader');
    if (loader && loader.style.display !== 'none') {
      logTerminal('Handshake latency exceeded. Activating fallback credentials gateway.', 'warning');
      loader.style.opacity = '0';
      setTimeout(() => {
        loader.style.display = 'none';
      }, 500);
      
      // Force gateway display if state is not resolved
      if (!auth || !auth.currentUser) {
        authOverlay.style.display = 'flex';
        dashboardContainer.style.display = 'none';
      }
    }
  }, 2500);

  // Direct config sliders button from the login vault gate
  const btnAuthConfig = document.getElementById('btn-auth-config');
  if (btnAuthConfig) {
    btnAuthConfig.addEventListener('click', () => {
      configModal.style.display = 'flex';
    });
  }

  try {
    loadFirebaseConfig();
    setupAuthListeners();
  } catch (err) {
    console.error("Initialization Error:", err);
    logTerminal(`Initialization error: ${err.message}`, 'error');
  }

  setupThemeToggle();
  setupDragAndDrop();
  setupUIHandlers();
  // Continuous 60fps canvas shader and tilt loops disabled for maximum performance
  startLatencySimulator();
  
  if (apkUrlInput) {
    apkUrlInput.addEventListener('input', () => {
      if (apkUrlInput.value.trim() !== '') {
        deployApkBtn.disabled = false;
      } else if (!selectedApkFile) {
        deployApkBtn.disabled = true;
      }
    });
  }

  const pullGithubBtn = document.getElementById('btn-pull-github');
  if (pullGithubBtn) {
    pullGithubBtn.addEventListener('click', async () => {
      logTerminal('Contacting GitHub API for latest release payload...', 'info');
      pullGithubBtn.disabled = true;
      const originalText = pullGithubBtn.innerHTML;
      pullGithubBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> FETCHING RELEASE...';
      
      try {
        const response = await fetch(`https://api.github.com/repos/malikaurangzaibahmed-lab/iris-enhanced/releases/latest`);
        if (!response.ok) {
          throw new Error(`HTTP Error ${response.status}: Repository may be private or not found.`);
        }
        
        const release = await response.json();
        const tagName = release.tag_name || "";
        const versionName = tagName.replace(/^v/i, "");
        
        let apkUrl = "";
        if (release.assets && release.assets.length > 0) {
          const targetAsset = release.assets.find(a => a.name.includes("arm64-v8a")) || 
                              release.assets.find(a => a.name.endsWith(".apk"));
          if (targetAsset) {
            apkUrl = targetAsset.browser_download_url;
          }
        }
        
        if (apkVersionName) apkVersionName.value = versionName;
        if (apkNotes) apkNotes.value = release.body || "";
        if (apkUrlInput) {
          apkUrlInput.value = apkUrl;
          deployApkBtn.disabled = false;
        }
        
        logTerminal(`Autofill success: Pulled version <strong>${versionName}</strong> from GitHub.`, 'success');
        showMossToast(`Fetched release ${tagName} successfully!`, "success");
      } catch (err) {
        logTerminal(`GitHub fetch failed: ${err.message}`, 'error');
        showMossToast(err.message, "error");
      } finally {
        pullGithubBtn.disabled = false;
        pullGithubBtn.innerHTML = originalText;
      }
    });
  }

  // MULTI-SCREEN SIDEBAR NAVIGATION CONTROLLER
  const navItems = document.querySelectorAll('.nav-item');
  const pagePanes = document.querySelectorAll('.page-pane');
  const pageTitle = document.getElementById('page-title');
  const pageSubtitle = document.getElementById('page-subtitle');

  const pageMeta = {
    dashboard: {
      title: 'Overview & Telemetry',
      subtitle: 'Real-time status monitoring and global operational mode controls'
    },
    timetables: {
      title: 'Daily Timetables Database',
      subtitle: 'Import, parse, preview, and deploy daily class schedule databases'
    },
    exams: {
      title: 'Exam Date Sheets & Schedules',
      subtitle: 'Convert Midterms and Finals Excel date sheets and inspect active records'
    },
    semester: {
      title: 'Semester Schedule & Milestones',
      subtitle: 'Publish official semester milestone timelines directly to student devices'
    },
    broadcast: {
      title: 'Emergency Broadcast Studio',
      subtitle: 'Push instant priority campus alerts and announcements across mobile clients'
    },
    feedback: {
      title: 'Community Feedback Stream',
      subtitle: 'Review student and faculty ratings, device telemetry, and suggestions'
    },
    releases: {
      title: 'In-App APK Release Deployer',
      subtitle: 'Publish Android package binaries and notify active app installations'
    },
    terminal: {
      title: 'Systems Activity Terminal',
      subtitle: 'Real-time telemetry event stream and administrative execution logs'
    }
  };

  // Mobile Sidebar Drawer Controller
  const btnMobileSidebarToggle = document.getElementById('btn-mobile-sidebar-toggle');
  const btnSidebarClose = document.getElementById('btn-sidebar-close');
  const sidebarOverlay = document.getElementById('sidebar-overlay');
  const adminSidebar = document.getElementById('admin-sidebar');

  function closeMobileSidebar() {
    if (adminSidebar) adminSidebar.classList.remove('mobile-open');
    if (sidebarOverlay) sidebarOverlay.classList.remove('active');
  }

  function openMobileSidebar() {
    if (adminSidebar) adminSidebar.classList.add('mobile-open');
    if (sidebarOverlay) sidebarOverlay.classList.add('active');
  }

  if (btnMobileSidebarToggle) {
    btnMobileSidebarToggle.addEventListener('click', (e) => {
      e.stopPropagation();
      if (adminSidebar && adminSidebar.classList.contains('mobile-open')) {
        closeMobileSidebar();
      } else {
        openMobileSidebar();
      }
    });
  }

  if (btnSidebarClose) {
    btnSidebarClose.addEventListener('click', closeMobileSidebar);
  }

  if (sidebarOverlay) {
    sidebarOverlay.addEventListener('click', closeMobileSidebar);
  }

  navItems.forEach(item => {
    item.addEventListener('click', () => {
      const targetPage = item.dataset.navTarget;
      if (!targetPage) return;

      closeMobileSidebar();

      navItems.forEach(n => n.classList.remove('active'));
      item.classList.add('active');

      pagePanes.forEach(pane => {
        if (pane.id === `page-${targetPage}`) {
          pane.classList.add('active');
        } else {
          pane.classList.remove('active');
        }
      });

      if (pageMeta[targetPage]) {
        if (pageTitle) pageTitle.innerText = pageMeta[targetPage].title;
        if (pageSubtitle) pageSubtitle.innerText = pageMeta[targetPage].subtitle;
      }

      logTerminal(`Screen navigation: Switched to <strong>${targetPage.toUpperCase()}</strong> workspace.`, 'info');

      if (targetPage === 'timetables') {
        refreshLiveClassesInspector();
      } else if (targetPage === 'exams') {
        refreshLiveExamsInspector();
      } else if (targetPage === 'feedback') {
        renderFeedbackFeed();
      }
    });
  });

  // Dynamic Liquid Glass Specular Spotlight Tracking (Master.dev & Kube.io)
  document.addEventListener('mousemove', (e) => {
    const activeCards = document.querySelectorAll('.tech-card, .metric-card, .glass-panel, .auth-card');
    activeCards.forEach(card => {
      const rect = card.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      card.style.setProperty('--mouse-x', `${x}px`);
      card.style.setProperty('--mouse-y', `${y}px`);
    });
  });

  // 3-Stage Nature Wallpaper Switcher (Glacial Aurora, Alpine Sunset, Emerald Forest)
  const btnToggleWallpaper = document.getElementById('btn-toggle-wallpaper');
  if (btnToggleWallpaper) {
    const wallpapers = [
      { id: 'aurora', name: 'Glacial Aurora Borealis', class: 'theme-aurora', icon: 'fa-wand-magic-sparkles' },
      { id: 'alpine', name: 'Alpine Sunset Lake', class: 'theme-alpine', icon: 'fa-mountain-sun' },
      { id: 'forest', name: 'Emerald Mist Forest', class: 'theme-forest', icon: 'fa-tree' }
    ];

    function applyWallpaper(wId) {
      document.body.classList.remove('theme-aurora', 'theme-alpine', 'theme-forest');
      const wp = wallpapers.find(w => w.id === wId) || wallpapers[0];
      document.body.classList.add(wp.class);
      localStorage.setItem('iris_portal_wallpaper', wp.id);
      btnToggleWallpaper.innerHTML = `<i class="fa-solid ${wp.icon}"></i>`;
      return wp;
    }

    btnToggleWallpaper.addEventListener('click', () => {
      const current = localStorage.getItem('iris_portal_wallpaper') || 'aurora';
      const curIdx = wallpapers.findIndex(w => w.id === current);
      const nextWp = wallpapers[(curIdx + 1) % wallpapers.length];
      applyWallpaper(nextWp.id);
      showMossToast(`Nature Wallpaper: ${nextWp.name}!`, "info");
      logTerminal(`Wallpaper switched: <strong>${nextWp.name}</strong>`, 'info');
    });

    const savedWp = localStorage.getItem('iris_portal_wallpaper') || 'aurora';
    applyWallpaper(savedWp);
  }

  const btnThemeToggle = document.getElementById('btn-theme-toggle');
  if (btnThemeToggle) {
    btnThemeToggle.addEventListener('click', () => {
      const currentTheme = document.documentElement.getAttribute('data-theme') || 'dark';
      const nextTheme = currentTheme === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', nextTheme);
      localStorage.setItem('iris_portal_theme', nextTheme);
      btnThemeToggle.innerHTML = nextTheme === 'dark' ? '<i class="fa-solid fa-sun"></i>' : '<i class="fa-solid fa-moon"></i>';
      showMossToast(`Theme switched to ${nextTheme.toUpperCase()} mode!`, "info");
    });
    const savedTheme = localStorage.getItem('iris_portal_theme');
    if (savedTheme) {
      document.documentElement.setAttribute('data-theme', savedTheme);
      btnThemeToggle.innerHTML = savedTheme === 'dark' ? '<i class="fa-solid fa-sun"></i>' : '<i class="fa-solid fa-moon"></i>';
    }
  }

  // Legacy tab support
  const tabButtons = document.querySelectorAll('.tab-btn');
  const tabPanes = document.querySelectorAll('.workspace-tab-pane');
  tabButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const targetTab = btn.dataset.workspaceTab;
      tabButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      tabPanes.forEach(pane => {
        pane.style.display = pane.id === `workspace-tab-${targetTab}` ? 'block' : 'none';
      });
    });
  });

  // Live Inspector Search Listeners
  const classesSearch = document.getElementById('inspector-classes-search');
  if (classesSearch) {
    classesSearch.addEventListener('input', renderLiveClassesInspector);
  }
  const examsSearch = document.getElementById('inspector-exams-search');
  if (examsSearch) {
    examsSearch.addEventListener('input', renderLiveExamsInspector);
  }

  // Refresh and Wipe Button Bindings
  const btnRefreshClasses = document.getElementById('btn-refresh-inspector-classes');
  if (btnRefreshClasses) {
    btnRefreshClasses.addEventListener('click', refreshLiveClassesInspector);
  }
  const btnRefreshExams = document.getElementById('btn-refresh-inspector-exams');
  if (btnRefreshExams) {
    btnRefreshExams.addEventListener('click', refreshLiveExamsInspector);
  }
  const btnWipeExams = document.getElementById('btn-wipe-exams');
  if (btnWipeExams) {
    btnWipeExams.addEventListener('click', wipeLiveExams);
  }
  const btnWipeClasses = document.getElementById('btn-wipe-classes');
  if (btnWipeClasses) {
    btnWipeClasses.addEventListener('click', wipeLiveClasses);
  }
  const btnClearStagedFiles = document.getElementById('btn-clear-staged-files');
  if (btnClearStagedFiles) {
    btnClearStagedFiles.addEventListener('click', () => {
      stagedTimetableFiles = [];
      recomputeStagedTimetables();
      logTerminal('Purged all staged daily class timetable files.', 'info');
    });
  }

  // Inspector Exams Mids/Finals Period switcher
  const inspectorExamSegments = document.querySelectorAll('#inspector-exam-period-switcher .ribbon-segment');
  inspectorExamSegments.forEach(seg => {
    seg.addEventListener('click', () => {
      inspectorExamSegments.forEach(s => s.classList.remove('active'));
      seg.classList.add('active');
      activeInspectorExamPeriod = seg.dataset.inspectorPeriod;
      logTerminal(`Live Inspector switched: Viewing active <strong>${activeInspectorExamPeriod.toUpperCase()}</strong>.`, 'info');
    });
  });
  
  // Mobile Mockup tab switching
  const mockTabs = document.querySelectorAll('.emulator-tab-btn');
  const mockScreens = document.querySelectorAll('.emulator-screen');
  
  mockTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      mockTabs.forEach(t => t.classList.remove('active'));
      mockScreens.forEach(s => s.classList.remove('active-screen'));
      
      tab.classList.add('active');
      const targetScreenId = `emulator-screen-${tab.dataset.mockTab}`;
      const targetScreen = document.getElementById(targetScreenId);
      if (targetScreen) {
        targetScreen.classList.add('active-screen');
      }
      logTerminal(`Mockup switched view to: <strong>${tab.dataset.mockTab.toUpperCase()}</strong>`, 'info');
    });
  });

  const onboardingDots = document.querySelectorAll('.onboarding-dot');
  const onboardingSlides = [
    {
      title: "Secure Synchronization",
      desc: "Your daily academic lectures, timetables, and notification noticeboard synced to local cache.",
      badge: "Iris Companion",
      color: "var(--accent-indigo)"
    },
    {
      title: "Real-time Telemetry",
      desc: "Instant live broadcast indicators, updates alerts, and offline caching overrides.",
      badge: "ECG Telemetry",
      color: "var(--accent-cyan)"
    },
    {
      title: "Fluid Glass Design",
      desc: "Premium obsidian dark themes, animated weather headers, and nature physics sliders.",
      badge: "Obsidian Liquid",
      color: "var(--accent-rose)"
    }
  ];
  
  let currentSlide = 0;
  
  const switchOnboardingSlide = (index) => {
    onboardingDots.forEach((dot, idx) => {
      dot.className = idx === index ? 'onboarding-dot active' : 'onboarding-dot';
    });
    
    const slide = onboardingSlides[index];
    const mockTitle = document.getElementById('mock-onboarding-title');
    const mockDesc = document.getElementById('mock-onboarding-desc');
    const mockPill = document.getElementById('mock-onboarding-pill');
    
    if (mockTitle) mockTitle.innerText = slide.title;
    if (mockDesc) mockDesc.innerText = slide.desc;
    if (mockPill) {
      mockPill.innerHTML = `<div class="mock-floating-pill" style="background: ${slide.color}; box-shadow: 0 8px 20px ${slide.color}50;">${slide.badge}</div>`;
    }
  };
  
  onboardingDots.forEach(dot => {
    dot.addEventListener('click', () => {
      currentSlide = parseInt(dot.dataset.slide);
      switchOnboardingSlide(currentSlide);
    });
  });
  
  // Auto slide onboarding every 4s
  setInterval(() => {
    const onboardingScreen = document.getElementById('emulator-screen-onboarding');
    if (onboardingScreen && onboardingScreen.classList.contains('active-screen')) {
      currentSlide = (currentSlide + 1) % onboardingSlides.length;
      switchOnboardingSlide(currentSlide);
    }
  }, 4000);
});

// ==========================================================================
// SYSTEMS TELEMETRY CONSOLE LOGS
// ==========================================================================

function logTerminal(message, type = 'info') {
  const time = new Date().toLocaleTimeString();
  const rawText = `[${time}] > ${message.replace(/<[^>]*>/g, '')}`;
  
  logHistory.push({ time, message, type, rawText });
  renderTerminalLogs();
}

function renderTerminalLogs() {
  if (!terminalOutput) return;
  terminalOutput.innerHTML = '';
  
  const searchVal = searchTerminalInput ? searchTerminalInput.value.toLowerCase().trim() : '';
  const filterVal = filterTerminalSelect ? filterTerminalSelect.value : 'all';
  
  const filtered = logHistory.filter(log => {
    if (filterVal !== 'all' && log.type !== filterVal) return false;
    if (searchVal && !log.rawText.toLowerCase().includes(searchVal)) return false;
    return true;
  });
  
  filtered.forEach(log => {
    const line = document.createElement('div');
    line.className = 'log-line';
    line.innerHTML = `<span class="log-time-indicator">[${log.time}]</span><span class="log-txt-core log-${log.type}">${log.message}</span>`;
    terminalOutput.appendChild(line);
  });
  
  setupTerminalScroll();
}

function setupTerminalScroll() {
  const view = document.querySelector('.console-terminal-view');
  if (view) {
    view.scrollTop = view.scrollHeight;
  }
}

function setupTerminalControls() {
  if (clearTerminalBtn) {
    clearTerminalBtn.addEventListener('click', () => {
      logHistory = [];
      renderTerminalLogs();
      logTerminal('Console records purged successfully.', 'info');
    });
  }
  
  if (searchTerminalInput) {
    searchTerminalInput.addEventListener('input', renderTerminalLogs);
  }
  
  if (filterTerminalSelect) {
    filterTerminalSelect.addEventListener('change', renderTerminalLogs);
  }
  
  if (downloadLogsBtn) {
    downloadLogsBtn.addEventListener('click', () => {
      if (logHistory.length === 0) {
        logTerminal('Console stream empty. Compile aborted.', 'warning');
        return;
      }
      
      let md = `# Nexsync Biosphere Command Console - System Diagnostics Report\r\n\r\n`;
      md += `## Administrative Session Details\r\n`;
      md += `* **Exported Timestamp:** ${new Date().toLocaleString()}\r\n`;
      md += `* **Connection Status:** ${isConnected ? "STREAM ACTIVE" : "OFFLINE"}\r\n`;
      md += `* **Operational Period:** ${ribbonSegments ? Array.from(ribbonSegments).find(s => s.classList.contains('active'))?.dataset.period.toUpperCase() : "CLASSES"}\r\n`;
      md += `* **Session Cache Key:** Fresh Active Handshake\r\n\r\n`;
      
      md += `## Core System Activity Log\r\n`;
      md += `| Timestamp | Severity | Diagnostic Event Statement |\r\n`;
      md += `| :--- | :--- | :--- |\r\n`;
      
      logHistory.forEach(log => {
        const severity = log.type.toUpperCase();
        const cleanText = log.message.replace(/<[^>]*>/g, '');
        md += `| ${log.time} | \`${severity}\` | ${cleanText} |\r\n`;
      });
      
      const blob = new Blob([md], { type: 'text/markdown;charset=utf-8' });
      const url = URL.createObjectURL(blob);
      
      const link = document.createElement('a');
      link.href = url;
      link.download = `nexsync-diagnostics-report-${Date.now()}.md`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
      
      logTerminal('Diagnostics record exported in Markdown table format.', 'success');
    });
  }
}

// ==========================================================================
// FIREBASE ENVIRONMENT HANDSHAKE
// ==========================================================================

function loadFirebaseConfig() {
  let savedConfig = localStorage.getItem('iris_admin_firebase_config');
  let configToUse = DEFAULT_FIREBASE_CONFIG;
  
  if (savedConfig) {
    try {
      const parsed = JSON.parse(savedConfig);
      if (parsed.apiKey) {
        configToUse = parsed;
        logTerminal('Custom administrative configs loaded from local cache.', 'info');
      } else {
        logTerminal('Incomplete cached parameters. Reverting to system defaults.', 'warning');
        localStorage.removeItem('iris_admin_firebase_config');
      }
    } catch (e) {
      logTerminal('Configuration file parse failed. Defaults staged.', 'warning');
    }
  } else {
    logTerminal('Telemetry channel linked to core database "iris-138ef".', 'info');
  }
  
  if (configJsonArea) {
    configJsonArea.value = JSON.stringify(configToUse, null, 2);
  }
  initializeFirebase(configToUse);
}

function initializeFirebase(config) {
  try {
    if (typeof firebase === 'undefined') {
      throw new Error('Firebase script libraries failed to load. CDN may be blocked or offline.');
    }

    if (firebase.apps.length > 0) {
      firebase.apps.forEach(app => app.delete());
    }
    
    app = firebase.initializeApp(config);
    auth = firebase.auth();
    db = firebase.firestore();
    storage = firebase.storage();
    
    try {
      db.enablePersistence().catch((err) => {
        console.warn("Firestore offline persistence promise rejected:", err);
      });
    } catch (e) {
      console.warn("Firestore offline persistence failed synchronously:", e);
    }
    
    isConnected = true;
    logTerminal('Credentials authenticated securely.', 'success');
    
    if (authConnectionBeacon) {
      authConnectionBeacon.className = "connection-beacon";
      beaconText.innerText = "Telemetry Secure Link Active";
    }
  } catch (e) {
    isConnected = false;
    logTerminal(`Credentials handshake failure: ${e.message}`, 'error');
    console.error("Firebase Handshake ERROR:", e);
    showAuthError(`System Error: ${e.message}. Rectify details inside sliders.`);
    
    if (authConnectionBeacon) {
      authConnectionBeacon.className = "connection-beacon offline";
      beaconText.innerText = "Telemetry Offline - Error";
    }
  }
}

// ==========================================================================
// VAULT GATE SECURITY KEY ENTRY
// ==========================================================================

function setupAuthListeners() {
  const loader = document.getElementById('initial-loader');
  
  const hideLoader = () => {
    if (loader) {
      loader.style.opacity = '0';
      setTimeout(() => {
        loader.style.display = 'none';
      }, 500);
    }
  };

  if (!isConnected || !auth) {
    hideLoader();
    authOverlay.style.display = 'flex';
    dashboardContainer.style.display = 'none';
    logTerminal('Gateway offline. Ready for local configuration adjustments.', 'warning');
    return;
  }
  
  auth.onAuthStateChanged(user => {
    hideLoader();
    
    if (user) {
      logTerminal(`Vault session successfully mapped: <strong>${user.email}</strong>`, 'success');
      showMossToast("Welcome back! Biosphere secure link active.", "success");
      
      if (user.email && userMonogram) {
        userMonogram.innerText = user.email.substring(0, 2).toUpperCase();
      }
      
      authOverlay.style.display = 'none';
      dashboardContainer.style.display = 'flex';
      
      syncActivePeriodState();
      loadTimetableHistory();
      startNodesSimulator();
    } else {
      authOverlay.style.display = 'flex';
      dashboardContainer.style.display = 'none';
      logTerminal('Administrative sync session closed.', 'info');
    }
  });
}

// Clear any stale local lockouts
localStorage.removeItem('iris_admin_failed_attempts');
localStorage.removeItem('iris_admin_lock_until');

loginBtn.addEventListener('click', async () => {
  const email = emailInput.value.trim();
  const pass = passInput.value;
  
  if (!email || !pass) {
    showAuthError('Please enter your access email and password.');
    return;
  }
  
  if (!isConnected || !auth) {
    showAuthError('Firebase connection initializing... Please check network or reload.');
    return;
  }
  
  loginBtn.disabled = true;
  loginBtn.querySelector('span').innerText = 'AUTHENTICATING...';
  authError.style.display = 'none';
  
  try {
    await auth.signInWithEmailAndPassword(email, pass);
    logTerminal(`Vault session successfully mapped: <strong>${email}</strong>`, 'success');
  } catch (e) {
    console.error("Auth error:", e);
    let msg = e.message;
    if (e.code === 'auth/invalid-credential' || e.code === 'auth/wrong-password' || e.code === 'auth/user-not-found') {
      msg = 'Invalid email or password. Please verify your admin credentials.';
    } else if (e.code === 'auth/invalid-email') {
      msg = 'Please enter a valid email address format.';
    } else if (e.code === 'auth/network-request-failed') {
      msg = 'Network timeout. Could not reach Firebase servers.';
    } else if (e.code === 'auth/too-many-requests') {
      msg = 'Temporarily rate limited due to multiple attempts. Please wait a moment.';
    }
    
    showAuthError(msg);
    logTerminal(`Authentication failed: ${msg}`, 'error');
  } finally {
    loginBtn.disabled = false;
    loginBtn.querySelector('span').innerText = 'Verify Access Portal';
  }
});

// Enter key support for instant login
[emailInput, passInput].forEach(input => {
  if (input) {
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        loginBtn.click();
      }
    });
  }
});

logoutBtn.addEventListener('click', () => {
  auth.signOut();
});

function showAuthError(msg) {
  authError.innerText = msg;
  authError.style.display = 'block';
}

if (btnTogglePassword && passInput) {
  btnTogglePassword.addEventListener('click', () => {
    const type = passInput.getAttribute('type') === 'password' ? 'text' : 'password';
    passInput.setAttribute('type', type);
    
    const icon = btnTogglePassword.querySelector('i');
    if (type === 'text') {
      icon.className = 'fa-solid fa-eye-slash';
      logTerminal('Vault passkey visibility enabled.', 'info');
    } else {
      icon.className = 'fa-solid fa-eye';
      logTerminal('Vault passkey visibility disabled.', 'info');
    }
  });
}

// Config Sliders Configuration Modal Bindings
showConfigBtn.addEventListener('click', () => {
  configModal.style.display = 'flex';
});

closeModalBtn.addEventListener('click', () => {
  configModal.style.display = 'none';
});

saveConfigBtn.addEventListener('click', () => {
  const jsonStr = configJsonArea.value.trim();
  const validated = sanitizeAndValidateFirebaseConfig(jsonStr);
  if (!validated) {
    showMossToast('Configuration error. See modal log entries.', 'error');
    return;
  }
  
  localStorage.setItem('iris_admin_firebase_config', JSON.stringify(validated));
  configJsonArea.value = JSON.stringify(validated, null, 2);
  
  showMossToast('Saving parameters & re-connecting...', 'info');
  setTimeout(() => {
    configModal.style.display = 'none';
    const logConsole = document.getElementById('config-validation-log');
    if (logConsole) logConsole.style.display = 'none';
    
    initializeFirebase(validated);
    setupAuthListeners();
  }, 1000);
});



function syncActivePeriodState() {
  if (!isConnected) return;
  
  logTerminal('Establishing real-time cloud database synchronization...', 'info');
  initFirestoreFeedbackStream();
  
  db.collection('config').doc('global').onSnapshot(doc => {
    if (doc.exists) {
      const data = doc.data();
      const currentPeriod = data.academic_period || 'classes';
      
      logTerminal(`Sync Telemetry: Operational period mode: <strong>${currentPeriod}</strong>`, 'success');
      
      // Update tactile Segmented Switcher state
      ribbonSegments.forEach(seg => {
        if (seg.dataset.period === currentPeriod) {
          seg.classList.add('active');
        } else {
          seg.classList.remove('active');
        }
      });
      
      // Update switcher description copy
      const descs = {
        classes: 'Standard classes mode: regular curriculum sessions, lectures, and laboratory periods.',
        vacation: '🏖️ Vacation Mode: Campus in recess, semester break notice, and upcoming milestones active.',
        ramadan: '🌙 Ramadan Timing Mode: Compressed lecture periods and adjusted prayer intervals in effect.',
        midterms: 'Midterm testing mode: interim assessments, mid-semester testing logs, and check schedules.',
        finals: 'Final examination mode: core semester finals, grade evaluation compiles, and term closeout.',
        sports_week: 'Athletic Sports Week: campus extracurricular activities, sports day schedules, and session breaks.'
      };
      if (activePeriodDesc) {
        activePeriodDesc.innerText = descs[currentPeriod] || 'Lecture tracks active.';
      }

      const metricModeVal = document.getElementById('metric-mode-val');
      if (metricModeVal) {
        metricModeVal.innerText = currentPeriod.toUpperCase().replace('_', ' ');
      }

      // Update Mockup period card theme
      const mockCard = document.getElementById('mock-period-card');
      const mockBadge = document.getElementById('mock-period-badge');
      const mockTitle = document.getElementById('mock-period-title');
      const mockSubtitle = document.getElementById('mock-period-subtitle');
      if (mockCard && mockBadge && mockTitle && mockSubtitle) {
        mockCard.className = 'emulator-mode-card';
        if (currentPeriod === 'classes') {
          mockCard.classList.add('theme-classes');
          mockBadge.innerHTML = '<i class="fa-solid fa-graduation-cap"></i> CLASSES MODE';
          mockTitle.innerText = 'CLASSES IN SESSION';
          mockSubtitle.innerText = 'Regular academic lecturing track';
        } else if (currentPeriod === 'vacation') {
          mockCard.classList.add('theme-vacation');
          mockBadge.innerHTML = '<i class="fa-solid fa-umbrella-beach"></i> VACATION MODE';
          mockTitle.innerText = 'CAMPUS IN RECESS';
          mockSubtitle.innerText = 'Semester break & milestones active';
        } else if (currentPeriod === 'ramadan') {
          mockCard.classList.add('theme-ramadan');
          mockBadge.innerHTML = '<i class="fa-solid fa-moon"></i> RAMADAN MODE';
          mockTitle.innerText = 'RAMADAN TIMINGS ACTIVE';
          mockSubtitle.innerText = 'Compressed 1-hr lecture slots';
        } else if (currentPeriod === 'midterms') {
          mockCard.classList.add('theme-midterms');
          mockBadge.innerHTML = '<i class="fa-solid fa-pen-clip"></i> MIDTERMS MODE';
          mockTitle.innerText = 'MIDTERMS ACTIVE';
          mockSubtitle.innerText = 'Warm study session tracks';
        } else if (currentPeriod === 'finals') {
          mockCard.classList.add('theme-finals');
          mockBadge.innerHTML = '<i class="fa-solid fa-award"></i> FINALS MODE';
          mockTitle.innerText = 'FINALS ACTIVE';
          mockSubtitle.innerText = 'Obsidian exam card theme';
        } else if (currentPeriod === 'sports_week') {
          mockCard.classList.add('theme-sports');
          mockBadge.innerHTML = '<i class="fa-solid fa-volleyball"></i> SPORTS WEEK';
          mockTitle.innerText = 'SPORTS WEEK IN SESSION';
          mockSubtitle.innerText = 'Extracurricular activities & breaks';
        }
      }

      // Render active timetable statistics dynamically from database
      if (data.active_timetable_json) {
        try {
          const parsedTimetable = JSON.parse(data.active_timetable_json);
          updateActiveTimetablePreview(parsedTimetable);
        } catch (e) {
          console.warn("Failed to parse active timetable json:", e);
        }
      }

      // Dynamic pre-fill version code from database
      if (data.latest_apk_update) {
        const ota = data.latest_apk_update;
        if (apkVersionName && (!apkVersionName.value || apkVersionName.value === '1.2.0')) {
          apkVersionName.value = ota.version_name || '1.2.0';
        }
        if (apkVersionCode && (!apkVersionCode.value || apkVersionCode.value === '3')) {
          apkVersionCode.value = (parseInt(ota.version_code) || 0) + 1;
        }
        if (apkSwitchVisible) {
          apkSwitchVisible.checked = ota.show_update_card !== false;
        }
      }

      // Announcement Transceiver synchronization
      if (broadcastSwitchVisible && broadcastMessage) {
        const isBroadcastOn = data.broadcast_enabled || false;
        const broadcastMsg = data.broadcast_message || '';
        
        broadcastSwitchVisible.checked = isBroadcastOn;
        if (document.activeElement !== broadcastMessage) {
          broadcastMessage.value = broadcastMsg;
          updateBroadcastCharCount(broadcastMsg.length);
        }
        
        // Direct mockup Notice sync
        const mockNoticeCard = document.getElementById('mock-notice-card');
        const mockNoticeText = document.getElementById('mock-notice-text') || document.getElementById('mock-notice-body');
        if (mockNoticeCard && mockNoticeText) {
          mockNoticeText.innerText = broadcastMsg || 'All Quiet on Campus • No active broadcasts right now';
          if (isBroadcastOn && broadcastMsg) {
            mockNoticeCard.style.background = 'rgba(239, 68, 68, 0.12)';
            mockNoticeCard.style.borderColor = 'rgba(239, 68, 68, 0.35)';
          } else {
            mockNoticeCard.style.background = 'rgba(6, 182, 212, 0.1)';
            mockNoticeCard.style.borderColor = 'rgba(6, 182, 212, 0.25)';
          }
        }
        
        if (btnBroadcastPush) {
          btnBroadcastPush.disabled = false;
          const span = btnBroadcastPush.querySelector('span');
          if (span) {
            span.innerText = isBroadcastOn ? 'BROADCAST ACTIVE (CLICK TO UPDATE)' : 'PUSH EMERGENCY BROADCAST';
          }
        }
        
        // Synchronize hidden legacy elements for workspace compatibility
        if (broadcastSwitch) broadcastSwitch.checked = isBroadcastOn;
        if (broadcastingBadge) broadcastingBadge.style.display = isBroadcastOn ? 'inline-block' : 'none';
      }
    } else {
      logTerminal('Operational config document empty. Initializing defaults.', 'warning');
      db.collection('config').doc('global').set({
        academic_period: 'classes',
        active_timetable_version: Date.now(),
        latest_apk_update: {
          version_name: '1.2.0',
          version_code: 3,
          apk_url: '',
          release_notes: 'Production updates and optimization releases.',
          released_at: firebase.firestore.FieldValue.serverTimestamp()
        }
      });
    }
  }, err => {
    logTerminal(`Database Sync Failure: ${err.message}`, 'error');
  });
}

function updateActiveTimetablePreview(json) {
  let sessions = [];
  if (Array.isArray(json)) {
    sessions = json;
  } else if (json && json.sessions && Array.isArray(json.sessions)) {
    sessions = json.sessions;
  } else {
    return;
  }

  const normalized = sessions.map(s => {
    let batch = s.batch || s.class_name || s.section || '';
    let day = s.day || s.weekday || 'Monday';
    let start = s.start || '08:30';
    let end = s.end || '10:00';
    if (s.time || s.period) {
      let parts = (s.time || s.period).split('-');
      if (parts.length >= 2) {
        start = parts[0].trim();
        end = parts[1].trim();
      }
    }
    let subject = s.subject || s.course || s.title || 'LECTURE';
    let teacher = s.teacher || s.instructor || s.staff || 'Staff';
    let room = s.room || s.location || 'TBD';
    return {
      id: s.id || `${batch}-${day}-${start}`,
      department: s.department || '',
      batch: batch,
      day: day,
      start: start,
      end: end,
      subject: cleanSubject(subject),
      teacher: teacher,
      room: room
    };
  });

  updateTimetablePreview(normalized);
  
  // Sync device emulator timetable screen
  updateEmulatorTimetables(normalized);
}

// Ribbon Switch Snappy Selection Handler
ribbonSegments.forEach(seg => {
  seg.addEventListener('click', async () => {
    // 1. Instantly respond client-side first for extreme snappiness
    ribbonSegments.forEach(s => s.classList.remove('active'));
    seg.classList.add('active');
    
    const targetPeriod = seg.dataset.period;
    
    // Update local text descriptions instantly
    const descs = {
      classes: 'Standard classes mode: regular curriculum sessions, lectures, and laboratory periods.',
      vacation: '🏖️ Vacation Mode: Campus in recess, semester break notice, and upcoming milestones active.',
      ramadan: '🌙 Ramadan Timing Mode: Compressed lecture periods and adjusted prayer intervals in effect.',
      midterms: 'Midterm testing mode: interim assessments, mid-semester testing logs, and check schedules.',
      finals: 'Final examination mode: core semester finals, grade evaluation compiles, and term closeout.',
      sports_week: 'Athletic Sports Week: campus extracurricular activities, sports day schedules, and session breaks.'
    };
    if (activePeriodDesc) {
      activePeriodDesc.innerText = descs[targetPeriod] || 'Lecture tracks active.';
    }

    logTerminal(`Snappy Action: Selecting operational period: <strong>${targetPeriod}</strong>`, 'info');
    
    if (!isConnected) {
      logTerminal('Offline State: State updated locally but server sync is pending.', 'warning');
      return;
    }
    
    // 2. Fire the database update asynchronously in background
    try {
      await db.collection('config').doc('global').update({
        academic_period: targetPeriod,
        updated_at: firebase.firestore.FieldValue.serverTimestamp()
      });
      incrementDatabaseOps();
      logTerminal(`Database Sync complete: Operational period committed as <strong>${targetPeriod}</strong>.`, 'success');
      showMossToast(`Academic Timeline set to ${targetPeriod.toUpperCase()}!`, "success");
    } catch (e) {
      logTerminal(`Database Sync Failed: ${e.message}`, 'error');
      showMossToast(e.message, "error");
    }
  });
});

// ==========================================================================
// GLOBAL ALERTS TRANSMITTER
// ==========================================================================

function formatMockTime(date) {
  const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  const month = months[date.getMonth()];
  const day = date.getDate();
  let hr = date.getHours();
  const period = hr >= 12 ? 'PM' : 'AM';
  hr = hr % 12;
  hr = hr ? hr : 12;
  const min = date.getMinutes().toString().padStart(2, '0');
  return `${month} ${day}, ${hr}:${min} ${period}`;
}

function updateBroadcastCharCount(len) {
  if (!broadcastCharCount) return;
  broadcastCharCount.innerText = len;
  
  // Dynamic warning color state shifts
  broadcastCharCount.className = '';
  if (len <= 100) {
    broadcastCharCount.classList.add('char-counter-normal');
  } else if (len <= 135) {
    broadcastCharCount.classList.add('char-counter-warning');
  } else {
    broadcastCharCount.classList.add('char-counter-danger');
  }

  const mockNoticeCard = document.getElementById('mock-notice-card');
  const mockNoticeBody = document.getElementById('mock-notice-body');
  const mockNoticeTime = document.getElementById('mock-notice-time');
  const mockNoticeIcon = document.getElementById('mock-notice-icon-badge');
  const mockNoticeLive = document.getElementById('mock-notice-live-tag');
  
  if (mockNoticeBody && broadcastMessage) {
    const rawVal = broadcastMessage.value.trim();
    mockNoticeBody.innerText = rawVal || 'All Quiet on Campus • No active broadcasts right now';
    
    const isBroadcastEnabled = broadcastSwitchVisible ? broadcastSwitchVisible.checked : false;
    
    if (mockNoticeCard) {
      if (isBroadcastEnabled && rawVal) {
        mockNoticeCard.className = 'mock-notice-card active-notice';
        if (mockNoticeIcon) mockNoticeIcon.className = 'notice-icon-badge';
        if (mockNoticeLive) mockNoticeLive.style.display = 'inline-block';
      } else {
        mockNoticeCard.className = 'mock-notice-card notice-off';
        if (mockNoticeIcon) mockNoticeIcon.className = 'notice-icon-badge off';
        if (mockNoticeLive) mockNoticeLive.style.display = 'none';
      }
    }
    
    if (mockNoticeTime) {
      if (rawVal) {
        mockNoticeTime.innerText = formatMockTime(new Date());
      } else {
        mockNoticeTime.innerText = 'NEVER';
      }
    }
  }
  
  if (btnBroadcastPush) {
    btnBroadcastPush.disabled = false;
  }
}

if (broadcastMessage) {
  broadcastMessage.addEventListener('input', () => {
    const len = broadcastMessage.value.length;
    updateBroadcastCharCount(len);
  });
}

// Preset chips triggers
presetChips.forEach(chip => {
  chip.addEventListener('click', () => {
    const text = chip.dataset.preset;
    if (broadcastMessage) {
      broadcastMessage.value = text;
      updateBroadcastCharCount(text.length);
      logTerminal('Preset announcement copy staged in transceiver.', 'info');
    }
  });
});

// Explicit visible industrial slide toggle switch logic
if (broadcastSwitchVisible) {
  broadcastSwitchVisible.addEventListener('change', async () => {
    if (!isConnected || !db) {
      showMossToast("Database offline. Reconnecting...", "warning");
      return;
    }
    
    const enabled = broadcastSwitchVisible.checked;
    logTerminal(`Updating broadcast transmission link state: ${enabled ? 'ACTIVE' : 'STANDBY'}...`, 'info');
    
    try {
      await db.collection('config').doc('global').set({
        broadcast_enabled: enabled,
        broadcast_updated_at: firebase.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      
      incrementDatabaseOps();
      logTerminal(`Server sync complete: Broadcast live stream set to ${enabled ? 'ON' : 'OFF'}.`, 'success');
      showMossToast(`Broadcast announcement banner turned ${enabled ? 'ON' : 'OFF'}!`, "info");
    } catch (e) {
      logTerminal(`Failed to update broadcast switch: ${e.message}`, 'error');
      showMossToast(e.message, "error");
      // Revert UI on failure
      broadcastSwitchVisible.checked = !enabled;
    }
  });
}

// Dedicated Dispatch Signal button (explicitly turns alert ON with textarea message)
if (btnBroadcastPush) {
  btnBroadcastPush.addEventListener('click', async () => {
    if (!isConnected || !db) {
      showMossToast("Database connection offline.", "error");
      return;
    }
    
    const msg = (broadcastMessage?.value || '').trim();
    logTerminal(`Preparing to dispatch broadcast signal packet...`, 'info');
    
    btnBroadcastPush.disabled = true;
    const btnSpan = btnBroadcastPush.querySelector('span');
    if (btnSpan) btnSpan.innerText = 'TRANSMITTING EMISSION WAVE...';
    
    try {
      await db.collection('config').doc('global').set({
        broadcast_message: msg,
        broadcast_enabled: true, // Always force enable ON upon explicit dispatch
        broadcast_updated_at: firebase.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      
      incrementDatabaseOps();
      
      // Sync visible switch UI
      if (broadcastSwitchVisible) broadcastSwitchVisible.checked = true;
      
      logTerminal(`Dispatch success: Broadcast alert is now LIVE with message: "${msg}".`, 'success');
      showMossToast("Global notice dispatched live to student devices!", "success");
    } catch (e) {
      logTerminal(`Broadcast transmission failed: ${e.message}`, 'error');
      showMossToast(e.message, "error");
    } finally {
      btnBroadcastPush.disabled = false;
      if (btnSpan) btnSpan.innerText = 'PUSH EMERGENCY BROADCAST';
    }
  });
}

// ==========================================================================
// TIMETABLE DEPLOYMENT ENGINE (AIRPORT DEPARTURES LEDGER)
// ==========================================================================

// ==========================================================================
// TIMETABLE DEPLOYMENT ENGINE (AIRPORT DEPARTURES LEDGER)
// ==========================================================================

const BATCH_RE = /\b(?:(?:FA|SP)\d{2}-[A-Z0-9]+(?:-[A-Z0-9]+)?|(?:BCS|BSE|BAI|BDS|BCY|BEE|BME|BCE|BBA|BAF|BEN|BPS|FSN|BTY|BCH|HND|RBS|BSCS|BSSE|BSAI|BSDS|BSEE|BSME|BSCE)-?\d*[A-Z]?|[A-Z]{2,4}-\d+[A-Z]?)\b/i;

const GRID_COLUMNS = [
  { name: "Batch", minX: 0, maxX: 100 },
  { name: "Slot 1", minX: 100, maxX: 204 },
  { name: "Slot 2", minX: 204, maxX: 319 },
  { name: "Slot 3", minX: 319, maxX: 434 },
  { name: "Slot 4", minX: 434, maxX: 549 },
  { name: "Slot 5", minX: 549, maxX: 664 },
  { name: "Slot 6", minX: 664, maxX: 780 }
];

const DEPT_CODES = new Set([
  "CS", "SE", "AI", "DS", "CYS", "BCS", "BSE", "BAI", "BDS", "BCY", "BSCS", "BSSE", "BSAI", "BSDS",
  "EE", "BEE", "BSEE", "CE", "BCE", "TE", "BTE", "PTE",
  "ME", "BME", "BSME", "CVE", "BCVE", "BSCE",
  "MS", "BBA", "MBA", "AF", "BAF", "BBS", "EC", "BEC", "MGT", "HRM",
  "MT", "MTH", "BMT", "HUM", "ENG", "BEN", "PSY", "BPS", "MCM", "IR", "BIR",
  "FSN", "BTY", "BCH", "HND", "RBS", "BIO", "BBI", "MB", "PHY", "CHM", "VS"
]);

const TEACHER_TITLE_RE = /\b(Dr\.?|Prof\.?|Engr\.?|Mr\.?|Ms\.?|Mrs\.?|Sir|Mam|Madam|Instructor|Lecturer|Teacher|Faculty|Advocate|Barrister|Hafiz|Qari|Syed|Syeda|Chaudhry|Ch\.?|Malik|Raja|Sardar|Mian|Sheikh|Sh\.?)\b/i;
const CAPACITY_RE = /\s*\(\d+\)\s*/g;
const DURATION_MARKER_RE = /\s*\(\s*\d+\s*(?:hrs?|hours?)\s*\)\s*/gi;

const SUBJECT_KEYWORDS = new Set([
  "programming", "engineering", "structures", "systems", "calculus",
  "algebra", "physics", "chemistry", "communication", "technology",
  "network", "networks", "database", "security", "intelligence", "learning",
  "design", "architecture", "development", "operating", "digital",
  "web", "mobile", "software", "compiler", "automata", "quran",
  "marketing", "management", "psychology", "commerce", "civics",
  "lab", "fundamentals", "advanced", "introduction", "applied",
  "quantum", "machine", "formal", "methods", "data", "mining",
  "patterns", "interaction", "resource", "functional", "english",
  "pre-calculus", "engagement", "community", "probability",
  "statistics", "analysis", "computing", "science", "theory",
  "information", "numerical", "discrete", "linear", "islamic",
  "studies", "professional", "ethics", "technical", "writing",
  "computer", "organization", "graphics", "visualization",
  "parallel", "distributed", "artificial", "deep", "circuits",
  "signals", "differential", "equations", "dynamics", "thermodynamics",
  "fluid", "mechanics", "electromagnetics", "microprocessor", "embedded",
  "instrumentation", "measurement", "materials", "robotics", "control",
  "algorithms", "vision", "nlp", "forensics", "cryptography", "blockchain",
  "iot", "microcontroller", "vlsi", "antennas", "propagation", "renewable",
  "energy", "accounting", "finance", "economics", "econometrics", "auditing",
  "taxation", "banking", "investments", "portfolio", "logistics", "entrepreneurship",
  "tajweed", "hadith", "seerah", "sociology", "diplomacy", "journalism", "media",
  "french", "german", "chinese", "arabic", "matrices", "vectors", "biochemistry",
  "microbiology", "genetics", "physiology", "immunology", "nutrition"
]);

const ROOM_PATTERNS = [
  /\bPhysics\s+Lab\b/i,
  /\bNetworking\s+Lab\b/i,
  /\bDLD\s+Lab\b/i,
  /\bBio\s+Lab\b/i,
  /\bFP\s+Lab\b/i,
  /\bFA\s+Lab\b/i,
  /\bDigital\s+Lab\b/i,
  /\bElectric\s+Machines\s+Lab\b/i,
  /\bMechanical\s+Vibrations\s+Lab\b/i,
  /\bIC\s+Engines\s+Lab\b/i,
  /\bHMT\s+Lab\b/i,
  /\bThermodynamics\s+Lab\b/i,
  /\bThermo\s+Lab\b/i,
  /\bFluid\s+Mechanics\s+Lab\b/i,
  /\bPower\s+Lab\b/i,
  /\bC\s*&\s*E\s+Lab\b/i,
  /\bD\s*Block\s+Seminar\s+Room\b/i,
  /\bSeminar\s+Room\b/i,
  /\bConference\s+Room\b/i,
  /\bAuditorium\b/i,
  /\bMOM\s*Lab\b/i,
  /\bEFM\s*Lab\b/i,
  /\bMechanical\s+Lab\b/i,
  /\bElectronics\s+Lab\b/i,
  /\bHardware\s+Lab\b/i,
  /\bCircuit\s+Lab\b/i,
  /\bSoftware\s+Lab\b/i,
  /\bComputer\s+Lab\b/i,
  /\bCLab-?\d*\b/i,
  /\bLab-?\d+\b/i,
  /\bHall-[A-Z0-9]+\b/i,
  /\bRoom\s*[A-Z0-9-]+\b/i,
  /\b[A-Z]-\d+\b/i,
  /\b[A-Z]\d+(?:\.\d)?\b/i,
  /\b[A-Z]\d{1,2}\b/i
];

function stripCapacity(text) {
  if (!text) return "";
  return text.replace(CAPACITY_RE, "").replace(DURATION_MARKER_RE, "").trim();
}

function isBatchLine(line) {
  if (!line) return false;
  const stripped = line.trim();
  if (BATCH_RE.test(stripped)) {
    const withoutBatch = stripped.replace(BATCH_RE, '').replace(/[\s,/&-]+/g, '').trim();
    if (withoutBatch.length <= 4) return true;
  }
  return false;
}

function isTeacherLine(line) {
  if (!line) return false;
  const clean = stripCapacity(line).trim();
  if (TEACHER_TITLE_RE.test(clean)) return true;

  const words = clean.split(/\s+/).filter(w => w);
  if (words.length >= 2 && words.length <= 5) {
    const first = words[0].replace(/\.$/, "").toUpperCase();
    if (DEPT_CODES.has(first)) {
      const rest = words.slice(1).join(" ");
      if (!looksLikeSubject(rest) && !matchRoom(rest) && !isBatchLine(rest)) {
        return true;
      }
    }

    // Capitalized name heuristic: 2-4 words, starts with uppercase, no subject keywords, no numbers
    const hasDigits = /\d/.test(clean);
    const allCapitalized = words.every(w => /^[A-Z][a-zA-Z.'-]*$/.test(w));
    const hasSubjectWord = words.some(w => SUBJECT_KEYWORDS.has(w.toLowerCase()));
    const isRoom = matchRoom(clean);
    const isBatch = isBatchLine(clean);

    if (!hasDigits && allCapitalized && !hasSubjectWord && !isRoom && !isBatch) {
      return true;
    }
  }
  return false;
}

function cleanTeacherName(raw) {
  let cleaned = stripCapacity(raw).trim();
  // Normalize missing space after title e.g. "Dr.Saqib" -> "Dr. Saqib", "Engr.Hafiz" -> "Engr. Hafiz"
  cleaned = cleaned.replace(/^(Dr|Prof|Engr|Mr|Ms|Mrs|Sir|Mam)\.([A-Za-z])/i, '$1. $2');
  cleaned = cleaned.replace(/^(Dr|Prof|Engr|Mr|Ms|Mrs|Sir|Mam)([A-Z])/i, '$1 $2');
  
  let words = cleaned.split(/\s+/).filter(w => w);
  if (words.length >= 2) {
    let first = words[0].replace(/\.$/, "").toUpperCase();
    if (DEPT_CODES.has(first)) {
      cleaned = words.slice(1).join(" ");
    }
  }
  
  let subjectCode = "";
  words = cleaned.split(/\s+/).filter(w => w);
  if (words.length >= 3) {
    let lastWord = words[words.length - 1].trim();
    if (/^[A-Z]{2,4}\d*$/.test(lastWord) && !DEPT_CODES.has(lastWord)) {
      subjectCode = lastWord;
      cleaned = words.slice(0, -1).join(" ");
    }
  }
  
  return { name: cleaned.trim(), subjectCode };
}

function looksLikeSubject(text) {
  if (!text) return false;
  let lower = text.toLowerCase();
  for (let kw of SUBJECT_KEYWORDS) {
    if (lower.includes(kw)) return true;
  }
  // Course code format e.g. CS314, CSC101, MTH101, EEE241, HUM100
  if (/\b[A-Z]{2,4}\s*\d{2,4}[A-Z]?\b/i.test(text)) return true;
  return false;
}

function matchRoom(text) {
  if (!text) return null;
  let stripped = stripCapacity(text);
  for (let pat of ROOM_PATTERNS) {
    let m = stripped.match(pat);
    if (m) return m[0].trim();
  }
  return null;
}

function cleanRoomFromText(text) {
  if (!text) return "";
  let cleaned = text;
  for (let pat of ROOM_PATTERNS) {
    cleaned = cleaned.replace(pat, "");
  }
  return stripCapacity(cleaned).trim();
}

function cleanSubject(text) {
  if (!text) return "";
  let cleaned = cleanRoomFromText(text);
  // Strip watermarks like "aSc Timetables", "CUI Sahiwal"
  cleaned = cleaned.replace(/\b(aSc\s+Timetables|Timetable\s+generated|COMSATS\s+University|CUI\s+Sahiwal|Islamabad,Sahiwal)\b/gi, '');
  // Strip leading/trailing time slots or slot numbers e.g. "8:00 9:00", "1 8:00 - 9:00"
  cleaned = cleaned.replace(/^\s*(?:\d+\s+)?\d{1,2}[:.]?\d{2}(?:\s*-\s*|\s+)\d{1,2}[:.]?\d{2}\s*/gi, '');
  cleaned = cleaned.replace(/\s*(?:\d+\s+)?\d{1,2}[:.]?\d{2}(?:\s*-\s*|\s+)\d{1,2}[:.]?\d{2}\s*$/gi, '');
  cleaned = cleaned.replace(/\b\d{1,2}[:.]?\d{2}\s*-\s*\d{1,2}[:.]?\d{2}\b/gi, '');
  cleaned = cleaned.replace(/\b\d{1,2}[:.]?\d{2}\s+\d{1,2}[:.]?\d{2}\b/gi, '');
  // Strip parenthesized teacher or duration annotations e.g. (Dr. Shahzad Ali), (1 hr)
  cleaned = cleaned.replace(/\s*\([^)]*(?:Dr|Prof|Engr|Mr|Ms|Mrs|Sir|Mam|[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)[^)]*\)/gi, '');
  cleaned = cleaned.replace(DURATION_MARKER_RE, '');
  cleaned = cleaned.replace(CAPACITY_RE, '');
  // Strip leading/trailing batch identifiers
  cleaned = cleaned.replace(/^(?:(?:FA|SP)\d{2}-[A-Z0-9]+(?:-[A-Z0-9]+)?|[A-Z]{2,4}-\d+[A-Z]?|(?:BCS|BSE|BAI|BDS|BEE|BME|BBA|BSCS|BSSE|BSAI|BSDS|BSEE|BSME)-?\d*[A-Z]?)\s*[-/:]?\s*/i, '');
  cleaned = cleaned.replace(/\s*[-/:]?\s*(?:(?:FA|SP)\d{2}-[A-Z0-9]+(?:-[A-Z0-9]+)?|[A-Z]{2,4}-\d+[A-Z]?|(?:BCS|BSE|BAI|BDS|BEE|BME|BBA)-?\d*[A-Z]?)$/i, '');
  cleaned = cleaned.replace(/\s{2,}/g, " ").trim();
  return cleaned;
}

function isNameContinuation(line) {
  if (!line) return false;
  let words = line.split(/\s+/).filter(w => w);
  if (words.length === 0) return false;
  if (looksLikeSubject(line)) return false;
  if (matchRoom(line)) return false;
  if (isBatchLine(line)) return false;
  if (/\d/.test(line)) return false;

  for (let w of words) {
    if (!/^[A-Z][a-zA-Z.'-]*$/.test(w)) return false;
  }
  return words.length <= 3 && line.length <= 25;
}

function parseBatch(text) {
  if (!text) return null;
  let cleaned = text.replace(/\(.*?\)/g, "").trim().replace(/\s+/g, "");
  // Examples: FA22-BCS-6A -> BCS, BCS-6A -> BCS, FA25-BSME-B21-A -> BSME, BBA-4A -> BBA
  let mWithIntake = cleaned.match(/^(?:FA|SP)\d{2}-([A-Z]{2,4})/i);
  if (mWithIntake) {
    return {
      batch: cleaned,
      department: mWithIntake[1].toUpperCase()
    };
  }
  let mNoIntake = cleaned.match(/^([A-Z]{2,4})/i);
  if (mNoIntake) {
    return {
      batch: cleaned,
      department: mNoIntake[1].toUpperCase()
    };
  }
  let parts = cleaned.split("-");
  return {
    batch: cleaned,
    department: parts.length >= 2 ? parts[0].toUpperCase() : "General"
  };
}

function parseClassCell(cellText) {
  if (!cellText) return null;
  let flat = cellText.replace(/\n/g, " ").trim();
  if (!flat || /Break|kaerB/i.test(flat)) return null;

  // Handle single-line combined formats (e.g. "CS314 AI - Dr. Shahzad Ali - C101" or "CS314 AI | Shahzad Ali | C101")
  let rawLines = cellText.split("\n").map(l => l.trim()).filter(l => l);
  let lines = [];
  for (let r of rawLines) {
    if (r.includes(' - ') && !looksLikeSubject(r)) {
      lines.push(...r.split(/\s+-\s+/));
    } else if (r.includes(' | ')) {
      lines.push(...r.split(/\s+\|\s+/));
    } else {
      lines.push(r);
    }
  }
  lines = lines.map(l => l.trim()).filter(l => l);
  if (lines.length === 0) return null;

  let teacher = "Unknown";
  let room = "TBD";
  let subject = "";
  
  let teacherIdx = -1;
  let teacherContIdx = -1;
  let roomIdx = -1;
  let batchIdx = -1;

  // 1. Check if teacher is embedded in parentheses inside any line e.g. "CS314 AI (Dr. Shahzad Ali)"
  for (let i = 0; i < lines.length; i++) {
    const matchParenTeacher = lines[i].match(/\(((?:Dr\.?|Prof\.?|Engr\.?|Mr\.?|Ms\.?|Mrs\.?|Sir|Mam|[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)\s*[^)]*)\)/i);
    if (matchParenTeacher) {
      teacher = cleanTeacherName(matchParenTeacher[1]).name;
      lines[i] = lines[i].replace(matchParenTeacher[0], '').trim();
      break;
    }
  }

  // 2. Identify Batch line (so it is not merged into subject)
  for (let i = 0; i < lines.length; i++) {
    if (isBatchLine(lines[i])) {
      batchIdx = i;
      break;
    }
  }

  // 3. Identify Teacher line
  if (teacher === "Unknown") {
    for (let i = 0; i < lines.length; i++) {
      if (i === batchIdx) continue;
      if (isTeacherLine(lines[i])) {
        let cleanedTeacher = cleanTeacherName(lines[i]);
        teacher = cleanedTeacher.name;
        teacherIdx = i;
        
        if (i + 1 < lines.length && i + 1 !== batchIdx) {
          let nextLine = lines[i + 1];
          if (isNameContinuation(nextLine)) {
            teacher = teacher + " " + nextLine;
            teacherContIdx = i + 1;
          }
        }
        break;
      }
    }
  }

  // 4. Identify Room line
  for (let i = lines.length - 1; i >= 0; i--) {
    if (i === teacherIdx || i === teacherContIdx || i === batchIdx) continue;
    let line = lines[i];
    let stripped = stripCapacity(line);
    let roomMatch = matchRoom(stripped);
    if (roomMatch) {
      room = roomMatch;
      roomIdx = i;
      break;
    }
  }

  // 5. Construct cleaned Course Subject
  let subjectParts = [];
  for (let i = 0; i < lines.length; i++) {
    if (i === teacherIdx || i === teacherContIdx || i === batchIdx) continue;
    let cleaned = stripCapacity(lines[i]);
    if (i === roomIdx) {
      cleaned = cleanRoomFromText(cleaned);
    }
    if (cleaned) {
      subjectParts.push(cleaned);
    }
  }

  subject = subjectParts.join(" ") || "Unknown";
  subject = cleanSubject(subject);

  if (!subject || subject.trim() === '') return null;

  return { subject, teacher, room };
}

async function parseTimetablePdf(arrayBuffer) {
  const pdf = await pdfjsLib.getDocument({ data: arrayBuffer }).promise;
  let allSessions = [];
  let currentDay = "Monday";
  
  for (let pNum = 1; pNum <= pdf.numPages; pNum++) {
    const page = await pdf.getPage(pNum);
    const textContent = await page.getTextContent();
    const items = textContent.items;
    
    // 1. Detect Day
    let pageDay = null;
    for (let item of items) {
      let str = item.str.trim();
      let dayMatch = str.match(/\b(Mon|Monday|Tue|Tues|Tuesday|Wed|Wednesday|Thu|Thur|Thurs|Thursday|Fri|Friday|Sat|Saturday|Sun|Sunday)\b/i);
      if (dayMatch) {
        let rawDay = dayMatch[1].toLowerCase();
        const DAY_MAP = {
          mon: "Monday", monday: "Monday",
          tue: "Tuesday", tues: "Tuesday", tuesday: "Tuesday",
          wed: "Wednesday", wednesday: "Wednesday",
          thu: "Thursday", thur: "Thursday", thurs: "Thursday", thursday: "Thursday",
          fri: "Friday", friday: "Friday",
          sat: "Saturday", saturday: "Saturday",
          sun: "Sunday", sunday: "Sunday"
        };
        pageDay = DAY_MAP[rawDay];
        break;
      }
    }
    if (pageDay) {
      currentDay = pageDay;
    }
    
    // 2. Identify time headers & dynamically discover columns
    let timeWords = [];
    for (let item of items) {
      if (/\b\d{1,2}:\d{2}\b/.test(item.str) || /break|kaerb/i.test(item.str)) {
        timeWords.push(item);
      }
    }
    let timeLines = {};
    for (let tw of timeWords) {
      let roundedY = Math.round(tw.transform[5] / 5) * 5;
      if (!timeLines[roundedY]) timeLines[roundedY] = [];
      timeLines[roundedY].push(tw);
    }
    let headerY = -1;
    let maxCount = 0;
    for (let yVal in timeLines) {
      if (timeLines[yVal].length > maxCount) {
        maxCount = timeLines[yVal].length;
        headerY = parseFloat(yVal);
      }
    }
    
    // Dynamically discover columns from header
    let pageColumns = [];
    if (headerY !== -1) {
      let headerItems = items.filter(item => Math.abs(item.transform[5] - headerY) <= 15 && item.str.trim() !== '');
      headerItems.sort((a, b) => a.transform[4] - b.transform[4]);
      
      // Group horizontally adjacent header items into slot clusters
      let clusters = [];
      let curCluster = [];
      for (let it of headerItems) {
        if (it.transform[4] < 100) continue; // Skip batch column header
        if (curCluster.length === 0) {
          curCluster.push(it);
        } else {
          let prevRight = curCluster[curCluster.length - 1].transform[4] + (curCluster[curCluster.length - 1].width || 0);
          if (it.transform[4] - prevRight < 30) {
            curCluster.push(it);
          } else {
            clusters.push(curCluster);
            curCluster = [it];
          }
        }
      }
      if (curCluster.length > 0) clusters.push(curCluster);

      if (clusters.length >= 4) {
        let firstSlotMinX = clusters[0][0].transform[4];
        let batchMaxX = Math.max(80, firstSlotMinX - 10);
        
        pageColumns.push({
          name: "Batch",
          minX: 0,
          maxX: batchMaxX,
          start: "00:00",
          end: "00:00",
          isBreak: false
        });

        for (let i = 0; i < clusters.length; i++) {
          let cl = clusters[i];
          let text = cl.map(it => it.str).join(" ").trim();
          let clusterMinX = cl[0].transform[4];
          let clusterMaxX = cl[cl.length - 1].transform[4] + (cl[cl.length - 1].width || 0);
          
          let minX = i === 0 ? batchMaxX : (clusters[i-1][clusters[i-1].length - 1].transform[4] + clusterMinX) / 2;
          let maxX = i + 1 < clusters.length ? (clusterMaxX + clusters[i+1][0].transform[4]) / 2 : 850;
          
          let isBreak = /break|kaerb/i.test(text) || /\b(12:45\s*-\s*1:40|12:00\s*-\s*1:00|1:00\s*-\s*1:30)\b/i.test(text);
          let m = text.match(/(\d{1,2})[:.]?(\d{2})\s*-\s*(\d{1,2})[:.]?(\d{2})/);
          let start = "00:00";
          let end = "00:00";
          if (m) {
            start = `${m[1].padStart(2, '0')}:${m[2]}`;
            end = `${m[3].padStart(2, '0')}:${m[4]}`;
          }

          pageColumns.push({
            name: `Slot ${i + 1}`,
            minX: minX,
            maxX: maxX,
            start: start,
            end: end,
            isBreak: isBreak,
            text: text
          });
        }
      }
    }

    // Fallback if no dynamic header found
    if (pageColumns.length < 5) {
      pageColumns = [
        { name: "Batch", minX: 0, maxX: 100, start: "00:00", end: "00:00", isBreak: false },
        { name: "Slot 1", minX: 100, maxX: 204, start: "08:30", end: "09:55", isBreak: false },
        { name: "Slot 2", minX: 204, maxX: 319, start: "09:55", end: "11:20", isBreak: false },
        { name: "Slot 3", minX: 319, maxX: 434, start: "11:20", end: "12:45", isBreak: false },
        { name: "Slot 4", minX: 434, maxX: 549, start: "12:45", end: "01:40", isBreak: true },
        { name: "Slot 5", minX: 549, maxX: 664, start: "01:40", end: "03:05", isBreak: false },
        { name: "Slot 6", minX: 664, maxX: 780, start: "03:05", end: "04:30", isBreak: false }
      ];
    }
    
    // 3. Cluster batch rows
    let col0Groups = {};
    for (let item of items) {
      let x = item.transform[4];
      let y = item.transform[5];
      if (x < pageColumns[0].maxX && item.str.trim() !== '') {
        let roundedY = Math.round(y / 5) * 5;
        if (!col0Groups[roundedY]) col0Groups[roundedY] = [];
        col0Groups[roundedY].push(item);
      }
    }
    
    let rowStarts = [];
    for (let roundedY in col0Groups) {
      let groupItems = col0Groups[roundedY];
      groupItems.sort((a, b) => a.transform[4] - b.transform[4]);
      let text = groupItems.map(item => item.str).join("").trim();
      let match = text.match(BATCH_RE);
      if (match) {
        let cleanBatch = match[0].replace(CAPACITY_RE, '').trim();
        rowStarts.push({ text: cleanBatch, y: parseFloat(roundedY) });
      }
    }
    rowStarts.sort((a, b) => b.y - a.y);
    
    if (rowStarts.length === 0) continue;
    
    // 4. Construct cells
    let numCols = pageColumns.length;
    let reconstructedRows = [];
    for (let i = 0; i < rowStarts.length; i++) {
      reconstructedRows.push({
        batch: rowStarts[i].text,
        cells: Array(numCols).fill(""),
        cellItems: Array(numCols).fill(null).map(() => [])
      });
    }
    
    for (let item of items) {
      let str = item.str.trim();
      if (str === '') continue;
      if (/\b(aSc\s+Timetables|Timetable\s+generated|COMSATS\s+University|CUI\s+Sahiwal|Islamabad,Sahiwal)\b/i.test(str)) continue;
      
      let x = item.transform[4];
      let y = item.transform[5];
      
      // Strict header filter: never assign header tokens to class cells
      if (headerY !== -1 && y >= headerY - 15) continue;
      if (/^\s*(?:\d+\s+)?\d{1,2}[:.]?\d{2}(?:\s*-\s*|\s+)\d{1,2}[:.]?\d{2}\s*$/i.test(str)) continue;
      if (/^(?:1|2|3|4|5|6|Break|kaerB)$/i.test(str) && y >= rowStarts[0].y + 5) continue;
      
      if (y > rowStarts[0].y + 15) continue;
      
      let targetRowIdx = -1;
      for (let i = 0; i < rowStarts.length; i++) {
        let startY = i === 0 ? (headerY !== -1 ? headerY - 15 : rowStarts[0].y + 15) : (rowStarts[i-1].y + rowStarts[i].y) / 2;
        let endY = i + 1 < rowStarts.length ? (rowStarts[i].y + rowStarts[i+1].y) / 2 : rowStarts[i].y - 35;
        if (y <= startY && y > endY) {
          targetRowIdx = i;
          break;
        }
      }
      if (targetRowIdx === -1) continue;
      
      let targetColIdx = -1;
      let centerX = x + (item.width || 0) / 2;
      for (let colIdx = 0; colIdx < pageColumns.length; colIdx++) {
        let col = pageColumns[colIdx];
        if (centerX >= col.minX && centerX < col.maxX) {
          targetColIdx = colIdx;
          break;
        }
      }
      if (targetColIdx !== -1) {
        reconstructedRows[targetRowIdx].cellItems[targetColIdx].push(item);
      }
    }
    
    // Reconstruct strings
    for (let row of reconstructedRows) {
      for (let c = 0; c < numCols; c++) {
        let cellItems = row.cellItems[c];
        if (cellItems.length === 0) continue;
        let lines = {};
        for (let item of cellItems) {
          let roundedY = Math.round(item.transform[5] / 3) * 3;
          if (!lines[roundedY]) lines[roundedY] = [];
          lines[roundedY].push(item);
        }
        let sortedY = Object.keys(lines).map(Number).sort((a, b) => b - a);
        let lineTexts = [];
        for (let yVal of sortedY) {
          let lineItems = lines[yVal];
          lineItems.sort((a, b) => a.transform[4] - b.transform[4]);
          lineTexts.push(lineItems.map(item => item.str).join(" ").trim());
        }
        row.cells[c] = lineTexts.join("\n");
      }
    }
    
    // 5. Unify multi-slot spanned labs where subject is centered and teacher/room is right-aligned
    for (let row of reconstructedRows) {
      for (let c = 1; c < numCols - 1; c++) {
        let curCell = row.cells[c];
        let nextCell = row.cells[c + 1];
        if (!curCell || !nextCell) continue;
        if (pageColumns[c].isBreak || pageColumns[c + 1].isBreak) continue;
        
        let curParsed = parseClassCell(curCell);
        let nextParsed = parseClassCell(nextCell);
        
        if (curParsed && nextParsed) {
          // If curCell has a subject but no teacher (Unknown), and nextCell has a teacher/room
          if (curParsed.teacher === "Unknown" && nextParsed.teacher !== "Unknown") {
            if (nextParsed.subject === "Unknown" || nextParsed.subject === curParsed.subject || curParsed.subject.toLowerCase().includes("lab")) {
              row.cells[c] = `${curCell}\n${nextCell}`;
              row.cells[c + 1] = ""; // Merged into slot c
            }
          }
        }
      }
    }
    
    // 6. Parse cell content and merge consecutive columns (for lab slots)
    for (let row of reconstructedRows) {
      let batchInfo = parseBatch(row.batch);
      if (!batchInfo) continue;
      
      let c = 1;
      while (c < numCols) {
        let cellText = row.cells[c];
        if (!cellText || cellText.trim() === '') {
          c++;
          continue;
        }
        
        let colDef = pageColumns[c];
        let isBreakCol = colDef.isBreak || 
                         /\b(break|kaerb|prayer|reyarp|fehm|mhef|namaz|lunch)\b/i.test(cellText) || 
                         /\b(12:45\s*-\s*1:40|12:00\s*-\s*1:00|1:00\s*-\s*1:30)\b/i.test(colDef.text || '');
        if (isBreakCol) {
          c++;
          continue;
        }
        
        let parsed = parseClassCell(cellText);
        if (!parsed) {
          c++;
          continue;
        }
        
        let startTime = colDef.start;
        let endTime = colDef.end;
        
        let j = c + 1;
        while (j < numCols) {
          let nextCol = pageColumns[j];
          let nextCell = row.cells[j];
          let nextIsBreak = nextCol.isBreak || 
                            /\b(break|kaerb|prayer|reyarp|fehm|mhef|namaz|lunch)\b/i.test(nextCell || '') || 
                            /\b(12:45\s*-\s*1:40|12:00\s*-\s*1:00|1:00\s*-\s*1:30)\b/i.test(nextCol.text || '');
          
          let isLabOrMulti = parsed.subject.toLowerCase().includes('lab') || 
                             parsed.room.toLowerCase().includes('lab') || 
                             /(3\s*hrs?|2\s*hrs?)/i.test(parsed.subject) || 
                             /(3\s*hrs?|2\s*hrs?)/i.test(cellText);
          
          if (!nextCell || nextCell.trim() === '') {
            if (!isLabOrMulti || nextIsBreak) {
              break; // Regular theory classes must NEVER span into empty slots
            }
            endTime = nextCol.end;
            j++;
          } else if (!nextIsBreak) {
            // Check if consecutive cell has the exact same lecture/lab (2-slot course)
            let nextParsed = parseClassCell(nextCell);
            if (nextParsed && 
                nextParsed.subject === parsed.subject && 
                nextParsed.teacher === parsed.teacher && 
                nextParsed.room === parsed.room) {
              endTime = nextCol.end;
              j++;
            } else {
              break;
            }
          } else {
            break;
          }
        }
        
        // Handle "(1 hr)" / "(1 Hour)" / "(1Hr)" marker - adjust end time to be exactly 1 hour from start
        if (/(1\s*hr|1\s*hour|1hr)/i.test(parsed.subject) || /(1\s*hr|1\s*hour|1hr)/i.test(cellText)) {
          let [sh, sm] = startTime.split(':').map(Number);
          let eh = sh + 1;
          let em = sm;
          endTime = `${eh.toString().padStart(2, '0')}:${em.toString().padStart(2, '0')}`;
        }
        
        allSessions.push({
          department: batchInfo.department,
          batch: batchInfo.batch,
          day: currentDay,
          start: startTime,
          end: endTime,
          subject: parsed.subject,
          teacher: parsed.teacher,
          room: parsed.room
        });
        
        c = j;
      }
    }
  }
  return allSessions;
}

function updateTimetablePreview(sessions) {
  const sessionCount = sessions.length;
  const uniqueSubjects = new Set();
  const uniqueBatches = new Set();
  let labCount = 0;
  let oneHrCount = 0;
  let unknownTeachers = 0;
  let unknownRooms = 0;
  
  timetablePreviewBody.innerHTML = '';
  const previewLimit = Math.min(20, sessions.length);
  
  for (let i = 0; i < previewLimit; i++) {
    const s = sessions[i];
    const tr = document.createElement('tr');
    
    const isOneHr = /(1\s*hr|1\s*hour|1hr)/i.test(s.subject);
    const isLab = (s.subject && s.subject.toLowerCase().includes('lab')) || (s.room && s.room.toLowerCase().includes('lab'));
    
    let badgeHtml = '';
    if (isOneHr) {
      badgeHtml += `<span style="background: rgba(56, 189, 248, 0.15); color: #38bdf8; font-size: 10px; font-weight: 700; padding: 2px 6px; border-radius: 4px; margin-left: 6px;">1 Hr (60m)</span>`;
    }
    if (isLab) {
      badgeHtml += `<span style="background: rgba(168, 85, 247, 0.15); color: #c084fc; font-size: 10px; font-weight: 700; padding: 2px 6px; border-radius: 4px; margin-left: 6px;">Lab</span>`;
    }

    tr.innerHTML = `
      <td style="font-weight: 600; color: var(--text-title);">${s.day || 'Monday'}</td>
      <td style="font-family: var(--font-mono); color: var(--accent-cyan); font-size: 11px;">${s.start} - ${s.end}</td>
      <td><span style="background: rgba(16, 185, 129, 0.12); color: #34d399; font-weight: 600; padding: 2px 6px; border-radius: 4px; font-family: var(--font-mono); font-size: 11px;">${s.room || 'TBD'}</span></td>
      <td style="font-weight: 600; color: var(--accent-indigo);">${s.batch || s.class_name || s.section || 'GENERAL'}</td>
      <td style="color: var(--text-title); font-weight: 500;">${s.subject || 'LECTURE'} ${badgeHtml}</td>
      <td style="color: var(--text-caption); font-weight: 500;">${s.teacher || 'STAFF'}</td>
    `;
    timetablePreviewBody.appendChild(tr);
  }
  
  sessions.forEach(s => {
    if (s.batch) uniqueBatches.add(s.batch);
    if (s.subject) {
      const cleanSub = s.subject.replace(/\s*\(\d*\s*hrs?\)\s*/gi, '')
                               .replace(/\s*\(\d*\s*hr\)\s*/gi, '')
                               .replace(/\s*\(Lab\)\s*/gi, '')
                               .trim();
      uniqueSubjects.add(cleanSub);
      
      if (s.subject.toLowerCase().includes('lab') || (s.room && s.room.toLowerCase().includes('lab'))) {
        labCount++;
      }
      if (/(1\s*hr|1\s*hour|1hr)/i.test(s.subject)) {
        oneHrCount++;
      }
    }
    if (!s.teacher || s.teacher === "Unknown") unknownTeachers++;
    if (!s.room || s.room === "TBD") unknownRooms++;
  });

  if (statSessions) statSessions.innerText = sessionCount;
  if (statCourses) statCourses.innerText = uniqueSubjects.size;
  if (statLabs) statLabs.innerText = labCount;
  
  const statBatchesElem = document.getElementById('stat-batches');
  if (statBatchesElem) statBatchesElem.innerText = uniqueBatches.size;
  const statOneHrElem = document.getElementById('stat-one-hr');
  if (statOneHrElem) statOneHrElem.innerText = oneHrCount;
  
  timetableAnalytics.style.display = 'block';
  logTerminal(`Extracted <strong>${sessionCount} sessions</strong> across <strong>${uniqueBatches.size} batches</strong> (${uniqueSubjects.size} courses, ${labCount} labs, ${oneHrCount} 1-hr classes, <strong>${unknownTeachers} unknown teachers</strong>, <strong>${unknownRooms} TBD rooms</strong>).`, 'success');
}

function setupDragAndDrop() {
  // Timetable JSON/PDF (supports multiple)
  setupDropzone(timetableDropzone, timetableFileInput, async (files) => {
    await handleTimetableFilesSelect(files);
  });
  
  // Android APK OTA split drops (single file)
  setupDropzone(apkDropzone, apkFileInput, (files) => {
    if (files.length > 0) {
      selectedApkFile = files[0];
      apkFileInfo.innerText = `OTA split APK: ${files[0].name} (${(files[0].size / 1024 / 1024).toFixed(2)} MB)`;
      apkFileInfo.style.display = 'block';
      deployApkBtn.disabled = false;
      logTerminal(`Staged Android OTA package: <strong>${files[0].name}</strong>`, 'info');
    }
  });

  // Excel Date Sheets (single file)
  setupDropzone(examsDropzone, examsFileInput, (files) => {
    if (files.length > 0) {
      handleExamsFileSelect(files[0]);
    }
  });
}

function setupDropzone(dropzone, input, onFilesSelect) {
  if (!dropzone || !input) return;
  dropzone.addEventListener('click', () => input.click());
  
  input.addEventListener('change', (e) => {
    if (e.target.files.length > 0) {
      onFilesSelect(Array.from(e.target.files));
    }
  });
  
  ['dragenter', 'dragover'].forEach(name => {
    dropzone.addEventListener(name, (e) => {
      e.preventDefault();
      dropzone.classList.add('drag-active');
    }, false);
  });
  
  ['dragleave', 'drop'].forEach(name => {
    dropzone.addEventListener(name, (e) => {
      e.preventDefault();
      dropzone.classList.remove('drag-active');
    }, false);
  });
  
  dropzone.addEventListener('drop', (e) => {
    const dt = e.dataTransfer;
    if (dt.files.length > 0) {
      onFilesSelect(Array.from(dt.files));
    }
  }, false);
}

async function handleTimetableFilesSelect(files) {
  logTerminal(`Staging ${files.length} daily timetable file(s)...`, 'info');
  
  for (let file of files) {
    if (stagedTimetableFiles.some(f => f.name === file.name && f.size === file.size)) {
      logTerminal(`File <strong>${file.name}</strong> is already staged. Skipping.`, 'warning');
      continue;
    }
    
    if (file.name.toLowerCase().endsWith('.pdf')) {
      logTerminal(`Processing Timetable PDF file: <strong>${file.name}</strong>...`, 'info');
      showMossToast(`Parsing PDF Timetable: ${file.name}...`, "info");
      deployTimetableBtn.disabled = true;
      deployTimetableBtn.querySelector('span').innerText = 'PARSING PDF...';
      
      try {
        const arrayBuffer = await file.arrayBuffer();
        const sessions = await parseTimetablePdf(arrayBuffer);
        
        if (sessions.length === 0) {
          throw new Error("No classes could be parsed from the PDF. Check template/coordinates.");
        }
        
        stagedTimetableFiles.push({
          name: file.name,
          size: file.size,
          sessions: sessions
        });
        
        logTerminal(`Parsed ${sessions.length} sessions from <strong>${file.name}</strong> successfully!`, 'success');
        showMossToast(`Extracted ${sessions.length} classes from ${file.name}!`, "success");
      } catch (err) {
        logTerminal(`PDF Parse Error for ${file.name}: ${err.message}`, 'error');
        showMossToast(`PDF Parse Error for ${file.name}: ${err.message}`, "error");
      }
    } else if (file.name.toLowerCase().endsWith('.json')) {
      logTerminal(`Processing Timetable JSON file: <strong>${file.name}</strong>...`, 'info');
      try {
        const jsonText = await new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.onload = (e) => resolve(e.target.result);
          reader.onerror = (err) => reject(err);
          reader.readAsText(file);
        });
        
        const json = JSON.parse(jsonText);
        let sessions = Array.isArray(json) ? json : (json.sessions || []);
        
        if (sessions.length === 0) {
          throw new Error("JSON file has no sessions.");
        }
        
        stagedTimetableFiles.push({
          name: file.name,
          size: file.size,
          sessions: sessions
        });
        
        logTerminal(`Parsed ${sessions.length} sessions from JSON <strong>${file.name}</strong>.`, 'success');
        showMossToast(`Loaded ${sessions.length} classes from ${file.name}!`, "success");
      } catch (err) {
        logTerminal(`JSON Parse Error for ${file.name}: ${err.message}`, 'error');
        showMossToast(`JSON Parse Error for ${file.name}: ${err.message}`, "error");
      }
    } else {
      logTerminal(`Unsupported file format for <strong>${file.name}</strong>. Only .pdf and .json are supported.`, 'warning');
      showMossToast(`Unsupported format: ${file.name}`, "warning");
    }
  }
  
  recomputeStagedTimetables();
}

function recomputeStagedTimetables() {
  const container = document.getElementById('staged-files-container');
  const list = document.getElementById('staged-files-list');
  if (!container || !list) return;
  
  list.innerHTML = '';
  stagedTimetablePayload = [];
  
  if (stagedTimetableFiles.length === 0) {
    container.style.display = 'none';
    timetableFileInfo.style.display = 'none';
    timetableAnalytics.style.display = 'none';
    deployTimetableBtn.disabled = true;
    deployTimetableBtn.querySelector('span').innerText = 'Commit Timetable Seed';
    return;
  }
  
  container.style.display = 'block';
  timetableFileInfo.style.display = 'none';
  
  stagedTimetableFiles.forEach((file, index) => {
    stagedTimetablePayload.push(...file.sessions);
    
    const li = document.createElement('li');
    li.style.display = 'flex';
    li.style.justifyContent = 'space-between';
    li.style.alignItems = 'center';
    li.style.padding = '10px 14px';
    li.style.background = 'rgba(255, 255, 255, 0.04)';
    li.style.border = '1px solid rgba(255, 255, 255, 0.1)';
    li.style.borderRadius = '8px';
    li.style.fontSize = '11.5px';
    li.style.color = 'var(--text-title)';
    
    li.innerHTML = `
      <div style="display: flex; align-items: center; gap: 10px;">
        <i class="fa-solid ${file.name.toLowerCase().endsWith('.pdf') ? 'fa-file-pdf' : 'fa-file-code'}" style="color: var(--accent-indigo); font-size: 14px;"></i>
        <div>
          <strong style="color: var(--text-title); font-weight: 600;">${file.name}</strong>
          <span style="color: var(--text-muted); font-size: 10px; margin-left: 6px;">(${(file.size / 1024).toFixed(1)} KB)</span>
        </div>
      </div>
      <div style="display: flex; align-items: center; gap: 12px;">
        <span class="badge" style="background: rgba(99, 102, 241, 0.15); color: #818cf8; font-weight: bold; border: 1px solid rgba(99, 102, 241, 0.3);">${file.sessions.length} sessions</span>
        <button type="button" class="btn-remove-staged" onclick="removeStagedTimetableFile(${index})" style="background: transparent; border: none; color: #f87171; cursor: pointer; padding: 4px;" title="Remove file"><i class="fa-solid fa-trash-can"></i></button>
      </div>
    `;
    list.appendChild(li);
  });
  
  updateTimetablePreview(stagedTimetablePayload);
  deployTimetableBtn.disabled = false;
  deployTimetableBtn.querySelector('span').innerText = `Commit Timetable Seed (${stagedTimetablePayload.length} sessions)`;
}

window.removeStagedTimetableFile = function(index) {
  const removed = stagedTimetableFiles.splice(index, 1)[0];
  logTerminal(`Removed staged file: <strong>${removed.name}</strong>`, 'info');
  recomputeStagedTimetables();
};

deployTimetableBtn.addEventListener('click', async () => {
  if (!isConnected || !stagedTimetablePayload || stagedTimetablePayload.length === 0) {
    logTerminal('No valid timetable payload staged for deployment.', 'warning');
    return;
  }
  
  logTerminal('Initiating timetable ledger deployment sequence...', 'info');
  deployTimetableBtn.disabled = true;
  
  try {
    const versionId = `SEED_${new Date().toISOString().replace(/[-:T]/g, '_').substring(0, 15)}`;
    const timeStr = new Date().toISOString();
    const classesCount = stagedTimetablePayload.length;
    const payload = JSON.stringify(stagedTimetablePayload);

    await db.collection('config').doc('global').update({
      active_timetable_version: Date.now(),
      active_timetable_url: "", 
      active_timetable_json: payload,
      updated_at: firebase.firestore.FieldValue.serverTimestamp()
    });
    incrementDatabaseOps();

    await db.collection('timetable_history').doc(versionId).set({
      id: versionId,
      time: timeStr,
      classes: classesCount,
      json: payload
    });
    incrementDatabaseOps();
    
    await loadTimetableHistory();
    
    logTerminal(`Database Sync Complete: Timetable ledger (${classesCount} classes) synchronized globally.`, 'success');
    showMossToast("Timetable seed committed and deployed!", "success");
    
    // Reset state
    stagedTimetableFiles = [];
    stagedTimetablePayload = [];
    recomputeStagedTimetables();
    
    refreshLiveClassesInspector();
  } catch (e) {
    logTerminal(`Deployment failed: ${e.message}`, 'error');
    showMossToast(e.message, "error");
    deployTimetableBtn.disabled = false;
  }
});

// ==========================================================================
// ANDROID OTA SPLITS & CDN CENTER
// ==========================================================================

deployApkBtn.addEventListener('click', async () => {
  const vName = apkVersionName.value.trim();
  const vCode = parseInt(apkVersionCode.value);
  const notes = apkNotes.value.trim();
  const pastedUrl = apkUrlInput ? apkUrlInput.value.trim() : '';
  
  if (!vName || isNaN(vCode)) {
    alert('Invalid version criteria parameters.');
    return;
  }
  
  if (!selectedApkFile && !pastedUrl) {
    alert('Select APK files or paste direct download CDN repositories.');
    return;
  }
  
  logTerminal(`Staging application split OTA release: v${vName} (Build #${vCode})...`, 'info');
  deployApkBtn.disabled = true;
  
  try {
    // External CDN mapping uploader (bypasses Cloud Storage limits)
    if (pastedUrl) {
      logTerminal('Staging update package mapping direct external CDN link...', 'info');
      
      await db.collection('config').doc('global').update({
        latest_apk_update: {
          version_name: vName,
          version_code: vCode,
          apk_url: pastedUrl,
          release_notes: notes || 'Production system optimization patches.',
          released_at: firebase.firestore.FieldValue.serverTimestamp(),
          show_update_card: true
        }
      });
      incrementDatabaseOps();
      
      logTerminal(`Staging Complete: Released v${vName} (${vCode}) via CDN URL. Auto-prompts active.`, 'success');
      showMossToast(`Android OTA Split v${vName} staged successfully!`, "success");
      
      if (apkUrlInput) apkUrlInput.value = '';
      apkNotes.value = '';
      deployApkBtn.disabled = true;
      return;
    }
    
    // Cloud storage uploader (If storage is active and paid)
    if (!storage) {
      throw new Error('Local storage service offline. stage packages via external CDN repository instead.');
    }
    
    uploadProgressContainer.style.display = 'flex';
    const filename = `nexsync-v${vName}-release.apk`;
    const storageRef = storage.ref().child(`updates/${filename}`);
    
    const uploadTask = storageRef.put(selectedApkFile);
    
    let lastLoggedPct = -1;
    uploadTask.on('state_changed', 
      (snapshot) => {
        const pct = Math.round((snapshot.bytesTransferred / snapshot.totalBytes) * 100);
        uploadProgressFill.style.width = `${pct}%`;
        uploadProgressPct.innerText = `${pct}%`;
        
        // Log every 5% progression step
        const step = Math.floor(pct / 5) * 5;
        if (step > lastLoggedPct) {
          logTerminal(`Uploading APK binaries: ${pct}% complete... (${(snapshot.bytesTransferred / 1024 / 1024).toFixed(1)}MB / ${(snapshot.totalBytes / 1024 / 1024).toFixed(1)}MB)`, 'info');
          lastLoggedPct = step;
        }
      }, 
      (err) => {
        logTerminal(`Binary upload error occurred: ${err.message}`, 'error');
        deployApkBtn.disabled = false;
        uploadProgressContainer.style.display = 'none';
      }, 
      async () => {
        const downloadUrl = await uploadTask.snapshot.ref.getDownloadURL();
        logTerminal(`APK Binary stored securely. Path: updates/${filename}`, 'success');
        
        await db.collection('config').doc('global').update({
          latest_apk_update: {
            version_name: vName,
            version_code: vCode,
            apk_url: downloadUrl,
            release_notes: notes || 'Production system optimization patches.',
            released_at: firebase.firestore.FieldValue.serverTimestamp(),
            show_update_card: true
          }
        });
        incrementDatabaseOps();
        
        logTerminal(`Staging Complete: Binary v${vName} deployed. Clients notified.`, 'success');
        
        selectedApkFile = null;
        apkFileInfo.style.display = 'none';
        apkFileInput.value = '';
        apkNotes.value = '';
        deployApkBtn.disabled = true;
        uploadProgressContainer.style.display = 'none';
      }
    );
  } catch (e) {
    logTerminal(`OTA staging deployment failure: ${e.message}`, 'error');
    deployApkBtn.disabled = false;
    if (uploadProgressContainer) uploadProgressContainer.style.display = 'none';
  }
});
// App update visibility toggle listener
if (apkSwitchVisible) {
  apkSwitchVisible.addEventListener('change', async () => {
    if (!isConnected) return;
    
    const enabled = apkSwitchVisible.checked;
    logTerminal(`Updating app update card visibility: ${enabled ? 'VISIBLE' : 'HIDDEN'}...`, 'info');
    
    try {
      const doc = await db.collection('config').doc('global').get();
      if (doc.exists) {
        const data = doc.data();
        const currentUpdate = data.latest_apk_update || {};
        currentUpdate.show_update_card = enabled;
        
        await db.collection('config').doc('global').update({
          latest_apk_update: currentUpdate,
          updated_at: firebase.firestore.FieldValue.serverTimestamp()
        });
        incrementDatabaseOps();
        logTerminal(`Server sync complete: App update card set to ${enabled ? 'VISIBLE' : 'HIDDEN'}.`, 'success');
        showMossToast(`App Update Banner is now ${enabled ? 'VISIBLE' : 'HIDDEN'} on client screens!`, "success");
      }
    } catch (e) {
      logTerminal(`Failed to update visibility toggle: ${e.message}`, 'error');
      showMossToast(e.message, "error");
      apkSwitchVisible.checked = !enabled;
    }
  });
}

// ==========================================================================
// SESSION TIMEOUTS & HARDWARE BEACONS
// ==========================================================================

function setupUIHandlers() {
  let lastActivityTime = Date.now();
  let countdownVal = 60;
  let countdownInterval = null;
  let isWarningShown = false;

  function resetActivityTimer() {
    if (isWarningShown) return;
    lastActivityTime = Date.now();
  }

  ['mousedown', 'mousemove', 'keydown', 'scroll', 'touchstart', 'click'].forEach(evt => {
    document.addEventListener(evt, resetActivityTimer, true);
  });

  setInterval(() => {
    if (!auth || !auth.currentUser) {
      if (isWarningShown) hideTimeoutModal();
      return;
    }

    const now = Date.now();
    const idleTime = now - lastActivityTime;

    // 15 minutes of inactivity warning countdown
    if (idleTime > 15 * 60 * 1000 && !isWarningShown) {
      showTimeoutModal();
    }
  }, 1000);

  function showTimeoutModal() {
    isWarningShown = true;
    timeoutModal.style.display = 'flex';
    countdownVal = 60;
    timeoutCountdown.innerText = countdownVal;
    logTerminal('Security Alert: Key entry session verification required.', 'warning');

    countdownInterval = setInterval(() => {
      countdownVal--;
      timeoutCountdown.innerText = countdownVal;
      if (countdownVal <= 0) {
        clearInterval(countdownInterval);
        logTerminal('Security Protocol: Vault gate locked due to inactivity.', 'error');
        auth.signOut();
        hideTimeoutModal();
      }
    }, 1000);
  }

  function hideTimeoutModal() {
    isWarningShown = false;
    timeoutModal.style.display = 'none';
    if (countdownInterval) {
      clearInterval(countdownInterval);
      countdownInterval = null;
    }
  }

  if (extendSessionBtn) {
    extendSessionBtn.addEventListener('click', () => {
      hideTimeoutModal();
      lastActivityTime = Date.now();
      logTerminal('Security session hold accepted.', 'success');
    });
  }

  // Key press listener overrides inside credentials forms
  [emailInput, passInput].forEach(input => {
    if (input) {
      input.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
          loginBtn.click();
        }
      });
    }
  });
}

// Real active core ping latency tracker (measures actual Firestore document read speed)
function startLatencySimulator() {
  const valEl = document.getElementById('latency-val');
  
  // Measure latency immediately
  setTimeout(triggerPing, 1000);
  
  async function triggerPing() {
    if (isConnected && db) {
      const startTime = Date.now();
      try {
        await db.collection('config').doc('global').get();
        const latency = Date.now() - startTime;
        if (valEl) valEl.innerText = `${latency}ms`;
        if (telemetryHealth) telemetryHealth.innerText = 'OPTIMAL';
      } catch (err) {
        console.warn("Latency query error:", err);
        if (valEl) valEl.innerText = '--';
        if (telemetryHealth) telemetryHealth.innerText = 'DEGRADED';
      }
    } else {
      if (valEl) valEl.innerText = 'offline';
    }
  }

  setInterval(triggerPing, 10000); // Trigger every 10 seconds to keep read counts reasonable
}

// ==========================================================================
// IRIDIUM 3D PERSPECTIVE TILT ENGINES & TOAST SYSTEM
// ==========================================================================

function setup3DTiltEffects() {
  // Disabled for maximum 60FPS UI performance
}

function showMossToast(message, type = 'success') {
  const container = document.getElementById('toast-container');
  if (!container) return;
  
  const toast = document.createElement('div');
  toast.className = 'moss-toast';
  
  let iconClass = 'fa-circle-check';
  if (type === 'error') iconClass = 'fa-circle-exclamation';
  if (type === 'warning') iconClass = 'fa-triangle-exclamation';
  if (type === 'info') iconClass = 'fa-circle-info';
  
  toast.innerHTML = `
    <i class="fa-solid ${iconClass} moss-toast-icon"></i>
    <div class="moss-toast-content">${message}</div>
    <button class="moss-toast-close"><i class="fa-solid fa-xmark"></i></button>
  `;
  
  container.appendChild(toast);
  
  setTimeout(() => {
    toast.classList.add('visible');
  }, 50);
  
  const closeBtn = toast.querySelector('.moss-toast-close');
  const dismiss = () => {
    toast.classList.remove('visible');
    setTimeout(() => {
      toast.remove();
    }, 500);
  };
  
  if (closeBtn) closeBtn.addEventListener('click', dismiss);
  setTimeout(dismiss, 4000);
}

// ==========================================================================
// ADDITIONAL REFINEMENTS & HIGH-FIDELITY TELEMETRY SERVICES
// ==========================================================================

let timetableHistory = [];
const rollbackLedgerBody = document.getElementById('rollback-ledger-body');
const telemetryNodes = document.getElementById('telemetry-nodes');
const telemetryOps = document.getElementById('telemetry-ops');
const telemetryHealth = document.getElementById('telemetry-health');
let activeVersionId = '';
let databaseWriteOps = 0;

function incrementDatabaseOps() {
  databaseWriteOps++;
  if (telemetryOps) {
    telemetryOps.innerText = `${databaseWriteOps} writes`;
  }
}

function startNodesSimulator() {
  if (telemetryNodes) {
    if (db && db.app && db.app.options) {
      telemetryNodes.innerText = db.app.options.projectId || "iris-138ef";
    } else {
      telemetryNodes.innerText = "iris-138ef";
    }
  }
}

async function loadTimetableHistory() {
  if (!isConnected || !db) {
    // Read from localStorage if offline
    const cached = localStorage.getItem('iris_timetable_history');
    if (cached) {
      try {
        timetableHistory = JSON.parse(cached);
      } catch (e) {
        timetableHistory = [];
      }
    }
    renderRollbackLedger();
    return;
  }
  
  try {
    logTerminal('Fetching historical timetable seeds from Firestore ledger...', 'info');
    const snapshot = await db.collection('timetable_history').orderBy('time', 'desc').limit(6).get();
    
    timetableHistory = [];
    snapshot.forEach(doc => {
      timetableHistory.push(doc.data());
    });
    
    // Fallback: If database has no history records yet, populate with a record representing the current active configuration
    if (timetableHistory.length === 0) {
      logTerminal('History ledger empty. Creating initial seed record...', 'warning');
      const globalDoc = await db.collection('config').doc('global').get();
      if (globalDoc.exists) {
        const data = globalDoc.data();
        const activeVer = data.active_timetable_version || Date.now();
        const activeJson = data.active_timetable_json || '[]';
        let parsed = [];
        try { parsed = JSON.parse(activeJson); } catch(e) {}
        
        const initialSeed = {
          id: `SEED_${new Date(activeVer).toISOString().replace(/[-:T]/g, '_').substring(0, 15)}`,
          time: new Date(activeVer).toISOString(),
          classes: Array.isArray(parsed) ? parsed.length : (parsed.sessions ? parsed.sessions.length : 0),
          json: activeJson
        };
        
        await db.collection('timetable_history').doc(initialSeed.id).set(initialSeed);
        incrementDatabaseOps();
        timetableHistory.push(initialSeed);
      }
    }
    
    localStorage.setItem('iris_timetable_history', JSON.stringify(timetableHistory));
    activeVersionId = localStorage.getItem('iris_active_timetable_id') || (timetableHistory[0] ? timetableHistory[0].id : '');
    renderRollbackLedger();
  } catch (err) {
    logTerminal(`Error fetching history from Firestore: ${err.message}`, 'warning');
    // Fallback to localStorage on query failure
    const cached = localStorage.getItem('iris_timetable_history');
    if (cached) {
      try { timetableHistory = JSON.parse(cached); } catch (e) {}
    }
    renderRollbackLedger();
  }
}

function renderRollbackLedger() {
  if (!rollbackLedgerBody) return;
  rollbackLedgerBody.innerHTML = '';
  
  timetableHistory.forEach(version => {
    const tr = document.createElement('tr');
    const isActive = version.id === activeVersionId;
    if (isActive) tr.className = 'active-row';
    
    const formattedTime = new Date(version.time).toLocaleString();
    
    tr.innerHTML = `
      <td>${version.id}</td>
      <td>${formattedTime}</td>
      <td style="font-family: var(--font-mono);">${version.classes} classes</td>
      <td>
        ${isActive ? `<span style="font-size: 8px; color: var(--accent-indigo); font-weight: 700; letter-spacing: 0.5px;">[ ACTIVE ]</span>` : `<button class="btn-revert" onclick="revertTimetableVersion('${version.id}')">Revert</button>`}
      </td>
    `;
    rollbackLedgerBody.appendChild(tr);
  });
}

window.revertTimetableVersion = async function(id) {
  const version = timetableHistory.find(v => v.id === id);
  if (!version) return;
  
  logTerminal(`Reverting operational database to historical seed <strong>${id}</strong>...`, 'warning');
  showMossToast(`Reverting to database version ${id}...`, "info");
  
  try {
    if (isConnected && db) {
      await db.collection('config').doc('global').update({
        active_timetable_version: Date.now(),
        active_timetable_url: "",
        active_timetable_json: version.json,
        updated_at: firebase.firestore.FieldValue.serverTimestamp()
      });
      incrementDatabaseOps();
    }
    
    activeVersionId = id;
    localStorage.setItem('iris_active_timetable_id', id);
    renderRollbackLedger();
    
    logTerminal(`Rollback complete: Restored version <strong>${id}</strong> with ${version.classes} classes active.`, 'success');
    showMossToast(`Database successfully reverted to ${id}!`, "success");
  } catch (err) {
    logTerminal(`Rollback failed: ${err.message}`, 'error');
    showMossToast(`Rollback failure: ${err.message}`, "error");
  }
}

// ==========================================================================
// DATE SHEET EXCEL PARSER AND DEPLOYMENT CORE
// ==========================================================================

function splitCombinedBatches(raw) {
  if (!raw) return [];
  const s = String(raw).trim();
  if (s === '' || s.toLowerCase() === 'none' || s.toLowerCase() === 'date' || s.toLowerCase() === 'time') return [];
  
  let results = [];

  // 1. Check compound batches e.g. "FA25-BME-FA24-BME-FA22-BEE" or "FA25-BME/FA24-BME"
  const batchMatches = s.match(/(?:FA|SP)\d{2}-[A-Z0-9]+(?:-[A-Z0-9]+)*/gi);
  if (batchMatches && batchMatches.length > 0) {
    for (let bm of batchMatches) {
      const sub = bm.split(/(?=(?:FA|SP)\d{2}-)/i).map(b => b.replace(/^[-/, ]+|[-/, ]+$/g, '').trim()).filter(Boolean);
      for (let sb of sub) {
        // Expand section combos like "FA25-BCS-2-A&B" -> ["FA25-BCS-2-A", "FA25-BCS-2-B"]
        const parts = sb.split('-');
        if (parts.length >= 3 && (parts[parts.length - 1].includes('&') || parts[parts.length - 1].includes(','))) {
          const last = parts[parts.length - 1];
          const secs = last.split(/[&,]/).map(x => x.trim()).filter(Boolean);
          const prefix = parts.slice(0, parts.length - 1).join('-');
          secs.forEach(sc => results.push(`${prefix}-${sc}`));
        } else {
          results.push(sb);
        }
      }
    }
    return results;
  }
  
  // 2. Fallback split on slash or comma
  return s.split(/[\/,]+/).map(b => b.trim()).filter(Boolean);
}

function parseBatchTaxonomy(raw) {
  if (!raw) return { raw: "", session: "", year: 2025, program: "", department: "General", semester: 1, section: "A", fullTitle: "" };
  const s = String(raw).trim().toUpperCase();
  const parts = s.split('-');
  
  let intake = parts[0] || "FA25";
  let session = intake.startsWith("FA") ? "Fall" : (intake.startsWith("SP") ? "Spring" : intake);
  let yearNum = 2000 + (parseInt(intake.replace(/^[A-Z]+/, ''), 10) || 25);
  
  let program = parts.length > 1 ? parts[1] : "BCS";
  let deptMap = {
    'BCS': 'Computer Science', 'CS': 'Computer Science', 'MCS': 'Computer Science', 'MSCS': 'Computer Science',
    'BSE': 'Software Engineering', 'SE': 'Software Engineering', 'MSSE': 'Software Engineering',
    'BEE': 'Electrical Engineering', 'EE': 'Electrical Engineering', 'MSEE': 'Electrical Engineering',
    'BME': 'Mechanical Engineering', 'ME': 'Mechanical Engineering', 'MSME': 'Mechanical Engineering',
    'CVE': 'Civil Engineering', 'BCE': 'Civil Engineering', 'CE': 'Civil Engineering', 'MSCE': 'Civil Engineering',
    'BBA': 'Management Sciences', 'BBS': 'Management Sciences', 'AF': 'Management Sciences', 'MS': 'Management Sciences', 'MBA': 'Management Sciences', 'MSMS': 'Management Sciences',
    'BTY': 'Biotechnology', 'BBC': 'Biochemistry', 'BCH': 'Biochemistry', 'FSN': 'Food Science & Nutrition', 'HND': 'Human Nutrition & Dietetics', 'RBS': 'Remote Sensing & GIS', 'BI': 'Biosciences',
    'BEN': 'Humanities', 'ENG': 'Humanities', 'HUM': 'Humanities',
    'MT': 'Mathematics', 'MTH': 'Mathematics',
    'VS': 'Visiting Faculty'
  };
  let department = deptMap[program] || "General";
  
  let semester = 1;
  let section = "A";
  
  if (parts.length >= 4) {
    semester = parseInt(parts[2], 10) || 1;
    section = parts[3] || "A";
  } else if (parts.length === 3) {
    let last = parts[2];
    let m = last.match(/^(\d+)?([A-Za-z]+)?$/);
    if (m && m[1]) {
      semester = parseInt(m[1], 10);
      section = m[2] || "A";
    } else {
      section = last;
      // Calculate dynamic semester from intake
      let now = new Date();
      let curYear = now.getFullYear();
      let curMonth = now.getMonth() + 1; // 1-12
      
      let intakeIdx = yearNum * 2 + (intake.startsWith("FA") ? 1 : 0);
      let curAcademicYear = curYear;
      let isFall = false;
      
      if (curMonth >= 9) {
        isFall = true;
        curAcademicYear = curYear;
      } else if (curMonth <= 2) {
        isFall = true;
        curAcademicYear = curYear - 1;
      } else {
        isFall = false;
        curAcademicYear = curYear;
      }
      
      let curIdx = curAcademicYear * 2 + (isFall ? 1 : 0);
      semester = Math.max(1, Math.min(8, curIdx - intakeIdx + 1));
    }
  }
  
  return {
    raw: s,
    session,
    year: yearNum,
    program,
    department,
    semester,
    section,
    fullTitle: `${session} ${yearNum} - ${program} (Semester ${semester}, Section ${section})`
  };
}

function cleanRoomName(raw) {
  if (!raw) return "";
  let r = String(raw).trim();
  r = r.replace(/\s*\([^)]*\)\s*/g, ''); // Strip (42) or (CS) or parenthesized capacities
  
  // Normalize "A - 3" -> "A-3", "C - 1.1" -> "C-1.1"
  r = r.replace(/^([A-Za-z]+)\s*-\s*([0-9.]+)$/, '$1-$2');
  
  // Normalize "WCR 1" -> "WCR-1"
  r = r.replace(/^(WCR)\s*(\d+)$/i, 'WCR-$2');
  
  // Normalize "D 1" -> "D1"
  r = r.replace(/^([D])\s*(\d+)$/i, 'D$2');

  // Normalize "C-Lab 3", "CLab 3", "Computer Lab 3" -> "CLab-3"
  r = r.replace(/^(?:C-Lab|CLab|Computer\s*Lab)\s*[- ]?(\d+)$/i, 'CLab-$1');

  r = r.replace(/\s+/g, '-');
  return r.trim();
}

function formatExamTime(raw) {
  if (!raw) return "";
  let t = String(raw).trim();
  const m = t.match(/^(\d{2})(\d{2})\s*-\s*(\d{2})(\d{2})$/);
  if (m) {
    let sh = parseInt(m[1], 10);
    let sm = m[2];
    let eh = parseInt(m[3], 10);
    let em = m[4];
    
    let sPeriod = (sh >= 8 && sh <= 11) ? "AM" : "PM";
    let ePeriod = (eh >= 8 && eh <= 11) ? "AM" : "PM";
    if (sh >= 1 && sh <= 5) sPeriod = "PM";
    if ((eh >= 1 && eh <= 5) || eh === 12) ePeriod = "PM";
    
    let sDisp = sh.toString().padStart(2, '0');
    let eDisp = eh.toString().padStart(2, '0');
    return `${sDisp}:${sm} ${sPeriod} - ${eDisp}:${em} ${ePeriod}`;
  }
  return t;
}

function handleExamsFileSelect(file) {
  parsedExams = [];
  examsFileInfo.innerText = `Parsing: ${file.name} (${(file.size / 1024).toFixed(1)} KB)`;
  examsFileInfo.style.display = 'block';
  btnDeployMidterms.disabled = true;
  btnDeployFinals.disabled = true;
  logTerminal(`Staged Excel Date Sheet: <strong>${file.name}</strong>`, 'info');
  
  const reader = new FileReader();
  reader.onload = (e) => {
    try {
      const data = new Uint8Array(e.target.result);
      const workbook = XLSX.read(data, { type: 'array', cellDates: false, cellNF: true, cellText: true });
      const firstSheetName = workbook.SheetNames[0];
      const worksheet = workbook.Sheets[firstSheetName];
      const rows = XLSX.utils.sheet_to_json(worksheet, { header: 1, raw: false, defval: null });
      
      if (rows.length < 4) {
        throw new Error("Excel sheet contains too few rows. Header row expected.");
      }
      
      // Dynamically locate the header row containing "Date", "Time", or room columns
      let headerRowIdx = -1;
      for (let rIdx = 0; rIdx < Math.min(rows.length, 10); rIdx++) {
        const row = rows[rIdx] || [];
        const dateCount = row.filter(c => c && String(c).trim().toLowerCase() === 'date').length;
        if (dateCount >= 2) {
          headerRowIdx = rIdx;
          break;
        }
      }
      if (headerRowIdx === -1) headerRowIdx = 2; // Fallback to index 2
      
      const headerRow = rows[headerRowIdx] || [];
      
      // Identify all 4 campus blocks across the 53-column matrix
      const blocks = [];
      for (let c = 0; c < headerRow.length; c++) {
        const val = headerRow[c];
        if (val && String(val).trim().toLowerCase() === 'date') {
          blocks.push({ dateCol: c, timeCol: c + 1, startCol: c + 2, endCol: headerRow.length });
        }
      }
      for (let i = 0; i < blocks.length; i++) {
        if (i + 1 < blocks.length) {
          blocks[i].endCol = blocks[i + 1].dateCol;
        }
      }
      
      if (blocks.length === 0) {
        // Fallback single block
        blocks.push({ dateCol: 0, timeCol: 1, startCol: 2, endCol: headerRow.length });
      }
      
      let totalRooms = 0;
      blocks.forEach(b => {
        const rooms = [];
        for (let c = b.startCol; c < b.endCol; c++) {
          if (headerRow[c]) rooms.push({ colIdx: c, name: cleanRoomName(headerRow[c]) });
        }
        b.rooms = rooms;
        totalRooms += rooms.length;
      });
      
      logTerminal(`Detected ${blocks.length} Campus Building Blocks with ${totalRooms} examination venues.`, 'info');
      
      const currentDates = Array(blocks.length).fill(null);
      let r = headerRowIdx + 1;
      
      while (r < rows.length) {
        const row = rows[r] || [];
        const nextRow = rows[r + 1] || [];
        
        if (!row.some(Boolean) && !nextRow.some(Boolean)) {
          r += 1;
          continue;
        }
        
        for (let bIdx = 0; bIdx < blocks.length; bIdx++) {
          const b = blocks[bIdx];
          const rawDate = row[b.dateCol];
          const rawTime = row[b.timeCol];
          
          const dateStr = rawDate ? String(rawDate).trim() : "";
          const timeStr = rawTime ? String(rawTime).trim() : "";
          
          if (dateStr && dateStr.toLowerCase() !== 'date') {
            currentDates[bIdx] = dateStr;
          }
          
          const activeDate = currentDates[bIdx] || currentDates[0] || "Unknown Date";
          const activeTime = formatExamTime(timeStr);
          
          if (!timeStr || timeStr.toLowerCase() === 'time') {
            continue;
          }
          
          for (const room of b.rooms) {
            const batchCell = row[room.colIdx];
            const subjectCell = nextRow[room.colIdx];
            
            if (batchCell === null || batchCell === undefined) continue;
            const bStr = String(batchCell).trim();
            if (bStr === '' || bStr.toLowerCase() === 'none' || bStr.toLowerCase() === 'date' || bStr.toLowerCase() === 'time') continue;
            
            const sStr = subjectCell !== null && subjectCell !== undefined ? String(subjectCell).trim() : "";
            const batches = splitCombinedBatches(bStr);
            if (batches.length === 0) continue;
            
            for (const batch of batches) {
              parsedExams.push({
                date: activeDate,
                time: activeTime,
                room: room.name,
                batch: batch,
                subject: sStr || "EXAM"
              });
            }
          }
        }
        r += 2;
      }
      
      if (parsedExams.length === 0) {
        throw new Error("No exam entries extracted. Check format of sheet.");
      }
      
      logTerminal(`Successfully extracted ${parsedExams.length} individual cohort exam records across ${totalRooms} venues.`, 'success');
      
      // Compile stats
      const uniqueBatches = new Set();
      const uniqueSubjects = new Set();
      
      // Render preview
      examsPreviewBody.innerHTML = '';
      const previewLimit = Math.min(10, parsedExams.length);
      for (let i = 0; i < previewLimit; i++) {
        const ex = parsedExams[i];
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td>${ex.date}</td>
          <td>${ex.time}</td>
          <td>${ex.room}</td>
          <td style="font-weight: 600; color: var(--accent-indigo);">${ex.batch}</td>
          <td style="color: var(--text-title);">${ex.subject}</td>
        `;
        examsPreviewBody.appendChild(tr);
      }
      
      parsedExams.forEach(ex => {
        uniqueBatches.add(ex.batch);
        uniqueSubjects.add(ex.subject);
      });
      
      examsStatTotal.innerText = parsedExams.length;
      examsStatBatches.innerText = uniqueBatches.size;
      examsStatSubjects.innerText = uniqueSubjects.size;
      examsAnalytics.style.display = 'block';
      
      btnDeployMidterms.disabled = false;
      btnDeployFinals.disabled = false;
      
      // Update emulator datesheet preview
      updateEmulatorExams(parsedExams);
      
    } catch (err) {
      logTerminal(`Excel Date Sheet Parsing Failed: ${err.message}`, 'error');
      examsAnalytics.style.display = 'none';
      btnDeployMidterms.disabled = true;
      btnDeployFinals.disabled = true;
    }
  };
  reader.readAsArrayBuffer(file);
}

function splitCombinedCell(val) {
  if (!val) return [];
  
  val = String(val).trim().replace(/-+$/, '');
  const parts = val.split(/-(?=FA\d{2}|SP\d{2})/i);
  
  const result = [];
  for (const part of parts) {
    const trimmedPart = part.trim();
    const match = trimmedPart.match(/^((?:FA|SP)\d{2}-[A-Z0-9]+)(?:-([A-Z0-9,\s/&]+))?$/i);
    if (match) {
      const base = match[1];
      const suffix = match[2];
      if (suffix) {
        const sections = suffix.split(/[,/&]/).map(s => s.trim()).filter(s => s);
        if (sections.every(s => s.length <= 4)) {
          for (const s of sections) {
            result.push(`${base}-${s}`);
          }
        } else {
          result.push(trimmedPart);
        }
      } else {
        result.push(base);
      }
    } else {
      const altParts = trimmedPart.split(/[,/]/).map(p => p.trim()).filter(p => p);
      result.push(...altParts);
    }
  }
  
  return result.map(r => r.trim().replace(/-+$/, '')).filter(r => r);
}

btnDeployMidterms.addEventListener('click', async () => {
  if (!isConnected || parsedExams.length === 0) return;
  btnDeployMidterms.disabled = true;
  btnDeployFinals.disabled = true;
  logTerminal('Deploying parsed Midterm Date Sheet to cloud Firestore...', 'info');
  
  try {
    const payload = JSON.stringify(parsedExams);
    await db.collection('config').doc('global').update({
      active_midterm_json: payload,
      active_midterm_version: Date.now(),
      updated_at: firebase.firestore.FieldValue.serverTimestamp()
    });
    incrementDatabaseOps();
    logTerminal(`Cloud update complete: Midterm Date Sheet live with ${parsedExams.length} entries.`, 'success');
    showMossToast("Midterm Date Sheet successfully committed!", "success");
    
    // Clear state
    parsedExams = [];
    examsFileInfo.style.display = 'none';
    examsFileInput.value = '';
    examsAnalytics.style.display = 'none';
  } catch (err) {
    logTerminal(`Failed to deploy Midterm Date Sheet: ${err.message}`, 'error');
    showMossToast(err.message, "error");
    btnDeployMidterms.disabled = false;
    btnDeployFinals.disabled = false;
  }
});

btnDeployFinals.addEventListener('click', async () => {
  if (!isConnected || parsedExams.length === 0) return;
  btnDeployMidterms.disabled = true;
  btnDeployFinals.disabled = true;
  logTerminal('Deploying parsed Final Term Date Sheet to cloud Firestore...', 'info');
  
  try {
    const payload = JSON.stringify(parsedExams);
    await db.collection('config').doc('global').update({
      active_finals_json: payload,
      active_finals_version: Date.now(),
      updated_at: firebase.firestore.FieldValue.serverTimestamp()
    });
    incrementDatabaseOps();
    logTerminal(`Cloud update complete: Final Term Date Sheet live with ${parsedExams.length} entries.`, 'success');
    showMossToast("Final Term Date Sheet successfully committed!", "success");
    
    // Clear state
    parsedExams = [];
    examsFileInfo.style.display = 'none';
    examsFileInput.value = '';
    examsAnalytics.style.display = 'none';
  } catch (err) {
    logTerminal(`Failed to deploy Final Term Date Sheet: ${err.message}`, 'error');
    showMossToast(err.message, "error");
    btnDeployMidterms.disabled = false;
    btnDeployFinals.disabled = false;
  }
});

let telemetryHistoryPoints = [];
const maxTelemetryPoints = 15;

function initTelemetryChart() {
  for (let i = 0; i < maxTelemetryPoints; i++) {
    telemetryHistoryPoints.push({
      ops: 0,
      latency: Math.floor(Math.random() * 15) + 5
    });
  }
  
  // Start drawing loop
  setInterval(tickTelemetryChart, 1500);
}

function tickTelemetryChart() {
  const svg = document.getElementById('telemetry-svg');
  if (!svg) return;
  
  const currentOps = databaseWriteOps;
  const newOpsVal = currentOps * 2 + Math.floor(Math.random() * 2);
  const newLatencyVal = Math.floor(Math.random() * 12) + (isConnected ? 6 : 99);
  
  telemetryHistoryPoints.shift();
  telemetryHistoryPoints.push({
    ops: newOpsVal,
    latency: newLatencyVal
  });
  
  const width = 300;
  const height = 80;
  const pointsCount = telemetryHistoryPoints.length;
  const dx = width / (pointsCount - 1);
  
  let opsPathD = '';
  let opsAreaD = `M 0 ${height} `;
  let latencyPathD = '';
  let latencyAreaD = `M 0 ${height} `;
  
  const maxOps = Math.max(...telemetryHistoryPoints.map(p => p.ops), 10);
  const maxLat = Math.max(...telemetryHistoryPoints.map(p => p.latency), 30);
  
  telemetryHistoryPoints.forEach((pt, idx) => {
    const x = idx * dx;
    const yOps = height - 10 - ((pt.ops / maxOps) * 50);
    const yLat = height - 10 - ((pt.latency / maxLat) * 45);
    
    if (idx === 0) {
      opsPathD += `M ${x} ${yOps} `;
      opsAreaD += `L ${x} ${yOps} `;
      latencyPathD += `M ${x} ${yLat} `;
      latencyAreaD += `L ${x} ${yLat} `;
    } else {
      opsPathD += `L ${x} ${yOps} `;
      opsAreaD += `L ${x} ${yOps} `;
      latencyPathD += `L ${x} ${yLat} `;
      latencyAreaD += `L ${x} ${yLat} `;
    }
  });
  
  opsAreaD += `L ${width} ${height} Z`;
  latencyAreaD += `L ${width} ${height} Z`;
  
  const opsPathEl = document.getElementById('chart-ops-path');
  const opsAreaEl = document.getElementById('chart-ops-area');
  const latPathEl = document.getElementById('chart-latency-path');
  const latAreaEl = document.getElementById('chart-latency-area');
  const opsDotEl = document.getElementById('chart-ops-dot');
  
  if (opsPathEl) opsPathEl.setAttribute('d', opsPathD);
  if (opsAreaEl) opsAreaEl.setAttribute('d', opsAreaD);
  if (latPathEl) latPathEl.setAttribute('d', latencyPathD);
  if (latAreaEl) latAreaEl.setAttribute('d', latencyAreaD);
  
  if (opsDotEl && telemetryHistoryPoints.length > 0) {
    const finalIdx = telemetryHistoryPoints.length - 1;
    const finalOps = telemetryHistoryPoints[finalIdx].ops;
    const finalX = finalIdx * dx;
    const finalY = height - 10 - ((finalOps / maxOps) * 50);
    opsDotEl.setAttribute('cx', finalX);
    opsDotEl.setAttribute('cy', finalY);
  }
}

function updateEmulatorTimetables(sessions) {
  const mockList = document.getElementById('mock-timetable-list');
  const mockHomeList = document.getElementById('mock-feed-schedule-container');
  if (!mockList) return;
  
  if (!sessions || sessions.length === 0) {
    mockList.innerHTML = `<div style="text-align: center; color: var(--text-muted); font-size: 10px; padding: 20px;">No daily timetables seeded. Upload a timetable to preview.</div>`;
    if (mockHomeList) {
      mockHomeList.innerHTML = `<div style="text-align: center; color: var(--text-muted); font-size: 9px; padding: 10px;">All schedule tracks clean.</div>`;
    }
    return;
  }
  
  mockList.innerHTML = '';
  sessions.slice(0, 15).forEach(s => {
    const item = document.createElement('div');
    item.className = 'mock-feed-item';
    
    const subject = s.subject || 'Lecture';
    const time = s.start && s.end ? `${s.start} - ${s.end}` : (s.time || s.period || 'ON SCHEDULE');
    const teacher = s.teacher || s.instructor || 'STAFF';
    const venue = s.room || 'TBD';
    
    item.innerHTML = `
      <div class="mock-feed-left">
        <strong>${subject}</strong>
        <span>${teacher}</span>
      </div>
      <div class="mock-feed-right">
        <span class="badge-room">${venue}</span>
        <span class="badge-time">${time}</span>
      </div>
    `;
    mockList.appendChild(item);
  });
  
  if (mockHomeList) {
    mockHomeList.innerHTML = '';
    const limit = Math.min(2, sessions.length);
    for (let i = 0; i < limit; i++) {
      const s = sessions[i];
      const item = document.createElement('div');
      item.className = 'mock-feed-item';
      
      const subject = s.subject || 'Lecture';
      const teacher = s.teacher || s.instructor || 'STAFF';
      const venue = s.room || 'TBD';
      const time = s.start || s.time || '08:30';
      
      item.innerHTML = `
        <div class="mock-feed-left">
          <strong>${subject}</strong>
          <span>${teacher}</span>
        </div>
        <div class="mock-feed-right">
          <span class="badge-room">${venue}</span>
          <span class="badge-time">${time}</span>
        </div>
      `;
      mockHomeList.appendChild(item);
    }
  }
}

function updateEmulatorExams(exams) {
  const mockList = document.getElementById('mock-exams-list');
  if (!mockList) return;
  
  if (!exams || exams.length === 0) {
    mockList.innerHTML = `<div style="text-align: center; color: var(--text-muted); font-size: 10px; padding: 20px;">No exam datesheets seeded. Upload an excel sheet to preview.</div>`;
    return;
  }
  
  mockList.innerHTML = '';
  const limit = Math.min(10, exams.length);
  for (let i = 0; i < limit; i++) {
    const ex = exams[i];
    const item = document.createElement('div');
    item.className = 'mock-feed-item';
    item.innerHTML = `
      <div class="mock-feed-left">
        <strong>${ex.subject}</strong>
        <span>${ex.batch}</span>
      </div>
      <div class="mock-feed-right">
        <span class="badge-room" style="background: rgba(244, 63, 94, 0.08); border-color: rgba(244, 63, 94, 0.2); color: #f43f5e;">${ex.room}</span>
        <span class="badge-time" style="font-size: 7px; white-space: nowrap;">${ex.date} | ${ex.time}</span>
      </div>
    `;
    mockList.appendChild(item);
  }
}

function setup3DTiltEffects() {
  // 3D tilt effects disabled for clean, stable layout
}

// ==========================================================================
// LIVE DATABASE INSPECTORS (TIMETABLE & EXAMS)
// ==========================================================================

let liveClassesLedger = [];
let liveExamsLedger = [];

async function refreshLiveClassesInspector() {
  const tableBody = document.getElementById('inspector-classes-body');
  if (!tableBody) return;

  if (isConnected && db) {
    try {
      const doc = await db.collection('config').doc('global').get();
      if (doc.exists && doc.data().active_timetable_json) {
        const parsed = JSON.parse(doc.data().active_timetable_json);
        if (Array.isArray(parsed) && parsed.length > 0) {
          liveClassesLedger = parsed;
        } else if (parsed.sessions && Array.isArray(parsed.sessions) && parsed.sessions.length > 0) {
          liveClassesLedger = parsed.sessions;
        }
      }
    } catch (e) {
      console.warn("Could not query live classes:", e);
    }
  }

  filterLiveClassesInspector();
}

function filterLiveClassesInspector() {
  const tableBody = document.getElementById('inspector-classes-body');
  const searchInput = document.getElementById('inspector-classes-search');
  if (!tableBody) return;

  const q = (searchInput?.value || '').toLowerCase().trim();
  const filtered = liveClassesLedger.filter(s => {
    if (!q) return true;
    const blob = `${s.day || ''} ${s.start || ''} ${s.end || ''} ${s.time || ''} ${s.room || ''} ${s.batch || ''} ${s.subject || ''} ${s.teacher || ''}`.toLowerCase();
    return blob.includes(q);
  });

  if (filtered.length === 0) {
    tableBody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 24px;">No class sessions match "${q}".</td></tr>`;
    return;
  }

  tableBody.innerHTML = filtered.slice(0, 100).map(s => `
    <tr>
      <td><span style="font-family: var(--font-mono); font-size: 11px; font-weight: 700; color: var(--accent-cyan);">${s.day || 'Day'}</span></td>
      <td><span style="font-family: var(--font-mono); font-size: 11px;">${s.start && s.end ? `${s.start} - ${s.end}` : (s.time || '08:30')}</span></td>
      <td><span class="glass-pill-badge" style="color: var(--accent-emerald); font-size: 10px;">${s.room || 'TBD'}</span></td>
      <td><span style="font-family: var(--font-mono); font-size: 11px; font-weight: 700;">${s.batch || 'General'}</span></td>
      <td><strong style="color: var(--text-title); font-size: 12px;">${s.subject || 'Lecture'}</strong></td>
      <td style="color: var(--text-muted); font-size: 11.5px;">${s.teacher || s.instructor || 'STAFF'}</td>
    </tr>
  `).join('');
}

async function refreshLiveExamsInspector() {
  const tableBody = document.getElementById('inspector-exams-body');
  if (!tableBody) return;

  if (isConnected && db) {
    try {
      const doc = await db.collection('config').doc('global').get();
      if (doc.exists) {
        const data = doc.data();
        const jsonStr = data.active_midterm_json || data.active_finals_json;
        if (jsonStr) {
          const parsed = JSON.parse(jsonStr);
          if (Array.isArray(parsed) && parsed.length > 0) {
            liveExamsLedger = parsed;
          }
        }
      }
    } catch (e) {
      console.warn("Could not query live exams:", e);
    }
  }

  filterLiveExamsInspector();
}

function filterLiveExamsInspector() {
  const tableBody = document.getElementById('inspector-exams-body');
  const searchInput = document.getElementById('inspector-exams-search');
  if (!tableBody) return;

  const q = (searchInput?.value || '').toLowerCase().trim();
  const filtered = liveExamsLedger.filter(ex => {
    if (!q) return true;
    const blob = `${ex.date || ''} ${ex.time || ''} ${ex.room || ''} ${ex.batch || ''} ${ex.subject || ''}`.toLowerCase();
    return blob.includes(q);
  });

  if (filtered.length === 0) {
    tableBody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 24px;">No exam records match "${q}".</td></tr>`;
    return;
  }

  tableBody.innerHTML = filtered.slice(0, 100).map(ex => `
    <tr>
      <td><span style="font-family: var(--font-mono); font-size: 11px; font-weight: 700; color: var(--accent-cyan);"><i class="fa-solid fa-calendar-day" style="margin-right: 4px;"></i> ${ex.date || 'TBD'}</span></td>
      <td><span style="font-family: var(--font-mono); font-size: 11px;">${ex.time || '09:00 - 11:00'}</span></td>
      <td><span class="glass-pill-badge" style="color: var(--accent-rose); font-size: 10px;">${ex.room || 'HALL'}</span></td>
      <td><span style="font-family: var(--font-mono); font-size: 11px; font-weight: 700;">${ex.batch || 'Batch'}</span></td>
      <td><strong style="color: var(--text-title); font-size: 12px;">${ex.subject || 'Subject'}</strong></td>
    </tr>
  `).join('');
}

// Bind live inspector search and wipe buttons
document.addEventListener('DOMContentLoaded', () => {
  const classSearch = document.getElementById('inspector-classes-search');
  if (classSearch) classSearch.addEventListener('input', filterLiveClassesInspector);

  const btnRefreshClasses = document.getElementById('btn-refresh-inspector-classes');
  if (btnRefreshClasses) btnRefreshClasses.addEventListener('click', () => {
    refreshLiveClassesInspector();
    showMossToast("Refreshed live classes ledger.", "info");
  });

  const btnWipeClasses = document.getElementById('btn-wipe-classes');
  if (btnWipeClasses) btnWipeClasses.addEventListener('click', async () => {
    if (!confirm("Are you sure you want to clear active classes timetable from the live database?")) return;
    if (isConnected && db) {
      await db.collection('config').doc('global').update({
        active_timetable_json: "[]",
        active_timetable_version: Date.now(),
        updated_at: firebase.firestore.FieldValue.serverTimestamp()
      });
      incrementDatabaseOps();
      liveClassesLedger = [];
      filterLiveClassesInspector();
      showMossToast("Live classes database wiped.", "info");
      logTerminal("Wiped active classes timetable from database.", "warning");
    }
  });

  const examsSearch = document.getElementById('inspector-exams-search');
  if (examsSearch) examsSearch.addEventListener('input', filterLiveExamsInspector);

  const btnRefreshExams = document.getElementById('btn-refresh-inspector-exams');
  if (btnRefreshExams) btnRefreshExams.addEventListener('click', () => {
    refreshLiveExamsInspector();
    showMossToast("Refreshed live exams ledger.", "info");
  });

  const btnWipeExams = document.getElementById('btn-wipe-exams');
  if (btnWipeExams) btnWipeExams.addEventListener('click', async () => {
    if (!confirm("Are you sure you want to clear active exam date sheets from the live database?")) return;
    if (isConnected && db) {
      await db.collection('config').doc('global').update({
        active_midterm_json: "[]",
        active_finals_json: "[]",
        updated_at: firebase.firestore.FieldValue.serverTimestamp()
      });
      incrementDatabaseOps();
      liveExamsLedger = [];
      filterLiveExamsInspector();
      showMossToast("Live exams database wiped.", "info");
      logTerminal("Wiped active exams date sheets from database.", "warning");
    }
  });
});

function sanitizeAndValidateFirebaseConfig(jsonStr) {
  const logConsole = document.getElementById('config-validation-log');
  if (logConsole) {
    logConsole.innerHTML = '';
    logConsole.style.display = 'block';
  }
  
  const addLog = (message, type = 'info') => {
    if (logConsole) {
      const line = document.createElement('div');
      line.className = `val-log-line val-log-${type}`;
      line.innerText = `> [${type.toUpperCase()}] ${message}`;
      logConsole.appendChild(line);
      logConsole.scrollTop = logConsole.scrollHeight;
    }
  };
  
  addLog('Initializing sanitization checks...', 'info');
  
  let cleaned = jsonStr.trim();
  
  // 1. Fix single quotes to double quotes
  if (cleaned.includes("'")) {
    cleaned = cleaned.replace(/'/g, '"');
    addLog('Single quotes converted to double quotes.', 'warning');
  }
  
  // 2. Quote unquoted keys (e.g. { apiKey: ... } -> { "apiKey": ... })
  const unquotedKeyRegex = /([{,]\s*)([a-zA-Z0-9_]+)\s*:/g;
  if (unquotedKeyRegex.test(cleaned)) {
    cleaned = cleaned.replace(unquotedKeyRegex, '$1"$2":');
    addLog('Added quotes to unquoted object keys.', 'warning');
  }
  
  // 3. Strip trailing commas
  const trailingCommaRegex = /,\s*([}\]])/g;
  if (trailingCommaRegex.test(cleaned)) {
    cleaned = cleaned.replace(trailingCommaRegex, '$1');
    addLog('Stripped trailing commas.', 'warning');
  }
  
  // 4. Wrap with curly braces if copy-pasted as raw properties without wrap
  if (!cleaned.startsWith('{')) {
    cleaned = '{' + cleaned + '}';
    addLog('Wrapped properties with missing outer curly braces.', 'warning');
  }
  
  let parsed = null;
  try {
    parsed = JSON.parse(cleaned);
    addLog('JSON syntax verified successfully.', 'success');
  } catch (e) {
    addLog(`Syntax Error: ${e.message}`, 'error');
    addLog('Parsing aborted. Check braces and comma placement.', 'error');
    return null;
  }
  
  // Validate required keys
  const requiredKeys = ['apiKey', 'projectId', 'storageBucket'];
  let missing = [];
  requiredKeys.forEach(key => {
    if (!parsed[key]) {
      missing.push(key);
    }
  });
  
  if (missing.length > 0) {
    addLog(`Missing required parameters: ${missing.join(', ')}`, 'error');
    return null;
  }
  
  // Verify format of specific keys
  if (parsed.apiKey && !parsed.apiKey.startsWith('AIzaSy')) {
    addLog('Warning: apiKey does not match standard Firebase API Key format.', 'warning');
  }
  if (parsed.projectId && !/^[a-z0-9-]+$/.test(parsed.projectId)) {
    addLog('Warning: projectId contains non-standard characters.', 'warning');
  }
  
  addLog('Connection configuration validation complete.', 'success');
  return parsed;
}

function startTelemetryECG() {
  initTelemetryChart();
}

let activeClassesData = [];
let activeExamsData = [];
let activeInspectorExamPeriod = 'midterms';

async function refreshLiveClassesInspector() {
  const tbody = document.getElementById('inspector-classes-body');
  if (!tbody) return;
  
  tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--accent-indigo); padding: 20px;"><i class="fa-solid fa-spinner fa-spin"></i> Reading active timetable from live database...</td></tr>`;
  
  try {
    if (!isConnected || !db) {
      tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 20px;">Offline: Cannot query live database.</td></tr>`;
      return;
    }
    const doc = await db.collection('config').doc('global').get();
    if (doc.exists) {
      const data = doc.data();
      const jsonStr = data.active_timetable_json || '[]';
      const parsed = JSON.parse(jsonStr);
      activeClassesData = Array.isArray(parsed) ? parsed : (parsed.sessions || []);
      renderLiveClassesInspector();
      updateEmulatorTimetables(activeClassesData);
    } else {
      tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 20px;">No active configuration found on Firestore.</td></tr>`;
    }
  } catch (err) {
    tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--accent-rose); padding: 20px;">Error loading data: ${err.message}</td></tr>`;
  }
}

function renderLiveClassesInspector() {
  const tbody = document.getElementById('inspector-classes-body');
  const searchInput = document.getElementById('inspector-classes-search');
  if (!tbody) return;
  
  const query = searchInput ? searchInput.value.toLowerCase().trim() : '';
  let filtered = activeClassesData;
  
  if (query) {
    filtered = activeClassesData.filter(s => {
      return (s.batch || '').toLowerCase().includes(query) ||
             (s.class_name || '').toLowerCase().includes(query) ||
             (s.section || '').toLowerCase().includes(query) ||
             (s.subject || '').toLowerCase().includes(query) ||
             (s.teacher || '').toLowerCase().includes(query) ||
             (s.room || '').toLowerCase().includes(query) ||
             (s.day || '').toLowerCase().includes(query);
    });
  }
  
  if (filtered.length === 0) {
    tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 20px;">No classes matching search criteria.</td></tr>`;
    return;
  }
  
  tbody.innerHTML = '';
  const renderLimit = Math.min(100, filtered.length);
  for (let i = 0; i < renderLimit; i++) {
    const s = filtered[i];
    const tr = document.createElement('tr');
    
    const batchDisplay = s.batch || s.class_name || s.section || 'N/A';
    const timeDisplay = s.start && s.end ? `${s.start} - ${s.end}` : (s.time || s.period || 'N/A');
    
    tr.innerHTML = `
      <td style="font-weight: 600; color: var(--accent-indigo);">${batchDisplay}</td>
      <td>${s.day}</td>
      <td>${timeDisplay}</td>
      <td style="color: var(--text-title); font-weight: 500;">${s.subject}</td>
      <td>${s.teacher}</td>
      <td style="font-family: var(--font-mono);">${s.room}</td>
    `;
    tbody.appendChild(tr);
  }
  
  if (filtered.length > 100) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td colspan="6" style="text-align: center; font-style: italic; color: var(--text-muted); font-size: 9.5px; padding: 10px;">Truncated: displaying first 100 of ${filtered.length} active classes.</td>`;
    tbody.appendChild(tr);
  }
}

async function wipeLiveClasses() {
  if (!isConnected || !db) return;
  if (!confirm("WARNING: Are you sure you want to completely WIPE the active daily class timetable from the live database? This will clear the schedule for all student devices.")) {
    return;
  }
  
  logTerminal("Wiping live active daily class timetable...", "warning");
  
  try {
    await db.collection('config').doc('global').update({
      active_timetable_json: '[]',
      active_timetable_version: Date.now(),
      updated_at: firebase.firestore.FieldValue.serverTimestamp()
    });
    incrementDatabaseOps();
    
    logTerminal("Live Wipe Success: Cleared active daily class timetable database payload.", "success");
    showMossToast("Wiped active daily class timetable!", "success");
    
    refreshLiveClassesInspector();
  } catch (err) {
    logTerminal(`Wipe failed: ${err.message}`, 'error');
    showMossToast(err.message, "error");
  }
}

async function refreshLiveExamsInspector() {
  const tbody = document.getElementById('inspector-exams-body');
  if (!tbody) return;
  
  tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--accent-rose); padding: 20px;"><i class="fa-solid fa-spinner fa-spin"></i> Reading ${activeInspectorExamPeriod.toUpperCase()} schedule from live database...</td></tr>`;
  
  try {
    if (!isConnected || !db) {
      tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 20px;">Offline: Cannot query live database.</td></tr>`;
      return;
    }
    const doc = await db.collection('config').doc('global').get();
    if (doc.exists) {
      const data = doc.data();
      let jsonStr = '[]';
      if (activeInspectorExamPeriod === 'midterms') {
        jsonStr = data.active_midterm_json || '[]';
      } else {
        jsonStr = data.active_finals_json || '[]';
      }
      const parsed = JSON.parse(jsonStr);
      activeExamsData = Array.isArray(parsed) ? parsed : [];
      renderLiveExamsInspector();
      updateEmulatorExams(activeExamsData);
    } else {
      tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 20px;">No active configuration found on Firestore.</td></tr>`;
    }
  } catch (err) {
    tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--accent-rose); padding: 20px;">Error loading data: ${err.message}</td></tr>`;
  }
}

function renderLiveExamsInspector() {
  const tbody = document.getElementById('inspector-exams-body');
  const searchInput = document.getElementById('inspector-exams-search');
  if (!tbody) return;
  
  const query = searchInput ? searchInput.value.toLowerCase().trim() : '';
  let filtered = activeExamsData;
  
  if (query) {
    filtered = activeExamsData.filter(ex => {
      return (ex.batch || '').toLowerCase().includes(query) ||
             (ex.subject || '').toLowerCase().includes(query) ||
             (ex.room || '').toLowerCase().includes(query) ||
             (ex.date || '').toLowerCase().includes(query) ||
             (ex.time || '').toLowerCase().includes(query);
    });
  }
  
  if (filtered.length === 0) {
    tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 20px;">No exams matching search criteria.</td></tr>`;
    return;
  }
  
  tbody.innerHTML = '';
  const renderLimit = Math.min(100, filtered.length);
  for (let i = 0; i < renderLimit; i++) {
    const ex = filtered[i];
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${ex.date}</td>
      <td>${ex.time}</td>
      <td style="font-family: var(--font-mono); font-weight: 500;">${ex.room}</td>
      <td style="font-weight: 600; color: var(--accent-indigo);">${ex.batch}</td>
      <td style="color: var(--text-title);">${ex.subject}</td>
    `;
    tbody.appendChild(tr);
  }
  
  if (filtered.length > 100) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td colspan="5" style="text-align: center; font-style: italic; color: var(--text-muted); font-size: 9.5px; padding: 10px;">Truncated: displaying first 100 of ${filtered.length} active exams.</td>`;
    tbody.appendChild(tr);
  }
}

async function wipeLiveExams() {
  if (!isConnected || !db) return;
  if (!confirm(`WARNING: Are you sure you want to completely WIPE all active ${activeInspectorExamPeriod.toUpperCase()} exams from the live database? This will remove all schedules on student devices.`)) {
    return;
  }
  
  logTerminal(`Wiping live active ${activeInspectorExamPeriod} schedules...`, 'warning');
  
  try {
    let updateObj = {};
    if (activeInspectorExamPeriod === 'midterms') {
      updateObj.active_midterm_json = '[]';
      updateObj.active_midterm_version = Date.now();
    } else {
      updateObj.active_finals_json = '[]';
      updateObj.active_finals_version = Date.now();
    }
    updateObj.updated_at = firebase.firestore.FieldValue.serverTimestamp();
    
    await db.collection('config').doc('global').update(updateObj);
    incrementDatabaseOps();
    
    logTerminal(`Live Wipe Success: Cleared active ${activeInspectorExamPeriod} exams schedule database payload.`, 'success');
    showMossToast(`Wiped ${activeInspectorExamPeriod.toUpperCase()} schedule!`, "success");
    
    refreshLiveExamsInspector();
  } catch (err) {
    logTerminal(`Wipe failed: ${err.message}`, 'error');
    showMossToast(err.message, "error");
  }
}

function setupGlassShaderEffects() {
  // 1. Animate background SVG turbulence seed (if turbulence filter is defined)
  const turbulence = document.querySelector('#liquid-refraction feTurbulence');
  if (turbulence) {
    let seed = 1;
    setInterval(() => {
      seed = (seed + 1) % 1000;
      turbulence.setAttribute('seed', seed);
    }, 120);
  }

  // 2. Initialize offscreen displacement maps for all cards
  const cards = document.querySelectorAll('.tech-card, .modal-card');
  const filtersContainer = document.getElementById('svg-filters-container');
  if (!filtersContainer) return;

  let glassCounter = 0;

  cards.forEach(card => {
    const glassId = ++glassCounter;
    card.dataset.glassId = glassId;

    // Create offscreen canvas for SDF displacement calculation (hidden from DOM)
    const offscreenCanvas = document.createElement('canvas');
    offscreenCanvas.width = 64;
    offscreenCanvas.height = 64;
    card.glassCanvas = offscreenCanvas;
    card.glassCtx = offscreenCanvas.getContext('2d');

    // Generate unique SVG filter ID for chromatic dispersion
    const filterId = `liquid-glass-filter-${glassId}`;
    const mapId = `liquid-glass-map-${glassId}`;
    
    const svgNS = "http://www.w3.org/2000/svg";
    const filter = document.createElementNS(svgNS, "filter");
    filter.setAttribute("id", filterId);
    filter.setAttribute("filterUnits", "userSpaceOnUse");
    filter.setAttribute("color-interpolation-filters", "sRGB");
    filter.setAttribute("x", "0");
    filter.setAttribute("y", "0");
    
    const feImage = document.createElementNS(svgNS, "feImage");
    feImage.setAttribute("id", mapId);
    feImage.setAttribute("result", "map");
    feImage.setAttribute("x", "0");
    feImage.setAttribute("y", "0");
    
    // Chromatic dispersion channel maps (Red/Green/Blue split)
    const feDispR = document.createElementNS(svgNS, "feDisplacementMap");
    feDispR.setAttribute("in", "SourceGraphic");
    feDispR.setAttribute("in2", "map");
    feDispR.setAttribute("scale", "35"); // Red bends more
    feDispR.setAttribute("xChannelSelector", "R");
    feDispR.setAttribute("yChannelSelector", "G");
    feDispR.setAttribute("result", "redDisp");

    const feDispG = document.createElementNS(svgNS, "feDisplacementMap");
    feDispG.setAttribute("in", "SourceGraphic");
    feDispG.setAttribute("in2", "map");
    feDispG.setAttribute("scale", "25"); // Green normal
    feDispG.setAttribute("xChannelSelector", "R");
    feDispG.setAttribute("yChannelSelector", "G");
    feDispG.setAttribute("result", "greenDisp");

    const feDispB = document.createElementNS(svgNS, "feDisplacementMap");
    feDispB.setAttribute("in", "SourceGraphic");
    feDispB.setAttribute("in2", "map");
    feDispB.setAttribute("scale", "15"); // Blue bends less
    feDispB.setAttribute("xChannelSelector", "R");
    feDispB.setAttribute("yChannelSelector", "G");
    feDispB.setAttribute("result", "blueDisp");

    // Isolate color channels
    const feMatR = document.createElementNS(svgNS, "feColorMatrix");
    feMatR.setAttribute("in", "redDisp");
    feMatR.setAttribute("type", "matrix");
    feMatR.setAttribute("values", "1 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1 0");
    feMatR.setAttribute("result", "redOnly");

    const feMatG = document.createElementNS(svgNS, "feColorMatrix");
    feMatG.setAttribute("in", "greenDisp");
    feMatG.setAttribute("type", "matrix");
    feMatG.setAttribute("values", "0 0 0 0 0  0 1 0 0 0  0 0 0 0 0  0 0 0 1 0");
    feMatG.setAttribute("result", "greenOnly");

    const feMatB = document.createElementNS(svgNS, "feColorMatrix");
    feMatB.setAttribute("in", "blueDisp");
    feMatB.setAttribute("type", "matrix");
    feMatB.setAttribute("values", "0 0 0 0 0  0 0 0 0 0  0 0 1 0 0  0 0 0 1 0");
    feMatB.setAttribute("result", "blueOnly");

    // Recombine channels back to full color screen space
    const feBlend1 = document.createElementNS(svgNS, "feBlend");
    feBlend1.setAttribute("in", "redOnly");
    feBlend1.setAttribute("in2", "greenOnly");
    feBlend1.setAttribute("mode", "screen");
    feBlend1.setAttribute("result", "rg");

    const feBlend2 = document.createElementNS(svgNS, "feBlend");
    feBlend2.setAttribute("in", "rg");
    feBlend2.setAttribute("in2", "blueOnly");
    feBlend2.setAttribute("mode", "screen");
    feBlend2.setAttribute("result", "rgb");

    filter.appendChild(feImage);
    filter.appendChild(feDispR);
    filter.appendChild(feDispG);
    filter.appendChild(feDispB);
    filter.appendChild(feMatR);
    filter.appendChild(feMatG);
    filter.appendChild(feMatB);
    filter.appendChild(feBlend1);
    filter.appendChild(feBlend2);

    filtersContainer.appendChild(filter);

    card.feImage = feImage;
    card.filterElement = filter;

    // Apply inline backdrop filter linking to card-specific SVG
    card.style.backdropFilter = `url(#${filterId}) blur(16px) saturate(1.1) brightness(1.05)`;
    card.style.webkitBackdropFilter = `url(#${filterId}) blur(16px) saturate(1.1) brightness(1.05)`;

    // Physics parameters
    card.mouseActive = false;
    card.mouseX = 0;
    card.mouseY = 0;
    card.targetX = 0;
    card.targetY = 0;
    card.warpX = 0;
    card.warpY = 0;
    card.vx = 0;
    card.vy = 0;

    let lastMouseX = 0;
    let lastMouseY = 0;
    let lastTime = Date.now();

    card.addEventListener('mouseenter', () => {
      card.mouseActive = true;
    });

    card.addEventListener('mousemove', e => {
      const rect = card.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      
      card.mouseX = x;
      card.mouseY = y;
      
      const now = Date.now();
      const dt = Math.max(1, now - lastTime);
      
      // Calculate cursor velocity to drive physical fluid sloshing
      const vxMouse = (x - lastMouseX) / dt;
      const vyMouse = (y - lastMouseY) / dt;
      
      card.targetX = Math.max(-25, Math.min(25, vxMouse * 12));
      card.targetY = Math.max(-25, Math.min(25, vyMouse * 12));
      
      lastMouseX = x;
      lastMouseY = y;
      lastTime = now;
      
      // 3D tilt effects disabled for clean, flat layout
      card.style.transform = 'none';

      // Write CSS variables to feed the GPU touch glow
      card.style.setProperty('--mouse-x', `${x}px`);
      card.style.setProperty('--mouse-y', `${y}px`);
    });

    card.addEventListener('mouseleave', () => {
      card.mouseActive = false;
      card.targetX = 0;
      card.targetY = 0;
      card.style.transform = 'none';
    });
  });

  // Math models for refraction simulation
  function circleMap(x) {
    return 1.0 - Math.sqrt(Math.max(0.0, 1.0 - x * x));
  }

  function roundedRectSDF(x, y, w, h, r) {
    const qx = Math.abs(x) - w + r;
    const qy = Math.abs(y) - h + r;
    return Math.min(Math.max(qx, qy), 0) + Math.sqrt(Math.max(qx, 0)**2 + Math.max(qy, 0)**2) - r;
  }

  function gradSdRoundedRect(x, y, w, h, r) {
    const qx = Math.abs(x) - w + r;
    const qy = Math.abs(y) - h + r;
    if (qx >= 0 || qy >= 0) {
      const mx = Math.max(qx, 0);
      const my = Math.max(qy, 0);
      const len = Math.sqrt(mx * mx + my * my);
      return {
        x: Math.sign(x) * (len > 0 ? mx / len : 0),
        y: Math.sign(y) * (len > 0 ? my / len : 0)
      };
    } else {
      const gradX = qy < qx ? 1 : 0;
      return {
        x: Math.sign(x) * gradX,
        y: Math.sign(y) * (1 - gradX)
      };
    }
  }

  // Render & Physics Loop
  function updatePhysicsAndRender() {
    const spring = 0.08;
    const damping = 0.82;
    const resolution = 64;

    cards.forEach(card => {
      const width = card.offsetWidth;
      const height = card.offsetHeight;

      // Prevent DOMExceptions from hidden cards or zero-bounding elements
      if (width <= 0 || height <= 0) return;

      // Update SVG filter mapping on layout changes
      if (card.lastWidth !== width || card.lastHeight !== height) {
        card.lastWidth = width;
        card.lastHeight = height;

        card.filterElement.setAttribute('x', '0');
        card.filterElement.setAttribute('y', '0');
        card.filterElement.setAttribute('width', width.toString());
        card.filterElement.setAttribute('height', height.toString());

        card.feImage.setAttribute('width', width.toString());
        card.feImage.setAttribute('height', height.toString());
      }

      // Spring sloshing logic
      const ax = (card.targetX - card.warpX) * spring;
      const ay = (card.targetY - card.warpY) * spring;
      card.vx = (card.vx + ax) * damping;
      card.vy = (card.vy + ay) * damping;
      card.warpX += card.vx;
      card.warpY += card.vy;

      // Decay velocity
      card.targetX *= 0.92;
      card.targetY *= 0.92;

      // CPU Guard: if elements settle, skip redraw frame to save energy (0% CPU idle)
      const isMoving = Math.abs(card.vx) > 0.005 || Math.abs(card.vy) > 0.005;
      if (!isMoving && !card.mouseActive && card.hasStaticRendered) {
        return;
      }

      const ctx = card.glassCtx;
      const w = resolution;
      const h = resolution;
      const imgData = ctx.createImageData(w, h);
      const data = imgData.data;

      const halfW = width / 2;
      const halfH = height / 2;
      const refractWidth = 24; // Lens boundary border width
      const refractAmount = 15; // Max displacement shift in pixels

      const wx = card.warpX * 0.15;
      const wy = card.warpY * 0.15;

      for (let y = 0; y < h; y++) {
        const cardY = (y / (h - 1)) * height;
        const cy = cardY - halfH;

        for (let x = 0; x < w; x++) {
          const cardX = (x / (w - 1)) * width;
          const cx = cardX - halfW;

          // Compute Signed Distance Field to find distance to card border
          const sd = roundedRectSDF(cx, cy, halfW, halfH, 12);
          
          let dx = 0;
          let dy = 0;

          if (sd < 0) {
            // Inside the card boundaries
            if (sd > -refractWidth) {
              // Map curved edge light bending refraction
              const ratio = 1.0 - (-sd / refractWidth);
              const d = circleMap(ratio) * refractAmount;

              const grad = gradSdRoundedRect(cx, cy, halfW, halfH, 12);
              const len = Math.sqrt(grad.x**2 + grad.y**2);
              const nx = len > 0 ? grad.x / len : 0;
              const ny = len > 0 ? grad.y / len : 0;

              // Convex lens: bends background light inward
              dx = -d * nx;
              dy = -d * ny;
            }

            // Apply global sloshing shift behind card
            dx += wx;
            dy += wy;
          }

          // Encode coordinates to 8-bit color space relative to reference scale 25
          const r = Math.max(0, Math.min(255, Math.round((dx / 25) * 128 + 128)));
          const g = Math.max(0, Math.min(255, Math.round((dy / 25) * 128 + 128)));

          const idx = (y * w + x) * 4;
          data[idx] = r;
          data[idx + 1] = g;
          data[idx + 2] = 0;
          data[idx + 3] = 255;
        }
      }

      ctx.putImageData(imgData, 0, 0);

      // Apply displacement texture data-URL to SVG feImage filter target using both standard and xlink:href
      const dataUrl = card.glassCanvas.toDataURL();
      card.feImage.setAttribute('href', dataUrl);
      card.feImage.setAttributeNS('http://www.w3.org/1999/xlink', 'href', dataUrl);

      // Force Chrome/Safari repaint of the backdrop-filter by alternating tiny subpixel blur sizes
      card.repaintToggle = !card.repaintToggle;
      const blurVal = card.repaintToggle ? "16px" : "16.01px";
      const filterStyle = `url(#liquid-glass-filter-${card.dataset.glassId}) blur(${blurVal}) saturate(1.1) brightness(1.05)`;
      card.style.backdropFilter = filterStyle;
      card.style.webkitBackdropFilter = filterStyle;

      card.hasStaticRendered = true;
    });

    requestAnimationFrame(updatePhysicsAndRender);
  }

  // Launch loop
  requestAnimationFrame(updatePhysicsAndRender);
}

// Seamless Light/Dark Theme Switcher Engine
function setupThemeToggle() {
  const btnThemeToggle = document.getElementById('btn-theme-toggle');
  const savedTheme = localStorage.getItem('admin_portal_theme') || 'dark';
  
  document.documentElement.setAttribute('data-theme', savedTheme);
  updateThemeIcon(savedTheme);

  if (btnThemeToggle) {
    btnThemeToggle.addEventListener('click', () => {
      const currentTheme = document.documentElement.getAttribute('data-theme') || 'dark';
      const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
      
      document.documentElement.setAttribute('data-theme', newTheme);
      localStorage.setItem('admin_portal_theme', newTheme);
      updateThemeIcon(newTheme);
      logTerminal(`UI Theme toggled to ${newTheme.toUpperCase()} mode.`, 'info');
    });
  }
}

function updateThemeIcon(theme) {
  const btnThemeToggle = document.getElementById('btn-theme-toggle');
  if (btnThemeToggle) {
    const icon = btnThemeToggle.querySelector('i');
    if (icon) {
      if (theme === 'light') {
        icon.className = 'fa-solid fa-moon';
      } else {
        icon.className = 'fa-solid fa-sun';
      }
    }
  }
}



// ==========================================================================
// SEMESTER SCHEDULE & MILESTONES WORKSPACE MANAGER (ADVANCED EASE-OF-ACCESS)
// ==========================================================================

let stagedSemesterMilestones = [];

const DEFAULT_COMSATS_MILESTONES = [
  { title: "REGISTRATION WEEK", date: "2026-01-26", category: "Registration", status: "expired" },
  { title: "COMMENCEMENT OF CLASSES", date: "2026-02-02", category: "Classes", status: "active" },
  { title: "LAST DATE FOR DROP COURSE", date: "2026-03-06", category: "Registration", status: "upcoming" },
  { title: "MIDTERM EXAMINATIONS", date: "2026-04-13", category: "Exams", status: "upcoming" },
  { title: "STUDENT SPORTS & CULTURAL WEEK", date: "2026-05-04", category: "Events", status: "upcoming" },
  { title: "LAST DAY OF CLASSES", date: "2026-05-22", category: "Classes", status: "upcoming" },
  { title: "TERMINAL EXAMINATIONS", date: "2026-06-03", category: "Exams", status: "upcoming" },
  { title: "RESULT OF TERMINAL EXAMS", date: "2026-07-06", category: "Registration", status: "upcoming" }
];

function setupSemesterScheduleHandlers() {
  const btnAdd = document.getElementById('btn-add-milestone');
  const btnTemplate = document.getElementById('btn-template-milestones');
  const btnClear = document.getElementById('btn-clear-milestones');
  const btnDeploy = document.getElementById('btn-deploy-semester');
  const btnFetchCloud = document.getElementById('btn-fetch-cloud-milestones');
  const btnExport = document.getElementById('btn-export-milestones');
  const btnSort = document.getElementById('btn-sort-chronological');

  // Quick Preset Chips Handler
  const presetChips = document.querySelectorAll('.milestone-preset-chip');
  presetChips.forEach(chip => {
    chip.addEventListener('click', () => {
      const title = chip.dataset.title || chip.innerText.trim();
      const cat = chip.dataset.cat || 'Classes';
      const status = chip.dataset.status || 'upcoming';

      const titleInput = document.getElementById('input-milestone-title');
      const catSelect = document.getElementById('select-milestone-category');
      const statusSelect = document.getElementById('select-milestone-status');
      const dateInput = document.getElementById('input-milestone-date');

      if (titleInput) titleInput.value = title;
      if (catSelect) catSelect.value = cat;
      if (statusSelect) statusSelect.value = status;
      if (dateInput) dateInput.focus();

      logTerminal(`Auto-filled milestone preset: <strong>${title}</strong> (${cat})`, 'info');
      showMossToast(`Preset applied: ${title}`, 'info');
    });
  });

  // Date Mode Toggle (Single vs Range)
  const dateModeRadios = document.querySelectorAll('input[name="milestone-date-mode"]');
  const singleDateContainer = document.getElementById('date-single-container');
  const rangeDateContainer = document.getElementById('date-range-container');
  const singlePicker = document.getElementById('input-milestone-date-picker');
  const singleText = document.getElementById('input-milestone-date');
  const startDatePicker = document.getElementById('input-milestone-start-date');
  const endDatePicker = document.getElementById('input-milestone-end-date');

  dateModeRadios.forEach(radio => {
    radio.addEventListener('change', () => {
      if (radio.value === 'range') {
        if (singleDateContainer) singleDateContainer.style.display = 'none';
        if (rangeDateContainer) rangeDateContainer.style.display = 'flex';
      } else {
        if (singleDateContainer) singleDateContainer.style.display = 'flex';
        if (rangeDateContainer) rangeDateContainer.style.display = 'none';
      }
    });
  });

  if (singlePicker && singleText) {
    singlePicker.addEventListener('change', () => {
      if (singlePicker.value) {
        singleText.value = singlePicker.value;
      }
    });
  }

  const updateRangeDateText = () => {
    const s = startDatePicker?.value;
    const e = endDatePicker?.value;
    if (s && e) {
      if (singleText) singleText.value = `${s} to ${e}`;
    } else if (s) {
      if (singleText) singleText.value = s;
    }
  };

  if (startDatePicker) startDatePicker.addEventListener('change', updateRangeDateText);
  if (endDatePicker) endDatePicker.addEventListener('change', updateRangeDateText);

  // Add Milestone
  if (btnAdd) {
    btnAdd.addEventListener('click', addSemesterMilestoneFromInput);
  }

  // Load Template
  if (btnTemplate) {
    btnTemplate.addEventListener('click', () => {
      stagedSemesterMilestones = JSON.parse(JSON.stringify(DEFAULT_COMSATS_MILESTONES));
      renderSemesterMilestonesTable();
      logTerminal('Staged standard COMSATS semester milestones template.', 'info');
      showMossToast("Loaded standard semester milestones template!", "info");
    });
  }

  // Fetch Live Cloud Schedule
  if (btnFetchCloud) {
    btnFetchCloud.addEventListener('click', fetchLiveCloudSchedule);
  }

  // Export JSON
  if (btnExport) {
    btnExport.addEventListener('click', exportSemesterScheduleJson);
  }

  // Auto-Sort Chronological
  if (btnSort) {
    btnSort.addEventListener('click', sortMilestonesChronologically);
  }

  // Clear All
  if (btnClear) {
    btnClear.addEventListener('click', () => {
      stagedSemesterMilestones = [];
      renderSemesterMilestonesTable();
      logTerminal('Cleared all staged semester milestones.', 'info');
      showMossToast('Cleared all milestones.', 'info');
    });
  }

  // Deploy
  if (btnDeploy) {
    btnDeploy.addEventListener('click', deploySemesterScheduleToFirestore);
  }
}

async function fetchLiveCloudSchedule() {
  if (!isConnected || !db) {
    showMossToast("Database connection offline.", "error");
    return;
  }

  const btn = document.getElementById('btn-fetch-cloud-milestones');
  if (btn) btn.disabled = true;

  try {
    logTerminal('Querying live semester milestones from Firestore...', 'info');
    const doc = await db.collection('config').doc('global').get();
    
    if (doc.exists && doc.data().semester_schedule && Array.isArray(doc.data().semester_schedule)) {
      stagedSemesterMilestones = JSON.parse(JSON.stringify(doc.data().semester_schedule));
      renderSemesterMilestonesTable();
      logTerminal(`Fetched <strong>${stagedSemesterMilestones.length}</strong> active milestones from Firestore.`, 'success');
      showMossToast(`Loaded ${stagedSemesterMilestones.length} live milestones from cloud!`, 'success');
    } else {
      showMossToast("No custom cloud milestones found. Loaded default template.", "info");
      stagedSemesterMilestones = JSON.parse(JSON.stringify(DEFAULT_COMSATS_MILESTONES));
      renderSemesterMilestonesTable();
    }
  } catch (err) {
    console.error("Fetch live schedule error:", err);
    logTerminal(`Fetch failed: ${err.message}`, 'error');
    showMossToast(err.message, 'error');
  } finally {
    if (btn) btn.disabled = false;
  }
}

function exportSemesterScheduleJson() {
  if (stagedSemesterMilestones.length === 0) {
    showMossToast("No milestones to export.", "warning");
    return;
  }
  const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(stagedSemesterMilestones, null, 2));
  const downloadAnchor = document.createElement('a');
  downloadAnchor.setAttribute("href", dataStr);
  downloadAnchor.setAttribute("download", `semester_schedule_${new Date().toISOString().split('T')[0]}.json`);
  document.body.appendChild(downloadAnchor);
  downloadAnchor.click();
  downloadAnchor.remove();
  showMossToast("Exported semester milestones to JSON!", "success");
}

function sortMilestonesChronologically() {
  if (stagedSemesterMilestones.length < 2) return;
  stagedSemesterMilestones.sort((a, b) => {
    const extractDate = (str) => {
      const match = str.match(/\d{4}-\d{2}-\d{2}/);
      if (match) return new Date(match[0]).getTime();
      const parsed = Date.parse(str.split('to')[0].trim());
      return isNaN(parsed) ? 0 : parsed;
    };
    return extractDate(a.date) - extractDate(b.date);
  });
  renderSemesterMilestonesTable();
  logTerminal('Auto-sorted milestones chronologically.', 'info');
  showMossToast("Milestones sorted by timeline date!", "info");
}

function addSemesterMilestoneFromInput() {
  const titleInput = document.getElementById('input-milestone-title');
  const dateInput = document.getElementById('input-milestone-date');
  const catSelect = document.getElementById('select-milestone-category');
  const statusSelect = document.getElementById('select-milestone-status');

  const title = (titleInput?.value || '').trim();
  const date = (dateInput?.value || '').trim();
  const category = catSelect?.value || 'Classes';
  const status = statusSelect?.value || 'upcoming';

  if (!title) {
    showMossToast("Please enter a milestone title.", "warning");
    return;
  }
  if (!date) {
    showMossToast("Please enter a date or timeline range.", "warning");
    return;
  }

  stagedSemesterMilestones.push({ title, date, category, status });
  renderSemesterMilestonesTable();

  if (titleInput) titleInput.value = '';
  if (dateInput) dateInput.value = '';

  logTerminal(`Staged milestone: <strong>${title}</strong> (${date})`, 'success');
  showMossToast(`Added "${title}" to schedule!`, "success");
}

window.moveSemesterMilestone = function(index, direction) {
  const targetIndex = index + direction;
  if (targetIndex < 0 || targetIndex >= stagedSemesterMilestones.length) return;
  
  const temp = stagedSemesterMilestones[index];
  stagedSemesterMilestones[index] = stagedSemesterMilestones[targetIndex];
  stagedSemesterMilestones[targetIndex] = temp;
  
  renderSemesterMilestonesTable();
};

window.cycleMilestoneStatus = function(index) {
  if (index < 0 || index >= stagedSemesterMilestones.length) return;
  const current = stagedSemesterMilestones[index].status || 'upcoming';
  const nextStatus = current === 'upcoming' ? 'active' : (current === 'active' ? 'expired' : 'upcoming');
  stagedSemesterMilestones[index].status = nextStatus;
  renderSemesterMilestonesTable();
  showMossToast(`Status set to: ${nextStatus.toUpperCase()}`, 'info');
};

window.editSemesterMilestone = function(index) {
  if (index < 0 || index >= stagedSemesterMilestones.length) return;
  const m = stagedSemesterMilestones[index];
  const newTitle = prompt("Edit Milestone Title:", m.title);
  if (newTitle === null) return;
  const newDate = prompt("Edit Milestone Date / Timeline:", m.date);
  if (newDate === null) return;
  
  m.title = newTitle.trim() || m.title;
  m.date = newDate.trim() || m.date;
  renderSemesterMilestonesTable();
  showMossToast(`Updated: ${m.title}`, 'success');
};

window.duplicateSemesterMilestone = function(index) {
  if (index < 0 || index >= stagedSemesterMilestones.length) return;
  const clone = { ...stagedSemesterMilestones[index], title: `${stagedSemesterMilestones[index].title} (Copy)` };
  stagedSemesterMilestones.splice(index + 1, 0, clone);
  renderSemesterMilestonesTable();
  showMossToast(`Duplicated milestone!`, 'info');
};

window.removeSemesterMilestone = function(index) {
  if (index >= 0 && index < stagedSemesterMilestones.length) {
    const removed = stagedSemesterMilestones.splice(index, 1)[0];
    renderSemesterMilestonesTable();
    logTerminal(`Removed milestone: ${removed.title}`, 'info');
    showMossToast(`Removed ${removed.title}`, 'info');
  }
};

function renderSemesterMilestonesTable() {
  const tableBody = document.getElementById('milestones-table-body');
  const countBadge = document.getElementById('milestone-count');
  const statusSummary = document.getElementById('milestones-status-summary');

  if (countBadge) {
    countBadge.innerText = stagedSemesterMilestones.length;
  }

  // Compute status counts
  const activeCount = stagedSemesterMilestones.filter(m => m.status === 'active').length;
  const upcomingCount = stagedSemesterMilestones.filter(m => m.status === 'upcoming').length;
  const expiredCount = stagedSemesterMilestones.filter(m => m.status === 'expired').length;

  if (statusSummary) {
    if (stagedSemesterMilestones.length > 0) {
      statusSummary.innerHTML = `• <span style="color: var(--accent-cyan); font-weight: 700;">${activeCount} Active</span> • <span style="color: var(--accent-emerald); font-weight: 700;">${upcomingCount} Upcoming</span> • <span style="color: var(--text-muted);">${expiredCount} Expired</span>`;
    } else {
      statusSummary.innerHTML = '';
    }
  }

  if (!tableBody) return;

  if (stagedSemesterMilestones.length === 0) {
    tableBody.innerHTML = `
      <tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 32px;">No milestones staged. Click "Fetch Live Cloud", "Load Template", or add milestones above.</td></tr>
    `;
    return;
  }

  tableBody.innerHTML = stagedSemesterMilestones.map((m, idx) => {
    let catBadgeColor = 'var(--accent-indigo)';
    let catBg = 'rgba(99, 102, 241, 0.12)';
    if (m.category === 'Exams') { catBadgeColor = 'var(--accent-amber)'; catBg = 'rgba(245, 158, 11, 0.12)'; }
    else if (m.category === 'Events') { catBadgeColor = '#a855f7'; catBg = 'rgba(168, 85, 247, 0.12)'; }
    else if (m.category === 'Registration') { catBadgeColor = 'var(--accent-cyan)'; catBg = 'rgba(6, 182, 212, 0.12)'; }
    else if (m.category === 'Holidays') { catBadgeColor = 'var(--accent-rose)'; catBg = 'rgba(239, 68, 68, 0.12)'; }

    let statusBadgeColor = 'var(--accent-emerald)';
    let statusBg = 'rgba(16, 185, 129, 0.12)';
    let statusIcon = 'fa-clock';
    if (m.status === 'expired') { 
      statusBadgeColor = 'var(--text-muted)'; 
      statusBg = 'rgba(255, 255, 255, 0.05)'; 
      statusIcon = 'fa-circle-check';
    } else if (m.status === 'active') { 
      statusBadgeColor = 'var(--accent-cyan)'; 
      statusBg = 'rgba(6, 182, 212, 0.18)'; 
      statusIcon = 'fa-bolt';
    }

    return `
      <tr>
        <td style="text-align: center;">
          <div style="display: flex; flex-direction: column; gap: 2px; align-items: center;">
            <button type="button" class="btn-row-action" onclick="moveSemesterMilestone(${idx}, -1)" ${idx === 0 ? 'disabled style="opacity: 0.3;"' : ''} title="Move Up" style="padding: 2px 4px; font-size: 8px;">
              <i class="fa-solid fa-chevron-up"></i>
            </button>
            <span style="font-family: var(--font-mono); font-size: 10px; font-weight: 700; color: var(--text-muted);">${idx + 1}</span>
            <button type="button" class="btn-row-action" onclick="moveSemesterMilestone(${idx}, 1)" ${idx === stagedSemesterMilestones.length - 1 ? 'disabled style="opacity: 0.3;"' : ''} title="Move Down" style="padding: 2px 4px; font-size: 8px;">
              <i class="fa-solid fa-chevron-down"></i>
            </button>
          </div>
        </td>
        <td>
          <strong style="color: var(--text-title); font-size: 12.5px; display: block;">${m.title}</strong>
        </td>
        <td>
          <span style="font-family: var(--font-mono); font-size: 11.5px; color: var(--accent-cyan); font-weight: 600; background: rgba(6, 182, 212, 0.06); padding: 4px 8px; border-radius: 6px;">
            <i class="fa-solid fa-calendar-day" style="margin-right: 4px;"></i> ${m.date}
          </span>
        </td>
        <td>
          <span style="padding: 4px 10px; border-radius: 6px; font-size: 9.5px; font-weight: 800; text-transform: uppercase; background: ${catBg}; color: ${catBadgeColor};">
            ${m.category || 'General'}
          </span>
        </td>
        <td>
          <span class="status-clickable-pill" onclick="cycleMilestoneStatus(${idx})" title="Click to cycle: Upcoming -> Active -> Expired" style="padding: 4px 10px; border-radius: 6px; font-size: 9.5px; font-weight: 800; text-transform: uppercase; background: ${statusBg}; color: ${statusBadgeColor};">
            <i class="fa-solid ${statusIcon}"></i> ${m.status || 'Upcoming'}
          </span>
        </td>
        <td style="text-align: right;">
          <div style="display: inline-flex; gap: 4px;">
            <button type="button" class="btn-row-action" onclick="editSemesterMilestone(${idx})" title="Edit Title/Date">
              <i class="fa-solid fa-pen"></i>
            </button>
            <button type="button" class="btn-row-action" onclick="duplicateSemesterMilestone(${idx})" title="Duplicate Row">
              <i class="fa-solid fa-clone"></i>
            </button>
            <button type="button" class="btn-row-action delete" onclick="removeSemesterMilestone(${idx})" title="Delete Milestone">
              <i class="fa-solid fa-trash-can"></i>
            </button>
          </div>
        </td>
      </tr>
    `;
  }).join('');
}

async function deploySemesterScheduleToFirestore() {
  if (!isConnected || !db) {
    showMossToast("Database link offline. Cannot deploy schedule.", "error");
    return;
  }
  if (stagedSemesterMilestones.length === 0) {
    showMossToast("No milestones staged to deploy. Add milestones first.", "warning");
    return;
  }

  const btnDeploy = document.getElementById('btn-deploy-semester');
  if (btnDeploy) {
    btnDeploy.disabled = true;
    btnDeploy.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> DEPLOYING SEMESTER SCHEDULE...';
  }

  try {
    logTerminal(`Initiating deployment of <strong>${stagedSemesterMilestones.length}</strong> semester milestones...`, 'info');

    const updatePayload = {
      semester_schedule: stagedSemesterMilestones,
      active_semester_version: Date.now(),
      semester_schedule_updated_at: firebase.firestore.FieldValue.serverTimestamp()
    };

    // Write to Firestore global config and dedicated semester_schedule document
    await Promise.all([
      db.collection('config').doc('global').set(updatePayload, { merge: true }),
      db.collection('config').doc('semester_schedule').set({
        milestones: stagedSemesterMilestones,
        version: Date.now(),
        updated_at: firebase.firestore.FieldValue.serverTimestamp()
      })
    ]);

    incrementDatabaseOps();
    logTerminal(`✅ SUCCESS: Published <strong>${stagedSemesterMilestones.length}</strong> semester milestones live to IRIS Firestore.`, 'success');
    showMossToast("Semester schedule published live to IRIS mobile apps!", "success");
  } catch (err) {
    console.error("Semester schedule deployment error:", err);
    logTerminal(`Deployment failed: ${err.message}`, 'error');
    showMossToast(`Deployment error: ${err.message}`, "error");
  } finally {
    if (btnDeploy) {
      btnDeploy.disabled = false;
      btnDeploy.innerHTML = '<i class="fa-solid fa-cloud-arrow-up" style="margin-right: 8px;"></i> <span>DEPLOY SEMESTER SCHEDULE TO IRIS (FIRESTORE)</span>';
    }
  }
}

// ==========================================================================
// AUTHENTIC COMMUNITY FEEDBACK & TELEMETRY STREAM CONTROLLER
// ==========================================================================

let allLiveFeedback = [];
let firestoreFeedbackListener = null;

async function fetchFirestoreFeedbackDirect() {
  if (!db) return;
  try {
    const snap = await db.collection('feedback').get();
    processFeedbackSnapshot(snap);
  } catch (e) {
    console.warn("Direct feedback fetch error:", e);
  }
}

function processFeedbackSnapshot(snapshot) {
  const cloudItems = [];
  snapshot.forEach(doc => {
    const data = doc.data() || {};
    let rawDate = 0;
    let formattedDate = 'Recent';

    if (data.created_at && typeof data.created_at.toDate === 'function') {
      const d = data.created_at.toDate();
      rawDate = d.getTime();
      formattedDate = d.toLocaleString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    } else if (data.created_at && typeof data.created_at === 'number') {
      const d = new Date(data.created_at);
      rawDate = d.getTime();
      formattedDate = d.toLocaleString('en-US');
    } else if (data.created_at && typeof data.created_at === 'string') {
      const d = new Date(data.created_at);
      if (!isNaN(d.getTime())) {
        rawDate = d.getTime();
        formattedDate = d.toLocaleString('en-US');
      } else {
        formattedDate = data.created_at;
      }
    } else if (data.timestamp && typeof data.timestamp.toDate === 'function') {
      const d = data.timestamp.toDate();
      rawDate = d.getTime();
      formattedDate = d.toLocaleString('en-US');
    } else if (data.date) {
      formattedDate = data.date;
    }

    const commentText = (data.comment || data.feedback_text || data.feedback || data.message || data.text || data.comments || data.note || '').trim();

    cloudItems.push({
      id: doc.id,
      name: data.name || data.user_name || data.student_name || data.faculty_name || 'Anonymous User',
      user_role: data.user_role || data.role || 'Student',
      roll_number: data.roll_number || data.rollNo || data.roll_no || data.roll || '',
      batch: data.batch || data.department || data.dept || '',
      device: data.device || data.device_info || data.deviceSpecs || data.device_specs || '',
      category: data.category || 'General Feedback',
      rating: Number(data.rating) || 5,
      comment: commentText,
      date: formattedDate,
      rawDate: rawDate || Date.now(),
      platform: data.platform || 'Android Mobile Client',
      isCloud: true
    });
  });

  cloudItems.sort((a, b) => b.rawDate - a.rawDate);
  allLiveFeedback = cloudItems;

  filterFeedbackFeed();
}

function initFirestoreFeedbackStream() {
  if (!db) return;
  if (firestoreFeedbackListener) return; // already listening

  try {
    logTerminal('Connecting live Firestore feedback stream from IRIS mobile clients...', 'info');
    fetchFirestoreFeedbackDirect();
    firestoreFeedbackListener = db.collection('feedback').onSnapshot(snapshot => {
      processFeedbackSnapshot(snapshot);
      logTerminal(`Feedback stream synchronized: <strong>${allLiveFeedback.length}</strong> authentic submissions active.`, 'info');
    }, err => {
      console.warn("Feedback snapshot listener error:", err);
      logTerminal(`Feedback stream error: ${err.message}`, 'warning');
    });
  } catch (e) {
    console.warn("Could not start feedback stream:", e);
    logTerminal(`Feedback initialization error: ${e.message}`, 'warning');
  }
}

async function renderFeedbackFeed() {
  initFirestoreFeedbackStream();
  filterFeedbackFeed();
}

window.filterFeedbackFeed = function() {
  const container = document.getElementById('feedback-feed-container');
  const countBadge = document.getElementById('feedback-count-badge');
  const searchInput = document.getElementById('feedback-search');
  const roleSelect = document.getElementById('feedback-role-filter');
  if (!container) return;

  const q = (searchInput?.value || '').toLowerCase().trim();
  const roleFilter = roleSelect?.value || 'ALL';

  // Compute live analytics
  const totalCount = allLiveFeedback.length;
  const facultyCount = allLiveFeedback.filter(f => (f.user_role || '').toLowerCase() === 'faculty').length;
  const studentCount = allLiveFeedback.filter(f => (f.user_role || '').toLowerCase() !== 'faculty').length;
  const avgRating = totalCount > 0
    ? (allLiveFeedback.reduce((sum, f) => sum + (Number(f.rating) || 5), 0) / totalCount).toFixed(1)
    : '5.0';

  const statAvgEl = document.getElementById('fb-stat-avg-rating');
  const statStarsEl = document.getElementById('fb-stat-stars');
  const statTotalEl = document.getElementById('fb-stat-total');
  const statRolesEl = document.getElementById('fb-stat-roles');

  if (statAvgEl) statAvgEl.innerText = avgRating;
  if (statStarsEl) {
    const numAvg = Math.round(Number(avgRating));
    let sHtml = '';
    for (let i = 1; i <= 5; i++) {
      sHtml += `<i class="fa-solid fa-star" style="color: ${i <= numAvg ? 'var(--accent-amber)' : 'rgba(255,255,255,0.2)'}; margin-right: 2px;"></i>`;
    }
    statStarsEl.innerHTML = sHtml;
  }
  if (statTotalEl) statTotalEl.innerText = totalCount;
  if (statRolesEl) statRolesEl.innerText = `${studentCount} Students • ${facultyCount} Faculty`;

  const filtered = allLiveFeedback.filter(item => {
    const matchRole = roleFilter === 'ALL' || (item.user_role || 'Student').toLowerCase() === roleFilter.toLowerCase();
    const textBlob = `${item.name || ''} ${item.roll_number || ''} ${item.batch || ''} ${item.category || ''} ${item.comment || ''} ${item.device || ''} ${item.platform || ''}`.toLowerCase();
    const matchQuery = !q || textBlob.includes(q);
    return matchRole && matchQuery;
  });

  if (countBadge) {
    countBadge.innerText = `${filtered.length} ${filtered.length === 1 ? 'SUBMISSION' : 'SUBMISSIONS'}`;
  }

  if (filtered.length === 0) {
    container.innerHTML = `
      <div class="glass-panel" style="text-align: center; color: var(--text-muted); padding: 48px 24px;">
        <i class="fa-solid fa-comments" style="font-size: 32px; color: var(--accent-cyan); margin-bottom: 12px; display: block; opacity: 0.8;"></i>
        <strong style="font-size: 14px; color: var(--text-title); display: block; margin-bottom: 6px;">
          ${q ? `No feedback matching "${q}"` : 'No Feedback Submissions in Cloud'}
        </strong>
        <p style="font-size: 12px; color: var(--text-muted); max-width: 360px; margin: 0 auto; line-height: 1.5;">
          ${q ? 'Try adjusting your search terms or role filters.' : 'Live user telemetry and feedback submitted from the IRIS mobile app will stream here automatically in real time.'}
        </p>
      </div>
    `;
    return;
  }

  container.innerHTML = filtered.map((f, idx) => {
    const rating = Math.max(1, Math.min(5, Number(f.rating) || 5));
    let starsHtml = '';
    for (let i = 1; i <= 5; i++) {
      starsHtml += `<i class="fa-solid fa-star" style="color: ${i <= rating ? 'var(--accent-amber)' : 'rgba(255,255,255,0.18)'}; font-size: 11px;"></i>`;
    }

    const isFaculty = (f.user_role || '').toLowerCase() === 'faculty';
    const roleBadgeColor = isFaculty ? 'var(--accent-indigo)' : 'var(--accent-cyan)';
    const roleBg = isFaculty ? 'rgba(129, 140, 248, 0.18)' : 'rgba(56, 189, 248, 0.18)';
    const initial = (f.name || 'U').trim().charAt(0).toUpperCase() || 'U';
    const isLongComment = f.comment && f.comment.length > 240;
    const hasComment = Boolean(f.comment && f.comment.trim().length > 0);

    return `
      <div class="glass-panel feedback-card" style="${f.isCloud ? 'border-color: rgba(56, 189, 248, 0.45); box-shadow: 0 8px 30px rgba(56, 189, 248, 0.15);' : ''}">
        <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; flex-wrap: wrap;">
          <div style="display: flex; align-items: center; gap: 12px;">
            <div style="width: 42px; height: 42px; border-radius: 50%; background: linear-gradient(135deg, ${roleBadgeColor}, #0284c7); display: flex; align-items: center; justify-content: center; font-weight: 800; color: white; font-size: 15px; box-shadow: 0 4px 14px rgba(0,0,0,0.3); border: 1px solid rgba(255,255,255,0.35); flex-shrink: 0;">
              ${initial}
            </div>
            <div>
              <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                <strong style="color: var(--text-title); font-size: 14.5px;">${f.name}</strong>
                ${f.isCloud ? `<span style="background: rgba(56, 189, 248, 0.25); border: 1px solid var(--accent-cyan); color: var(--accent-cyan); font-size: 9px; padding: 2px 8px; border-radius: 9999px; font-weight: 800; font-family: var(--font-mono);"><i class="fa-solid fa-cloud-arrow-down" style="margin-right: 3px;"></i> LIVE CLOUD</span>` : ''}
                <span style="font-size: 9.5px; font-weight: 800; text-transform: uppercase; background: ${roleBg}; color: ${roleBadgeColor}; padding: 3px 10px; border-radius: 9999px; font-family: var(--font-mono); border: 1px solid rgba(255,255,255,0.2);">
                  ${isFaculty ? '<i class="fa-solid fa-graduation-cap" style="margin-right: 3px;"></i>' : ''}${f.user_role || 'Student'}
                </span>
                ${f.roll_number && f.roll_number !== 'N/A' ? `<span style="font-family: var(--font-mono); font-size: 10px; color: var(--accent-cyan); background: rgba(56, 189, 248, 0.12); padding: 3px 8px; border-radius: 6px; border: 1px solid rgba(56,189,248,0.25); font-weight: 700;">${f.roll_number}</span>` : ''}
                ${f.batch && f.batch !== 'N/A' ? `<span style="font-family: var(--font-mono); font-size: 10px; color: #c084fc; background: rgba(168, 85, 247, 0.12); padding: 3px 8px; border-radius: 6px; border: 1px solid rgba(168, 85, 247, 0.2); font-weight: 700;">${f.batch}</span>` : ''}
              </div>
              <div style="display: flex; align-items: center; gap: 8px; margin-top: 3px;">
                <span style="font-size: 11px; color: var(--text-muted); font-family: var(--font-mono);">${f.date}</span>
                ${f.category ? `<span style="font-size: 10px; font-family: var(--font-mono); color: var(--accent-emerald); font-weight: 700; background: rgba(16, 185, 129, 0.1); padding: 2px 7px; border-radius: 4px;">${f.category}</span>` : ''}
              </div>
            </div>
          </div>
          
          <div style="display: flex; align-items: center; gap: 8px;">
            <div style="display: inline-flex; gap: 3px; background: rgba(251, 191, 36, 0.14); padding: 5px 12px; border-radius: 9999px; border: 1px solid rgba(251, 191, 36, 0.35);">
              ${starsHtml}
            </div>
            ${hasComment ? `
              <button type="button" class="btn-row-action" onclick="copyFeedbackComment('${f.id}')" title="Copy feedback text">
                <i class="fa-solid fa-copy"></i>
              </button>
            ` : ''}
            <button type="button" class="btn-row-action delete" onclick="deleteLiveFeedback('${f.id}')" title="Delete Feedback Record">
              <i class="fa-solid fa-trash-can"></i>
            </button>
          </div>
        </div>

        ${hasComment ? `
          <div>
            <div class="feedback-comment-box ${isLongComment ? 'feedback-comment-collapsed' : ''}" id="fb-comment-${f.id}">
              ${f.comment}
            </div>
            ${isLongComment ? `
              <button type="button" class="btn-expand-feedback" id="fb-btn-expand-${f.id}" onclick="toggleExpandFeedback('${f.id}')">
                <i class="fa-solid fa-chevron-down"></i> Read Full Feedback (${f.comment.length} chars)
              </button>
            ` : ''}
          </div>
        ` : `
          <div style="font-size: 12px; color: var(--text-muted); font-style: italic; background: rgba(255,255,255,0.02); padding: 10px 14px; border-radius: 12px; border: 1px dashed var(--border-subtle);">
            (No written comment provided with rating)
          </div>
        `}

        ${f.device && f.device !== 'N/A' ? `
          <div style="display: flex; align-items: center; justify-content: space-between; gap: 6px; font-size: 11px; font-family: var(--font-mono); color: var(--text-muted); flex-wrap: wrap;">
            <div style="display: flex; align-items: center; gap: 6px;">
              <i class="fa-solid fa-mobile-screen-button" style="color: var(--accent-cyan);"></i>
              <span>${f.device}</span>
            </div>
            ${f.platform ? `<span style="font-size: 9px; opacity: 0.6;">${f.platform}</span>` : ''}
          </div>
        ` : ''}
      </div>
    `;
  }).join('');
};

window.toggleExpandFeedback = function(id) {
  const el = document.getElementById(`fb-comment-${id}`);
  const btn = document.getElementById(`fb-btn-expand-${id}`);
  if (!el || !btn) return;
  const isCollapsed = el.classList.contains('feedback-comment-collapsed');
  if (isCollapsed) {
    el.classList.remove('feedback-comment-collapsed');
    btn.innerHTML = '<i class="fa-solid fa-chevron-up"></i> Show Less';
  } else {
    el.classList.add('feedback-comment-collapsed');
    btn.innerHTML = `<i class="fa-solid fa-chevron-down"></i> Read Full Feedback`;
  }
};

window.copyFeedbackComment = function(id) {
  const item = allLiveFeedback.find(f => f.id === id);
  if (!item || !item.comment) return;
  navigator.clipboard.writeText(item.comment).then(() => {
    showMossToast("Feedback comment copied to clipboard!", "success");
  }).catch(() => {
    showMossToast("Failed to copy to clipboard", "warning");
  });
};

window.deleteLiveFeedback = async function(docId) {
  if (!confirm("Are you sure you want to delete this feedback record?")) return;

  try {
    if (db) {
      await db.collection('feedback').doc(docId).delete();
      incrementDatabaseOps();
    }
    allLiveFeedback = allLiveFeedback.filter(f => f.id !== docId);
    filterFeedbackFeed();
    showMossToast("Feedback entry removed.", "info");
    logTerminal(`Deleted feedback record: <code>${docId}</code>`, 'info');
  } catch (err) {
    showMossToast(`Failed to delete: ${err.message}`, "error");
    logTerminal(`Failed to delete feedback: ${err.message}`, 'error');
  }
};

window.clearAllLiveFeedback = async function() {
  if (!allLiveFeedback || allLiveFeedback.length === 0) {
    showMossToast("No feedback records to clear.", "info");
    return;
  }

  if (!confirm(`WARNING: Are you sure you want to permanently DELETE ALL ${allLiveFeedback.length} community feedback submissions from Firestore? This action cannot be undone.`)) {
    return;
  }

  logTerminal(`Initiating purge of all ${allLiveFeedback.length} feedback records...`, 'warning');

  try {
    if (db) {
      const snap = await db.collection('feedback').get();
      const batch = db.batch();
      snap.forEach(doc => {
        batch.delete(doc.ref);
      });
      await batch.commit();
      incrementDatabaseOps();
    }

    allLiveFeedback = [];
    filterFeedbackFeed();
    showMossToast("All feedback records purged successfully!", "success");
    logTerminal("Live Community Feedback ledger cleared.", "success");
  } catch (err) {
    showMossToast(`Failed to clear feedback: ${err.message}`, "error");
    logTerminal(`Clear all feedback failed: ${err.message}`, "error");
  }
};

// Liquid Glass Morphing Dropdowns Engine for Portal
function initGlassDropdowns() {
  const selects = document.querySelectorAll('select:not(.glass-enhanced)');
  selects.forEach(sel => {
    sel.classList.add('glass-enhanced');
    sel.style.display = 'none';

    const wrapper = document.createElement('div');
    wrapper.className = 'glass-dropdown-wrapper';

    const trigger = document.createElement('div');
    trigger.className = 'glass-dropdown-trigger';
    
    function updateTriggerText() {
      const selectedOpt = sel.options[sel.selectedIndex];
      const text = selectedOpt ? selectedOpt.text : 'Select Option';
      trigger.innerHTML = `<span>${text}</span> <i class="fa-solid fa-chevron-down" style="font-size: 10px; opacity: 0.7; transition: transform 0.25s ease;"></i>`;
    }
    updateTriggerText();

    const menu = document.createElement('div');
    menu.className = 'glass-dropdown-menu';

    function buildOptions() {
      menu.innerHTML = '';
      Array.from(sel.options).forEach((opt, idx) => {
        const item = document.createElement('div');
        item.className = `glass-dropdown-item ${idx === sel.selectedIndex ? 'selected' : ''}`;
        item.innerHTML = `<span>${opt.text}</span> ${idx === sel.selectedIndex ? '<i class="fa-solid fa-check" style="font-size: 10px; color: var(--accent-cyan);"></i>' : ''}`;
        item.addEventListener('click', (e) => {
          e.stopPropagation();
          sel.selectedIndex = idx;
          sel.dispatchEvent(new Event('change', { bubbles: true }));
          sel.dispatchEvent(new Event('input', { bubbles: true }));
          updateTriggerText();
          closeMenu();
        });
        menu.appendChild(item);
      });
    }

    function openMenu() {
      buildOptions();
      trigger.classList.add('open');
      menu.classList.add('open');
      const chevron = trigger.querySelector('.fa-chevron-down');
      if (chevron) chevron.style.transform = 'rotate(180deg)';
    }

    function closeMenu() {
      trigger.classList.remove('open');
      menu.classList.remove('open');
      const chevron = trigger.querySelector('.fa-chevron-down');
      if (chevron) chevron.style.transform = 'rotate(0deg)';
    }

    trigger.addEventListener('click', (e) => {
      e.stopPropagation();
      document.querySelectorAll('.glass-dropdown-menu.open').forEach(m => {
        if (m !== menu) m.classList.remove('open');
      });
      document.querySelectorAll('.glass-dropdown-trigger.open').forEach(t => {
        if (t !== trigger) t.classList.remove('open');
      });

      if (menu.classList.contains('open')) {
        closeMenu();
      } else {
        openMenu();
      }
    });

    document.addEventListener('click', (e) => {
      if (!wrapper.contains(e.target)) {
        closeMenu();
      }
    });

    sel.addEventListener('change', updateTriggerText);

    wrapper.appendChild(trigger);
    wrapper.appendChild(menu);
    sel.parentNode.insertBefore(wrapper, sel.nextSibling);
  });
}

// ==========================================================================
// SEMESTER SCHEDULE & MILESTONES MANAGER
// ==========================================================================

let stagedMilestones = [];

function getDefaultTargetSemester() {
  const d = new Date();
  const m = d.getMonth() + 1;
  const y = d.getFullYear();
  return m >= 8 ? `Spring ${y + 1}` : `Fall ${y}`;
}

function updateVacationCountdownDisplay() {
  const resumptionInput = document.getElementById('input-semester-resumption-date');
  const textElem = document.getElementById('vacation-countdown-text');
  if (!resumptionInput || !textElem) return;

  const dateVal = resumptionInput.value;
  if (!dateVal) {
    textElem.innerText = 'NO DATE SET';
    return;
  }

  const targetDate = new Date(dateVal);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  targetDate.setHours(0, 0, 0, 0);

  const diffTime = targetDate.getTime() - today.getTime();
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

  if (diffDays > 1) {
    textElem.innerText = `${diffDays} DAYS REMAINING`;
  } else if (diffDays === 1) {
    textElem.innerText = `1 DAY REMAINING`;
  } else if (diffDays === 0) {
    textElem.innerText = 'RESUMES TODAY!';
  } else {
    textElem.innerText = `${Math.abs(diffDays)} DAYS AGO`;
  }
}

function evaluateMilestoneStatusJs(dateStr, explicitStatus) {
  if (explicitStatus === 'expired' || explicitStatus === 'completed') return 'expired';
  if (!dateStr) return explicitStatus || 'upcoming';

  const clean = dateStr.replace(/–/g, '-').replace(/—/g, '-').trim();
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  const monthMap = {
    jan: 0, feb: 1, mar: 2, apr: 3, may: 4, jun: 5,
    jul: 6, aug: 7, sep: 8, oct: 9, nov: 10, dec: 11
  };

  let startDate = null;
  let endDate = null;

  // 1. ISO date range
  const isoRange = clean.match(/(\d{4})-(\d{1,2})-(\d{1,2})\s*(?:to|-)\s*(\d{4})-(\d{1,2})-(\d{1,2})/);
  if (isoRange) {
    startDate = new Date(parseInt(isoRange[1]), parseInt(isoRange[2]) - 1, parseInt(isoRange[3]));
    endDate = new Date(parseInt(isoRange[4]), parseInt(isoRange[5]) - 1, parseInt(isoRange[6]), 23, 59, 59);
  } else {
    // 2. Single ISO date
    const isoSingle = clean.match(/(\d{4})-(\d{1,2})-(\d{1,2})/);
    if (isoSingle) {
      startDate = new Date(parseInt(isoSingle[1]), parseInt(isoSingle[2]) - 1, parseInt(isoSingle[3]));
      endDate = new Date(parseInt(isoSingle[1]), parseInt(isoSingle[2]) - 1, parseInt(isoSingle[3]), 23, 59, 59);
    } else {
      // 3. Multi-month range: Aug 31 - Sep 4, 2026
      const multiMonth = clean.match(/([A-Za-z]{3,9})\s+(\d{1,2})\s*-\s*([A-Za-z]{3,9})\s+(\d{1,2})(?:[,\s]+(\d{4}))?/);
      if (multiMonth) {
        const m1 = monthMap[multiMonth[1].substring(0, 3).toLowerCase()];
        const d1 = parseInt(multiMonth[2]);
        const m2 = monthMap[multiMonth[3].substring(0, 3).toLowerCase()];
        const d2 = parseInt(multiMonth[4]);
        const year = multiMonth[5] ? parseInt(multiMonth[5]) : now.getFullYear();
        if (m1 !== undefined && m2 !== undefined) {
          const y2 = m2 < m1 ? year + 1 : year;
          startDate = new Date(year, m1, d1);
          endDate = new Date(y2, m2, d2, 23, 59, 59);
        }
      } else {
        // 4. Same month range: Nov 9-14, 2026
        const sameMonth = clean.match(/([A-Za-z]{3,9})\s+(\d{1,2})\s*-\s*(\d{1,2})(?:[,\s]+(\d{4}))?/);
        if (sameMonth) {
          const m = monthMap[sameMonth[1].substring(0, 3).toLowerCase()];
          const d1 = parseInt(sameMonth[2]);
          const d2 = parseInt(sameMonth[3]);
          const year = sameMonth[4] ? parseInt(sameMonth[4]) : now.getFullYear();
          if (m !== undefined) {
            startDate = new Date(year, m, d1);
            endDate = new Date(year, m, d2, 23, 59, 59);
          }
        } else {
          // 5. Single month date: Sep 7, 2026
          const singleMonth = clean.match(/([A-Za-z]{3,9})\s+(\d{1,2})(?:[,\s]+(\d{4}))?/);
          if (singleMonth) {
            const m = monthMap[singleMonth[1].substring(0, 3).toLowerCase()];
            const d = parseInt(singleMonth[2]);
            const year = singleMonth[3] ? parseInt(singleMonth[3]) : now.getFullYear();
            if (m !== undefined) {
              startDate = new Date(year, m, d);
              endDate = new Date(year, m, d, 23, 59, 59);
            }
          }
        }
      }
    }
  }

  if (!startDate || !endDate) return explicitStatus || 'upcoming';

  if (now > endDate) return 'expired';
  if (today >= startDate && today <= endDate) return 'active';
  return 'upcoming';
}

function renderMilestonesTable() {
  const tbody = document.getElementById('milestones-table-body');
  const countElem = document.getElementById('milestone-count');
  const summaryElem = document.getElementById('milestones-status-summary');
  if (!tbody) return;

  tbody.innerHTML = '';
  if (countElem) countElem.innerText = stagedMilestones.length;

  if (stagedMilestones.length === 0) {
    tbody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 32px;">No milestones staged. Click "Fetch Live Cloud", "Load Template", or add milestones above.</td></tr>`;
    if (summaryElem) summaryElem.innerText = '';
    return;
  }

  let activeCount = 0;
  let upcomingCount = 0;
  let expiredCount = 0;

  stagedMilestones.forEach((m, idx) => {
    // Dynamic real-time auto calculation
    const dynStatus = evaluateMilestoneStatusJs(m.date || m.timeline || '', m.status);
    const effectiveStatus = m.statusManuallyOverridden ? m.status : dynStatus;
    m.isDone = (effectiveStatus === 'expired');

    if (effectiveStatus === 'active') activeCount++;
    else if (effectiveStatus === 'expired') expiredCount++;
    else upcomingCount++;

    const tr = document.createElement('tr');

    const statusBadges = {
      active: `<span class="milestone-status-pill status-active" style="background: rgba(6, 182, 212, 0.18); color: #22d3ee; border: 1px solid rgba(6, 182, 212, 0.4); padding: 4px 10px; border-radius: 9999px; font-size: 10px; font-weight: 700; cursor: pointer; box-shadow: 0 0 10px rgba(6,182,212,0.25);"><i class="fa-solid fa-circle-dot" style="font-size: 8px; margin-right: 4px;"></i> ACTIVE NOW</span>`,
      upcoming: `<span class="milestone-status-pill status-upcoming" style="background: rgba(59, 130, 246, 0.15); color: #60a5fa; border: 1px solid rgba(59, 130, 246, 0.3); padding: 4px 10px; border-radius: 9999px; font-size: 10px; font-weight: 700; cursor: pointer;"><i class="fa-solid fa-clock" style="font-size: 8px; margin-right: 4px;"></i> UPCOMING</span>`,
      expired: `<span class="milestone-status-pill status-expired" style="background: rgba(16, 185, 129, 0.15); color: #34d399; border: 1px solid rgba(16, 185, 129, 0.3); padding: 4px 10px; border-radius: 9999px; font-size: 10px; font-weight: 700; cursor: pointer;"><i class="fa-solid fa-check" style="font-size: 8px; margin-right: 4px;"></i> COMPLETED</span>`
    };

    const categoryIcons = {
      Classes: 'fa-book-open',
      Exams: 'fa-pen-clip',
      Registration: 'fa-id-card',
      Events: 'fa-trophy',
      Holidays: 'fa-umbrella-beach'
    };

    const catIcon = categoryIcons[m.category] || 'fa-calendar-check';

    const levelBadge = m.level ? `<span style="font-size: 9.5px; font-weight: 700; color: var(--accent-cyan); background: rgba(6,182,212,0.12); padding: 2px 7px; border-radius: 4px; border: 1px solid rgba(6,182,212,0.25); display: inline-block; margin-bottom: 3px;">${escapeHtml(m.level)}</span><br>` : '';

    tr.innerHTML = `
      <td style="text-align: center; font-family: var(--font-mono); font-size: 11px; color: var(--text-muted);">${idx + 1}</td>
      <td style="font-size: 12px;">
        ${levelBadge}
        <strong style="color: ${effectiveStatus === 'expired' ? 'var(--text-muted)' : 'var(--text-title)'}; font-size: 12.5px; ${effectiveStatus === 'expired' ? 'text-decoration: line-through;' : ''}">${escapeHtml(m.title || '')}</strong>
      </td>
      <td style="font-family: var(--font-mono); color: ${effectiveStatus === 'expired' ? 'var(--text-muted)' : (effectiveStatus === 'active' ? 'var(--accent-cyan)' : '#fb7185')}; font-size: 11.5px; font-weight: 600;">${escapeHtml(m.date || m.timeline || '')}</td>
      <td>
        <span style="display: inline-flex; align-items: center; gap: 5px; font-size: 11px; font-weight: 600; color: var(--text-title); background: var(--bg-surface); padding: 3px 8px; border-radius: 6px; border: 1px solid var(--border-subtle);">
          <i class="fa-solid ${catIcon}" style="color: var(--accent-indigo); font-size: 10px;"></i> ${escapeHtml(m.category || 'General')}
        </span>
      </td>
      <td>${statusBadges[effectiveStatus] || statusBadges.upcoming}</td>
      <td style="text-align: right;">
        <div style="display: inline-flex; gap: 4px;">
          <button type="button" class="btn-icon btn-move-up" data-idx="${idx}" title="Move Up" ${idx === 0 ? 'disabled style="opacity:0.3;"' : ''} style="width: 28px; height: 28px; font-size: 10px;">
            <i class="fa-solid fa-arrow-up"></i>
          </button>
          <button type="button" class="btn-icon btn-move-down" data-idx="${idx}" title="Move Down" ${idx === stagedMilestones.length - 1 ? 'disabled style="opacity:0.3;"' : ''} style="width: 28px; height: 28px; font-size: 10px;">
            <i class="fa-solid fa-arrow-down"></i>
          </button>
          <button type="button" class="btn-icon btn-delete-milestone" data-idx="${idx}" title="Delete Milestone" style="width: 28px; height: 28px; font-size: 10px; color: var(--accent-rose);">
            <i class="fa-solid fa-trash-can"></i>
          </button>
        </div>
      </td>
    `;

    // Status toggle on click
    const statusPill = tr.querySelector('.milestone-status-pill');
    if (statusPill) {
      statusPill.addEventListener('click', () => {
        const nextStatus = m.status === 'upcoming' ? 'active' : (m.status === 'active' ? 'expired' : 'upcoming');
        m.statusManuallyOverridden = true;
        m.status = nextStatus;
        m.isDone = (nextStatus === 'expired');
        renderMilestonesTable();
      });
    }

    // Row Actions
    const btnUp = tr.querySelector('.btn-move-up');
    if (btnUp && idx > 0) {
      btnUp.addEventListener('click', () => {
        const temp = stagedMilestones[idx];
        stagedMilestones[idx] = stagedMilestones[idx - 1];
        stagedMilestones[idx - 1] = temp;
        renderMilestonesTable();
      });
    }

    const btnDown = tr.querySelector('.btn-move-down');
    if (btnDown && idx < stagedMilestones.length - 1) {
      btnDown.addEventListener('click', () => {
        const temp = stagedMilestones[idx];
        stagedMilestones[idx] = stagedMilestones[idx + 1];
        stagedMilestones[idx + 1] = temp;
        renderMilestonesTable();
      });
    }

    const btnDel = tr.querySelector('.btn-delete-milestone');
    if (btnDel) {
      btnDel.addEventListener('click', () => {
        stagedMilestones.splice(idx, 1);
        renderMilestonesTable();
        showMossToast('Milestone removed from staged timeline', 'info');
      });
    }

    tbody.appendChild(tr);
  });

  if (summaryElem) {
    summaryElem.innerText = `• ${activeCount} Active • ${upcomingCount} Upcoming • ${expiredCount} Completed`;
  }
}

function loadFall2026OfficialCalendar() {
  const targetSemInput = document.getElementById('input-semester-target');
  const resumptionInput = document.getElementById('input-semester-resumption-date');
  if (targetSemInput) targetSemInput.value = 'Fall 2026';
  if (resumptionInput) resumptionInput.value = '2026-09-07';

  stagedMilestones = [
    { level: 'Undergraduate & Graduate', title: 'Registration Week', date: 'Aug 31 – Sep 4, 2026 (Mon–Fri)', category: 'Registration', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Commencement of Classes', date: 'Sep 7, 2026 (Mon)', category: 'Classes', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Last Date for Drop of Courses', date: 'Oct 2, 2026 (Fri)', category: 'Classes', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Last Date for Withdrawal', date: 'Oct 23, 2026 (Fri)', category: 'Classes', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Mid-Term Examination Start Date', date: 'Nov 2, 2026 (Mon)', category: 'Exams', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Student Week', date: 'Nov 9–14, 2026 (Mon–Sat)', category: 'Events', status: 'upcoming', isDone: false },
    { level: 'Undergraduate', title: 'Final Year Project Submission', date: 'Dec 28, 2026 (Mon)', category: 'Classes', status: 'upcoming', isDone: false },
    { level: 'Graduate', title: 'MS Thesis Submission', date: 'Dec 28, 2026 (Mon)', category: 'Classes', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Last Day for Classes', date: 'Dec 28, 2026 (Mon)', category: 'Classes', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Terminal Exam Start Date', date: 'Dec 31, 2026 (Thu)', category: 'Exams', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Declaration of Results', date: 'Jan 28, 2027 (Thu)', category: 'Registration', status: 'upcoming', isDone: false },
    { level: 'Graduate', title: 'PhD Thesis Submission', date: 'One week before Spring 2027', category: 'Registration', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Final Result Notification', date: 'Feb 15, 2027 (Mon)', category: 'Registration', status: 'upcoming', isDone: false }
  ];

  renderMilestonesTable();
  updateVacationCountdownDisplay();
  showMossToast('Loaded Official COMSATS Fall 2026 Academic Calendar (13 events)!', 'success');
  logTerminal('Loaded Official COMSATS <strong>Fall 2026 Calendar</strong> (Classes start: Sep 7, 2026).', 'info');
}

function loadSpring2027OfficialCalendar() {
  const targetSemInput = document.getElementById('input-semester-target');
  const resumptionInput = document.getElementById('input-semester-resumption-date');
  if (targetSemInput) targetSemInput.value = 'Spring 2027';
  if (resumptionInput) resumptionInput.value = '2027-02-08';

  stagedMilestones = [
    { level: 'Undergraduate & Graduate', title: 'Registration Week', date: 'Feb 1–5, 2027 (Mon–Fri)', category: 'Registration', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Commencement of Classes', date: 'Feb 8, 2027 (Mon)', category: 'Classes', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Last Date for Drop of Courses', date: 'Mar 5, 2027 (Fri)', category: 'Classes', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Last Date for Withdrawal', date: 'Mar 26, 2027 (Fri)', category: 'Classes', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Mid-Term Examination Start Date', date: 'Apr 5, 2027 (Mon)', category: 'Exams', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Student Week', date: 'Apr 12–17, 2027 (Mon–Sat)', category: 'Events', status: 'upcoming', isDone: false },
    { level: 'Undergraduate', title: 'Final Year Project Submission', date: 'May 28, 2027 (Fri)', category: 'Classes', status: 'upcoming', isDone: false },
    { level: 'Graduate', title: 'MS Thesis Submission', date: 'May 28, 2027 (Fri)', category: 'Classes', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Last Day for Classes', date: 'May 28, 2027 (Fri)', category: 'Classes', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Terminal Exam Start Date', date: 'May 31, 2027 (Mon)', category: 'Exams', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Declaration of Results', date: 'Jun 25, 2027 (Fri)', category: 'Registration', status: 'upcoming', isDone: false },
    { level: 'Graduate', title: 'PhD Thesis Submission', date: 'One week before Fall 2027', category: 'Registration', status: 'upcoming', isDone: false },
    { level: 'Undergraduate & Graduate', title: 'Final Result Notification', date: 'Jul 16, 2027 (Fri)', category: 'Registration', status: 'upcoming', isDone: false }
  ];

  renderMilestonesTable();
  updateVacationCountdownDisplay();
  showMossToast('Loaded Official COMSATS Spring 2027 Academic Calendar (13 events)!', 'success');
  logTerminal('Loaded Official COMSATS <strong>Spring 2027 Calendar</strong> (Classes start: Feb 8, 2027).', 'info');
}

function loadSummer2027OfficialCalendar() {
  const targetSemInput = document.getElementById('input-semester-target');
  const resumptionInput = document.getElementById('input-semester-resumption-date');
  if (targetSemInput) targetSemInput.value = 'Summer 2027';
  if (resumptionInput) resumptionInput.value = '2027-07-06';

  stagedMilestones = [
    { level: 'Undergraduate', title: 'Registration Week', date: 'Jul 1–5, 2027 (Thu–Mon)', category: 'Registration', status: 'upcoming', isDone: false },
    { level: 'Undergraduate', title: 'Commencement of Classes', date: 'Jul 6, 2027 (Tue)', category: 'Classes', status: 'upcoming', isDone: false },
    { level: 'Undergraduate', title: 'Last Date for Drop of Courses', date: 'Jul 16, 2027 (Fri)', category: 'Classes', status: 'upcoming', isDone: false },
    { level: 'Undergraduate', title: 'Last Date for Withdrawal', date: 'Jul 30, 2027 (Fri)', category: 'Classes', status: 'upcoming', isDone: false },
    { level: 'Undergraduate', title: 'Midterm Examination', date: 'Aug 2, 2027 (Mon)', category: 'Exams', status: 'upcoming', isDone: false },
    { level: 'Undergraduate', title: 'Last Day for Classes', date: 'Aug 20, 2027 (Fri)', category: 'Classes', status: 'upcoming', isDone: false },
    { level: 'Undergraduate', title: 'Terminal Exam Start Date', date: 'Aug 21, 2027 (Sat)', category: 'Exams', status: 'upcoming', isDone: false },
    { level: 'Undergraduate', title: 'Declaration of Results', date: 'Aug 27, 2027 (Fri)', category: 'Registration', status: 'upcoming', isDone: false },
    { level: 'Undergraduate', title: 'Final Result Notification', date: 'Sep 3, 2027 (Fri)', category: 'Registration', status: 'upcoming', isDone: false }
  ];

  renderMilestonesTable();
  updateVacationCountdownDisplay();
  showMossToast('Loaded Official COMSATS Summer 2027 Academic Calendar (9 events)!', 'success');
  logTerminal('Loaded Official COMSATS <strong>Summer 2027 Calendar</strong> (Classes start: Jul 6, 2027).', 'info');
}

function setupSemesterScheduleHandlers() {
  const targetSemInput = document.getElementById('input-semester-target');
  const resumptionInput = document.getElementById('input-semester-resumption-date');
  if (resumptionInput) {
    resumptionInput.addEventListener('input', updateVacationCountdownDisplay);
    resumptionInput.addEventListener('change', updateVacationCountdownDisplay);
    updateVacationCountdownDisplay();
  }

  // Date Mode Toggle (Single / Range)
  const singleRadio = document.querySelector('input[name="milestone-date-mode"][value="single"]');
  const rangeRadio = document.querySelector('input[name="milestone-date-mode"][value="range"]');
  const singleContainer = document.getElementById('date-single-container');
  const rangeContainer = document.getElementById('date-range-container');

  if (singleRadio && rangeRadio && singleContainer && rangeContainer) {
    singleRadio.addEventListener('change', () => {
      singleContainer.style.display = 'flex';
      rangeContainer.style.display = 'none';
    });
    rangeRadio.addEventListener('change', () => {
      singleContainer.style.display = 'none';
      rangeContainer.style.display = 'flex';
    });
  }

  // Date Picker sync
  const datePicker = document.getElementById('input-milestone-date-picker');
  const dateTextInput = document.getElementById('input-milestone-date');
  if (datePicker && dateTextInput) {
    datePicker.addEventListener('change', () => {
      dateTextInput.value = datePicker.value;
    });
  }

  // 1-Click Preset Chips
  const presetChips = document.querySelectorAll('.milestone-preset-chip');
  const titleInput = document.getElementById('input-milestone-title');
  const levelSelect = document.getElementById('select-milestone-level');
  const catSelect = document.getElementById('select-milestone-category');
  const statusSelect = document.getElementById('select-milestone-status');

  presetChips.forEach(chip => {
    chip.addEventListener('click', () => {
      if (titleInput) titleInput.value = chip.dataset.title || '';
      if (levelSelect && chip.dataset.level) levelSelect.value = chip.dataset.level;
      if (catSelect && chip.dataset.cat) catSelect.value = chip.dataset.cat;
      if (statusSelect && chip.dataset.status) statusSelect.value = chip.dataset.status;
      showMossToast(`Selected preset: ${chip.dataset.title}`, 'info');
    });
  });

  // Add Milestone
  const btnAdd = document.getElementById('btn-add-milestone');
  if (btnAdd) {
    btnAdd.addEventListener('click', () => {
      const title = (titleInput ? titleInput.value : '').trim();
      if (!title) {
        showMossToast('Please enter a milestone event title', 'error');
        return;
      }

      let dateStr = '';
      const isRange = rangeRadio && rangeRadio.checked;
      if (isRange) {
        const start = (document.getElementById('input-milestone-start-date')?.value || '').trim();
        const end = (document.getElementById('input-milestone-end-date')?.value || '').trim();
        if (!start || !end) {
          showMossToast('Please specify both start and end dates', 'error');
          return;
        }
        dateStr = `${start} to ${end}`;
      } else {
        dateStr = (dateTextInput ? dateTextInput.value : '').trim();
        if (!dateStr) {
          showMossToast('Please enter or select a date', 'error');
          return;
        }
      }

      const level = levelSelect ? levelSelect.value : 'Undergraduate & Graduate';
      const cat = catSelect ? catSelect.value : 'Classes';
      const status = statusSelect ? statusSelect.value : 'upcoming';

      stagedMilestones.push({
        level: level,
        title: title,
        date: dateStr,
        category: cat,
        status: status,
        isDone: (status === 'expired')
      });

      renderMilestonesTable();
      showMossToast(`Added "${title}" to schedule!`, 'success');
      logTerminal(`Staged milestone: <strong>${title}</strong> (${dateStr})`, 'info');

      // Clear title input for next entry
      if (titleInput) titleInput.value = '';
    });
  }

  // Official Calendar Preset Buttons
  const btnFall2026 = document.getElementById('btn-calendar-fall2026');
  if (btnFall2026) btnFall2026.addEventListener('click', loadFall2026OfficialCalendar);

  const btnSpring2027 = document.getElementById('btn-calendar-spring2027');
  if (btnSpring2027) btnSpring2027.addEventListener('click', loadSpring2027OfficialCalendar);

  const btnSummer2027 = document.getElementById('btn-calendar-summer2027');
  if (btnSummer2027) btnSummer2027.addEventListener('click', loadSummer2027OfficialCalendar);

  // Clear Milestones Button
  const btnClear = document.getElementById('btn-clear-milestones');
  if (btnClear) {
    btnClear.addEventListener('click', () => {
      if (confirm('Clear all staged milestones?')) {
        stagedMilestones = [];
        renderMilestonesTable();
        showMossToast('Cleared all staged milestones', 'info');
      }
    });
  }

  // Auto-Sort Chronological Button
  const btnSort = document.getElementById('btn-sort-chronological');
  if (btnSort) {
    btnSort.addEventListener('click', () => {
      stagedMilestones.sort((a, b) => (a.date || '').localeCompare(b.date || ''));
      renderMilestonesTable();
      showMossToast('Milestones sorted chronologically!', 'info');
    });
  }

  // Backup JSON Export Button
  const btnExport = document.getElementById('btn-export-milestones');
  if (btnExport) {
    btnExport.addEventListener('click', () => {
      const payload = {
        target_semester: (targetSemInput && targetSemInput.value ? targetSemInput.value : getDefaultTargetSemester()).trim(),
        resumption_date: resumptionInput ? resumptionInput.value : '',
        milestones: stagedMilestones,
        exported_at: new Date().toISOString()
      };
      const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `semester_schedule_${(payload.target_semester || 'export').replace(/\s+/g, '_').toLowerCase()}.json`;
      a.click();
      URL.revokeObjectURL(url);
      showMossToast('Exported schedule backup JSON!', 'success');
    });
  }

  // Fetch Live Cloud Milestones Button
  const btnFetchCloud = document.getElementById('btn-fetch-cloud-milestones');
  if (btnFetchCloud) {
    btnFetchCloud.addEventListener('click', async () => {
      if (!isConnected) {
        showMossToast('Database connection is offline', 'error');
        return;
      }
      try {
        logTerminal('Fetching live semester schedule from Firestore...', 'info');
        const doc = await db.collection('config').doc('global').get();
        if (!doc.exists) {
          showMossToast('Global config document not found in Firestore', 'warning');
          return;
        }
        const data = doc.data() || {};
        const vacSchedule = data.vacation_schedule;
        if (vacSchedule && typeof vacSchedule === 'object') {
          if (targetSemInput && vacSchedule.target_semester) {
            targetSemInput.value = vacSchedule.target_semester;
          }
          if (resumptionInput && vacSchedule.resumption_date) {
            resumptionInput.value = vacSchedule.resumption_date;
            updateVacationCountdownDisplay();
          }
          if (Array.isArray(vacSchedule.milestones)) {
            stagedMilestones = vacSchedule.milestones;
            renderMilestonesTable();
            showMossToast(`Loaded ${stagedMilestones.length} live milestones from cloud!`, 'success');
            logTerminal(`Live Schedule synced: <strong>${stagedMilestones.length} milestones</strong> for ${vacSchedule.target_semester || 'target semester'}.`, 'success');
            return;
          }
        }
        if (Array.isArray(data.semester_milestones)) {
          stagedMilestones = data.semester_milestones;
          if (targetSemInput && data.target_semester) targetSemInput.value = data.target_semester;
          if (resumptionInput && data.resumption_date) resumptionInput.value = data.resumption_date;
          renderMilestonesTable();
          showMossToast(`Loaded ${stagedMilestones.length} milestones from cloud!`, 'success');
          return;
        }
        showMossToast('No active semester schedule in cloud. Loading template...', 'info');
        loadTemplateMilestones();
      } catch (e) {
        logTerminal(`Failed to fetch live schedule: ${e.message}`, 'error');
        showMossToast(e.message, 'error');
      }
    });
  }

  // Deploy Button
  const btnDeploy = document.getElementById('btn-deploy-semester');
  if (btnDeploy) {
    btnDeploy.addEventListener('click', async () => {
      if (!isConnected) {
        showMossToast('Database connection is offline', 'error');
        return;
      }

      const targetSem = ((targetSemInput ? targetSemInput.value : '') || getDefaultTargetSemester()).trim();
      const resumptionDate = (resumptionInput ? resumptionInput.value : '').trim();

      if (stagedMilestones.length === 0) {
        if (!confirm('No milestones are currently staged. Deploy target semester and empty milestone schedule?')) {
          return;
        }
      }

      btnDeploy.disabled = true;
      btnDeploy.innerHTML = '<i class="fa-solid fa-spinner fa-spin" style="margin-right: 8px;"></i> DEPLOYING SCHEDULE TO CLOUD...';

      try {
        logTerminal(`Deploying semester schedule for <strong>${targetSem}</strong> (${stagedMilestones.length} milestones)...`, 'info');

        const schedulePayload = {
          target_semester: targetSem,
          resumption_date: resumptionDate,
          milestones: stagedMilestones
        };

        await db.collection('config').doc('global').update({
          vacation_schedule: schedulePayload,
          semester_milestones: stagedMilestones,
          target_semester: targetSem,
          resumption_date: resumptionDate,
          updated_at: firebase.firestore.FieldValue.serverTimestamp()
        });

        incrementDatabaseOps();
        logTerminal(`Cloud Deployment Succeeded: <strong>${targetSem}</strong> schedule active in Firestore.`, 'success');
        showMossToast(`Semester Schedule for ${targetSem} successfully deployed!`, 'success');
      } catch (e) {
        logTerminal(`Deployment failed: ${e.message}`, 'error');
        showMossToast(e.message, 'error');
      } finally {
        btnDeploy.disabled = false;
        btnDeploy.innerHTML = '<i class="fa-solid fa-cloud-arrow-up" style="margin-right: 8px;"></i> <span>DEPLOY SEMESTER SCHEDULE TO IRIS (FIRESTORE)</span>';
      }
    });
  }

  // Initial load: Load template if empty
  if (stagedMilestones.length === 0) {
    loadTemplateMilestones();
  }
}

// ==========================================================================
// EXAM SCHEDULES & DATE SHEET MANAGER
// ==========================================================================

let stagedExams = [];
activeInspectorExamPeriod = 'midterms';
let liveLoadedExams = [];

function renderExamsPreview(exams) {
  const tbody = document.getElementById('exams-preview-body');
  const statTotal = document.getElementById('exams-stat-total');
  const statBatches = document.getElementById('exams-stat-batches');
  const statSubjects = document.getElementById('exams-stat-subjects');
  const deployMidtermsBtn = document.getElementById('btn-deploy-midterms');
  const deployFinalsBtn = document.getElementById('btn-deploy-finals');

  if (!tbody) return;
  tbody.innerHTML = '';

  if (!exams || exams.length === 0) {
    if (statTotal) statTotal.innerText = '0';
    if (statBatches) statBatches.innerText = '0';
    if (statSubjects) statSubjects.innerText = '0';
    if (deployMidtermsBtn) deployMidtermsBtn.disabled = true;
    if (deployFinalsBtn) deployFinalsBtn.disabled = true;
    return;
  }

  const uniqueBatches = new Set();
  const uniqueSubjects = new Set();

  exams.forEach(e => {
    if (e.batch) uniqueBatches.add(e.batch);
    if (e.subject) uniqueSubjects.add(e.subject);

    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td style="font-family: var(--font-mono); color: var(--accent-cyan); font-size: 11.5px; font-weight: 600;">${escapeHtml(e.date || 'TBD')}</td>
      <td style="font-family: var(--font-mono); font-size: 11px; color: var(--text-title);">${escapeHtml(e.time || '09:00 AM - 12:00 PM')}</td>
      <td><span style="background: rgba(16, 185, 129, 0.12); color: #34d399; font-weight: 600; padding: 2px 6px; border-radius: 4px; font-family: var(--font-mono); font-size: 11px;">${escapeHtml(e.room || 'Exam Hall')}</span></td>
      <td style="font-weight: 700; color: var(--accent-indigo);">${escapeHtml(e.batch || 'ALL')}</td>
      <td style="font-weight: 600; color: var(--text-title);">${escapeHtml(e.subject || 'EXAM')}</td>
    `;
    tbody.appendChild(tr);
  });

  if (statTotal) statTotal.innerText = exams.length;
  if (statBatches) statBatches.innerText = uniqueBatches.size;
  if (statSubjects) statSubjects.innerText = uniqueSubjects.size;

  const analyticsElem = document.getElementById('exams-analytics');
  if (analyticsElem) analyticsElem.style.display = 'block';

  if (deployMidtermsBtn) deployMidtermsBtn.disabled = false;
  if (deployFinalsBtn) deployFinalsBtn.disabled = false;
}

async function handleExamFileSelect(file) {
  if (!file) return;

  const fileInfo = document.getElementById('exams-file-info');
  if (fileInfo) {
    fileInfo.innerText = `Selected Date Sheet: ${file.name} (${(file.size / 1024).toFixed(1)} KB)`;
    fileInfo.style.display = 'block';
  }

  logTerminal(`Processing Date Sheet: <strong>${file.name}</strong>...`, 'info');

  if (file.name.endsWith('.json')) {
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const parsed = JSON.parse(e.target.result);
        if (Array.isArray(parsed)) {
          stagedExams = parsed;
        } else if (parsed.exams && Array.isArray(parsed.exams)) {
          stagedExams = parsed.exams;
        } else {
          showMossToast('Invalid JSON structure. Expected array of exam records.', 'error');
          return;
        }
        renderExamsPreview(stagedExams);
        showMossToast(`Loaded ${stagedExams.length} exams from ${file.name}!`, 'success');
        logTerminal(`Parsed <strong>${stagedExams.length} exams</strong> from JSON.`, 'success');
      } catch (err) {
        showMossToast(`JSON parse error: ${err.message}`, 'error');
        logTerminal(`Failed to parse JSON: ${err.message}`, 'error');
      }
    };
    reader.readAsText(file);
  } else if (file.name.endsWith('.pdf')) {
    try {
      const arrayBuffer = await file.arrayBuffer();
      const pdf = await pdfjsLib.getDocument({ data: arrayBuffer }).promise;
      const extractedExams = [];

      for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
        const page = await pdf.getPage(pageNum);
        const textContent = await page.getTextContent();
        const items = textContent.items.map(i => i.str).filter(s => s.trim().length > 0);
        const fullText = items.join(" ");

        // Regex heuristics for standard COMSATS date sheet tables
        // Patterns: Date, Time, Room, Batch, Course
        const lines = fullText.split(/\n|(?=(?:\d{1,2}[-/.]\d{1,2}[-/.]\d{4}|\d{4}[-/.]\d{1,2}[-/.]\d{1,2}))/i);
        lines.forEach(line => {
          const trimmed = line.trim();
          if (trimmed.length < 10) return;
          const dateMatch = trimmed.match(/(\d{1,2}[-/.]\d{1,2}[-/.]\d{4}|\d{4}[-/.]\d{1,2}[-/.]\d{1,2})/);
          const timeMatch = trimmed.match(/(\d{1,2}:\d{2}\s*(?:AM|PM)?\s*-\s*\d{1,2}:\d{2}\s*(?:AM|PM)?)/i);
          const batchMatch = trimmed.match(/\b((?:(?:FA|SP)\d{2}-[A-Za-z]+(?:-\d+)?[A-Za-z0-9]*|[A-Za-z]{2,4}-\d+[A-Za-z0-9]*)(?:\s*[,&/]\s*(?:(?:FA|SP)\d{2}-[A-Za-z]+(?:-\d+)?[A-Za-z0-9]*|[A-Za-z]{2,4}-\d+[A-Za-z0-9]*|\d+[A-Za-z0-9]*|[A-Za-z]))*)\b/i);

          if (dateMatch && batchMatch) {
            const date = dateMatch[0];
            const time = timeMatch ? timeMatch[0] : '09:00 AM - 12:00 PM';
            const batch = batchMatch[0].toUpperCase();
            let subject = trimmed
              .replace(date, '')
              .replace(time, '')
              .replace(batchMatch[0], '')
              .replace(/\b(Room|Lab|Hall|LH)\s*[-_0-9A-Za-z]+/gi, '')
              .replace(/[-|_|,|;]/g, ' ')
              .replace(/\s+/g, ' ')
              .trim();

            if (!subject || subject.length < 3) subject = 'EXAM COURSE';

            const roomMatch = trimmed.match(/\b(Room\s*\d+|Lab\s*\d+|LH\s*\d+|Hall\s*[A-Za-z0-9]+)\b/i);
            const room = roomMatch ? roomMatch[0] : 'Exam Hall';

            extractedExams.push({
              date: date,
              time: time,
              room: room,
              batch: batch,
              subject: subject
            });
          }
        });
      }

      if (extractedExams.length > 0) {
        stagedExams = extractedExams;
        renderExamsPreview(stagedExams);
        showMossToast(`Extracted ${stagedExams.length} exams from PDF!`, 'success');
        logTerminal(`Parsed <strong>${stagedExams.length} exams</strong> from PDF.`, 'success');
      } else {
        showMossToast('PDF parsed but no standard exam rows detected. Try JSON format for 100% precision.', 'warning');
      }
    } catch (err) {
      showMossToast(`PDF parse error: ${err.message}`, 'error');
      logTerminal(`PDF error: ${err.message}`, 'error');
    }
  } else if (file.name.endsWith('.xlsx') || file.name.endsWith('.xls')) {
    try {
      const arrayBuffer = await file.arrayBuffer();
      const workbook = XLSX.read(arrayBuffer, { type: 'array', cellDates: false, cellNF: true, cellText: true });
      const extractedExams = [];

      function formatSlotTime(raw) {
        if (!raw) return '09:00 AM - 12:00 PM';
        const clean = String(raw).trim();
        if (clean.includes('-')) {
          const parts = clean.split('-');
          if (parts.length === 2 && parts[0].trim().length === 4 && parts[1].trim().length === 4) {
            let sH = parseInt(parts[0].substring(0, 2), 10);
            const sM = parts[0].substring(2);
            let eH = parseInt(parts[1].substring(0, 2), 10);
            const eM = parts[1].substring(2);

            if (sH >= 1 && sH <= 5) sH += 12;
            if (eH >= 1 && eH <= 5) eH += 12;

            const sAmPm = sH >= 12 ? 'PM' : 'AM';
            const eAmPm = eH >= 12 ? 'PM' : 'AM';
            const sDisp = sH > 12 ? sH - 12 : (sH === 0 ? 12 : sH);
            const eDisp = eH > 12 ? eH - 12 : (eH === 0 ? 12 : eH);

            return `${String(sDisp).padStart(2, '0')}:${sM} ${sAmPm} - ${String(eDisp).padStart(2, '0')}:${eM} ${eAmPm}`;
          }
        }
        return clean;
      }

      for (const sheetName of workbook.SheetNames) {
        const worksheet = workbook.Sheets[sheetName];
        const rows = XLSX.utils.sheet_to_json(worksheet, { header: 1, raw: false, defval: '' });
        if (!rows || rows.length === 0) continue;

        // 1. Check if sheet is Multi-Block Quad Matrix Layout (Row 2 or 3 has venues across columns)
        let matrixHeaderRowIdx = -1;
        let venueCols = {};
        let curDateCol = -1;
        let curTimeCol = -1;

        for (let r = 0; r < Math.min(rows.length, 5); r++) {
          const row = rows[r] || [];
          let vCount = 0;
          row.forEach(cell => {
            const s = String(cell || '').trim();
            if (s.match(/^[A-D]\s*[-_]?\s*\d+(\.\d+)?(\s*\(\d+\))?/i) || s.match(/^WCR\s*\d+(\s*\(\d+\))?/i) || s.match(/^LH\s*\d+(\s*\(\d+\))?/i)) {
              vCount++;
            }
          });
          if (vCount >= 3) {
            matrixHeaderRowIdx = r;
            break;
          }
        }

        if (matrixHeaderRowIdx !== -1) {
          // Quad-Matrix Layout Parser
          const headerRow = rows[matrixHeaderRowIdx] || [];
          headerRow.forEach((val, c) => {
            const str = String(val || '').trim();
            const u = str.toUpperCase();
            if (u.includes('DATE')) curDateCol = c;
            else if (u.includes('TIME') || u.includes('SLOT')) curTimeCol = c;
            else if (str && !u.includes('DATE') && !u.includes('TIME')) {
              const venue = str.replace(/\s*\(\d+\)/, '').trim();
              venueCols[c] = { venue, dateCol: curDateCol, timeCol: curTimeCol };
            }
          });

          const activeDates = {};
          const activeTimes = {};

          let r = matrixHeaderRowIdx + 1;
          while (r < rows.length) {
            const row = rows[r] || [];
            const hasContent = row.some(c => String(c || '').trim().length > 0);
            if (!hasContent) {
              r++;
              continue;
            }

            // Check repeated header in middle of sheet
            const rowUpper = row.map(c => String(c || '').trim().toUpperCase());
            if (rowUpper.some(c => c.includes('DATE')) && rowUpper.some(c => c.includes('TIME'))) {
              row.forEach((val, c) => {
                const str = String(val || '').trim();
                const u = str.toUpperCase();
                if (u.includes('DATE')) curDateCol = c;
                else if (u.includes('TIME') || u.includes('SLOT')) curTimeCol = c;
                else if (str && !u.includes('DATE') && !u.includes('TIME')) {
                  const venue = str.replace(/\s*\(\d+\)/, '').trim();
                  if (venueCols[c]) {
                    venueCols[c].venue = venue;
                    venueCols[c].dateCol = curDateCol;
                    venueCols[c].timeCol = curTimeCol;
                  }
                }
              });
              r++;
              continue;
            }

            // Update active dates & times
            Object.values(venueCols).forEach(info => {
              if (info.dateCol !== -1) {
                const dVal = String(row[info.dateCol] || '').trim();
                if (dVal && !dVal.toUpperCase().includes('DATE')) activeDates[info.dateCol] = dVal;
              }
              if (info.timeCol !== -1) {
                const tVal = String(row[info.timeCol] || '').trim();
                if (tVal && !tVal.toUpperCase().includes('TIME')) activeTimes[info.timeCol] = tVal;
              }
            });

            const subjectRow = rows[r + 1] || [];

            Object.entries(venueCols).forEach(([cStr, info]) => {
              const c = parseInt(cStr, 10);
              const bVal = String(row[c] || '').trim();
              const sVal = String(subjectRow[c] || '').trim();

              if (!bVal || !sVal) return;
              const bU = bVal.toUpperCase();
              const sU = sVal.toUpperCase();
              if (['BATCH', 'CLASS', 'DATE', 'TIME'].includes(bU) || ['SUBJECT', 'COURSE', 'DATE', 'TIME'].includes(sU)) return;

              const date = activeDates[info.dateCol] || 'TBD';
              const rawTime = activeTimes[info.timeCol] || '0900-1200';
              const formattedTime = formatSlotTime(rawTime);

              extractedExams.push({
                date: date,
                time: formattedTime,
                room: info.venue,
                batch: bVal.toUpperCase(),
                subject: sVal
              });
            });

            r += 2;
          }
        } else {
          // Standard Tabular Layout Parser
          let dateCol = -1, timeCol = -1, batchCol = -1, subjectCol = -1, roomCol = -1, headerRowIdx = -1;
          for (let r = 0; r < Math.min(rows.length, 15); r++) {
            const row = rows[r];
            for (let c = 0; c < row.length; c++) {
              const cell = String(row[c] || '').toLowerCase().trim();
              if (cell.includes('date') || cell.includes('day')) dateCol = c;
              if (cell.includes('time') || cell.includes('slot') || cell.includes('timing')) timeCol = c;
              if (cell.includes('batch') || cell.includes('class') || cell.includes('program') || cell.includes('section')) batchCol = c;
              if (cell.includes('subject') || cell.includes('course') || cell.includes('paper') || cell.includes('title')) subjectCol = c;
              if (cell.includes('room') || cell.includes('hall') || cell.includes('venue') || cell.includes('location')) roomCol = c;
            }
            if (batchCol !== -1 && (subjectCol !== -1 || dateCol !== -1)) {
              headerRowIdx = r;
              break;
            }
          }

          if (headerRowIdx !== -1) {
            let currentDate = '';
            let currentTime = '09:00 AM - 12:00 PM';
            for (let r = headerRowIdx + 1; r < rows.length; r++) {
              const row = rows[r];
              if (!row || row.length === 0) continue;

              const dateVal = dateCol !== -1 ? String(row[dateCol] || '').trim() : '';
              if (dateVal && !dateVal.toLowerCase().includes('date')) currentDate = dateVal;

              const timeVal = timeCol !== -1 ? String(row[timeCol] || '').trim() : '';
              if (timeVal && !timeVal.toLowerCase().includes('time')) currentTime = formatSlotTime(timeVal);

              const batchVal = batchCol !== -1 ? String(row[batchCol] || '').trim() : '';
              const subjectVal = subjectCol !== -1 ? String(row[subjectCol] || '').trim() : '';
              const roomVal = roomCol !== -1 ? String(row[roomCol] || '').trim() : 'Exam Hall';

              if (batchVal && subjectVal && subjectVal.toLowerCase() !== 'subject' && batchVal.toLowerCase() !== 'batch') {
                extractedExams.push({
                  date: currentDate || 'TBD',
                  time: currentTime || '09:00 AM - 12:00 PM',
                  room: roomVal || 'Exam Hall',
                  batch: batchVal.toUpperCase(),
                  subject: subjectVal
                });
              }
            }
          }
        }
      }

      if (extractedExams.length > 0) {
        stagedExams = extractedExams;
        renderExamsPreview(stagedExams);
        showMossToast(`Extracted ${stagedExams.length} exams from Excel (${file.name})!`, 'success');
        logTerminal(`Parsed <strong>${stagedExams.length} exams</strong> with 100% precision from Excel spreadsheet.`, 'success');
      } else {
        showMossToast('Excel parsed but no exam records detected.', 'warning');
      }
    } catch (err) {
      showMossToast(`Excel parse error: ${err.message}`, 'error');
      logTerminal(`Excel error: ${err.message}`, 'error');
    }
  }
}

async function renderInspectorExamsTable(filterText = '') {
  const tbody = document.getElementById('inspector-exams-body');
  if (!tbody) return;
  tbody.innerHTML = '';

  const q = (filterText || '').toLowerCase().trim();
  const filtered = liveLoadedExams.filter(e => {
    if (!q) return true;
    return (e.batch && e.batch.toLowerCase().includes(q)) ||
           (e.subject && e.subject.toLowerCase().includes(q)) ||
           (e.room && e.room.toLowerCase().includes(q)) ||
           (e.date && e.date.toLowerCase().includes(q));
  });

  if (filtered.length === 0) {
    tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 24px;">No ${activeInspectorExamPeriod} records match "${escapeHtml(q)}".</td></tr>`;
    return;
  }

  filtered.forEach(e => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td style="font-family: var(--font-mono); color: var(--accent-cyan); font-size: 11.5px;">${escapeHtml(e.date || 'TBD')}</td>
      <td style="font-family: var(--font-mono); font-size: 11px;">${escapeHtml(e.time || '09:00 AM - 12:00 PM')}</td>
      <td><span style="background: rgba(16, 185, 129, 0.12); color: #34d399; font-weight: 600; padding: 2px 6px; border-radius: 4px; font-family: var(--font-mono); font-size: 11px;">${escapeHtml(e.room || 'Exam Hall')}</span></td>
      <td style="font-weight: 700; color: var(--accent-indigo);">${escapeHtml(e.batch || 'ALL')}</td>
      <td style="font-weight: 600; color: var(--text-title);">${escapeHtml(e.subject || 'EXAM')}</td>
    `;
    tbody.appendChild(tr);
  });
}

async function fetchLiveInspectorExams() {
  if (!isConnected) {
    showMossToast('Database offline', 'error');
    return;
  }

  const tbody = document.getElementById('inspector-exams-body');
  if (tbody) tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 24px;"><i class="fa-solid fa-spinner fa-spin"></i> Querying live ${activeInspectorExamPeriod} records from Firestore...</td></tr>`;

  try {
    const doc = await db.collection('config').doc('global').get();
    if (!doc.exists) {
      if (tbody) tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 24px;">Global config document not found in database.</td></tr>`;
      return;
    }

    const data = doc.data() || {};
    const fieldKey = activeInspectorExamPeriod === 'midterms' ? 'active_midterm_json' : 'active_finals_json';
    const jsonStr = data[fieldKey] || '';

    if (!jsonStr) {
      liveLoadedExams = [];
      if (tbody) tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 24px;">No active ${activeInspectorExamPeriod} records in cloud.</td></tr>`;
      return;
    }

    const parsed = JSON.parse(jsonStr);
    liveLoadedExams = Array.isArray(parsed) ? parsed : [];
    renderInspectorExamsTable(document.getElementById('inspector-exams-search')?.value || '');
    logTerminal(`Loaded <strong>${liveLoadedExams.length} live ${activeInspectorExamPeriod} records</strong> from Firestore.`, 'success');
  } catch (err) {
    logTerminal(`Failed to query exams: ${err.message}`, 'error');
    showMossToast(err.message, 'error');
    if (tbody) tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--accent-rose); padding: 24px;">Query Error: ${escapeHtml(err.message)}</td></tr>`;
  }
}

function setupExamsManager() {
  const examsDropzone = document.getElementById('exams-dropzone');
  const examsFileInput = document.getElementById('file-exams');
  const deployMidtermsBtn = document.getElementById('btn-deploy-midterms');
  const deployFinalsBtn = document.getElementById('btn-deploy-finals');
  const refreshInspectorBtn = document.getElementById('btn-refresh-inspector-exams');
  const wipeInspectorBtn = document.getElementById('btn-wipe-exams');
  const inspectorSearch = document.getElementById('inspector-exams-search');
  const inspectorPeriodSwitcher = document.getElementById('inspector-exam-period-switcher');

  if (examsDropzone && examsFileInput) {
    setupDropzone(examsDropzone, examsFileInput, (files) => {
      if (files.length > 0) {
        handleExamFileSelect(files[0]);
      }
    });
  }

  // Deploy Midterms
  if (deployMidtermsBtn) {
    deployMidtermsBtn.addEventListener('click', async () => {
      if (!isConnected) {
        showMossToast('Database connection offline', 'error');
        return;
      }
      if (stagedExams.length === 0) {
        showMossToast('No exams staged to deploy', 'error');
        return;
      }

      deployMidtermsBtn.disabled = true;
      deployMidtermsBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> DEPLOYING MIDTERMS...';

      try {
        logTerminal(`Deploying <strong>${stagedExams.length} Midterm exam records</strong> to Firestore...`, 'info');
        await db.collection('config').doc('global').update({
          active_midterm_json: JSON.stringify(stagedExams),
          updated_at: firebase.firestore.FieldValue.serverTimestamp()
        });
        incrementDatabaseOps();
        logTerminal(`Deployment Succeeded: <strong>${stagedExams.length} Midterms active</strong> in database.`, 'success');
        showMossToast(`Successfully deployed ${stagedExams.length} Midterm exams to cloud!`, 'success');
      } catch (err) {
        logTerminal(`Deployment failed: ${err.message}`, 'error');
        showMossToast(err.message, 'error');
      } finally {
        deployMidtermsBtn.disabled = false;
        deployMidtermsBtn.innerHTML = '<i class="fa-solid fa-pen-clip" style="margin-right: 6px;"></i> DEPLOY MIDTERMS';
      }
    });
  }

  // Deploy Finals
  if (deployFinalsBtn) {
    deployFinalsBtn.addEventListener('click', async () => {
      if (!isConnected) {
        showMossToast('Database connection offline', 'error');
        return;
      }
      if (stagedExams.length === 0) {
        showMossToast('No exams staged to deploy', 'error');
        return;
      }

      deployFinalsBtn.disabled = true;
      deployFinalsBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> DEPLOYING FINALS...';

      try {
        logTerminal(`Deploying <strong>${stagedExams.length} Final exam records</strong> to Firestore...`, 'info');
        await db.collection('config').doc('global').update({
          active_finals_json: JSON.stringify(stagedExams),
          updated_at: firebase.firestore.FieldValue.serverTimestamp()
        });
        incrementDatabaseOps();
        logTerminal(`Deployment Succeeded: <strong>${stagedExams.length} Finals active</strong> in database.`, 'success');
        showMossToast(`Successfully deployed ${stagedExams.length} Final exams to cloud!`, 'success');
      } catch (err) {
        logTerminal(`Deployment failed: ${err.message}`, 'error');
        showMossToast(err.message, 'error');
      } finally {
        deployFinalsBtn.disabled = false;
        deployFinalsBtn.innerHTML = '<i class="fa-solid fa-award" style="margin-right: 6px;"></i> DEPLOY FINALS';
      }
    });
  }

  // Inspector Period Switcher
  if (inspectorPeriodSwitcher) {
    const segments = inspectorPeriodSwitcher.querySelectorAll('.ribbon-segment');
    segments.forEach(seg => {
      seg.addEventListener('click', () => {
        segments.forEach(s => s.classList.remove('active'));
        seg.classList.add('active');
        activeInspectorExamPeriod = seg.dataset.inspectorPeriod || 'midterms';
        fetchLiveInspectorExams();
      });
    });
  }

  // Refresh Inspector
  if (refreshInspectorBtn) {
    refreshInspectorBtn.addEventListener('click', fetchLiveInspectorExams);
  }

  // Search Filter
  if (inspectorSearch) {
    inspectorSearch.addEventListener('input', () => {
      renderInspectorExamsTable(inspectorSearch.value);
    });
  }

  // Wipe Live Exams
  if (wipeInspectorBtn) {
    wipeInspectorBtn.addEventListener('click', async () => {
      if (!isConnected) {
        showMossToast('Database connection offline', 'error');
        return;
      }
      if (!confirm(`Are you sure you want to completely WIPE all live ${activeInspectorExamPeriod.toUpperCase()} exams from the database?`)) {
        return;
      }

      try {
        const fieldKey = activeInspectorExamPeriod === 'midterms' ? 'active_midterm_json' : 'active_finals_json';
        logTerminal(`Wiping ${activeInspectorExamPeriod} records from Firestore...`, 'warning');
        await db.collection('config').doc('global').update({
          [fieldKey]: '',
          updated_at: firebase.firestore.FieldValue.serverTimestamp()
        });
        incrementDatabaseOps();
        liveLoadedExams = [];
        renderInspectorExamsTable();
        showMossToast(`All live ${activeInspectorExamPeriod.toUpperCase()} exams wiped from cloud!`, 'success');
        logTerminal(`Wiped ${activeInspectorExamPeriod} records successfully.`, 'success');
      } catch (err) {
        logTerminal(`Wipe failed: ${err.message}`, 'error');
        showMossToast(err.message, 'error');
      }
    });
  }
}

// Auto-initialize handlers on document ready
document.addEventListener('DOMContentLoaded', () => {
  setupExamsManager();
  setupSemesterScheduleHandlers();
  renderFeedbackFeed();
  initGlassDropdowns();
});



