/* Browser-only capabilities. No paid speech service or remote audio storage. */
(() => {
  'use strict';
  const root = globalThis;
  let active = null, generation = 0, playback = null, playbackUrl = null;
  const emit = (state, type, value = '') => { if (!state.cancelled) state.callback(JSON.stringify({type, value})); };
  const openDB = () => new Promise((resolve, reject) => {
    const request = indexedDB.open('hamnava-audio', 1);
    request.onupgradeneeded = () => request.result.createObjectStore('clips');
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  async function audioDB(mode, action) {
    const db = await openDB();
    try {
      return await new Promise((resolve, reject) => {
        const tx = db.transaction('clips', mode);
        const request = action(tx.objectStore('clips'));
        tx.oncomplete = () => resolve(request.result);
        tx.onerror = () => reject(tx.error);
        tx.onabort = () => reject(tx.error || new Error('storage aborted'));
      });
    } finally { db.close(); }
  }
  const release = state => {
    clearTimeout(state.timer);
    state.stream?.getTracks().forEach(track => track.stop());
  };
  root.hamnavaCanRecord = () => !!(root.isSecureContext && root.navigator?.mediaDevices?.getUserMedia && root.MediaRecorder);
  root.hamnavaCanRecognize = () => !!(root.SpeechRecognition || root.webkitSpeechRecognition);
  root.hamnavaStart = async (key, locale, callback) => {
    if (active) return false;
    root.hamnavaStopPlayback();
    const state = {key, callback, cancelled: false, chunks: [], sequence: ++generation};
    active = state;
    try {
      if (key) {
        if (!root.isSecureContext) throw new Error('insecure-context');
        if (!root.hamnavaCanRecord()) throw new Error('recording-unavailable');
        state.stream = await navigator.mediaDevices.getUserMedia({audio: true});
        if (state.cancelled || state.sequence !== generation) { release(state); return false; }
        const types = ['audio/mp4;codecs=mp4a.40.2', 'audio/mp4', 'audio/webm;codecs=opus', 'audio/webm'];
        const mimeType = types.find(type => MediaRecorder.isTypeSupported?.(type));
        state.recorder = new MediaRecorder(state.stream, mimeType ? {mimeType} : {});
        state.recorder.ondataavailable = e => { if (e.data.size) state.chunks.push(e.data); };
        state.recorder.onerror = () => {
          emit(state, 'error', 'recording-failed');
          root.hamnavaStop().catch(() => {});
        };
        // A bounded recording needs only its final blob; avoiding fragmented
        // MP4 chunks is more reliable across Safari MediaRecorder versions.
        state.recorder.start();
      } else {
        // Starting a second microphone consumer after awaiting getUserMedia can
        // fail on iOS or lose the user gesture. Dictation is a separate mode.
        const Recognition = root.SpeechRecognition || root.webkitSpeechRecognition;
        if (!Recognition) throw new Error('speech-unavailable');
        state.recognition = new Recognition();
        state.recognition.lang = locale;
        state.recognition.continuous = true;
        state.recognition.interimResults = true;
        state.recognition.onresult = e => {
          let finalText = '', interim = '';
          for (let i = e.resultIndex; i < e.results.length; i++) {
            if (e.results[i].isFinal) finalText += e.results[i][0].transcript + ' ';
            else interim += e.results[i][0].transcript;
          }
          if (finalText.trim()) emit(state, 'text', finalText.trim());
          emit(state, 'interim', interim);
        };
        state.recognition.onerror = e => emit(state, 'error', e.error || 'speech-failed');
        state.recognition.onend = () => {
          state.recognitionEnded = true;
          state.speechDone?.(); emit(state, 'speech-ended');
        };
        state.recognition.start();
      }
      emit(state, 'started');
      state.timer = setTimeout(() => { if (active === state) root.hamnavaStop().catch(() => {}); }, 300000);
      return true;
    } catch (error) {
      const errors = {NotAllowedError: 'permission-denied', NotReadableError: 'microphone-busy',
        NotFoundError: 'microphone-missing', NotSupportedError: 'recording-unavailable'};
      emit(state, 'error', !key && error.name === 'NotAllowedError' ? 'speech-permission-denied'
        : errors[error.name] || error.message || 'recording-failed');
      release(state); if (active === state) active = null;
      return false;
    }
  };
  root.hamnavaStop = async () => {
    const state = active;
    if (!state) return '';
    if (state.stopping) return state.stopping;
    state.stopping = (async () => {
      clearTimeout(state.timer);
      if (state.recognition && !state.recognitionEnded) {
        await new Promise(resolve => {
          const timer = setTimeout(resolve, 1500);
          state.speechDone = () => { clearTimeout(timer); resolve(); };
          try { state.recognition.stop(); } catch (_) { clearTimeout(timer); resolve(); }
        });
      }
      let savedKey = '';
      try {
        if (state.recorder && state.recorder.state !== 'inactive') {
          await new Promise((resolve, reject) => {
            const timer = setTimeout(() => reject(new Error('recording-stop-timeout')), 5000);
            state.recorder.onstop = () => { clearTimeout(timer); resolve(); };
            state.recorder.stop();
          });
        }
        if (state.key && state.chunks.length && !state.cancelled) {
          const blob = new Blob(state.chunks, {type: state.recorder.mimeType || state.chunks[0].type});
          await audioDB('readwrite', store => store.put(blob, state.key));
          savedKey = state.key;
        } else if (state.key && !state.cancelled) {
          emit(state, 'error', 'recording-empty');
        }
      } catch (_) { emit(state, 'error', 'audio-storage-failed'); }
      finally { release(state); if (active === state) active = null; }
      emit(state, 'stopped', savedKey);
      return savedKey;
    })();
    return state.stopping;
  };
  root.hamnavaCancel = () => {
    generation++;
    const state = active; active = null;
    if (state) {
      state.cancelled = true;
      try { state.recognition?.abort(); } catch (_) {}
      try { if (state.recorder?.state === 'recording') state.recorder.stop(); } catch (_) {}
      release(state);
    }
    root.hamnavaStopPlayback();
  };
  function downloadBlob(blob, filename) {
    const url = URL.createObjectURL(blob), link = document.createElement('a');
    link.href = url; link.download = filename; document.body.appendChild(link); link.click(); link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 30000);
  }
  root.hamnavaDownload = (text, filename) => downloadBlob(new Blob([text], {type: 'application/json;charset=utf-8'}), filename);
  root.hamnavaDownloadBinary = (data, filename, mime) => {
    const binary = atob(data), bytes = Uint8Array.from(binary, char => char.charCodeAt(0));
    downloadBlob(new Blob([bytes], {type:mime}), filename);
  };
  root.hamnavaPickAudio = async key => {
    const file = await root.hamnavaChooseFile('audio/*,.m4a,.mp3,.wav,.webm');
    if (!file) return '';
    if (file.size > 20 * 1024 * 1024) return JSON.stringify({error:'audio-file-too-large'});
    const formats = {m4a:'audio/mp4',mp3:'audio/mpeg',wav:'audio/wav',webm:'audio/webm',ogg:'audio/ogg'};
    const mime = file.type || formats[file.name.split('.').pop().toLowerCase()];
    if (!mime?.startsWith('audio/')) return JSON.stringify({error:'audio-file-format'});
    try {
      await audioDB('readwrite', store => store.put(new Blob([file], {type:mime}), key));
      return JSON.stringify({key});
    } catch (_) { return JSON.stringify({error:'audio-storage-failed'}); }
  };
  root.hamnavaDownloadAudio = async key => {
    const blob = await audioDB('readonly', store => store.get(key));
    if (!blob) return false;
    const extension = blob.type.includes('mp4') ? 'm4a' : blob.type.includes('mpeg') ? 'mp3' : blob.type.includes('wav') ? 'wav' : blob.type.includes('ogg') ? 'ogg' : 'webm';
    downloadBlob(blob, `hamnava-audio.${extension}`); return true;
  };
  root.hamnavaRemoveAudio = key => audioDB('readwrite', store => store.delete(key));
  root.hamnavaStopPlayback = () => {
    root.speechSynthesis?.cancel(); playback?.pause(); playback = null;
    if (playbackUrl) URL.revokeObjectURL(playbackUrl); playbackUrl = null;
  };
  root.hamnavaPlay = async key => {
    root.hamnavaStopPlayback();
    const blob = await audioDB('readonly', store => store.get(key));
    if (!blob) return false;
    playbackUrl = URL.createObjectURL(blob); playback = new Audio(playbackUrl);
    playback.onended = () => root.hamnavaStopPlayback();
    try { await playback.play(); return true; } catch (_) { root.hamnavaStopPlayback(); return false; }
  };
  root.hamnavaSpeak = async (text, locale) => {
    if (!root.speechSynthesis) return false;
    root.hamnavaStopPlayback();
    let voices = speechSynthesis.getVoices();
    if (!voices.length) {
      await new Promise(resolve => {
        const done = () => { clearTimeout(timer); speechSynthesis.removeEventListener('voiceschanged', done); resolve(); };
        const timer = setTimeout(done, 1000); speechSynthesis.addEventListener('voiceschanged', done);
      });
      voices = speechSynthesis.getVoices();
    }
    const voice = voices.find(v => v.lang.replace('_', '-').toLowerCase().startsWith(locale.split('-')[0].toLowerCase()));
    if (!voice) return false;
    const utterance = new SpeechSynthesisUtterance(text); utterance.voice = voice; utterance.lang = locale;
    speechSynthesis.speak(utterance); return true;
  };
  root.hamnavaDraft = key => { try { return sessionStorage.getItem(key) || ''; } catch (_) { return ''; } };
  root.hamnavaSetDraft = (key, text) => { try { if (text) sessionStorage.setItem(key, text); else sessionStorage.removeItem(key); } catch (_) {} };
  const stopWhenHidden = () => {
    const state = active;
    if (state && !state.recorder && !state.recognition) {
      // Permission may still be pending. Cancel the late stream and reset UI.
      emit(state, 'stopped'); root.hamnavaCancel();
    } else if (state) {
      root.hamnavaStop().catch(() => root.hamnavaCancel());
      // Release hardware now even if the browser suspends the storage callback.
      release(state);
    }
    root.hamnavaStopPlayback();
  };
  root.document?.addEventListener('visibilitychange', () => {
    if (document.hidden) stopWhenHidden();
  });
  root.addEventListener('pagehide', stopWhenHidden);
})();
