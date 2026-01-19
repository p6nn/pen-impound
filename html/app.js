let mode = null;
let vehicleData = null;
let myVehicles = [];
let allVehicles = [];
let activeVehicles = [];
let selectedId = null;
let isAuthorized = false;
let filter = 'all';
let query = '';
let logs = [];
let showingLogs = false;

const closeBtn = document.getElementById('close-btn');
const sidebar = document.getElementById('sidebar');
const content = document.getElementById('content');
const headerTitle = document.getElementById('header-title');
const searchInput = document.getElementById('search-input');
const logsBtn = document.getElementById('logs-btn');

const post = (endpoint, body) => {
  return fetch(`https://pen-impound/${endpoint}`, {
    method: 'POST',
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined
  }).then(r => r.json());
};

const setDisabled = (selector, disabled) => {
  document.querySelectorAll(selector).forEach(el => { el.disabled = disabled; });
};

closeBtn.addEventListener('click', closeUI);

searchInput.addEventListener('input', () => {
  query = (searchInput.value || '').toLowerCase();
  showRetrieveUI();
});

document.querySelectorAll('.filter-btn').forEach(btn => {
  btn.addEventListener('click', (e) => {
    const next = e.currentTarget.dataset.filter;
    if (next === 'logs') return showLogs();
    setFilter(next, e.currentTarget);
  });
});

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};

  if (action === 'openImpound') {
    mode = 'impound';
    vehicleData = data;
    showImpoundUI();
    document.body.classList.add('show');
    return;
  }

  if (action === 'openRetrieve') {
    mode = 'retrieve';
    myVehicles = Array.isArray(data?.vehicles) ? data.vehicles : [];
    isAuthorized = !!data?.isAuthorized;

    if (isAuthorized) loadAllVehicles();
    else showRetrieveUI();

    document.body.classList.add('show');
    return;
  }

  if (action === 'retrieveResult') {
    setDisabled('button', false);
    if (data?.success) closeUI();
    return;
  }

  if (action === 'impoundResult') {
    setDisabled('button, input, textarea', false);
    if (data?.success) closeUI();
    else headerTitle.textContent = 'Impound Vehicle (Failed)';
    return;
  }

  if (action === 'refreshVehicles') {
    setDisabled('button', false);

    if (isAuthorized) {
      loadAllVehicles();
    } else {
      post('getMyImpounded')
        .then(list => {
          myVehicles = Array.isArray(list) ? list : [];
          showRetrieveUI();
        })
        .catch(showRetrieveUI);
    }
  }
});

function closeUI() {
  document.body.classList.remove('show');
  sidebar.classList.remove('show');
  content.classList.remove('with-sidebar');
  post('close').catch(() => {});
}

function loadAllVehicles() {
  post('getAllImpounded')
    .then(list => {
      allVehicles = Array.isArray(list) ? list : [];
      activeVehicles = allVehicles.filter(v => v.released == null || Number(v.released) === 0);
      showRetrieveUI();
      updateStats();
    })
    .catch(() => {
      allVehicles = [];
      activeVehicles = [];
      showRetrieveUI();
      updateStats();
    });
}

function updateStats() {
  const totalImpounds = allVehicles.length;
  const totalFees = allVehicles.reduce((sum, v) => sum + Number(v.fee || 0), 0);

  document.getElementById('total-impounds').textContent = totalImpounds;
  document.getElementById('total-fees').textContent = `$${totalFees.toLocaleString()}`;
}

function setFilter(next, btnEl) {
  filter = next;
  showingLogs = false;

  document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
  btnEl?.classList.add('active');

  showRetrieveUI();
}

function showLogs() {
  showingLogs = true;

  document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
  logsBtn.classList.add('active');

  post('getImpoundLogs')
    .then(list => {
      logs = Array.isArray(list) ? list : [];
      renderLogs();
    })
    .catch(() => {
      logs = [];
      renderLogs();
    });
}

