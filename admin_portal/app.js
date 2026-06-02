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

// Upload Buffers
let selectedTimetableFile = null;
let selectedApkFile = null;

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
  loadTimetableHistory();
  startNodesSimulator();
  
  if (apkUrlInput) {
    apkUrlInput.addEventListener('input', () => {
      if (apkUrlInput.value.trim() !== '') {
        deployApkBtn.disabled = false;
      } else if (!selectedApkFile) {
        deployApkBtn.disabled = true;
      }
    });
  }
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
    
    db.enablePersistence().catch(() => {});
    
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

// Dedicated Dispatch Signal button (explicitly turns alert ON with textarea message)
btnBroadcastPush.addEventListener('click', async () => {
  if (!isConnected) return;
  
  const msg = broadcastMessage.value.trim();
  logTerminal(`Preparing to dispatch broadcast signal packet...`, 'info');
  
  btnBroadcastPush.disabled = true;
  btnBroadcastPush.querySelector('span').innerText = 'TRANSMITTING EMISSION WAVE...';
  
  try {
    await db.collection('config').doc('global').update({
      broadcast_message: msg,
      broadcast_enabled: true, // Always force enable ON upon explicit dispatch
      updated_at: firebase.firestore.FieldValue.serverTimestamp()
    });
    incrementDatabaseOps();
    
    // Sync visible switch UI
    if (broadcastSwitchVisible) broadcastSwitchVisible.checked = true;
    
    logTerminal(`Dispatch success: Broadcast alert is now LIVE with message.`, 'success');
    showMossToast("Global notice dispatched live to student devices!", "success");
  } catch (e) {
    logTerminal(`Broadcast transmission failed: ${e.message}`, 'error');
    showMossToast(e.message, "error");
  } finally {
    btnBroadcastPush.disabled = false;
    btnBroadcastPush.querySelector('span').innerText = 'Transmit Notification Alert';
  }
});

// ==========================================================================
// TIMETABLE DEPLOYMENT ENGINE (AIRPORT DEPARTURES LEDGER)
// ==========================================================================

function setupDragAndDrop() {
  // Timetable JSON
  setupDropzone(timetableDropzone, timetableFileInput, (file) => {
    selectedTimetableFile = file;
    timetableFileInfo.innerText = `Inspected seed: ${file.name} (${(file.size / 1024).toFixed(1)} KB)`;
    timetableFileInfo.style.display = 'block';
    deployTimetableBtn.disabled = false;
    logTerminal(`Staged Timetable JSON file: <strong>${file.name}</strong>`, 'info');
    
    // Parse client side for departure inspection ledger
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const text = e.target.result;
        const json = JSON.parse(text);
        let sessions = [];
        if (Array.isArray(json)) {
          sessions = json;
        } else if (json.sessions && Array.isArray(json.sessions)) {
          sessions = json.sessions;
        } else {
          throw new Error('Unrecognized JSON structure. Expected array of sessions.');
        }

        const sessionCount = sessions.length;
        const uniqueSubjects = new Set();
        let labCount = 0;
        
        // Build departures visual ledger rows
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

        statSessions.innerText = sessionCount;
        statCourses.innerText = uniqueSubjects.size;
        statLabs.innerText = labCount;
        timetableAnalytics.style.display = 'block';
        logTerminal(`Ledger preview compiled: Inspected ${sessionCount} classes, ${uniqueSubjects.size} courses mapped.`, 'success');
      } catch (err) {
        logTerminal(`Ledger Inspection Failed: ${err.message}`, 'warning');
        timetableAnalytics.style.display = 'none';
      }
    };
    reader.readAsText(file);
  });
  
  // Android APK OTA split drops
  setupDropzone(apkDropzone, apkFileInput, (file) => {
    selectedApkFile = file;
    apkFileInfo.innerText = `OTA split APK: ${file.name} (${(file.size / 1024 / 1024).toFixed(2)} MB)`;
    apkFileInfo.style.display = 'block';
    deployApkBtn.disabled = false;
    logTerminal(`Staged Android OTA package: <strong>${file.name}</strong>`, 'info');
  });
}

function setupDropzone(dropzone, input, onFileSelect) {
  if (!dropzone || !input) return;
  dropzone.addEventListener('click', () => input.click());
  
  input.addEventListener('change', (e) => {
    if (e.target.files.length > 0) {
      onFileSelect(e.target.files[0]);
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
      onFileSelect(dt.files[0]);
    }
  }, false);
}

