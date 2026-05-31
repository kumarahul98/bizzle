// Traevy design tokens — light + dark
// Calm, transit-app inspired. Soft surfaces, warm-neutral whites, muted accents.

export const TOKENS = {
  light: {
    bg:        'oklch(0.985 0.003 80)',
    bgElev:    '#ffffff',
    surface:   'oklch(0.97 0.004 80)',
    surface2:  'oklch(0.945 0.005 80)',
    border:    'oklch(0.9 0.005 80)',
    borderStr: 'oklch(0.84 0.006 80)',
    text:      'oklch(0.22 0.01 250)',
    textDim:   'oklch(0.45 0.01 250)',
    textMuted: 'oklch(0.62 0.01 250)',

    moving:    'oklch(0.62 0.13 155)',
    movingBg:  'oklch(0.93 0.04 155)',
    stuck:     'oklch(0.68 0.14 65)',
    stuckBg:   'oklch(0.94 0.04 75)',

    accent:    'oklch(0.45 0.06 240)',
    accentBg:  'oklch(0.94 0.015 240)',

    danger:    'oklch(0.6 0.18 25)',
    record:    'oklch(0.62 0.16 25)',

    mapBg:     'oklch(0.955 0.005 95)',
    mapStreet: 'oklch(0.995 0.002 95)',
    mapStroke: 'oklch(0.88 0.005 95)',
    mapWater:  'oklch(0.92 0.025 230)',
    mapPark:   'oklch(0.92 0.04 145)',
    mapLabel:  'oklch(0.55 0.01 250)',
    routeMov:  'oklch(0.55 0.14 155)',
    routeStuck:'oklch(0.65 0.16 65)',
  },
  dark: {
    bg:        'oklch(0.16 0.006 250)',
    bgElev:    'oklch(0.21 0.006 250)',
    surface:   'oklch(0.22 0.006 250)',
    surface2:  'oklch(0.26 0.006 250)',
    border:    'oklch(0.28 0.008 250)',
    borderStr: 'oklch(0.34 0.01 250)',
    text:      'oklch(0.96 0.005 250)',
    textDim:   'oklch(0.72 0.008 250)',
    textMuted: 'oklch(0.55 0.008 250)',

    moving:    'oklch(0.78 0.14 155)',
    movingBg:  'oklch(0.32 0.04 155)',
    stuck:     'oklch(0.8 0.13 75)',
    stuckBg:   'oklch(0.34 0.05 70)',

    accent:    'oklch(0.78 0.08 240)',
    accentBg:  'oklch(0.28 0.025 240)',

    danger:    'oklch(0.7 0.18 25)',
    record:    'oklch(0.7 0.18 25)',

    mapBg:     'oklch(0.18 0.006 250)',
    mapStreet: 'oklch(0.26 0.008 250)',
    mapStroke: 'oklch(0.3 0.008 250)',
    mapWater:  'oklch(0.28 0.04 230)',
    mapPark:   'oklch(0.26 0.04 145)',
    mapLabel:  'oklch(0.6 0.01 250)',
    routeMov:  'oklch(0.78 0.14 155)',
    routeStuck:'oklch(0.82 0.14 70)',
  },
};

export const FONTS = {
  ui: '"Inter", -apple-system, system-ui, sans-serif',
  mono: '"JetBrains Mono", "SF Mono", ui-monospace, Menlo, monospace',
};