function renderLogs() {
  headerTitle.textContent = 'Activity Logs';

  let html = `
    <div class="logs-container">
      <div class="logs-header">
        <div class="logs-title">Recent Activity</div>
        <div class="logs-subtitle">Showing impound and release actions from the last 48 hours</div>
      </div>
      <div class="logs-list">
  `;

  if (!logs.length) {
    html += '<div class="empty-state">No recent activity</div>';
  } else {
    html += logs.map(log => {
      const when = log.action_type === 'released' && log.released_at
        ? new Date(log.released_at)
        : new Date(log.timestamp);

      const timeAgo = getTimeAgo(when);

      return `
        <div class="log-entry ${log.action_type}">
          <div class="log-header">
            <span class="log-badge ${log.action_type}">
              ${log.action_type === 'impounded'
                ? '<i class="fa-solid fa-car"></i> IMPOUNDED'
                : '<i class="fa-solid fa-check"></i> RELEASED'
              }
            </span>
            <span style="color:#868e96; font-size:12px;">${timeAgo}</span>
          </div>
          <div class="log-details">
            <div class="log-detail-row">
              <span class="log-label">Vehicle:</span>
              <span>${log.model} (${log.plate})</span>
            </div>
            <div class="log-detail-row">
              <span class="log-label">Owner:</span>
              <span>${log.owner_name}</span>
            </div>
            <div class="log-detail-row">
              <span class="log-label">Officer:</span>
              <span>${log.officer} (${String(log.job || '').toUpperCase()})</span>
            </div>
            ${log.action_type === 'impounded' ? `
              <div class="log-detail-row">
                <span class="log-label">Reason:</span>
                <span>${log.reason}</span>
              </div>
            ` : ''}
          </div>
        </div>
      `;
    }).join('');
  }

  html += `
      </div>
      <div class="button-group">
        <button class="btn btn-secondary" type="button" id="back-btn"><i class="fa-solid fa-arrow-left"></i> Back to Vehicles</button>
      </div>
    </div>
  `;

  content.innerHTML = html;
  document.getElementById('back-btn').addEventListener('click', backToVehicles);
}

function backToVehicles() {
  showingLogs = false;
  filter = 'all';

  document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
  document.querySelector('.filter-btn[data-filter="all"]')?.classList.add('active');

  if (isAuthorized) loadAllVehicles();
  else showRetrieveUI();
}

function getTimeAgo(date) {
  const seconds = Math.floor((Date.now() - date.getTime()) / 1000);

  const years = seconds / 31536000;
  if (years > 1) return `${Math.floor(years)} years ago`;

  const months = seconds / 2592000;
  if (months > 1) return `${Math.floor(months)} months ago`;

  const days = seconds / 86400;
  if (days > 1) return `${Math.floor(days)} days ago`;

  const hours = seconds / 3600;
  if (hours > 1) return `${Math.floor(hours)} hours ago`;

  const mins = seconds / 60;
  if (mins > 1) return `${Math.floor(mins)} minutes ago`;

  return `${Math.max(0, seconds)} seconds ago`;
}

function filterVehicles(list) {
  let out = list;

  if (query) {
    out = out.filter(v => {
      const plate = String(v.plate || '').toLowerCase();
      const owner = String(v.owner_name || '').toLowerCase();
      const model = String(v.model || '').toLowerCase();
      const report = String(v.report_id || '').toLowerCase();
      const cid = String(v.citizenid || '').toLowerCase();

      return (
        plate.includes(query) ||
        owner.includes(query) ||
        model.includes(query) ||
        report.includes(query) ||
        cid.includes(query)
      );
    });
  }

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const weekAgo = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);

  if (filter === 'today') out = out.filter(v => new Date(v.timestamp) >= today);
  if (filter === 'week') out = out.filter(v => new Date(v.timestamp) >= weekAgo);
  if (filter === 'overdue') {
    out = out.filter(v => {
      const days = Math.ceil((now - new Date(v.timestamp)) / 86400000);
      return days >= 30;
    });
  }

  return out;
}

