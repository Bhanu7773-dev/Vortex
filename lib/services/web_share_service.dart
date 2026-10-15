import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:vortex/services/connection_manager.dart';

class WebShareFileItem {
  final String path;
  final String name;
  final int sizeBytes;

  WebShareFileItem({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  String get sizeFormatted {
    if (sizeBytes >= 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeBytes >= 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$sizeBytes B';
  }

  Map<String, dynamic> toJson(int id) => {
        'id': id,
        'name': name,
        'size': sizeBytes,
        'sizeFormatted': sizeFormatted,
      };
}

class WebShareService extends ChangeNotifier {
  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;

  final List<WebShareFileItem> _sharedFiles = [];
  List<WebShareFileItem> get sharedFiles => List.unmodifiable(_sharedFiles);

  final List<WebShareFileItem> _receivedFromWeb = [];
  List<WebShareFileItem> get receivedFromWeb =>
      List.unmodifiable(_receivedFromWeb);

  String? _detectedIp;
  String? get detectedIp => _detectedIp;

  int get port => ConnectionManager.serverFixedPort;

  String get webPortalUrl {
    final ip = _detectedIp ?? '127.0.0.1';
    return 'http://$ip:$port/';
  }

  WebShareService() {
    refreshLocalIp();
  }

  bool _isUploadCancelled = false;
  bool get isUploadCancelled => _isUploadCancelled;

  void markUploadCancelled() {
    _isUploadCancelled = true;
    notifyListeners();
  }

  void resetUploadCancelled() {
    _isUploadCancelled = false;
  }

  void toggleWebShare(bool enabled) {
    _isEnabled = enabled;
    notifyListeners();
  }

  Future<void> refreshLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.')) {
            _detectedIp = addr.address;
            notifyListeners();
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[WebShare] Failed to detect IP: $e');
    }
  }

  void addFiles(List<String> filePaths) {
    for (final path in filePaths) {
      final file = File(path);
      if (file.existsSync()) {
        final name = path.split(Platform.pathSeparator).last;
        final size = file.lengthSync();
        if (!_sharedFiles.any((f) => f.path == path)) {
          _sharedFiles.add(WebShareFileItem(
            path: path,
            name: name,
            sizeBytes: size,
          ));
        }
      }
    }
    notifyListeners();
  }

  void removeFile(int index) {
    if (index >= 0 && index < _sharedFiles.length) {
      _sharedFiles.removeAt(index);
      notifyListeners();
    }
  }

  void clearSharedFiles() {
    _sharedFiles.clear();
    notifyListeners();
  }

  void registerReceivedFile(String relativePath, String absolutePath) {
    final file = File(absolutePath);
    final size = file.existsSync() ? file.lengthSync() : 0;
    _receivedFromWeb.insert(
      0,
      WebShareFileItem(
        path: absolutePath,
        name: relativePath.split('/').last,
        sizeBytes: size,
      ),
    );
    notifyListeners();
  }

  /// Handles incoming HTTP requests for Web Share features.
  /// Returns `true` if the request was handled, `false` otherwise.
  Future<bool> handleHttpRequest(HttpRequest request) async {
    if (!_isEnabled) return false;

    final path = request.uri.path;

    // ── 1. Serve Web Portal HTML ─────────────────────────────────────────────
    if (path == '/' || path == '/share') {
      final html = _buildPortalHtml();
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..headers.set('Cache-Control', 'no-cache, no-store, must-revalidate')
        ..headers.set('Pragma', 'no-cache')
        ..headers.set('Expires', '0')
        ..write(html);
      await request.response.close();
      return true;
    }

    // ── 2. Return JSON list of shared files ─────────────────────────────────
    if (path == '/api/shared-files') {
      final list = [
        for (int i = 0; i < _sharedFiles.length; i++) _sharedFiles[i].toJson(i),
      ];
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(list));
      await request.response.close();
      return true;
    }

    // ── 2b. Return upload cancellation status (used by browser to halt instantly)
    if (path == '/api/upload-status') {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..headers.set('Cache-Control', 'no-cache, no-store, must-revalidate')
        ..headers.set('Pragma', 'no-cache')
        ..headers.set('Expires', '0')
        ..write(jsonEncode({'cancelled': _isUploadCancelled}));
      await request.response.close();
      return true;
    }

    // ── 3. File Download ─────────────────────────────────────────────────────
    if (path == '/download') {
      final idParam = request.uri.queryParameters['id'];
      final id = int.tryParse(idParam ?? '');

      if (id == null || id < 0 || id >= _sharedFiles.length) {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('File not found');
        await request.response.close();
        return true;
      }

      final item = _sharedFiles[id];
      final file = File(item.path);

      if (!file.existsSync()) {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('File on device no longer exists');
        await request.response.close();
        return true;
      }

      final fileName = Uri.encodeComponent(item.name);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.binary
        ..headers.set('Content-Disposition', 'attachment; filename*=UTF-8\'\'$fileName')
        ..contentLength = item.sizeBytes;

      await request.response.addStream(file.openRead());
      await request.response.close();
      return true;
    }

    // ── 4. Favicon ───────────────────────────────────────────────────────────
    if (path == '/favicon.ico') {
      request.response
        ..statusCode = HttpStatus.noContent
        ..close();
      return true;
    }

    return false;
  }

