/* File picking is invoked synchronously from a user tap (including iOS). */
(() => {
  'use strict';
  const root = globalThis;
  root.hamnavaChooseFile = (accept, camera = false) => new Promise(resolve => {
    const input = document.createElement('input');
    input.type = 'file'; input.accept = accept;
    if (camera) input.setAttribute('capture', 'environment');
    input.style.display = 'none'; document.body.appendChild(input);
    let finished = false, focusTimer;
    const finish = file => {
      if (finished) return;
      finished = true; clearTimeout(focusTimer);
      root.removeEventListener('focus', onFocus); input.remove(); resolve(file);
    };
    const onFocus = () => {
      focusTimer = setTimeout(() => {
        if (!input.files?.length) finish(null);
      }, 1200);
    };
    input.onchange = () => finish(input.files?.[0] || null);
    input.addEventListener('cancel', () => finish(null));
    root.addEventListener('focus', onFocus);
    input.click();
  });
  const readData = blob => new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result); reader.onerror = () => reject(new Error('image-read-failed'));
    reader.readAsDataURL(blob);
  });
  root.hamnavaPickReceipt = async camera => {
    const file = await root.hamnavaChooseFile('image/jpeg,image/png,image/webp,image/heic,image/heif', camera);
    if (!file) return '';
    const mime = file.type === 'image/jpg' ? 'image/jpeg' : file.type;
    const allowed = ['image/jpeg','image/png','image/webp','image/heic','image/heif'];
    if ((mime && !allowed.includes(mime)) || (!mime && !/\.(jpe?g|png|webp|heic|heif)$/i.test(file.name))) {
      return JSON.stringify({error:'image-format'});
    }
    if (file.size > 16 * 1024 * 1024) return JSON.stringify({error:'image-too-large'});
    const url = URL.createObjectURL(file);
    try {
      const image = new Image();
      await new Promise((resolve, reject) => {
        image.onload = resolve; image.onerror = () => reject(new Error('image-format')); image.src = url;
      });
      if (!image.naturalWidth || !image.naturalHeight || image.naturalWidth * image.naturalHeight > 25000000) {
        throw new Error('image-too-large');
      }
      const canvas = document.createElement('canvas'), context = canvas.getContext('2d');
      if (!context) throw new Error('image-format');
      for (const edge of [1600, 1280, 1024, 800]) {
        const ratio = Math.min(1, edge / Math.max(image.naturalWidth, image.naturalHeight));
        canvas.width = Math.max(1, Math.round(image.naturalWidth * ratio));
        canvas.height = Math.max(1, Math.round(image.naturalHeight * ratio));
        context.fillStyle = '#fff'; context.fillRect(0, 0, canvas.width, canvas.height);
        context.drawImage(image, 0, 0, canvas.width, canvas.height);
        for (const quality of [.85, .7, .55]) {
          const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/jpeg', quality));
          if (blob?.size && blob.size <= 200 * 1024) {
            return JSON.stringify({name:file.name.replace(/[\x00-\x1f]/g,'').slice(0,120) || 'receipt.jpg',
              originalType:mime || 'unknown', image:await readData(blob), bytes:blob.size,
              width:canvas.width, height:canvas.height});
          }
        }
      }
      throw new Error('image-too-detailed');
    } catch (e) { return JSON.stringify({error:e.message || 'image-read-failed'}); }
    finally { URL.revokeObjectURL(url); }
  };
})();
