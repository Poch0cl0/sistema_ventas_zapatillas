// Video uses object-fit: cover. Use the exact same crop for tracked landmarks.
export function videoPoint(point, videoWidth, videoHeight, width, height) {
  const scale = Math.max(width / videoWidth, height / videoHeight);
  return { x: point.x * videoWidth * scale - (videoWidth * scale - width) / 2,
    y: point.y * videoHeight * scale - (videoHeight * scale - height) / 2 };
}

export function footTransform(landmarks, indices, dimensions) {
  const [ankle, heel, toe] = indices.map(i => landmarks[i]);
  if (![ankle, heel, toe].every(p => p && (p.visibility ?? 0) >= .6)) return null;
  const points = [heel, toe].map(p => videoPoint(p, ...dimensions));
  const [h, t] = points;
  const dx = t.x - h.x, dy = t.y - h.y;
  const length = Math.hypot(dx, dy);
  if (length < 18 || length > Math.max(dimensions[2], dimensions[3]) * .75) return null;
  if ([h, t].some(p => p.x < 0 || p.x > dimensions[2] || p.y < 0 || p.y > dimensions[3])) return null;
  return { x: (h.x + t.x) / 2, y: (h.y + t.y) / 2,
    length: length * 1.35, angle: Math.atan2(-dy, dx) + Math.PI / 2 };
}

export function smoothAngle(current, target, amount) {
  return current + Math.atan2(Math.sin(target-current), Math.cos(target-current))*amount;
}