  String _buildPortalHtml() {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Vortex Web</title>
  <style>
    :root {
      --bg: #000000;
      --card-white: #F3F4EF;
      --card-dark: #0E1115;
      --card-dark-border: #1C2128;
      --lime: #C6F36B;
      --text-muted: #78828A;
      --reticle-color: #2B3037;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: var(--bg);
      color: #FFFFFF;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      padding: 36px 32px;
      -webkit-font-smoothing: antialiased;
    }
    .wrapper {
      max-width: 1240px;
      width: 100%;
      margin: 0 auto;
      display: flex;
      flex-direction: column;
      flex: 1;
    }

    /* Top Navigation Header */
    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 28px;
    }
    .brand {
      font-size: 22px;
      font-weight: 800;
      letter-spacing: -0.4px;
      display: flex;
      align-items: center;
    }
    .brand-vortex { color: #FFFFFF; }
    .brand-web { color: var(--lime); margin-left: 6px; }

    .status-badge {
      display: flex;
      align-items: center;
      gap: 7px;
      font-size: 13px;
      font-weight: 500;
      color: var(--text-muted);
    }
    .status-dot {
      width: 7px;
      height: 7px;
      background-color: var(--lime);
      border-radius: 50%;
      display: inline-block;
      box-shadow: 0 0 8px rgba(198, 243, 107, 0.4);
    }

    /* Main Grid */
    .portal-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 24px;
      flex: 1;
      align-items: stretch;
    }
    @media (max-width: 860px) {
      body { padding: 20px 16px; }
      .portal-grid { grid-template-columns: 1fr; gap: 20px; }
    }

    /* ─── Left Card: Send Files (Drop Zone) ─── */
    .card-send {
      background-color: var(--card-white);
      border-radius: 28px;
      padding: 36px;
      position: relative;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      min-height: 520px;
      color: #000000;
      cursor: pointer;
      user-select: none;
      transition: transform 0.15s ease, box-shadow 0.2s ease;
    }
    .card-send.dragover {
      box-shadow: 0 0 0 3px var(--lime), 0 12px 36px rgba(198, 243, 107, 0.25);
      transform: translateY(-2px);
    }

    /* Reticle Corner Brackets (┌ ┐ └ ┘) */
    .reticle {
      position: absolute;
      width: 14px;
      height: 14px;
      pointer-events: none;
    }
    .reticle-tl { top: 16px; left: 16px; border-top: 2px solid var(--reticle-color); border-left: 2px solid var(--reticle-color); }
    .reticle-tr { top: 16px; right: 16px; border-top: 2px solid var(--reticle-color); border-right: 2px solid var(--reticle-color); }
    .reticle-bl { bottom: 16px; left: 16px; border-bottom: 2px solid var(--reticle-color); border-left: 2px solid var(--reticle-color); }
    .reticle-br { bottom: 16px; right: 16px; border-bottom: 2px solid var(--reticle-color); border-right: 2px solid var(--reticle-color); }

    .card-label {
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 1.2px;
      text-transform: uppercase;
      color: var(--text-muted);
    }

    .upload-icon-circle {
      width: 50px;
      height: 50px;
      border-radius: 50%;
      background: #000000;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-top: 32px;
      margin-bottom: 24px;
    }
    .upload-icon-circle svg {
      width: 22px;
      height: 22px;
      stroke: var(--lime);
      stroke-width: 2.4;
      fill: none;
    }

    .hero-title {
      font-size: 46px;
      font-weight: 850;
      letter-spacing: -1.4px;
      line-height: 1.08;
      color: #000000;
    }
    .hero-sub {
      font-size: 20px;
      font-weight: 500;
      color: #555E68;
      margin-top: 8px;
    }

