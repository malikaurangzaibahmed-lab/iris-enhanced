/* ==========================================================================
   IRIS ENTERPRISE CONTROL SPACE - 21ST.DEV OBSIDIAN CONTROLLER
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

// User Roles Management Bindings
const tabBtnUsers = document.getElementById('tab-btn-users');
const userEditModal = document.getElementById('user-edit-modal');
const btnCloseUserModal = document.getElementById('btn-close-user-modal');
const btnSaveUserProfile = document.getElementById('btn-save-user-profile');
const usersTableBody = document.getElementById('users-table-body');
const btnRefreshUsers = document.getElementById('btn-refresh-users');
const btnShowPreauthModal = document.getElementById('btn-show-preauth-modal');
const inspectorUsersSearch = document.getElementById('inspector-users-search');

const userEditUid = document.getElementById('user-edit-uid');
const userEditEmail = document.getElementById('user-edit-email');
const userEditName = document.getElementById('user-edit-name');
const userEditRole = document.getElementById('user-edit-role');
const userAssignmentsPanel = document.getElementById('user-assignments-panel');
const crAssignSection = document.getElementById('cr-assign-section');
const profAssignSection = document.getElementById('prof-assign-section');
const userAssignCrBatch = document.getElementById('user-assign-cr-batch');
const userAssignProfTeacher = document.getElementById('user-assign-prof-teacher');
const userAssignProfBatch = document.getElementById('user-assign-prof-batch');
const userAssignProfCourse = document.getElementById('user-assign-prof-course');
const btnAddCrAssignment = document.getElementById('btn-add-cr-assignment');
const btnSuggestProfAssignments = document.getElementById('btn-suggest-prof-assignments');
const btnAddProfAssignment = document.getElementById('btn-add-prof-assignment');
const userEditAssignmentsList = document.getElementById('user-edit-assignments-list');

let activeUsersList = [];
let activeUserAssignments = []; // Local assignments array buffer for user currently being edited

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

  setupDragAndDrop();
  setupUIHandlers();
  setup3DTiltEffects();
  startLatencySimulator();
  startTelemetryECG();
  
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

  // WORKSPACE SEEDER TABS TOGGLER
  const tabButtons = document.querySelectorAll('.tab-btn');
  const tabPanes = document.querySelectorAll('.workspace-tab-pane');
  tabButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      tabButtons.forEach(b => {
        b.classList.remove('active');
        b.style.background = 'transparent';
        b.style.color = 'var(--text-muted)';
        b.style.boxShadow = 'none';
      });
      btn.classList.add('active');
      btn.style.background = '#ffffff';
      btn.style.color = 'var(--accent-indigo)';
      btn.style.boxShadow = '0 1px 3px rgba(0,0,0,0.05)';
      
      const targetTab = btn.dataset.workspaceTab;
      tabPanes.forEach(pane => {
        if (pane.id === `workspace-tab-${targetTab}`) {
          pane.style.display = 'block';
        } else {
          pane.style.display = 'none';
        }
      });
      logTerminal(`Workspace switch: Staging <strong>${targetTab.toUpperCase()}</strong> workspace interface.`, 'info');
      
      // Auto-load live data when switching tabs
      if (targetTab === 'classes') {
        refreshLiveClassesInspector();
      } else if (targetTab === 'exams') {
        refreshLiveExamsInspector();
      } else if (targetTab === 'users') {
        refreshUsersList();
      }
    });
  });

  // User Management Event Listeners
  if (btnRefreshUsers) btnRefreshUsers.addEventListener('click', refreshUsersList);
  if (inspectorUsersSearch) inspectorUsersSearch.addEventListener('input', renderUsersList);
  if (btnShowPreauthModal) btnShowPreauthModal.addEventListener('click', () => openUserEditModal(null));
  if (btnCloseUserModal) btnCloseUserModal.addEventListener('click', () => { userEditModal.style.display = 'none'; });
  if (userEditRole) userEditRole.addEventListener('change', handleUserRoleChangeUI);
  if (btnAddCrAssignment) btnAddCrAssignment.addEventListener('click', addCRAssignmentUI);
  if (btnSuggestProfAssignments) btnSuggestProfAssignments.addEventListener('click', suggestProfessorAssignmentsUI);
  if (btnAddProfAssignment) btnAddProfAssignment.addEventListener('click', addProfAssignmentUI);
  if (btnSaveUserProfile) btnSaveUserProfile.addEventListener('click', saveUserProfile);

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
      refreshLiveExamsInspector();
    });
  });
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
      
      let md = `# IRIS Biosphere Command Console - System Diagnostics Report\r\n\r\n`;
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
      link.download = `iris-diagnostics-report-${Date.now()}.md`;
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

  // Load Cloudflare Worker configurations
  const savedWorkerUrl = localStorage.getItem('iris_fcm_worker_url') || '';
  const savedWorkerToken = localStorage.getItem('iris_fcm_worker_token') || '';
  const workerUrlInput = document.getElementById('fcm-worker-url');
  const workerTokenInput = document.getElementById('fcm-worker-token');
  if (workerUrlInput) workerUrlInput.value = savedWorkerUrl;
  if (workerTokenInput) workerTokenInput.value = savedWorkerToken;

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
      
      applyRolePermissions(user);
      
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

let failedAttempts = parseInt(localStorage.getItem('iris_admin_failed_attempts') || '0');
let lockUntil = parseInt(localStorage.getItem('iris_admin_lock_until') || '0');

loginBtn.addEventListener('click', async () => {
  const email = emailInput.value.trim();
  const pass = passInput.value;
  
  const now = Date.now();
  if (now < lockUntil) {
    const remainingSecs = Math.ceil((lockUntil - now) / 1000);
    showAuthError(`Vault locked. Security lockout active for ${remainingSecs} seconds.`);
    logTerminal(`Access Denied: Lockout actively running. Remaining: ${remainingSecs}s.`, 'error');
    return;
  }
  
  if (!email || !pass) {
    showAuthError('Email and passkey credentials parameters required.');
    return;
  }
  
  if (!isConnected || !auth) {
    showAuthError('Console gateway compilation error. Check backend connections.');
    return;
  }
  
  loginBtn.disabled = true;
  loginBtn.querySelector('span').innerText = 'DECRYPTING LOCKOUT KEY...';
  authError.style.display = 'none';
  
  try {
    await auth.signInWithEmailAndPassword(email, pass);
    failedAttempts = 0;
    localStorage.setItem('iris_admin_failed_attempts', '0');
  } catch (e) {
    failedAttempts++;
    localStorage.setItem('iris_admin_failed_attempts', failedAttempts.toString());
    logTerminal(`Vault credential validation failed: ${e.message}`, 'error');
    
    if (failedAttempts >= 3) {
      lockUntil = Date.now() + 45000; // 45 seconds lock
      localStorage.setItem('iris_admin_lock_until', lockUntil.toString());
      showAuthError(`Vault lock initialized. Access profile suspended for 45s.`);
      logTerminal(`Brute Shield: Successive failures. Key gateway suspended.`, 'error');
    } else {
      showAuthError(`Validation Failed. (${failedAttempts}/3 Attempts)`);
    }
  } finally {
    loginBtn.disabled = false;
    loginBtn.querySelector('span').innerText = 'Verify Access Profile';
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
  try {
    const config = JSON.parse(jsonStr);
    if (!config.apiKey || !config.projectId || !config.storageBucket) {
      alert('Invalid configuration. Required parameters missing: API key, Project ID.');
      return;
    }
    localStorage.setItem('iris_admin_firebase_config', JSON.stringify(config));

    // Save Cloudflare Worker Bridge configurations
    const workerUrlInput = document.getElementById('fcm-worker-url');
    const workerTokenInput = document.getElementById('fcm-worker-token');
    if (workerUrlInput) localStorage.setItem('iris_fcm_worker_url', workerUrlInput.value.trim());
    if (workerTokenInput) localStorage.setItem('iris_fcm_worker_token', workerTokenInput.value.trim());

    configModal.style.display = 'none';
    
    initializeFirebase(config);
    setupAuthListeners();
  } catch (e) {
    alert(`Payload Parsing Failure: ${e.message}`);
  }
});

// ==========================================================================
// ACADEMIC SYSTEM MATRIX SWITCHER & SVG ORBITS
// ==========================================================================

function rotateOrbitBodies(activePeriod) {
  // Balanced concentric scattered rotation values
  const angles = {
    classes: { classes: 0, midterms: 75, finals: 155, sports_week: 250 },
    midterms: { classes: 285, midterms: 0, finals: 80, sports_week: 175 },
    finals: { classes: 205, midterms: 280, finals: 0, sports_week: 105 },
    sports_week: { classes: 110, midterms: 185, finals: 250, sports_week: 0 }
  };
  
  const stateAngles = angles[activePeriod] || angles.classes;
  
  for (const [period, angle] of Object.entries(stateAngles)) {
    const element = document.getElementById(`orbit-body-${period}`);
    if (element) {
      element.style.transform = `rotate(${angle}deg)`;
      element.setAttribute('transform', `rotate(${angle}, 60, 60)`);
    }
  }
}

function syncActivePeriodState() {
  if (!isConnected) return;
  
  logTerminal('Establishing real-time cloud database synchronization...', 'info');
  
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
        midterms: 'Midterm testing mode: interim assessments, mid-semester testing logs, and check schedules.',
        finals: 'Final examination mode: core semester finals, grade evaluation compiles, and term closeout.',
        sports_week: 'Athletic Sports Week: campus extracurricular activities, sports day schedules, and session breaks.'
      };
      if (activePeriodDesc) {
        activePeriodDesc.innerText = descs[currentPeriod] || 'Lecture tracks active.';
      }
      
      // Rotate Visual SVG Orbits
      rotateOrbitBodies(currentPeriod);

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
        btnBroadcastPush.disabled = false;
        
        // Synchronize hidden legacy elements for workspace compatibility
        if (broadcastSwitch) broadcastSwitch.checked = isBroadcastOn;
        if (broadcastingBadge) broadcastingBadge.style.display = isBroadcastOn ? 'inline-block' : 'none';
        
        // Toggle industrial LED button state
        if (btnBroadcastPush) {
          if (isBroadcastOn) {
            btnBroadcastPush.classList.add('active-led');
            btnBroadcastPush.querySelector('span').innerText = 'Announcements live (Click to broadcast update)';
          } else {
            btnBroadcastPush.classList.remove('active-led');
            btnBroadcastPush.querySelector('span').innerText = 'Transmit Notification Alert';
          }
        }
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
  } else if (json.sessions && Array.isArray(json.sessions)) {
    sessions = json.sessions;
  } else {
    return;
  }

  const sessionCount = sessions.length;
  const uniqueSubjects = new Set();
  let labCount = 0;
  
  // Build departures visual ledger rows for active timetable
  timetablePreviewBody.innerHTML = '';
  const previewLimit = Math.min(5, sessions.length);
  
  for (let i = 0; i < previewLimit; i++) {
    const s = sessions[i];
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${s.class_name || s.section || 'CORE-GEN'}</td>
      <td style="color: var(--text-title); font-weight: 500;">${s.subject || 'LECTURE'}</td>
      <td>${s.time || s.period || 'ON SCHEDULE'}</td>
      <td style="color: var(--text-caption);">${s.teacher || s.instructor || 'STAFF'}</td>
    `;
    timetablePreviewBody.appendChild(tr);
  }
  
  sessions.forEach(s => {
    if (s.subject) {
      const cleanSub = s.subject.replace(/\s*\(\d*\s*hrs?\)\s*/gi, '')
                               .replace(/\s*\(\d*\s*hr\)\s*/gi, '')
                               .replace(/\s*\(Lab\)\s*/gi, '')
                               .trim();
      uniqueSubjects.add(cleanSub);
      
      if (s.subject.toLowerCase().includes('lab') || (s.room && s.room.toLowerCase().includes('lab'))) {
        labCount++;
      }
    }
  });

  if (statSessions) statSessions.innerText = sessionCount;
  if (statCourses) statCourses.innerText = uniqueSubjects.size;
  if (statLabs) statLabs.innerText = labCount;
  if (timetableAnalytics) timetableAnalytics.style.display = 'block';
}

