/**
 * Pure poll-tally logic, split out so it can be unit-tested independently of
 * Prisma. Computes per-option vote counts/percentages and the viewer's votes.
 */

export interface TallyOption {
  id: string;
  text: string;
}

export interface TallyVote {
  optionId: string;
  userId: string;
}

export interface OptionResult extends TallyOption {
  count: number;
  percent: number;
}

export interface PollTally {
  options: OptionResult[];
  totalVotes: number;
  totalVoters: number;
  viewerVotes: string[]; // option ids the viewer voted for
  viewerHasVoted: boolean;
}

export function tallyPoll(
  options: TallyOption[],
  votes: TallyVote[],
  viewerId?: string,
): PollTally {
  const counts = new Map<string, Set<string>>();
  for (const opt of options) counts.set(opt.id, new Set());
  for (const v of votes) {
    const set = counts.get(v.optionId);
    if (set) set.add(v.userId);
  }
  const voters = new Set(votes.map((v) => v.userId));
  const totalVoters = voters.size;

  const results: OptionResult[] = options.map((opt) => {
    const count = counts.get(opt.id)?.size ?? 0;
    return {
      id: opt.id,
      text: opt.text,
      count,
      percent: totalVoters === 0 ? 0 : Number(((count / totalVoters) * 100).toFixed(1)),
    };
  });

  const viewerVotes = viewerId
    ? votes.filter((v) => v.userId === viewerId).map((v) => v.optionId)
    : [];

  return {
    options: results,
    totalVotes: votes.length,
    totalVoters,
    viewerVotes,
    viewerHasVoted: viewerVotes.length > 0,
  };
}