    .send-bottom {
      display: flex;
      align-items: flex-end;
      justify-content: space-between;
      gap: 16px;
      margin-top: 48px;
    }
    .device-compat {
      font-size: 12px;
      font-weight: 500;
      color: var(--text-muted);
      max-width: 220px;
      line-height: 1.45;
    }
    .btn-browse {
      background: #000000;
      color: var(--lime);
      border-radius: 999px;
      padding: 12px 24px;
      font-size: 14px;
      font-weight: 700;
      border: none;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      transition: background-color 0.15s, transform 0.1s;
    }
    .btn-browse:hover { background: #181C20; }
    .btn-browse:active { transform: scale(0.97); }

    /* Upload Progress Box inside Send card */
    .upload-progress-box {
      display: none;
      background: #FFFFFF;
      border: 1px solid #E0E2DA;
      border-radius: 16px;
      padding: 16px 20px;
      margin-top: 24px;
    }
    .upload-status-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 13px;
      font-weight: 600;
      color: #000000;
      margin-bottom: 8px;
    }
    .upload-track {
      width: 100%;
      height: 6px;
      background: #E5E7EB;
      border-radius: 3px;
      overflow: hidden;
    }
    .upload-bar {
      width: 0%;
      height: 100%;
      background: #000000;
      border-radius: 3px;
      transition: width 0.15s ease;
    }
    .btn-cancel-transfer {
      margin-top: 10px;
      background: transparent;
      color: #DC2626;
      border: 1px solid #FCA5A5;
      border-radius: 8px;
      padding: 5px 12px;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
    }
    .btn-cancel-transfer:hover { background: #FEE2E2; }

    #fileInput { display: none; }

    /* ─── Right Card: Download from Phone ─── */
    .card-receive {
      background-color: var(--card-dark);
      border: 1px solid var(--card-dark-border);
      border-radius: 28px;
      padding: 36px;
      display: flex;
      flex-direction: column;
      min-height: 520px;
    }

    .counter-display {
      display: flex;
      align-items: baseline;
      gap: 12px;
      margin-top: 28px;
      margin-bottom: 16px;
    }
    .counter-number {
      font-size: 72px;
      font-weight: 850;
      line-height: 1;
      letter-spacing: -2px;
      color: #323A44;
      transition: color 0.25s ease;
    }
    .counter-number.has-files {
      color: var(--lime);
    }
    .counter-label {
      font-size: 14px;
      font-weight: 500;
      color: var(--text-muted);
    }

    .empty-desc {
      font-size: 14px;
      font-weight: 400;
      color: #8C96A2;
      line-height: 1.6;
      max-width: 380px;
      margin-bottom: 36px;
    }

    .table-container {
      margin-top: auto;
      display: flex;
      flex-direction: column;
    }
    .table-header {
      display: flex;
      justify-content: space-between;
      font-size: 11px;
      font-weight: 700;
      color: #4E5762;
      letter-spacing: 1px;
      text-transform: uppercase;
      padding-bottom: 12px;
      border-bottom: 1px solid #1C2128;
    }
    .table-rule {
      height: 1px;
      background-color: #1C2128;
      margin-top: 14px;
    }

    .file-list {
      display: flex;
      flex-direction: column;
      max-height: 260px;
      overflow-y: auto;
    }
    .file-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 14px 0;
      border-bottom: 1px solid #161A20;
    }
    .file-row:last-child { border-bottom: none; }
    .file-title-box {
      display: flex;
      flex-direction: column;
      gap: 2px;
      overflow: hidden;
      margin-right: 12px;
    }
    .file-title {
      font-size: 14px;
      font-weight: 600;
      color: #FFFFFF;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .file-meta {
      font-size: 12px;
      color: var(--text-muted);
    }
    .file-action {
      display: flex;
      align-items: center;
      gap: 12px;
      flex-shrink: 0;
    }
    .file-size-tag {
      font-size: 13px;
      font-weight: 500;
      color: var(--text-muted);
    }
    .btn-download {
      background: var(--lime);
      color: #000000;
      border-radius: 8px;
      padding: 6px 14px;
      font-size: 12px;
      font-weight: 700;
      text-decoration: none;
      display: inline-flex;
      align-items: center;
      gap: 4px;
      transition: opacity 0.15s;
    }
    .btn-download:hover { opacity: 0.88; }
  </style>
</head>
<body>
  <div class="wrapper">
    <!-- Header -->
    <header class="header">
      <div class="brand">
        <span class="brand-vortex">Vortex</span>
        <span class="brand-web">Web</span>
      </div>
      <div class="status-badge">
        <span class="status-dot"></span>
        <span>Local Wi-Fi · zero data · works offline</span>
      </div>
    </header>

