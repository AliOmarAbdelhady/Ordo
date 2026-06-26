/**
 * Lightweight search scoring. The MVP uses PostgreSQL ILIKE + this in-memory
 * ranker; the plan notes Meilisearch/OpenSearch as the scale-up path (§5.15).
 */

const STOP = new Set([
  'a', 'an', 'the', 'and', 'or', 'to', 'of', 'in', 'on', 'for', 'at', 'is', 'it',
]);

export function tokenize(query: string): string[] {
  return query
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[^\w\s]/g, ' ')
    .split(/\s+/)
    .filter((t) => t.length > 0 && !STOP.has(t));
}

/**
 * Score how well `text` matches `query`. Returns 0 when there is no token
 * overlap. Exact contiguous matches rank highest, then prefix, then token
 * containment.
 */
export function scoreMatch(text: string, query: string): number {
  if (!text || !query) return 0;
  const haystack = text.toLowerCase();
  const q = query.toLowerCase().trim();
  if (!q) return 0;

  const tokens = tokenize(q);
  if (tokens.length === 0) return 0;

  let score = 0;
  if (haystack.includes(q)) score += 0.5; // contiguous match
  for (const t of tokens) {
    if (haystack.includes(t)) score += 0.3;
    else {
      // prefix / fuzzy: count partial overlap
      let best = 0;
      for (const word of haystack.split(/\s+/)) {
        const common = commonPrefix(t, word);
        if (common >= 3) best = Math.max(best, 0.1);
      }
      score += best;
    }
  }
  // Normalise so more tokens don't blindly inflate the score.
  return Math.min(1, Number(score.toFixed(3)));
}

function commonPrefix(a: string, b: string): number {
  let i = 0;
  while (i < a.length && i < b.length && a[i] === b[i]) i++;
  return i;
}

export interface Ranked<T> {
  item: T;
  score: number;
}

/** Rank a list of items by a query applied to a text getter. Drops zero-score items. */
export function rankBy<T>(items: T[], query: string, getText: (item: T) => string): Ranked<T>[] {
  return items
    .map((item) => ({ item, score: scoreMatch(getText(item), query) }))
    .filter((r) => r.score > 0)
    .sort((a, b) => b.score - a.score);
}
