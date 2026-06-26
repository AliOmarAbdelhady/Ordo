import { tallyPoll } from './poll-tally';

const opts = [
  { id: 'a', text: 'Pizza' },
  { id: 'b', text: 'Burgers' },
  { id: 'c', text: 'Salad' },
];

describe('tallyPoll', () => {
  it('counts votes per option and computes percentages by unique voter', () => {
    const tally = tallyPoll(
      opts,
      [
        { optionId: 'a', userId: 'u1' },
        { optionId: 'a', userId: 'u2' },
        { optionId: 'b', userId: 'u3' },
      ],
      undefined,
    );
    expect(tally.totalVoters).toBe(3);
    expect(tally.totalVotes).toBe(3);
    const a = tally.options.find((o) => o.id === 'a')!;
    expect(a.count).toBe(2);
    expect(a.percent).toBeCloseTo(66.7, 1);
  });

  it('reports whether the viewer voted and for what', () => {
    const tally = tallyPoll(
      opts,
      [{ optionId: 'c', userId: 'u1' }],
      'u1',
    );
    expect(tally.viewerHasVoted).toBe(true);
    expect(tally.viewerVotes).toEqual(['c']);
  });

  it('handles multiple votes from the same voter', () => {
    const tally = tallyPoll(
      opts,
      [
        { optionId: 'a', userId: 'u1' },
        { optionId: 'b', userId: 'u1' },
      ],
      'u1',
    );
    // 1 unique voter → each option is 100%
    expect(tally.totalVoters).toBe(1);
    expect(tally.options.find((o) => o.id === 'a')!.percent).toBe(100);
  });

  it('returns zero percent when nobody has voted', () => {
    const tally = tallyPoll(opts, []);
    expect(tally.totalVoters).toBe(0);
    expect(tally.options.every((o) => o.percent === 0 && o.count === 0)).toBe(true);
    expect(tally.viewerHasVoted).toBe(false);
  });
});
