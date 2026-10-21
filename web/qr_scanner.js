// IONET Web QR Scanner Implementation
(function() {
  'use strict';

  let activeStream = null;
  let scanInterval = null;
  let currentFacingMode = 'environment';
  let isScanning = false;
  let modalElement = null;
  let audioCtx = null;

  function playSuccessBeep() {
    try {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      if (!AudioContext) return;
      if (!audioCtx) audioCtx = new AudioContext();
      if (audioCtx.state === 'suspended') audioCtx.resume();
      
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(880, audioCtx.currentTime); // A5 note
      osc.frequency.exponentialRampToValueAtTime(1760, audioCtx.currentTime + 0.12);
      gain.gain.setValueAtTime(0.15, audioCtx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.12);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start();
      osc.stop(audioCtx.currentTime + 0.12);
    } catch (_) {}
  }

  function stopCamera() {
    if (scanInterval) {
      clearInterval(scanInterval);
      scanInterval = null;
    }
    if (activeStream) {
      activeStream.getTracks().forEach(track => {
        try { track.stop(); } catch (_) {}
      });
      activeStream = null;
    }
    isScanning = false;
  }

  function closeScanner(onCancel) {
    stopCamera();
    if (modalElement && modalElement.parentNode) {
      modalElement.parentNode.removeChild(modalElement);
    }
    modalElement = null;
    if (typeof onCancel === 'function') {
      onCancel();
    }
  }

  async function decodeImageFile(file, onSuccess, onError) {
    try {
      if ('BarcodeDetector' in window) {
        const detector = new window.BarcodeDetector({ formats: ['qr_code'] });
        const img = new Image();
        img.src = URL.createObjectURL(file);
        await new Promise((res, rej) => {
          img.onload = res;
          img.onerror = rej;
        });
        const codes = await detector.detect(img);
        URL.revokeObjectURL(img.src);
        if (codes && codes.length > 0) {
          playSuccessBeep();
          stopCamera();
          if (modalElement && modalElement.parentNode) {
            modalElement.parentNode.removeChild(modalElement);
          }
          modalElement = null;
          onSuccess(codes[0].rawValue);
          return;
        }
      }

      if (window.Html5Qrcode) {
        const tempId = 'ionet-temp-qr-' + Date.now();
        const tempDiv = document.createElement('div');
        tempDiv.id = tempId;
        tempDiv.style.display = 'none';
        document.body.appendChild(tempDiv);

        try {
          const html5Qr = new window.Html5Qrcode(tempId);
          const decoded = await html5Qr.scanFile(file, true);
          html5Qr.clear();
          tempDiv.remove();
          playSuccessBeep();
          stopCamera();
          if (modalElement && modalElement.parentNode) {
            modalElement.parentNode.removeChild(modalElement);
          }
          modalElement = null;
          onSuccess(decoded);
          return;
        } catch (e) {
          tempDiv.remove();
        }
      }

      if (onError) onError('No QR code found in selected image.');
    } catch (err) {
      if (onError) onError('Error reading image: ' + err.message);
    }
  }

  function openScannerModal(onSuccess, onCancel) {
    // If already open, close first
    if (modalElement) {
      closeScanner();
    }

    // Build modal HTML
    const modal = document.createElement('div');
    modal.id = 'ionet-qr-scanner-overlay';
    modal.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100vw;
      height: 100vh;
      background: rgba(0, 0, 0, 0.82);
      backdrop-filter: blur(8px);
      -webkit-backdrop-filter: blur(8px);
      z-index: 999999;
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      padding: 16px;
      box-sizing: border-box;
    `;

    modal.innerHTML = `
      <div style="
        background: #1D222B;
        border: 1px solid #2B3240;
        border-radius: 24px;
        width: 100%;
        max-width: 420px;
        overflow: hidden;
        box-shadow: 0 20px 40px rgba(0,0,0,0.6);
        display: flex;
        flex-direction: column;
        animation: ionetFadeIn 0.25s ease-out;
      ">
        <style>
          @keyframes ionetFadeIn {
            from { opacity: 0; transform: scale(0.95); }
            to { opacity: 1; transform: scale(1); }
          }
          @keyframes ionetLaser {
            0% { top: 10%; opacity: 0.8; }
            50% { top: 90%; opacity: 1; }
            100% { top: 10%; opacity: 0.8; }
          }
          .ionet-qr-btn {
            background: #262D38;
            color: #E9EDEF;
            border: 1px solid #374252;
            border-radius: 12px;
            padding: 10px 16px;
            font-size: 14px;
            font-weight: 500;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            transition: all 0.2s;
          }
          .ionet-qr-btn:hover {
            background: #323B4A;
            border-color: #00A884;
          }
          .ionet-qr-btn-primary {
            background: #00A884;
            color: #ffffff;
            border: none;
          }
          .ionet-qr-btn-primary:hover {
            background: #008f70;
          }
        </style>

        <!-- Header -->
        <div style="
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 20px 24px 14px;
          border-bottom: 1px solid rgba(255,255,255,0.06);
        ">
          <div style="display: flex; align-items: center; gap: 10px;">
            <div style="
              width: 34px;
              height: 34px;
              border-radius: 10px;
              background: rgba(0, 168, 132, 0.15);
              display: flex;
              align-items: center;
              justify-content: center;
            ">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#00A884" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="3" y="3" width="7" height="7"></rect>
                <rect x="14" y="3" width="7" height="7"></rect>
                <rect x="14" y="14" width="7" height="7"></rect>
                <rect x="3" y="14" width="7" height="7"></rect>
              </svg>
            </div>
            <h3 style="margin: 0; color: #E9EDEF; font-size: 18px; font-weight: 600;">Scan Device QR</h3>
          </div>
          <button id="ionet-qr-close-btn" style="
            background: transparent;
            border: none;
            color: #8696A0;
            cursor: pointer;
            font-size: 24px;
            line-height: 1;
            padding: 6px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
          ">&times;</button>
        </div>

        <!-- Video & Viewfinder Container -->
        <div style="padding: 16px 20px;">
          <div id="ionet-qr-viewfinder" style="
            position: relative;
            width: 100%;
            aspect-ratio: 1;
            background: #111B21;
            border-radius: 20px;
            overflow: hidden;
            border: 1px solid #2B3240;
            display: flex;
            align-items: center;
            justify-content: center;
          ">
            <video id="ionet-qr-video" autoplay playsinline muted style="
              width: 100%;
              height: 100%;
              object-fit: cover;
              display: block;
            "></video>

            <!-- Scanner Box Overlay -->
            <div id="ionet-target-box" style="
              position: absolute;
              width: 220px;
              height: 220px;
              pointer-events: none;
              box-sizing: border-box;
            ">
              <!-- Corner Brackets -->
              <div style="position: absolute; top: 0; left: 0; width: 26px; height: 26px; border-top: 3.5px solid #00A884; border-left: 3.5px solid #00A884; border-top-left-radius: 8px;"></div>
              <div style="position: absolute; top: 0; right: 0; width: 26px; height: 26px; border-top: 3.5px solid #00A884; border-right: 3.5px solid #00A884; border-top-right-radius: 8px;"></div>
              <div style="position: absolute; bottom: 0; left: 0; width: 26px; height: 26px; border-bottom: 3.5px solid #00A884; border-left: 3.5px solid #00A884; border-bottom-left-radius: 8px;"></div>
              <div style="position: absolute; bottom: 0; right: 0; width: 26px; height: 26px; border-bottom: 3.5px solid #00A884; border-right: 3.5px solid #00A884; border-bottom-right-radius: 8px;"></div>

              <!-- Animated Laser Line -->
              <div style="
                position: absolute;
                left: 10px;
                right: 10px;
                height: 2px;
                background: #00A884;
                box-shadow: 0 0 10px #00A884, 0 0 18px #00A884;
                animation: ionetLaser 2s infinite ease-in-out;
              "></div>
            </div>

            <!-- Error / Status Message Overlay -->
            <div id="ionet-qr-error" style="
              position: absolute;
              inset: 0;
              background: rgba(17, 27, 33, 0.94);
              color: #E9EDEF;
              display: none;
              flex-direction: column;
              align-items: center;
              justify-content: center;
              padding: 24px;
              text-align: center;
              font-size: 14px;
              line-height: 1.5;
            ">
              <div style="font-size: 32px; margin-bottom: 12px; color: #F15C6D;">⚠️</div>
              <div id="ionet-qr-error-msg" style="margin-bottom: 16px; color: #8696A0;">Camera unavailable</div>
            </div>
          </div>

          <!-- Instruction Text -->
          <div style="text-align: center; margin-top: 14px;">
            <p style="margin: 0; color: #8696A0; font-size: 13.5px;">Align the QR code within the frame to scan</p>
          </div>
        </div>

        <!-- Controls Toolbar -->
        <div style="
          padding: 12px 20px 20px;
          display: flex;
          gap: 10px;
          justify-content: center;
          border-top: 1px solid rgba(255,255,255,0.06);
        ">
          <!-- Flip Camera Button -->
          <button id="ionet-qr-flip-btn" class="ionet-qr-btn" title="Flip Camera">
            <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M20 10c0-4.4-3.6-8-8-8s-8 3.6-8 8v2"></path>
              <path d="M10 14l-4-4-4 4"></path>
              <path d="M4 14c0 4.4 3.6 8 8 8s8-3.6 8-8v-2"></path>
              <path d="M14 10l4 4 4-4"></path>
            </svg>
            <span>Flip</span>
          </button>

          <!-- Upload QR Image Button -->
          <input type="file" id="ionet-qr-file-input" accept="image/*" style="display: none;" />
          <button id="ionet-qr-upload-btn" class="ionet-qr-btn" title="Upload QR image">
            <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
              <polyline points="17 8 12 3 7 8"></polyline>
              <line x1="12" y1="3" x2="12" y2="15"></line>
            </svg>
            <span>Upload Image</span>
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    modalElement = modal;

    const video = document.getElementById('ionet-qr-video');
    const closeBtn = document.getElementById('ionet-qr-close-btn');
    const flipBtn = document.getElementById('ionet-qr-flip-btn');
    const uploadBtn = document.getElementById('ionet-qr-upload-btn');
    const fileInput = document.getElementById('ionet-qr-file-input');
    const errorOverlay = document.getElementById('ionet-qr-error');
    const errorMsg = document.getElementById('ionet-qr-error-msg');

    closeBtn.onclick = () => closeScanner(onCancel);
    modal.onclick = (e) => {
      if (e.target === modal) closeScanner(onCancel);
    };

    uploadBtn.onclick = () => fileInput.click();
    fileInput.onchange = (e) => {
      const file = e.target.files && e.target.files[0];
      if (file) {
        decodeImageFile(file, onSuccess, (err) => {
          alert(err || 'Could not find a QR code in this image.');
        });
      }
    };

    flipBtn.onclick = () => {
      currentFacingMode = currentFacingMode === 'environment' ? 'user' : 'environment';
      startCamera();
    };

    function showError(msg) {
      if (errorOverlay && errorMsg) {
        errorMsg.innerText = msg;
        errorOverlay.style.display = 'flex';
      }
    }

    async function startCamera() {
      stopCamera();
      if (errorOverlay) errorOverlay.style.display = 'none';

      try {
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
          throw new Error('Camera is not supported on this device/browser.');
        }

        const constraints = {
          video: {
            facingMode: { ideal: currentFacingMode },
            width: { ideal: 1280 },
            height: { ideal: 720 },
          },
          audio: false,
        };

        const stream = await navigator.mediaDevices.getUserMedia(constraints);
        activeStream = stream;
        video.srcObject = stream;
        await video.play();
        isScanning = true;

        startDetectionLoop(video, onSuccess);
      } catch (err) {
        let msg = 'Camera error: ' + err.message;
        if (err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError') {
          msg = 'Camera permission was denied. Please allow camera in your browser settings, or use "Upload Image" below.';
        } else if (err.name === 'NotFoundError' || err.name === 'DevicesNotFoundError') {
          msg = 'No camera device found. You can upload a QR image from your gallery or file below.';
        }
        showError(msg);
      }
    }

    function onScanSuccess(rawCode) {
      if (!isScanning) return;
      isScanning = false;
      playSuccessBeep();
      stopCamera();
      if (modalElement && modalElement.parentNode) {
        modalElement.parentNode.removeChild(modalElement);
      }
      modalElement = null;
      if (typeof onSuccess === 'function') {
        onSuccess(rawCode);
      }
    }

    async function startDetectionLoop(videoElem, successCallback) {
      // Method 1: Native BarcodeDetector (Chrome Android, Chrome Desktop, Edge)
      if ('BarcodeDetector' in window) {
        try {
          const detector = new window.BarcodeDetector({ formats: ['qr_code'] });
          scanInterval = setInterval(async () => {
            if (!isScanning || videoElem.readyState < 2) return;
            try {
              const barcodes = await detector.detect(videoElem);
              if (barcodes && barcodes.length > 0 && barcodes[0].rawValue) {
                onScanSuccess(barcodes[0].rawValue);
              }
            } catch (_) {}
          }, 180);
          return;
        } catch (_) {}
      }

      // Method 2: Html5Qrcode fallback
      if (window.Html5Qrcode) {
        try {
          const html5Qr = new window.Html5Qrcode('ionet-qr-viewfinder');
          await html5Qr.start(
            { facingMode: currentFacingMode },
            { fps: 10, qrbox: { width: 220, height: 220 } },
            (decodedText) => {
              html5Qr.stop().then(() => {
                html5Qr.clear();
                onScanSuccess(decodedText);
              }).catch(() => {
                onScanSuccess(decodedText);
              });
            },
            () => {} // ignore frame parse errors
          );
          return;
        } catch (e) {
          // If html5Qr fails to start directly, fallback to canvas / detector
        }
      }

      // If neither is available, show image upload option
      showError('Direct video scanning is not supported by your browser. Please use "Upload Image" to scan your QR code.');
    }

    startCamera();
  }

  // Export to window
  window.ionetScanner = {
    open: openScannerModal,
    close: closeScanner,
  };
})();
