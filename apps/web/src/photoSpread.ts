export type SpreadPhoto = {
  id: string;
  day: string;
  thumbnail?: string;
  createdAt: string;
  kind: 'photo' | 'video';
  source: 'photos' | 'upload';
  assetID?: string;
  headline?: boolean;
  favorite?: boolean;
};

/**
 * Give each day one photo first, then use distinct spare images from photo-rich
 * days only when another day has no visible photo. Keep every image with its
 * real source day and cap the total spread at one image per weekday.
 */
export function buildPhotoSpread(
  days: string[],
  photosByDay: Record<string, SpreadPhoto[]>,
  futureDays: string[] = [],
): Record<string, SpreadPhoto[]> {
  const future = new Set(futureDays);
  const used = new Set<string>();
  const result: Record<string, SpreadPhoto[]> = {};
  const candidates: Record<string, SpreadPhoto[]> = {};

  for (const day of days) {
    const dayPhotos = [...(photosByDay[day] ?? [])].sort((a, b) =>
      Number(Boolean(b.headline)) - Number(Boolean(a.headline)) ||
      Number(a.kind === 'video') - Number(b.kind === 'video') ||
      Number(Boolean(b.favorite)) - Number(Boolean(a.favorite)) ||
      b.createdAt.localeCompare(a.createdAt),
    );
    candidates[day] = dayPhotos.filter((photo, index) =>
      dayPhotos.findIndex(candidate => candidate.id === photo.id) === index,
    );
    const lead = candidates[day].find(photo => !used.has(photo.id));
    result[day] = lead ? [lead] : [];
    if (lead) used.add(lead.id);
  }

  let emptySlots = days.filter(day => !future.has(day) && result[day].length === 0).length;
  const donors = days.filter(day => result[day].length && candidates[day].length > 1);
  // Take one extra from each donor in turn, favoring days with the most choices.
  donors.sort((a, b) => candidates[b].length - candidates[a].length || days.indexOf(a) - days.indexOf(b));
  const cursor = Object.fromEntries(donors.map(day => [day, 1]));
  while (emptySlots > 0 && donors.length) {
    let added = false;
    for (const day of donors) {
      while (cursor[day] < candidates[day].length && used.has(candidates[day][cursor[day]].id)) cursor[day]++;
      const extra = candidates[day][cursor[day]];
      if (!extra || result[day].length >= 4) continue;
      cursor[day]++;
      result[day].push(extra);
      used.add(extra.id);
      emptySlots--;
      added = true;
      if (emptySlots === 0) break;
    }
    if (!added) break;
  }
  return result;
}

export type PhotoHeadlineCandidate = {
  day: string;
  photoCount: number;
  sourceLength: number;
  detailLength: number;
  eligible?: boolean;
};

/** Choose one image-led card for the spread without hiding edited page text. */
export function choosePhotoHeadlineDay(cards: PhotoHeadlineCandidate[]): string | undefined {
  return [...cards]
    .filter(card => card.photoCount > 0 && card.eligible !== false)
    .sort((a, b) => b.photoCount - a.photoCount ||
      (a.sourceLength + a.detailLength) - (b.sourceLength + b.detailLength) ||
      a.day.localeCompare(b.day))[0]?.day;
}
