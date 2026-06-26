import { scoreMatch, rankBy, tokenize } from './search';

describe('search', () => {
  it('tokenizes and drops stop words', () => {
    expect(tokenize('The Study for AI!')).toEqual(['study', 'ai']);
  });

  it('scores contiguous matches highest', () => {
    const s = scoreMatch('Family dinner tonight', 'family dinner');
    expect(s).toBeGreaterThan(0.7);
  });

  it('returns 0 for no overlap', () => {
    expect(scoreMatch('Gym session', 'cooking class')).toBe(0);
  });

  it('ranks and filters zero-score items', () => {
    const items = [
      { id: '1', text: 'Buy groceries' },
      { id: '2', text: 'Gym workout' },
      { id: '3', text: 'Grocery shopping list' },
    ];
    const ranked = rankBy(items, 'grocery', (i) => i.text);
    expect(ranked.map((r) => r.item.id)).toContain('1');
    expect(ranked.map((r) => r.item.id)).toContain('3');
    expect(ranked.find((r) => r.item.id === '2')).toBeUndefined();
  });
});