function showImpoundUI() {
  headerTitle.textContent = 'Impound Vehicle';

  content.innerHTML = `
    <div class="vehicle-info">
      <div class="info-grid">
        <div class="info-item">
          <span class="info-icon"><i class="fa-solid fa-car"></i></span>
          <div class="info-content">
            <div class="info-label">Vehicle</div>
            <div class="info-value">${vehicleData.model}</div>
          </div>
        </div>

        <div class="info-item">
          <span class="info-icon"><i class="fa-solid fa-tag"></i></span>
          <div class="info-content">
            <div class="info-label">Plate</div>
            <div class="info-value">${vehicleData.plate}</div>
          </div>
        </div>

        <div class="info-item">
          <span class="info-icon"><i class="fa-solid fa-user"></i></span>
          <div class="info-content">
            <div class="info-label">Owner</div>
            <div class="info-value">${vehicleData.ownerName}</div>
          </div>
        </div>

        <div class="info-item">
          <span class="info-icon"><i class="fa-solid fa-gas-pump"></i></span>
          <div class="info-content">
            <div class="info-label">Fuel Level</div>
            <div class="info-value">${vehicleData.fuel}%</div>
          </div>
        </div>
      </div>
    </div>

    <div class="divider">
      <span class="divider-label">Impound Details</span>
    </div>

    <form id="impound-form">
      <div class="form-group">
        <label class="form-label required" for="reason">Impound Reason</label>
        <textarea
          class="form-textarea"
          id="reason"
          placeholder="Enter the reason for impounding this vehicle..."
          required
        ></textarea>
        <div class="error-message" id="reason-error" style="display:none;">Reason is required</div>
      </div>

      <div class="form-group">
        <label class="form-label" for="report-id">Report ID</label>
        <input
          type="text"
          class="form-input"
          id="report-id"
          placeholder="Optional: Enter report ID if applicable"
        />
      </div>

      <div class="button-group">
        <button type="button" class="btn btn-secondary" id="cancel-impound">Cancel</button>
        <button type="submit" class="btn btn-primary"><i class="fa-solid fa-check"></i> Impound Vehicle</button>
      </div>
    </form>
  `;

  const form = document.getElementById('impound-form');
  const cancel = document.getElementById('cancel-impound');
  const reasonEl = document.getElementById('reason');

  cancel.addEventListener('click', closeUI);
  reasonEl.addEventListener('input', () => {
    reasonEl.classList.remove('error');
    document.getElementById('reason-error').style.display = 'none';
  });

  form.addEventListener('submit', handleImpound);
}

