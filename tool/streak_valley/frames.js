// The artwork is authored on a pixel grid; the native views share its camera.
const valleyDays = [1, 2, 3, 4, 5, 7, 10, 14, 21, 28, 35, 42, 49, 60, 75, 90, 92, 94, 96, 98, 100];
function zoomFor(day) {
  return day < 7 ? 1.96 : day <= 28 ? 1.48 : day === 35 ? 1.12 : 1;
}
function camera(ctx, width, day) {
  ctx.scale(width/720, width/720);
  ctx.translate(360, 247);
  const zoom = zoomFor(day);
  ctx.scale(zoom, zoom);
  ctx.translate(-360, -247);
}
function makeCanvas(width, height) {
  const surface = document.createElement('canvas');
  surface.width = width;
  surface.height = height;
  return surface;
}
function frame(ctx, kind, day, light, phase, width) {
  ctx.save();
  if (kind === 'badge') {
    ctx.scale(width/300, width/300);
    ctx.translate(-210, 0);
  } else {
    camera(ctx, width, day);
  }
  paintPixel(ctx, day, light, phase, kind === 'badge');
  ctx.restore();
}
function sheet(kind, day, light) {
  const [w,h] = kind === 'badge' ? [72,72] : [240,100];
  const atlas = makeCanvas(w*8, h*9);
  const out = atlas.getContext('2d');
  const cell = makeCanvas(w, h);
  const ctx = cell.getContext('2d');
  for (let i=0; i<72; i++) {
    ctx.clearRect(0,0,w,h);
    frame(ctx, kind, day, light, i/72, w);
    out.drawImage(cell, i%8*w, Math.floor(i/8)*h);
  }
  return atlas;
}
function plate(image, light) {
  const layer = makeCanvas(720, 300);
  const ctx = layer.getContext('2d');
  const half = image.naturalHeight/2;
  const width = Math.min(image.naturalWidth, half*2.72);
  ctx.drawImage(image, (image.naturalWidth-width)/2, (light ? half : 0)+1,
    width, half-2, 0, 0, 720, 300);
  return layer;
}
function landscape(base, finale, day, light) {
  const result = makeCanvas(480, 200);
  const ctx = result.getContext('2d');
  camera(ctx, 480, day);
  ctx.drawImage(plate(day === 100 ? finale : base, light), 0, 0);
  if (day >= 42 && day !== 100) {
    const strength = day >= 90 ? .26 : day >= 60 ? .16 : .08;
    const warmth = ctx.createLinearGradient(0,28,0,292);
    warmth.addColorStop(0, 'rgba(174,67,40,'+strength+')');
    warmth.addColorStop(.7, 'rgba(235,116,46,'+strength*.45+')');
    warmth.addColorStop(1, 'rgba(237,126,51,0)');
    ctx.fillStyle = warmth;
    ctx.fillRect(0,0,720,300);
  }
  if (day === 90) {
    const margin = plate(finale, light);
    const maskCtx = margin.getContext('2d');
    maskCtx.globalCompositeOperation = 'destination-in';
    const fade = maskCtx.createLinearGradient(0,0,720,0);
    for (const [pos, alpha] of [[0,1],[.12,1],[.27,0],[.73,0],[.88,1],[1,1]]) {
      fade.addColorStop(pos, 'rgba(0,0,0,'+alpha+')');
    }
    maskCtx.fillStyle = fade;
    maskCtx.fillRect(0,0,720,300);
    ctx.drawImage(margin,0,0);
  }
  return result;
}