    <!-- Two-Card Layout -->
    <main class="portal-grid">
      <!-- Left Card: SEND FILES TO PHONE -->
      <section class="card-send" id="dropZone">
        <!-- Reticle Corner Markers -->
        <div class="reticle reticle-tl"></div>
        <div class="reticle reticle-tr"></div>
        <div class="reticle reticle-bl"></div>
        <div class="reticle reticle-br"></div>

        <div>
          <div class="card-label">SEND FILES TO PHONE</div>
          <div class="upload-icon-circle">
            <svg viewBox="0 0 24 24">
              <line x1="12" y1="18" x2="12" y2="6"></line>
              <polyline points="6 12 12 6 18 12"></polyline>
              <line x1="5" y1="20" x2="19" y2="20"></line>
            </svg>
          </div>
          <h1 class="hero-title">Drop files here</h1>
          <p class="hero-sub">or click to browse</p>
          <input type="file" id="fileInput" multiple>

          <!-- Upload Progress -->
          <div class="upload-progress-box" id="uploadProgressBox">
            <div class="upload-status-row">
              <span id="uploadStatusText">Sending files...</span>
              <span id="uploadPctText">0%</span>
            </div>
            <div class="upload-track">
              <div class="upload-bar" id="uploadBar"></div>
            </div>
            <button class="btn-cancel-transfer" id="btnCancelUpload">✕ Cancel Upload</button>
          </div>
        </div>

        <div class="send-bottom">
          <div class="device-compat">
            Works from iPhone, Mac, Windows and Android.
          </div>
          <button class="btn-browse" id="btnBrowse" type="button">
            Browse files
          </button>
        </div>
      </section>

      <!-- Right Card: DOWNLOAD FROM PHONE -->
      <section class="card-receive">
        <div class="card-label">DOWNLOAD FROM PHONE</div>

        <div class="counter-display">
          <span class="counter-number" id="sharedCountNumber">0</span>
          <span class="counter-label">files shared</span>
        </div>

        <p class="empty-desc" id="emptyDesc">
          Nothing is shared for download yet. Select files in the Vortex app to make them downloadable here.
        </p>

        <div class="table-container">
          <div class="table-header">
            <span>NAME</span>
            <span>SIZE</span>
          </div>

          <div class="file-list" id="fileList">
            <!-- Populated via API -->
          </div>

          <!-- Subtle bottom guide line if empty as in reference screenshot -->
          <div class="table-rule" id="tableRule"></div>
        </div>
      </section>
    </main>
  </div>

  <script>
    const dropZone = document.getElementById('dropZone');
    const fileInput = document.getElementById('fileInput');
    const btnBrowse = document.getElementById('btnBrowse');
    const uploadProgressBox = document.getElementById('uploadProgressBox');
    const uploadBar = document.getElementById('uploadBar');
    const uploadStatusText = document.getElementById('uploadStatusText');
    const uploadPctText = document.getElementById('uploadPctText');
    const btnCancelUpload = document.getElementById('btnCancelUpload');

    const sharedCountNumber = document.getElementById('sharedCountNumber');
    const emptyDesc = document.getElementById('emptyDesc');
    const fileList = document.getElementById('fileList');
    const tableRule = document.getElementById('tableRule');

    let currentUploadXhr = null;
    let isUploadCancelledByUser = false;
    let statusPollInterval = null;

    function startUploadStatusPoll() {
      stopUploadStatusPoll();
      statusPollInterval = setInterval(async () => {
        if (!currentUploadXhr) return;
        try {
          const res = await fetch('/api/upload-status?t=' + Date.now());
          const data = await res.json();
          if (data && data.cancelled) {
            console.log('[Vortex Web] Phone cancelled upload! Aborting browser transfer...');
            stopUploadStatusPoll();
            isUploadCancelledByUser = true;
            if (currentUploadXhr) {
              try { currentUploadXhr.abort(); } catch (_) {}
            }
          }
        } catch (_) {}
      }, 250);
    }

    function stopUploadStatusPoll() {
      if (statusPollInterval) {
        clearInterval(statusPollInterval);
        statusPollInterval = null;
      }
    }

    btnCancelUpload.addEventListener('click', (e) => {
      e.stopPropagation();
      isUploadCancelledByUser = true;
      stopUploadStatusPoll();
      if (currentUploadXhr) {
        try { currentUploadXhr.abort(); } catch (_) {}
      }
    });

    btnBrowse.addEventListener('click', (e) => {
      e.stopPropagation();
      fileInput.click();
    });

    dropZone.addEventListener('click', (e) => {
      if (e.target.closest('#uploadProgressBox') || e.target.closest('#btnBrowse')) return;
      fileInput.click();
    });

