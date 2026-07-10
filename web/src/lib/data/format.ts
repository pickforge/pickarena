const integerFormatter = new Intl.NumberFormat('en', {
  maximumFractionDigits: 0
});

const compactIntegerFormatter = new Intl.NumberFormat('en', {
  maximumFractionDigits: 1,
  notation: 'compact'
});

const currencyFormatter = new Intl.NumberFormat('en', {
  currency: 'USD',
  maximumFractionDigits: 2,
  minimumFractionDigits: 2,
  style: 'currency'
});

export function formatPercent(value: number | null): string {
  if (!isFiniteNumber(value)) return 'unknown';

  return `${(value * 100).toFixed(value === 0 || value === 1 ? 0 : 1)}%`;
}

export function formatCount(value: number | null): string {
  if (!isFiniteNumber(value)) return 'unknown';

  return integerFormatter.format(Math.round(value));
}

export function formatDuration(value: number | null): string {
  if (!isFiniteNumber(value)) return 'unknown';

  if (value < 1000) return `${Math.round(value)} ms`;
  if (value < 60000) return `${(value / 1000).toFixed(value < 10000 ? 1 : 0)} s`;

  const minutes = Math.floor(value / 60000);
  const seconds = Math.round((value % 60000) / 1000);
  return seconds > 0 ? `${minutes} min ${seconds} s` : `${minutes} min`;
}

export function formatTokens(value: number | null): string {
  if (!isFiniteNumber(value)) return 'unknown';

  return compactIntegerFormatter.format(Math.round(value));
}

export function formatCost(value: number | null): string {
  if (!isFiniteNumber(value)) return 'unknown';

  return currencyFormatter.format(value / 1_000_000);
}

type ModelIdentity = {
  providerId: string;
  modelId: string;
  displayName?: string | null;
  providerLabel?: string | null;
};

export function modelName(entity: ModelIdentity): string {
  if (entity.displayName && entity.displayName.length > 0) return entity.displayName;
  return entity.modelId.replace(/^custom:/, '');
}

export function providerName(entity: ModelIdentity): string {
  if (entity.providerLabel && entity.providerLabel.length > 0) {
    return entity.providerLabel;
  }
  return entity.providerId;
}

const EM_DASH = '—';

export function percentText(value: number | null): string {
  return isFiniteNumber(value) ? formatPercent(value) : EM_DASH;
}

export function countText(value: number | null): string {
  return isFiniteNumber(value) ? formatCount(value) : EM_DASH;
}

export function costText(value: number | null): string {
  return isFiniteNumber(value) ? formatCost(value) : EM_DASH;
}

export function durationText(value: number | null): string {
  return isFiniteNumber(value) ? formatDuration(value) : EM_DASH;
}

export function tokensText(value: number | null): string {
  return isFiniteNumber(value) ? formatTokens(value) : EM_DASH;
}

function isFiniteNumber(value: number | null): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}