function showRetrieveUI() {
  if (showingLogs) return;

  headerTitle.textContent = 'Retrieve Vehicle';

  if (isAuthorized) {
    sidebar.classList.add('show');
    content.classList.add('with-sidebar');
  } else {
    sidebar.classList.remove('show');
    content.classList.remove('with-sidebar');
  }

  let base = activeVehicles;
  if (query || filter !== 'all') base = allVehicles;

  const vehicles = isAuthorized ? filterVehicles(base) : myVehicles;

  if (!vehicles.length) {
    content.innerHTML = `
      <div class="empty-state">
        <p>${query || filter !== 'all' ? 'No vehicles match your search/filter' : 'No impounded vehicles found'}</p>
      </div>
    `;
    return;
  }

  content.innerHTML = vehicles.map(vehicle => {
    const releasedVal = Number(vehicle.released || 0);
    const released = !(vehicle.released == null || releasedVal === 0);
    const days = Math.ceil((Date.now() - new Date(vehicle.timestamp).getTime()) / 86400000);

    return `
      <div class="vehicle-card ${released ? 'released' : ''}" data-id="${vehicle.id}">
        <div class="vehicle-header">
          <div class="vehicle-title">
            <span class="info-icon" style="margin-top:0; width:24px; height:24px; font-size:20px;"><i class="fa-solid fa-car"></i></span>
            <div>
              <div class="vehicle-name">${vehicle.model}</div>
              <span class="badge badge-outline">${vehicle.plate}</span>
            </div>
          </div>
          ${
            released
              ? `<span class="badge badge-outline">RELEASED</span>`
              : `<span class="badge badge-red">$${Number(vehicle.fee || 0)}</span>`
          }
        </div>

        <div class="vehicle-details">
          ${
            isAuthorized ? `
              <div class="detail-item">
                <span class="detail-icon"><i class="fa-solid fa-user"></i></span>
                <div class="detail-content">
                  <div class="detail-label">Owner</div>
                  <div class="detail-value">${vehicle.owner_name}</div>
                </div>
              </div>
            ` : ''
          }

          <div class="detail-item">
            <span class="detail-icon"><i class="fa-solid fa-user-shield"></i></span>
            <div class="detail-content">
              <div class="detail-label">Officer</div>
              <div class="detail-value">${vehicle.officer}</div>
            </div>
          </div>

          <div class="detail-item">
            <span class="detail-icon"><i class="fa-solid fa-building"></i></span>
            <div class="detail-content">
              <div class="detail-label">Department</div>
              <div class="detail-value">${String(vehicle.job || '').toUpperCase()}</div>
            </div>
          </div>

          <div class="detail-item" style="grid-column: 1 / -1;">
            <span class="detail-icon"><i class="fa-solid fa-file-lines"></i></span>
            <div class="detail-content">
              <div class="detail-label">Reason</div>
              <div class="detail-value">${vehicle.reason}</div>
            </div>
          </div>

          <div class="detail-item" style="grid-column: 1 / -1;">
            <span class="detail-icon"><i class="fa-solid fa-clock"></i></span>
            <div class="detail-content">
              <div class="detail-label">Impounded</div>
              <div class="detail-value">${new Date(vehicle.timestamp).toLocaleString()} (${days} days ago)</div>
            </div>
          </div>

          ${vehicle.released_at && released ? `
            <div class="detail-item" style="grid-column: 1 / -1;">
              <span class="detail-icon"><i class="fa-solid fa-check"></i></span>
              <div class="detail-content">
                <div class="detail-label">Released</div>
                <div class="detail-value">${new Date(vehicle.released_at).toLocaleString()}</div>
              </div>
            </div>
          ` : ''}

          ${vehicle.report_id ? `
            <div class="detail-item" style="grid-column: 1 / -1;">
              <div class="detail-content">
                <div class="detail-label">Report ID: ${vehicle.report_id}</div>
              </div>
            </div>
          ` : ''}
        </div>

        ${
          !released ? `
            <div class="button-group" id="actions-${vehicle.id}" style="display:none;">
              <button type="button" class="btn btn-secondary" data-action="cancel">Cancel</button>
              ${
                isAuthorized ? `
                  <button type="button" class="btn btn-success" data-action="release" data-id="${vehicle.id}">
                    <i class="fa-solid fa-lock-open"></i> Release (No Charge)
                  </button>
                ` : `
                  <button type="button" class="btn btn-primary" data-action="retrieve" data-id="${vehicle.id}">
                    <i class="fa-solid fa-credit-card"></i> Pay ${Number(vehicle.fee || 0)} & Retrieve
                  </button>
                `
              }
            </div>
          ` : ''
        }
      </div>
    `;
  }).join('');

  content.querySelectorAll('.vehicle-card').forEach(card => {
    card.addEventListener('click', () => {
      const id = Number(card.dataset.id);
      const vehicle = vehicles.find(v => v.id === id);
      const released = vehicle && !(vehicle.released == null || Number(vehicle.released || 0) === 0);
      if (released) return;
      selectVehicle(id);
    });
  });

  content.querySelectorAll('[data-action="cancel"]').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      selectVehicle(null);
    });
  });

  content.querySelectorAll('[data-action="retrieve"]').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      retrieveVehicle(Number(btn.dataset.id));
    });
  });

  content.querySelectorAll('[data-action="release"]').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      releaseVehicle(Number(btn.dataset.id));
    });
  });
}

function selectVehicle(id) {
  document.querySelectorAll('[id^="actions-"]').forEach(el => { el.style.display = 'none'; });
  document.querySelectorAll('.vehicle-card').forEach(el => el.classList.remove('selected'));

  if (id && id !== selectedId) {
    document.getElementById(`actions-${id}`)?.style.setProperty('display', 'flex');
    document.querySelector(`.vehicle-card[data-id="${id}"]`)?.classList.add('selected');
    selectedId = id;
    return;
  }

  selectedId = null;
}

function handleImpound(e) {
  e.preventDefault();

  const reasonEl = document.getElementById('reason');
  const reportEl = document.getElementById('report-id');

  const reason = (reasonEl.value || '').trim();
  const reportId = (reportEl.value || '').trim();

  if (!reason) {
    reasonEl.classList.add('error');
    document.getElementById('reason-error').style.display = 'block';
    return;
  }

  setDisabled('button, input, textarea', true);

  post('impoundVehicle', { ...vehicleData, reason, reportId: reportId || null })
    .catch(() => setDisabled('button, input, textarea', false));
}

function retrieveVehicle(id) {
  setDisabled('button', true);

  post('retrieveVehicle', { id })
    .catch(() => setDisabled('button', false));
}

function releaseVehicle(id) {
  setDisabled('button', true);

  post('releaseVehicle', { id })
    .catch(() => setDisabled('button', false));
}

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') closeUI();
});