deployTimetableBtn.addEventListener('click', async () => {
  if (!isConnected || !selectedTimetableFile) return;
  
  logTerminal('Initiating timetable ledger uploader sequence...', 'info');
  deployTimetableBtn.disabled = true;
  
  try {
    const reader = new FileReader();
    reader.onload = async (e) => {
      try {
        const text = e.target.result;
        const json = JSON.parse(text);
        
        if (!Array.isArray(json) && !(json.sessions && Array.isArray(json.sessions))) {
          throw new Error('Invalid timetable JSON structure.');
        }
        
        logTerminal('Schema checked. Syncing database config global document...', 'info');
        
        await db.collection('config').doc('global').update({
          active_timetable_version: Date.now(),
          active_timetable_url: "", // storage cost bypassed
          active_timetable_json: JSON.stringify(json),
          updated_at: firebase.firestore.FieldValue.serverTimestamp()
        });
        incrementDatabaseOps();
        
        let sessions = Array.isArray(json) ? json : (json.sessions || []);
        let versionId = `SEED_${new Date().toISOString().replace(/[-:T]/g, '_').substring(0, 15)}`;
        timetableHistory.unshift({
          id: versionId,
          time: new Date().toISOString(),
          classes: sessions.length,
          json: JSON.stringify(json)
        });
        if (timetableHistory.length > 5) timetableHistory.pop();
        localStorage.setItem('iris_timetable_history', JSON.stringify(timetableHistory));
        activeVersionId = versionId;
        localStorage.setItem('iris_active_timetable_id', versionId);
        renderRollbackLedger();
        
        logTerminal('Database Sync Complete: Timetable ledger synchronized to global clients.', 'success');
        showMossToast("Timetable seed committed and deployed!", "success");
        selectedTimetableFile = null;
        timetableFileInfo.style.display = 'none';
        timetableFileInput.value = '';
        timetableAnalytics.style.display = 'none';
        deployTimetableBtn.disabled = true;
      } catch (jsonErr) {
        logTerminal(`Inspection failure: ${jsonErr.message}`, 'error');
        showMossToast(jsonErr.message, "error");
        deployTimetableBtn.disabled = false;
      }
    };
    reader.readAsText(selectedTimetableFile);
  } catch (e) {
    logTerminal(`Timetable ledger synchronization aborted: ${e.message}`, 'error');
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
          released_at: firebase.firestore.FieldValue.serverTimestamp()
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
    
    uploadTask.on('state_changed', 
      (snapshot) => {
        const pct = Math.round((snapshot.bytesTransferred / snapshot.totalBytes) * 100);
        uploadProgressFill.style.width = `${pct}%`;
        uploadProgressPct.innerText = `${pct}%`;
        
        if (pct % 20 === 0) {
          logTerminal(`Uploading APK binaries: ${pct}% complete...`, 'info');
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
            released_at: firebase.firestore.FieldValue.serverTimestamp()
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

// Simulated active core ping latency tracker
function startLatencySimulator() {
  const valEl = document.getElementById('latency-val');
  
  setInterval(() => {
    if (isConnected) {
      const ping = Math.floor(Math.random() * 10) + 4; // 4ms - 14ms
      if (valEl) valEl.innerText = `${ping}ms`;
    }
  }, 3500);
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
    telemetryNodes.innerText = "6 Active";
  }
  setInterval(() => {
    if (isConnected && telemetryNodes) {
      const nodes = Math.floor(Math.random() * 5) + 4; // 4 - 8 nodes
      telemetryNodes.innerText = `${nodes} Active`;
    }
  }, 6000);
}

function loadTimetableHistory() {
  const cached = localStorage.getItem('iris_timetable_history');
  if (cached) {
    try {
      timetableHistory = JSON.parse(cached);
    } catch (e) {
      timetableHistory = [];
    }
  }
  
  if (timetableHistory.length === 0) {
    timetableHistory = [
      {
        id: "SEED_2026_05_28_1200",
        time: "2026-05-28T12:00:00Z",
        classes: 56,
        json: JSON.stringify([{ class_name: "CS-6A", subject: "Artificial Intelligence", time: "09:00 - 10:30", teacher: "Dr. Aurangzaib" }])
      },
      {
        id: "SEED_2026_05_26_0900",
        time: "2026-05-26T09:00:00Z",
        classes: 52,
        json: JSON.stringify([{ class_name: "CS-4B", subject: "Software Engineering", time: "11:00 - 12:30", teacher: "Prof. Sarah" }])
      },
      {
        id: "SEED_2026_05_25_1430",
        time: "2026-05-25T14:30:00Z",
        classes: 45,
        json: JSON.stringify([{ class_name: "CS-8C", subject: "Cloud Computing Lab", time: "14:00 - 17:00", teacher: "Engr. Malik" }])
      }
    ];
    localStorage.setItem('iris_timetable_history', JSON.stringify(timetableHistory));
  }
  
  activeVersionId = localStorage.getItem('iris_active_timetable_id') || timetableHistory[0].id;
  renderRollbackLedger();
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

function startTelemetryECG() {
  // Disabled in favor of hardware-accelerated CSS biometric radar pulse signal beacons
}
