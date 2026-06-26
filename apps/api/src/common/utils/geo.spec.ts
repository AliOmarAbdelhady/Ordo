import { haversineMeters, withinRadius, fmtDistance } from './geo';

describe('geo', () => {
  it('returns ~0 for identical points', () => {
    expect(haversineMeters({ lat: 24.7, lng: 46.7 }, { lat: 24.7, lng: 46.7 })).toBeLessThan(1);
  });

  it('approximates the distance between Riyadh and Jeddah (~850km)', () => {
    const riyadh = { lat: 24.7136, lng: 46.6753 };
    const jeddah = { lat: 21.4858, lng: 39.1925 };
    const d = haversineMeters(riyadh, jeddah);
    expect(d).toBeGreaterThan(780_000);
    expect(d).toBeLessThan(900_000);
  });

  it('withinRadius is inclusive and directional-safe', () => {
    const a = { lat: 0, lng: 0 };
    const near = { lat: 0.001, lng: 0 }; // ~111m north
    const far = { lat: 1, lng: 0 }; // ~111km
    expect(withinRadius(a, near, 200)).toBe(true);
    expect(withinRadius(a, far, 200)).toBe(false);
    expect(withinRadius(a, a, 0)).toBe(true);
  });

  it('formats distance readably', () => {
    expect(fmtDistance(50)).toBe('50 m');
    expect(fmtDistance(1500)).toBe('1.5 km');
    expect(fmtDistance(42000)).toBe('42 km');
  });
});