// Ribbon Switch Snappy Selection Handler
ribbonSegments.forEach(seg => {
  seg.addEventListener('click', async () => {
    // 1. Instantly respond client-side first for extreme snappiness
    ribbonSegments.forEach(s => s.classList.remove('active'));
    seg.classList.add('active');
    
    const targetPeriod = seg.dataset.period;
    rotateOrbitBodies(targetPeriod);
    
    // Update local text descriptions instantly
    const descs = {
      classes: 'Standard classes mode: regular curriculum sessions, lectures, and laboratory periods.',
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

  const textRender = document.getElementById('emulator-text-render');
  const timeRender = document.getElementById('emulator-time-render');
  
  if (textRender && broadcastMessage) {
    const rawVal = broadcastMessage.value.trim();
    textRender.innerText = rawVal || 'All Quiet on Campus • No active broadcasts right now';
    
    if (timeRender) {
      if (rawVal) {
        timeRender.innerText = 'BROADCASTED: ' + formatMockTime(new Date());
      } else {
        timeRender.innerText = 'BROADCASTED: NEVER';
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
    if (!isConnected) return;
    
    const enabled = broadcastSwitchVisible.checked;
    logTerminal(`Updating broadcast transmission link state: ${enabled ? 'ACTIVE' : 'STANDBY'}...`, 'info');
    
    try {
      await db.collection('config').doc('global').update({
        broadcast_enabled: enabled,
        updated_at: firebase.firestore.FieldValue.serverTimestamp()
      });
      incrementDatabaseOps();
      logTerminal(`Server sync complete: Broadcast live stream set to ${enabled ? 'ON' : 'OFF'}.`, 'success');
    } catch (e) {
      logTerminal(`Failed to update broadcast switch: ${e.message}`, 'error');
      // Revert UI on failure
      broadcastSwitchVisible.checked = !enabled;
    }
  });
}

// Dedicated Dispatch Signal button (explicitly turns alert ON with target type and payload)
btnBroadcastPush.addEventListener('click', async () => {
  if (!isConnected || !db) return;
  
  const msg = broadcastMessage.value.trim();
  if (!msg) {
    showMossToast("Please enter announcement message content.", "warning");
    return;
  }

  const targetType = document.getElementById('broadcast-target-type').value;
  const targetBatch = document.getElementById('broadcast-target-batch').value;
  const targetCourse = document.getElementById('broadcast-target-course').value;

  // Validate dropdown selections
  if (targetType === 'batch' && !targetBatch) {
    showMossToast("Please select a target batch.", "warning");
    return;
  }
  if (targetType === 'course' && (!targetBatch || !targetCourse)) {
    showMossToast("Please select both target batch and target course.", "warning");
    return;
  }

  logTerminal(`Preparing to dispatch targeted notice document: type=${targetType}...`, 'info');
  
  btnBroadcastPush.disabled = true;
  const originalHtml = btnBroadcastPush.innerHTML;
  btnBroadcastPush.innerHTML = '<span>TRANSMITTING EMISSION WAVE...</span> <i class="fa-solid fa-spinner fa-spin"></i>';
  
  try {
    const user = firebase.auth().currentUser;
    
    // Construct visibleTo authorization lookup tags
    const visibleTo = ["global"];
    if (targetType === 'batch') {
      visibleTo.push(`batch_${targetBatch}`);
    } else if (targetType === 'course') {
      visibleTo.push(`batch_${targetBatch}`);
      visibleTo.push(`course_${targetBatch}_${targetCourse}`);
    }

    const payload = {
      message: msg,
      senderUid: user ? user.uid : "unknown",
      senderName: currentUserProfile.name || (user ? user.email.split('@')[0] : "System"),
      senderRole: currentUserProfile.role || "admin",
      targetType: targetType,
      targetBatch: targetBatch || null,
      targetCourse: targetCourse || null,
      visibleTo: visibleTo,
      timestamp: firebase.firestore.FieldValue.serverTimestamp()
    };

    // Write notice to history list
    await db.collection('announcements').add(payload);
    incrementDatabaseOps();

    // If global target, also update config/global for persistent homepage header card
    if (targetType === 'global') {
      await db.collection('config').doc('global').update({
        broadcast_message: msg,
        broadcast_enabled: true,
        updated_at: firebase.firestore.FieldValue.serverTimestamp()
      });
      incrementDatabaseOps();
      if (broadcastSwitchVisible) broadcastSwitchVisible.checked = true;
    }
    
    // Trigger Push Notification via Cloudflare Worker if configured
    const workerUrl = localStorage.getItem('iris_fcm_worker_url') || '';
    const workerToken = localStorage.getItem('iris_fcm_worker_token') || '';
    
    if (workerUrl) {
      logTerminal('FCM Bridge: Triggering background push notification via Cloudflare Worker...', 'info');
      
      let pushTopic = 'global_announcements';
      let pushTitle = 'New Announcement';
      const senderName = currentUserProfile.name || (user ? user.email.split('@')[0] : "System");
      
      if (targetType === 'batch' && targetBatch) {
        const normalizedBatch = targetBatch.replace(/[^a-zA-Z0-9-_.~%]/g, '_');
        pushTopic = `batch_${normalizedBatch}`;
        pushTitle = `${senderName} (CR)`;
      } else if (targetType === 'course' && targetBatch && targetCourse) {
        const normalizedBatch = targetBatch.replace(/[^a-zA-Z0-9-_.~%]/g, '_');
        const normalizedCourse = targetCourse.replace(/[^a-zA-Z0-9-_.~%]/g, '_');
        pushTopic = `course_${normalizedBatch}_${normalizedCourse}`;
        pushTitle = `Prof. ${senderName}`;
      } else {
        pushTitle = `System Alert: ${senderName}`;
      }
      
      fetch(workerUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${workerToken || 'IRIS_SECRET_TOKEN_2026_SWL'}`
        },
        body: JSON.stringify({
          topic: pushTopic,
          title: pushTitle,
          message: msg,
          data: {
            type: 'announcement',
            targetType: targetType,
            targetBatch: targetBatch || '',
            targetCourse: targetCourse || '',
            senderName: senderName
          }
        })
      })
      .then(async response => {
        const resText = await response.text();
        if (response.ok) {
          logTerminal(`FCM Bridge: Background push notification transmitted successfully to topic [<strong>${pushTopic}</strong>].`, 'success');
        } else {
          logTerminal(`FCM Bridge: Transmission failed. Status: ${response.status}. Response: ${resText}`, 'error');
        }
      })
      .catch(err => {
        logTerminal(`FCM Bridge Error: ${err.message}`, 'error');
      });
    } else {
      logTerminal('FCM Bridge: No Cloudflare Worker URL configured. Background push notification bypassed.', 'warning');
    }
    
    logTerminal(`Broadcast dispatched successfully to target: ${targetType === 'global' ? 'Global' : (targetType === 'batch' ? targetBatch : targetBatch + ' - ' + targetCourse)}.`, 'success');
    showMossToast("Announcement dispatched live!", "success");
    broadcastMessage.value = "";
    if (document.getElementById('broadcast-char-count')) {
      document.getElementById('broadcast-char-count').innerText = "0";
    }
  } catch (e) {
    logTerminal(`Broadcast transmission failed: ${e.message}`, 'error');
    showMossToast(e.message, "error");
  } finally {
    btnBroadcastPush.disabled = false;
    btnBroadcastPush.innerHTML = originalHtml;
  }
});


// ==========================================================================
// TIMETABLE DEPLOYMENT ENGINE (AIRPORT DEPARTURES LEDGER)
// ==========================================================================

// ==========================================================================
// TIMETABLE DEPLOYMENT ENGINE (AIRPORT DEPARTURES LEDGER)
// ==========================================================================

const BATCH_RE = /\b[A-Z]{2}\d{2}-[A-Z0-9]+/i;

const GRID_COLUMNS = [
  { name: "Batch", minX: 0, maxX: 100 },
  { name: "Slot 1", minX: 100, maxX: 204 },
  { name: "Slot 2", minX: 204, maxX: 319 },
  { name: "Slot 3", minX: 319, maxX: 434 },
  { name: "Slot 4", minX: 434, maxX: 549 },
  { name: "Slot 5", minX: 549, maxX: 664 },
  { name: "Slot 6", minX: 664, maxX: 780 }
];

const DEPT_CODES = new Set(["CS", "SE", "MS", "EE", "ME", "CVE", "BBA", "MBA", "MT", "VS", "HUM", "CE", "BI"]);
const TEACHER_TITLE_RE = /\b(Dr\.?|Prof\.?|Engr\.?|Mr\.?|Ms\.?|Mrs\.?|Sir|Mam)\b/i;
const CAPACITY_RE = /\s*\(\d+\)\s*/g;

const SUBJECT_KEYWORDS = new Set([
  "programming", "engineering", "structures", "systems", "calculus",
  "algebra", "physics", "chemistry", "communication", "technology",
  "network", "database", "security", "intelligence", "learning",
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
  "parallel", "distributed", "artificial", "deep"
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
  /\bMOM\s*Lab\b/i,
  /\bEFM\s*Lab\b/i,
  /\bMechanical\s+Lab\b/i,
  /\bElectronics\s+Lab\b/i,
  /\bHardware\s+Lab\b/i,
  /\bCircuit\s+Lab\b/i,
  /\bSoftware\s+Lab\b/i,
  /\bComputer\s+Lab\b/i,
  /\bCLab-?\d*\b/i,
  /\b[A-Z]\d+(?:\.\d)?\b/i
];

function stripCapacity(text) {
  return text.replace(CAPACITY_RE, "").trim();
}

function isTeacherLine(line) {
  if (TEACHER_TITLE_RE.test(line)) return true;
  let words = line.split(/\s+/);
  if (words.length >= 2) {
    let first = words[0].replace(/\.$/, "").toUpperCase();
    if (DEPT_CODES.has(first)) {
      let rest = words.slice(1).join(" ");
      if (!looksLikeSubject(rest) && !matchRoom(rest)) {
        return true;
      }
    }
  }
  return false;
}

function cleanTeacherName(raw) {
  let cleaned = stripCapacity(raw).trim();
  let words = cleaned.split(/\s+/);
  if (words.length >= 2) {
    let first = words[0].replace(/\.$/, "").toUpperCase();
    if (DEPT_CODES.has(first)) {
      cleaned = words.slice(1).join(" ");
    }
  }
  
  let subjectCode = "";
  words = cleaned.split(/\s+/);
  if (words.length >= 3) {
    let lastWord = words[words.length - 1].trim();
    if (/^[A-Z]{2,4}$/.test(lastWord) && !DEPT_CODES.has(lastWord)) {
      subjectCode = lastWord;
      cleaned = words.slice(0, -1).join(" ");
    }
  }
  
  return { name: cleaned.trim(), subjectCode };
}

function looksLikeSubject(text) {
  let lower = text.toLowerCase();
  for (let kw of SUBJECT_KEYWORDS) {
    if (lower.includes(kw)) return true;
  }
  return false;
}

function matchRoom(text) {
  let stripped = stripCapacity(text);
  for (let pat of ROOM_PATTERNS) {
    let m = stripped.match(pat);
    if (m) return m[0];
  }
  return null;
}

function cleanRoomFromText(text) {
  let cleaned = text;
  for (let pat of ROOM_PATTERNS) {
    cleaned = cleaned.replace(pat, "");
  }
  return stripCapacity(cleaned).trim();
}

function cleanSubject(text) {
  let cleaned = cleanRoomFromText(text);
  cleaned = cleaned.replace(/\s{2,}/g, " ").trim();
  return cleaned;
}

function isNameContinuation(line) {
  let words = line.split(/\s+/);
  if (words.length === 0) return false;
  
  if (words.length >= 2 && words[0].endsWith('.')) {
    if (words[0].length <= 6 && words[1].length <= 6) {
      return false;
    }
  }
  
  if (words.length >= 2) {
    if (words.some(w => w.length > 5)) return false;
    if (line.length > 12) return false;
  }
  
  if (/^[A-Z]+\.\s+[A-Z]/i.test(line)) return false;
  
  if (words.length === 1 && words[0].length >= 2 && words[0].length <= 4 && words[0] === words[0].toUpperCase() && !DEPT_CODES.has(words[0])) {
    return false;
  }
  
  if (words.length === 1) {
    let word = words[0];
    if (word.length > 6 && /^[A-Z][a-z]+$/.test(word)) {
      let vowels = (word.toLowerCase().match(/[aeiou]/g) || []).length;
      if (vowels >= 2) return false;
    }
  }
  
  for (let w of words) {
    if (!/^[A-Z]/.test(w)) return false;
    if (!/^[A-Z][a-z]*\.?$/.test(w)) return false;
  }
  
  if (looksLikeSubject(line)) return false;
  if (matchRoom(line)) return false;
  
  return true;
}

function parseBatch(text) {
  if (!text) return null;
  let cleaned = text.replace(/\(.*?\)/g, "").trim().replace(/\s+/g, "");
  let parts = cleaned.split("-");
  if (parts.length >= 2) {
    let program = parts[1];
    return {
      batch: cleaned,
      department: program
    };
  }
  return {
    batch: cleaned,
    department: "Unknown"
  };
}

function parseClassCell(cellText) {
  if (!cellText) return null;
  let flat = cellText.replace(/\n/g, " ").trim();
  if (!flat || /Break|kaerB/i.test(flat)) return null;

  let lines = cellText.split("\n").map(l => l.trim()).filter(l => l);
  if (lines.length === 0) return null;

  let teacher = "Unknown";
  let room = "TBD";
  let subject = "";
  
  let teacherIdx = -1;
  let teacherContIdx = -1;
  let roomIdx = -1;

  for (let i = 0; i < lines.length; i++) {
    if (isTeacherLine(lines[i])) {
      let cleanedTeacher = cleanTeacherName(lines[i]);
      teacher = cleanedTeacher.name;
      teacherIdx = i;
      
      if (i + 1 < lines.length) {
        let nextLine = lines[i + 1];
        if (isNameContinuation(nextLine)) {
          teacher = teacher + " " + nextLine;
          teacherContIdx = i + 1;
        }
      }
      break;
    }
  }

  for (let i = lines.length - 1; i >= 0; i--) {
    if (i === teacherIdx || i === teacherContIdx) continue;
    let line = lines[i];
    let stripped = stripCapacity(line);
    let roomMatch = matchRoom(stripped);
    if (roomMatch) {
      let ratio = roomMatch.length / Math.max(stripped.length, 1);
      if (ratio > 0.35) {
        room = roomMatch;
        roomIdx = i;
        break;
      }
    }
  }

  let subjectParts = [];
  for (let i = 0; i < lines.length; i++) {
    if (i === teacherIdx || i === teacherContIdx) continue;
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
    
    // 2. Identify time headers
    let timeWords = [];
    for (let item of items) {
      if (/\b\d{1,2}:\d{2}\b/.test(item.str)) {
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
    
    let slotTimes = Array(7).fill(null).map(() => ({ start: "00:00", end: "00:00", isBreak: false }));
    const DEFAULT_TIMES = [
      { start: "00:00", end: "00:00", isBreak: false },
      { start: "08:00", end: "09:00", isBreak: false },
      { start: "09:00", end: "10:00", isBreak: false },
      { start: "10:00", end: "11:00", isBreak: false },
      { start: "11:00", end: "12:00", isBreak: false },
      { start: "12:00", end: "01:00", isBreak: true },
      { start: "01:00", end: "02:00", isBreak: false }
    ];
    for (let c = 0; c < 7; c++) {
      slotTimes[c] = { ...DEFAULT_TIMES[c] };
    }
    
    if (headerY !== -1) {
      let headerItems = items.filter(item => Math.abs(item.transform[5] - headerY) <= 8 && item.str.trim() !== '');
      for (let c = 1; c < 7; c++) {
        let col = GRID_COLUMNS[c];
        let colItems = headerItems.filter(item => {
          let centerX = item.transform[4] + (item.width || 0) / 2;
          return centerX >= col.minX && centerX < col.maxX;
        });
        colItems.sort((a, b) => a.transform[4] - b.transform[4]);
        let text = colItems.map(item => item.str).join(" ").trim();
        if (text) {
          if (/break|kaerb/i.test(text)) {
            slotTimes[c].isBreak = true;
          } else {
            let m = text.match(/(\d{1,2})[:.]?(\d{2})\s*-\s*(\d{1,2})[:.]?(\d{2})/);
            if (m) {
              slotTimes[c].start = `${m[1].padStart(2, '0')}:${m[2]}`;
              slotTimes[c].end = `${m[3].padStart(2, '0')}:${m[4]}`;
            }
          }
        }
      }
    }
    
    // 3. Cluster batch rows
    let col0Groups = {};
    for (let item of items) {
      let x = item.transform[4];
      let y = item.transform[5];
      if (x < 100 && item.str.trim() !== '') {
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
      if (BATCH_RE.test(text)) {
        rowStarts.push({ text: text, y: parseFloat(roundedY) });
      }
    }
    rowStarts.sort((a, b) => b.y - a.y);
    
    if (rowStarts.length === 0) continue;
    
    // 4. Construct cells
    let reconstructedRows = [];
    for (let i = 0; i < rowStarts.length; i++) {
      reconstructedRows.push({
        batch: rowStarts[i].text,
        cells: Array(7).fill(""),
        cellItems: Array(7).fill(null).map(() => [])
      });
    }
    
    for (let item of items) {
      let str = item.str.trim();
      if (str === '') continue;
      
      let x = item.transform[4];
      let y = item.transform[5];
      
      if (y > rowStarts[0].y + 15) continue;
      
      let targetRowIdx = -1;
      for (let i = 0; i < rowStarts.length; i++) {
        let startY = rowStarts[i].y + 12;
        let endY = i + 1 < rowStarts.length ? rowStarts[i+1].y + 12 : -9999;
        if (y <= startY && y > endY) {
          targetRowIdx = i;
          break;
        }
      }
      if (targetRowIdx === -1) continue;
      
      let targetColIdx = -1;
      let centerX = x + (item.width || 0) / 2;
      for (let colIdx = 0; colIdx < GRID_COLUMNS.length; colIdx++) {
        let col = GRID_COLUMNS[colIdx];
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
      for (let c = 0; c < 7; c++) {
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
    
    // 5. Parse cell content and merge consecutive columns (for lab slots)
    for (let row of reconstructedRows) {
      let batchInfo = parseBatch(row.batch);
      if (!batchInfo) continue;
      
      let c = 1;
      while (c <= 6) {
        let cellText = row.cells[c];
        if (!cellText || cellText.trim() === '') {
          c++;
          continue;
        }
        
        if (slotTimes[c].isBreak || /break|kaerb/i.test(cellText)) {
          c++;
          continue;
        }
        
        let parsed = parseClassCell(cellText);
        if (!parsed) {
          c++;
          continue;
        }
        
        let startTime = slotTimes[c].start;
        let endTime = slotTimes[c].end;
        
        let j = c + 1;
        while (j <= 6) {
          if (!row.cells[j] || row.cells[j].trim() === '') {
            if (slotTimes[j].isBreak) {
              break;
            }
            endTime = slotTimes[j].end;
            j++;
          } else {
            break;
          }
        }
        
        // Handle "(1 hr)" marker - adjust end time to be exactly 1 hour from start
        if (/(1\s*hr)/i.test(parsed.subject)) {
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
  let labCount = 0;
  
  timetablePreviewBody.innerHTML = '';
  const previewLimit = Math.min(10, sessions.length);
  
  for (let i = 0; i < previewLimit; i++) {
    const s = sessions[i];
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${s.batch || 'CORE-GEN'}</td>
      <td style="color: var(--text-title); font-weight: 500;">${s.subject || 'LECTURE'}</td>
      <td>${s.day} // ${s.start} - ${s.end}</td>
      <td style="color: var(--text-caption);">${s.teacher || 'STAFF'}</td>
    `;
    timetablePreviewBody.appendChild(tr);
  }
  
  sessions.forEach(s => {
    if (s.subject) {
      const cleanSub = s.subject.replace(/\s*\(\d*\s*hrs?\)\s*/gi, '')
                               .replace(/\s*\(\d*\s*hr\)\s*/gi, '')
                               .replace(/\s*\(Lab\)\s*/gi, '')
                               .trim();
      uniqueSubjects.add(cleanSub);
      
      if (s.subject.toLowerCase().includes('lab') || (s.room && s.room.toLowerCase().includes('lab'))) {
        labCount++;
      }
    }
  });

  statSessions.innerText = sessionCount;
  statCourses.innerText = uniqueSubjects.size;
  statLabs.innerText = labCount;
  timetableAnalytics.style.display = 'block';
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
    li.style.padding = '8px 12px';
    li.style.background = 'white';
    li.style.border = '1px solid var(--border-subtle)';
    li.style.borderRadius = '6px';
    li.style.fontSize = '11px';
    
    li.innerHTML = `
      <div style="display: flex; align-items: center; gap: 8px;">
        <i class="fa-solid ${file.name.toLowerCase().endsWith('.pdf') ? 'fa-file-pdf' : 'fa-file-code'}" style="color: var(--accent-indigo);"></i>
        <div>
          <strong style="color: var(--text-title);">${file.name}</strong>
          <span style="color: var(--text-muted); font-size: 9.5px; margin-left: 6px;">(${(file.size / 1024).toFixed(1)} KB)</span>
        </div>
      </div>
      <div style="display: flex; align-items: center; gap: 12px;">
        <span class="badge" style="background: rgba(79, 70, 229, 0.08); color: var(--accent-indigo); font-weight: bold; border: 1px solid rgba(79, 70, 229, 0.15);">${file.sessions.length} sessions</span>
        <button type="button" class="btn-remove-staged" onclick="removeStagedTimetableFile(${index})" style="background: transparent; border: none; color: var(--accent-rose); cursor: pointer; padding: 4px;" title="Remove file"><i class="fa-solid fa-trash-can"></i></button>
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
    const filename = `iris-v${vName}-release.apk`;
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
        throw new Error("Excel sheet contains too few rows. Header row 3 expected.");
      }
      
      // Header is on Row 3 (index 2)
      const headerRow = rows[2] || [];
      const rooms = [];
      for (let c = 2; c < headerRow.length; c++) {
        const val = headerRow[c];
        if (val !== undefined && val !== null) {
          rooms.push({ colIdx: c, name: String(val).trim() });
        }
      }
      
      if (rooms.length === 0) {
        throw new Error("No exam rooms/venues detected on row 3.");
      }
      
      logTerminal(`Detected ${rooms.length} exam rooms/venues in header.`, 'info');
      
      let r = 3; // Row 4 (index 3)
      let currentDate = null;
      let currentTime = null;
      
      while (r < rows.length) {
        const row = rows[r] || [];
        const nextRow = rows[r + 1] || [];
        
        const rowDate = row[0];
        const rowTime = row[1];
        
        const rowDateStr = (rowDate !== undefined && rowDate !== null) ? String(rowDate).trim() : "";
        const rowTimeStr = (rowTime !== undefined && rowTime !== null) ? String(rowTime).trim() : "";
        
        // Skip header/subheader rows
        if (rowDateStr.toLowerCase() === "date" || rowTimeStr.toLowerCase() === "time") {
          r += 1;
          continue;
        }
        
        // Skip empty rows
        if (!rowTimeStr) {
          r += 1;
          continue;
        }
        
        if (rowDateStr) {
          currentDate = rowDateStr;
        }
        currentTime = rowTimeStr;
        
        for (const room of rooms) {
          const batchCell = row[room.colIdx];
          const subjectCell = nextRow[room.colIdx];
          
          if (batchCell !== undefined && batchCell !== null && 
              subjectCell !== undefined && subjectCell !== null) {
            const batchStr = String(batchCell).trim();
            const subjectStr = String(subjectCell).trim();
            
            if (batchStr === "" || subjectStr === "") {
              continue;
            }
            
            if (batchStr.toLowerCase() === "date" || batchStr.toLowerCase() === "time" || 
                subjectStr.toLowerCase() === "date" || subjectStr.toLowerCase() === "time") {
              continue;
            }
            if (batchStr === room.name) {
              continue;
            }
            if (rooms.some(rm => rm.name === batchStr)) {
              continue;
            }
            
            const batches = splitCombinedCell(batchStr);
            const subjects = splitCombinedCell(subjectStr);
            
            const maxLen = Math.max(batches.length, subjects.length);
            for (let idx = 0; idx < maxLen; idx++) {
              const b = idx < batches.length ? batches[idx] : batches[batches.length - 1];
              const s = idx < subjects.length ? subjects[idx] : subjects[subjects.length - 1];
              
              parsedExams.push({
                date: currentDate || "Unknown Date",
                time: currentTime,
                room: room.name,
                batch: b,
                subject: s
              });
            }
          }
        }
        r += 2;
      }
      
      if (parsedExams.length === 0) {
        throw new Error("No exam entries extracted. Check format of sheet.");
      }
      
      logTerminal(`Successfully extracted ${parsedExams.length} individual exam slots.`, 'success');
      
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
  
  val = val.trim().replace(/-+$/, '');
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
        if (sections.every(s => s.length <= 3)) {
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

function startTelemetryECG() {
  // Disabled in favor of hardware-accelerated CSS biometric radar pulse signal beacons
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

// ==========================================================================
// ROLE-BASED ACCESS CONTROL (RBAC) CONTROLLERS
// ==========================================================================

let currentUserProfile = { role: 'admin', name: 'System' };

async function applyRolePermissions(user) {
  currentUserProfile = { role: 'student', name: 'System' };
  
  try {
    let userDoc = await db.collection('users').doc(user.uid).get();
    
    // First-time login: check if pre-authorized by email (using email as doc ID)
    if (!userDoc.exists && user.email) {
      logTerminal(`Profile checking: Checking pre-authorization for email <strong>${user.email}</strong>...`, 'info');
      const emailDocRef = db.collection('users').doc(user.email.toLowerCase().trim());
      const emailDoc = await emailDocRef.get();
      
      if (emailDoc.exists) {
        logTerminal(`Pre-authorization match! Porting permissions for <strong>${user.email}</strong>...`, 'success');
        const preAuthData = emailDoc.data();
        
        // Write profile to actual UID document
        await db.collection('users').doc(user.uid).set({
          email: user.email.toLowerCase().trim(),
          name: preAuthData.name || user.email.split('@')[0],
          role: preAuthData.role || 'student',
          updated_at: firebase.firestore.FieldValue.serverTimestamp()
        });
        
        // Copy assignments from the subcollection
        const assignmentsSnap = await emailDocRef.collection('assignments').get();
        for (const doc of assignmentsSnap.docs) {
          await db.collection('users').doc(user.uid).collection('assignments').doc(doc.id).set(doc.data());
          await emailDocRef.collection('assignments').doc(doc.id).delete();
        }
        
        // Delete the temporary email-indexed placeholder doc
        await emailDocRef.delete();
        logTerminal(`Access permissions successfully ported to session profile. Handshake complete.`, 'success');
        
        // Fetch the newly created profile doc
        userDoc = await db.collection('users').doc(user.uid).get();
      }
    }
    
    if (userDoc.exists) {
      const data = userDoc.data();
      currentUserProfile.role = data.role || 'student';
      currentUserProfile.name = data.name || user.email.split('@')[0];
    } else {
      // Default fallback for owner/main admin if doc not created yet
      if (user.email === 'malikaurangzaibahmed@gmail.com') {
        currentUserProfile.role = 'admin';
        currentUserProfile.name = 'Owner Admin';
        // Auto-create document to prevent checks next time
        await db.collection('users').doc(user.uid).set({
          email: user.email,
          name: 'Owner Admin',
          role: 'admin',
          updated_at: firebase.firestore.FieldValue.serverTimestamp()
        });
      } else {
        currentUserProfile.role = 'student'; // Fallback
      }
    }
  } catch (err) {
    console.error("Error reading user profile:", err);
    logTerminal(`Error loading user role: ${err.message}`, 'error');
  }

  logTerminal(`User identity mapped: <strong>${currentUserProfile.name}</strong> as <strong>${currentUserProfile.role.toUpperCase()}</strong>.`, 'info');

  // Load assignments if not main admin
  let assignments = [];
  try {
    if (currentUserProfile.role !== 'admin') {
      const snap = await db.collection('users').doc(user.uid).collection('assignments').get();
      assignments = snap.docs.map(doc => doc.id); // Array of strings (e.g. batch or batch_course)
    }
  } catch (err) {
    console.error("Error loading user assignments:", err);
  }

  // Adjust UI panel visibilities based on role
  const isUserAdmin = currentUserProfile.role === 'admin';
  const isCR = currentUserProfile.role === 'cr';
  const isProf = currentUserProfile.role === 'professor';

  // Toggle visible sections:
  // 1. Column 1 (Term Scheduler, OTA Software Releases)
  const col1Cards = document.querySelectorAll('.narrow-col .tech-card');
  if (col1Cards.length >= 2) {
    col1Cards[0].style.display = isUserAdmin ? 'block' : 'none'; // Term Scheduler
    col1Cards[1].style.display = isUserAdmin ? 'block' : 'none'; // OTA Releases
  }

  // 2. Column 2 (Timetables/Exams, Rollback, Inspectors)
  const tabBtnClasses = document.querySelector('[data-workspace-tab="classes"]');
  const tabBtnExams = document.querySelector('[data-workspace-tab="exams"]');
  
  // Find timetable database seeder card and rollback card and inspectors
  const timetableSeederCard = document.getElementById('timetable-dropzone') ? document.getElementById('timetable-dropzone').closest('.tech-card') : null;
  const rollbackCard = document.getElementById('rollback-ledger-body') ? document.getElementById('rollback-ledger-body').closest('.tech-card') : null;
  const inspectorClassesCard = document.getElementById('inspector-classes-body') ? document.getElementById('inspector-classes-body').closest('.tech-card') : null;
  const examConverterCard = document.getElementById('exams-dropzone') ? document.getElementById('exams-dropzone').closest('.tech-card') : null;
  const inspectorExamsCard = document.getElementById('inspector-exams-body') ? document.getElementById('inspector-exams-body').closest('.tech-card') : null;
  
  if (tabBtnClasses && tabBtnExams) {
    tabBtnClasses.style.display = isUserAdmin ? 'flex' : 'none';
    tabBtnExams.style.display = isUserAdmin ? 'flex' : 'none';
  }
  if (tabBtnUsers) {
    tabBtnUsers.style.display = isUserAdmin ? 'flex' : 'none';
  }
  if (timetableSeederCard) timetableSeederCard.style.display = isUserAdmin ? 'block' : 'none';
  if (rollbackCard) rollbackCard.style.display = isUserAdmin ? 'block' : 'none';
  if (inspectorClassesCard) inspectorClassesCard.style.display = isUserAdmin ? 'block' : 'none';
  if (examConverterCard) examConverterCard.style.display = isUserAdmin ? 'block' : 'none';
  if (inspectorExamsCard) inspectorExamsCard.style.display = isUserAdmin ? 'block' : 'none';

  // Target selectors config
  const targetTypeSelect = document.getElementById('broadcast-target-type');
  const targetDetailsRow = document.getElementById('target-details-row');
  const targetBatchSelect = document.getElementById('broadcast-target-batch');
  const targetCourseGroup = document.getElementById('target-course-group');
  const targetCourseSelect = document.getElementById('broadcast-target-course');

  // Reset dropdowns
  targetTypeSelect.innerHTML = '';
  targetBatchSelect.innerHTML = '<option value="">-- Choose Batch --</option>';
  targetCourseSelect.innerHTML = '<option value="">-- Choose Course --</option>';

  if (isUserAdmin) {
    // Admin: access to all targets
    targetTypeSelect.innerHTML = `
      <option value="global">Global (All Students)</option>
      <option value="batch">Specific Batch / Section</option>
      <option value="course">Specific Course / Class</option>
    `;
    targetTypeSelect.disabled = false;
    targetDetailsRow.style.display = 'none';
    targetCourseGroup.style.display = 'none';
    
    // Load all unique batches and courses from active Daily Class timetable to populate dropdowns
    populateAdminDropdowns();
  } else if (isCR) {
    // CR: restricted to batch-level announcements for assigned batches
    targetTypeSelect.innerHTML = `
      <option value="batch">Specific Batch / Section</option>
    `;
    targetTypeSelect.value = 'batch';
    targetTypeSelect.disabled = true;
    targetDetailsRow.style.display = 'flex';
    targetCourseGroup.style.display = 'none';

    // Populate batch dropdown with CR's assigned batches
    assignments.forEach(batch => {
      const opt = document.createElement('option');
      opt.value = batch;
      opt.innerText = batch;
      targetBatchSelect.appendChild(opt);
    });
  } else if (isProf) {
    // Professor: restricted to course-level announcements for assigned course+batch
    targetTypeSelect.innerHTML = `
      <option value="course">Specific Course / Class</option>
    `;
    targetTypeSelect.value = 'course';
    targetTypeSelect.disabled = true;
    targetDetailsRow.style.display = 'flex';
    targetCourseGroup.style.display = 'block';

    // Populate batch & course dropdowns from assignments (assignments are formatted as batch_course)
    const uniqueBatches = new Set();
    const parsedAssignments = assignments.map(a => {
      const idx = a.indexOf('_');
      if (idx !== -1) {
        return { batch: a.substring(0, idx), course: a.substring(idx + 1) };
      }
      return null;
    }).filter(Boolean);

    parsedAssignments.forEach(a => uniqueBatches.add(a.batch));
    uniqueBatches.forEach(batch => {
      const opt = document.createElement('option');
      opt.value = batch;
      opt.innerText = batch;
      targetBatchSelect.appendChild(opt);
    });

    targetBatchSelect.onchange = () => {
      targetCourseSelect.innerHTML = '<option value="">-- Choose Course --</option>';
      const selected = targetBatchSelect.value;
      parsedAssignments.filter(a => a.batch === selected).forEach(a => {
        const opt = document.createElement('option');
        opt.value = a.course;
        opt.innerText = a.course;
        targetCourseSelect.appendChild(opt);
      });
    };
  } else {
    // Standard student (should not log in, but handle gracefully)
    targetTypeSelect.innerHTML = `<option value="">Access Denied</option>`;
    targetTypeSelect.disabled = true;
    logTerminal('Warning: Student access mapped. Announcement broadcasting disabled.', 'warning');
  }
}

async function populateAdminDropdowns() {
  const targetBatchSelect = document.getElementById('broadcast-target-batch');
  const targetCourseSelect = document.getElementById('broadcast-target-course');
  if (!targetBatchSelect) return;

  try {
    const doc = await db.collection('config').doc('global').get();
    if (doc.exists) {
      const data = doc.data();
      const rawTimetable = data.active_timetable_json || '[]';
      const parsed = JSON.parse(rawTimetable);
      const sessions = Array.isArray(parsed) ? parsed : [];
      
      const batches = new Set();
      const coursesByBatch = {}; // { batch: Set(courses) }

      sessions.forEach(s => {
        const batch = (s.batch || s.class_name || s.section || '').toString().trim();
        const course = (s.subject || s.course || s.title || '').toString().trim();
        
        if (batch) {
          batches.add(batch);
          if (!coursesByBatch[batch]) {
            coursesByBatch[batch] = new Set();
          }
          if (course) {
            coursesByBatch[batch].add(course);
          }
        }
      });

      // Populate batch selector
      const sortedBatches = Array.from(batches).sort();
      sortedBatches.forEach(batch => {
        const opt = document.createElement('option');
        opt.value = batch;
        opt.innerText = batch;
        targetBatchSelect.appendChild(opt);
      });

      // Dynamic course populating based on selected batch
      targetBatchSelect.onchange = () => {
        targetCourseSelect.innerHTML = '<option value="">-- Choose Course --</option>';
        const selectedBatch = targetBatchSelect.value;
        if (selectedBatch && coursesByBatch[selectedBatch]) {
          const sortedCourses = Array.from(coursesByBatch[selectedBatch]).sort();
          sortedCourses.forEach(course => {
            const opt = document.createElement('option');
            opt.value = course;
            opt.innerText = course;
            targetCourseSelect.appendChild(opt);
          });
        }
      };
    }
  } catch (err) {
    console.error("Error populating admin dropdowns:", err);
  }
}

// Bind Target Type visibility toggle
document.getElementById('broadcast-target-type').addEventListener('change', (e) => {
  const type = e.target.value;
  const detailsRow = document.getElementById('target-details-row');
  const courseGroup = document.getElementById('target-course-group');

  if (type === 'global') {
    detailsRow.style.display = 'none';
  } else if (type === 'batch') {
    detailsRow.style.display = 'flex';
    courseGroup.style.display = 'none';
  } else if (type === 'course') {
    detailsRow.style.display = 'flex';
    courseGroup.style.display = 'block';
  }
});


// ==========================================================================
// USER ACCESS MANAGEMENT CONTROLLER (RBAC DASHBOARD)
// ==========================================================================

async function refreshUsersList() {
  if (!isConnected || !db) return;
  logTerminal('Querying user access profiles from database...', 'info');

  try {
    const usersSnap = await db.collection('users').get();
    const list = [];

    for (const doc of usersSnap.docs) {
      const data = doc.data();
      const userId = doc.id;
      
      // Load assignments for this user
      const assignSnap = await db.collection('users').doc(userId).collection('assignments').get();
      const assignments = assignSnap.docs.map(d => d.id);

      list.push({
        uid: userId,
        email: data.email || (userId.includes('@') ? userId : ''), // If pre-auth email doc
        name: data.name || 'Anonymous User',
        role: data.role || 'student',
        assignments: assignments
      });
    }

    activeUsersList = list;
    renderUsersList();
    logTerminal(`Successfully loaded <strong>${list.length}</strong> access profiles.`, 'success');
  } catch (err) {
    logTerminal(`Error loading user profiles: ${err.message}`, 'error');
    console.error(err);
  }
}

function renderUsersList() {
  if (!usersTableBody) return;
  usersTableBody.innerHTML = '';

  const searchVal = inspectorUsersSearch ? inspectorUsersSearch.value.toLowerCase().trim() : '';

  const filtered = activeUsersList.filter(u => {
    if (!searchVal) return true;
    return u.name.toLowerCase().includes(searchVal) ||
           u.email.toLowerCase().includes(searchVal) ||
           u.role.toLowerCase().includes(searchVal) ||
           u.assignments.some(a => a.toLowerCase().includes(searchVal));
  });

  if (filtered.length === 0) {
    usersTableBody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 20px;">No user profiles found.</td></tr>`;
    return;
  }

  filtered.forEach(u => {
    const tr = document.createElement('tr');
    
    // Format assignments nicely
    let assignsText = '--';
    if (u.assignments && u.assignments.length > 0) {
      assignsText = u.assignments.map(a => {
        const idx = a.indexOf('_');
        if (idx !== -1) {
          // professor mapping format: Batch: Course
          return `<span class="badge" style="background: rgba(59, 130, 246, 0.1); color: var(--accent-indigo); margin: 2px; display: inline-block;">${a.substring(0, idx)} (${a.substring(idx + 1)})</span>`;
        }
        // cr batch format
        return `<span class="badge" style="background: rgba(16, 185, 129, 0.1); color: #059669; margin: 2px; display: inline-block;">${a}</span>`;
      }).join(' ');
    }

    tr.innerHTML = `
      <td style="font-weight: 600; color: var(--text-title);">${u.name}</td>
      <td style="font-family: var(--font-mono); font-size: 11px;">${u.email || '<span style="color: var(--text-muted);">No Email</span>'}</td>
      <td>
        <span class="badge" style="background: ${u.role === 'admin' ? 'rgba(239, 68, 68, 0.1)' : u.role === 'professor' ? 'rgba(59, 130, 246, 0.1)' : u.role === 'cr' ? 'rgba(16, 185, 129, 0.1)' : 'rgba(0,0,0,0.05)'}; color: ${u.role === 'admin' ? 'var(--accent-rose)' : u.role === 'professor' ? 'var(--accent-indigo)' : u.role === 'cr' ? '#059669' : 'var(--text-muted)'}; font-weight: bold; text-transform: uppercase;">
          ${u.role}
        </span>
      </td>
      <td>${assignsText}</td>
      <td>
        <button type="button" class="btn btn-secondary btn-small" onclick="openUserEditModal('${u.uid}')" style="padding: 6px 12px; font-size: 11px;">
          <i class="fa-solid fa-user-pen"></i> Edit Scopes
        </button>
      </td>
    `;
    usersTableBody.appendChild(tr);
  });
}

async function openUserEditModal(uid) {
  if (!userEditModal) return;

  // Clear modal fields
  userEditUid.value = '';
  userEditEmail.value = '';
  userEditName.value = '';
  userEditRole.value = 'student';
  activeUserAssignments = [];
  
  userEditEmail.disabled = false;
  
  // Populate dropdowns from active timetable
  await populateModalDropdowns();

  if (!uid) {
    // Pre-Authorize User Mode
    document.getElementById('user-modal-title').innerText = 'Pre-Authorize Access Profile';
    document.getElementById('user-modal-desc').innerText = 'Enter details and credentials below. Access rights will activate when the user signs in with this email.';
  } else {
    // Edit User Mode
    document.getElementById('user-modal-title').innerText = 'User Access Profile';
    document.getElementById('user-modal-desc').innerText = 'Configure role hierarchy levels and scopes assigned to this profile.';
    
    const user = activeUsersList.find(u => u.uid === uid);
    if (user) {
      userEditUid.value = user.uid;
      userEditEmail.value = user.email;
      userEditName.value = user.name;
      userEditRole.value = user.role;
      activeUserAssignments = [...user.assignments];
      
      // If editing existing user, lock the email field to maintain index
      if (!user.uid.includes('@')) {
        userEditEmail.disabled = true;
      }
    }
  }

  handleUserRoleChangeUI();
  renderModalAssignmentsList();
  
  userEditModal.style.display = 'flex';
}

async function populateModalDropdowns() {
  if (!userAssignCrBatch || !userAssignProfBatch || !userAssignProfCourse || !userAssignProfTeacher) return;

  userAssignCrBatch.innerHTML = '<option value="">-- Select Batch --</option>';
  userAssignProfBatch.innerHTML = '<option value="">-- Batch --</option>';
  userAssignProfCourse.innerHTML = '<option value="">-- Course --</option>';
  userAssignProfTeacher.innerHTML = '<option value="">-- Map to Timetable Teacher --</option>';

  const sessions = await getTimetableSessions();
  const batches = new Set();
  const courses = new Set();
  const teachers = new Set();

  sessions.forEach(s => {
    const batch = (s.batch || s.class_name || s.section || '').toString().trim();
    const course = (s.subject || s.course || s.title || '').toString().trim();
    const teacher = (s.teacher || s.instructor || '').toString().trim();

    if (batch) batches.add(batch);
    if (course) courses.add(course);
    if (teacher && teacher !== 'Unknown' && teacher !== 'TBD') teachers.add(teacher);
  });

  // Populate Batch lists
  Array.from(batches).sort().forEach(b => {
    const opt1 = document.createElement('option');
    opt1.value = b;
    opt1.innerText = b;
    userAssignCrBatch.appendChild(opt1);

    const opt2 = document.createElement('option');
    opt2.value = b;
    opt2.innerText = b;
    userAssignProfBatch.appendChild(opt2);
  });

  // Populate Course list
  Array.from(courses).sort().forEach(c => {
    const opt = document.createElement('option');
    opt.value = c;
    opt.innerText = c;
    userAssignProfCourse.appendChild(opt);
  });

  // Populate Teacher list
  Array.from(teachers).sort().forEach(t => {
    const opt = document.createElement('option');
    opt.value = t;
    opt.innerText = t;
    userAssignProfTeacher.appendChild(opt);
  });
}

async function getTimetableSessions() {
  try {
    const doc = await db.collection('config').doc('global').get();
    if (doc.exists) {
      const data = doc.data();
      const raw = data.active_timetable_json || '[]';
      return JSON.parse(raw);
    }
  } catch (e) {
    console.error("Error loading active timetable json:", e);
  }
  return [];
}

function handleUserRoleChangeUI() {
  const role = userEditRole.value;
  if (role === 'cr' || role === 'professor') {
    userAssignmentsPanel.style.display = 'block';
    crAssignSection.style.display = role === 'cr' ? 'block' : 'none';
    profAssignSection.style.display = role === 'professor' ? 'block' : 'none';
  } else {
    userAssignmentsPanel.style.display = 'none';
  }
}

function renderModalAssignmentsList() {
  if (!userEditAssignmentsList) return;
  userEditAssignmentsList.innerHTML = '';

  if (activeUserAssignments.length === 0) {
    userEditAssignmentsList.innerHTML = `<li style="padding: 8px 12px; text-align: center; color: var(--text-muted); font-size: 11px;">No active scopes assigned.</li>`;
    return;
  }

  activeUserAssignments.forEach((a, idx) => {
    const li = document.createElement('li');
    li.style.display = 'flex';
    li.style.justify = 'space-between';
    li.style.alignItems = 'center';
    li.style.padding = '6px 12px';
    li.style.borderBottom = '1px solid var(--border-subtle)';
    li.style.fontSize = '11px';

    const cleanLabel = a.includes('_') ? a.replace('_', ' // Course: ') : `Batch: ${a}`;

    li.innerHTML = `
      <span style="font-family: var(--font-mono); color: var(--text-title);">${cleanLabel}</span>
      <button type="button" class="btn btn-logout" onclick="removeModalAssignment(${idx})" style="padding: 2px 6px; font-size: 9px; height: auto; border-color: rgba(239, 68, 68, 0.15); color: var(--accent-rose); background: rgba(239, 68, 68, 0.02);">
        <i class="fa-solid fa-xmark"></i> Remove
      </button>
    `;
    userEditAssignmentsList.appendChild(li);
  });
}

function removeModalAssignment(idx) {
  activeUserAssignments.splice(idx, 1);
  renderModalAssignmentsList();
}

function addCRAssignmentUI() {
  const batch = userAssignCrBatch.value;
  if (!batch) {
    showMossToast('Please select a batch scope.', 'warning');
    return;
  }
  if (activeUserAssignments.includes(batch)) {
    showMossToast('Scope already assigned.', 'warning');
    return;
  }
  activeUserAssignments.push(batch);
  renderModalAssignmentsList();
}

function addProfAssignmentUI() {
  const batch = userAssignProfBatch.value;
  const course = userAssignProfCourse.value;
  if (!batch || !course) {
    showMossToast('Please select both batch and course scopes.', 'warning');
    return;
  }
  const assignmentId = `${batch}_${course}`;
  if (activeUserAssignments.includes(assignmentId)) {
    showMossToast('Scope already assigned.', 'warning');
    return;
  }
  activeUserAssignments.push(assignmentId);
  renderModalAssignmentsList();
}

async function suggestProfessorAssignmentsUI() {
  const teacher = userAssignProfTeacher.value;
  if (!teacher) {
    showMossToast('Please select a teacher name.', 'warning');
    return;
  }

  logTerminal(`Scraping timetable schedule for teacher <strong>${teacher}</strong>...`, 'info');
  const sessions = await getTimetableSessions();
  let matches = 0;

  sessions.forEach(s => {
    const sTeacher = (s.teacher || s.instructor || '').toString().trim();
    if (sTeacher.toLowerCase() === teacher.toLowerCase()) {
      const batch = (s.batch || s.class_name || s.section || '').toString().trim();
      const course = (s.subject || s.course || s.title || '').toString().trim();
      
      if (batch && course) {
        const assignmentId = `${batch}_${course}`;
        if (!activeUserAssignments.includes(assignmentId)) {
          activeUserAssignments.push(assignmentId);
          matches++;
        }
      }
    }
  });

  renderModalAssignmentsList();
  if (matches > 0) {
    showMossToast(`Auto-assigned ${matches} scopes based on schedule!`, 'success');
    logTerminal(`Auto-fill complete: Registered <strong>${matches}</strong> timetabled schedules to professor profile.`, 'success');
  } else {
    showMossToast('No active courses found in timetable for this teacher.', 'warning');
    logTerminal('Auto-fill complete: No matches found in active daily timetable ledger.', 'warning');
  }
}

async function saveUserProfile() {
  const uid = userEditUid.value;
  const email = userEditEmail.value.trim().toLowerCase();
  const name = userEditName.value.trim();
  const role = userEditRole.value;

  if (!email || !name) {
    showMossToast('Email and Display Name parameters are required.', 'warning');
    return;
  }

  btnSaveUserProfile.disabled = true;
  btnSaveUserProfile.innerText = 'SAVING ACCESS PROFILE...';

  try {
    // If pre-authorizing new user, document ID is their email
    const docId = uid || email;

    // 1. Update Profile info
    const profileRef = db.collection('users').doc(docId);
    await profileRef.set({
      email: email,
      name: name,
      role: role,
      updated_at: firebase.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    // 2. Sync Scope Assignments
    const currentAssignmentsSnap = await profileRef.collection('assignments').get();
    
    // Delete existing scopes
    for (const doc of currentAssignmentsSnap.docs) {
      await profileRef.collection('assignments').doc(doc.id).delete();
    }

    // Write new scopes
    for (const scope of activeUserAssignments) {
      await profileRef.collection('assignments').doc(scope).set({
        assigned_at: firebase.firestore.FieldValue.serverTimestamp()
      });
    }

    logTerminal(`Successfully saved profile & scopes for <strong>${name}</strong> (${role}).`, 'success');
    showMossToast('Profile saved successfully!', 'success');
    
    userEditModal.style.display = 'none';
    refreshUsersList();
  } catch (err) {
    logTerminal(`Failed to save access profile: ${err.message}`, 'error');
    showMossToast(`Error: ${err.message}`, 'error');
  } finally {
    btnSaveUserProfile.disabled = false;
    btnSaveUserProfile.innerText = 'Save Access Profile & Permissions';
  }
}