    ['dragenter', 'dragover'].forEach(name => {
      dropZone.addEventListener(name, (e) => {
        e.preventDefault();
        dropZone.classList.add('dragover');
      });
    });

    ['dragleave', 'drop'].forEach(name => {
      dropZone.addEventListener(name, (e) => {
        e.preventDefault();
        dropZone.classList.remove('dragover');
      });
    });

    dropZone.addEventListener('drop', (e) => {
      const files = e.dataTransfer.files;
      if (files.length > 0) handleUpload(files);
    });

    fileInput.addEventListener('change', () => {
      if (fileInput.files.length > 0) handleUpload(fileInput.files);
    });

    async function handleUpload(files) {
      if (!files || files.length === 0) return;
      isUploadCancelledByUser = false;
      uploadProgressBox.style.display = 'block';
      uploadBar.style.width = '0%';
      uploadBar.style.background = '#000000';
      uploadStatusText.innerText = 'Sending files...';
      uploadPctText.innerText = '0%';
      btnCancelUpload.style.display = 'inline-block';

      startUploadStatusPoll();

      try {
        for (let i = 0; i < files.length; i++) {
          if (isUploadCancelledByUser) {
            throw new Error('Transfer was cancelled by phone');
          }

          const file = files[i];
          uploadStatusText.innerText = 'Sending (' + (i + 1) + '/' + files.length + '): ' + file.name;
          uploadBar.style.width = '0%';

          await new Promise((resolve, reject) => {
            const xhr = new XMLHttpRequest();
            currentUploadXhr = xhr;

            xhr.open('POST', '/upload', true);
            xhr.setRequestHeader('x-vortex-path', encodeURIComponent(file.name));

            xhr.upload.onprogress = (e) => {
              if (isUploadCancelledByUser) return;
              if (e.lengthComputable) {
                const pct = Math.round((e.loaded / e.total) * 100);
                uploadBar.style.width = pct + '%';
                uploadPctText.innerText = pct + '%';
              }
            };

            xhr.onload = () => {
              currentUploadXhr = null;
              if (xhr.status >= 200 && xhr.status < 300) {
                resolve();
              } else {
                isUploadCancelledByUser = true;
                reject(new Error('Transfer was cancelled by phone'));
              }
            };

            xhr.onerror = () => {
              currentUploadXhr = null;
              isUploadCancelledByUser = true;
              reject(new Error('Transfer connection interrupted'));
            };

            xhr.onabort = () => {
              currentUploadXhr = null;
              isUploadCancelledByUser = true;
              reject(new Error('Transfer was cancelled by phone'));
            };

            xhr.send(file);
          });
        }

        stopUploadStatusPoll();
        uploadBar.style.width = '100%';
        uploadBar.style.background = '#15803D';
        uploadStatusText.innerText = '✓ Sent ' + files.length + ' file(s) successfully!';
        uploadPctText.innerText = '100%';
        btnCancelUpload.style.display = 'none';

        setTimeout(() => {
          uploadProgressBox.style.display = 'none';
        }, 4000);

      } catch (err) {
        stopUploadStatusPoll();
        uploadBar.style.width = '100%';
        uploadBar.style.background = '#DC2626';
        uploadStatusText.innerText = '✕ ' + (err.message || 'Transfer cancelled');
        btnCancelUpload.style.display = 'none';

        setTimeout(() => {
          uploadProgressBox.style.display = 'none';
        }, 5000);
      } finally {
        stopUploadStatusPoll();
        currentUploadXhr = null;
        fileInput.value = '';
      }
    }

    async function loadSharedFiles() {
      try {
        const res = await fetch('/api/shared-files');
        const files = await res.json();

        if (!files || files.length === 0) {
          sharedCountNumber.innerText = '0';
          sharedCountNumber.classList.remove('has-files');
          emptyDesc.style.display = 'block';
          fileList.innerHTML = '';
          tableRule.style.display = 'block';
          return;
        }

        sharedCountNumber.innerText = files.length;
        sharedCountNumber.classList.add('has-files');
        emptyDesc.style.display = 'none';
        tableRule.style.display = 'none';

        fileList.innerHTML = files.map(f => `
          <div class="file-row">
            <div class="file-title-box">
              <span class="file-title" title="\${f.name}">\${f.name}</span>
            </div>
            <div class="file-action">
              <span class="file-size-tag">\${f.sizeFormatted}</span>
              <a class="btn-download" href="/download?id=\${f.id}" download>
                Download
              </a>
            </div>
          </div>
        `).join('');
      } catch (e) {
        // silent fail on network polling
      }
    }

    loadSharedFiles();
    setInterval(loadSharedFiles, 3500);
  </script>
</body>
</html>
''';
  }

}
