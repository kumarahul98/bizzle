// Traevy phone shell — replaces android-frame's status bar with our own
// styled status bar, hides app bar, owns content area.

import React from 'react'
import { TOKENS, FONTS } from '../tokens.js'

const TraevyStatusBar = ({ t, dark, time = '8:47' }) => (
  <div style={{
    height: 32, display: 'flex', alignItems: 'center',
    justifyContent: 'space-between', padding: '0 20px 0 22px',
    position: 'relative', flexShrink: 0,
    fontFamily: FONTS.ui, color: t.text, fontSize: 13, fontWeight: 600,
    letterSpacing: 0.1,
  }}>
    <span style={{ fontVariantNumeric: 'tabular-nums' }}>{time}</span>
    <div style={{
      position: 'absolute', left: '50%', top: 8, transform: 'translateX(-50%)',
      width: 18, height: 18, borderRadius: 100, background: '#0a0a0a',
    }} />
    <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
      {/* signal */}
      <svg width="14" height="11" viewBox="0 0 14 11" fill="none">
        {[0,1,2,3].map(i => (
          <rect key={i} x={i*3.5} y={11-(i+1)*2.5} width="2.5" height={(i+1)*2.5} rx="0.5" fill={t.text}/>
        ))}
      </svg>
      {/* wifi */}
      <svg width="14" height="11" viewBox="0 0 14 11" fill="none">
        <path d="M7 10.2 L1 4.2 a8.5 8.5 0 0 1 12 0 z" fill={t.text}/>
      </svg>
      {/* battery */}
      <svg width="22" height="11" viewBox="0 0 22 11" fill="none">
        <rect x="0.5" y="0.5" width="18" height="10" rx="2.5" stroke={t.text} fill="none"/>
        <rect x="2.5" y="2.5" width="13" height="6" rx="1" fill={t.text}/>
        <rect x="19.5" y="3.5" width="1.5" height="4" rx="0.5" fill={t.text}/>
      </svg>
    </div>
  </div>
);

const TraevyNavBar = ({ t }) => (
  <div style={{
    height: 22, display: 'flex', alignItems: 'flex-start', justifyContent: 'center',
    paddingTop: 8, flexShrink: 0,
  }}>
    <div style={{ width: 124, height: 4, borderRadius: 2, background: t.text, opacity: 0.55 }} />
  </div>
);

// Phone — owns its theme. Pass `dark` to flip.
function Phone({ children, dark = false, time = '8:47', width = 360, height = 740 }) {
  const t = dark ? TOKENS.dark : TOKENS.light;
  return (
    <div style={{
      width, height, background: t.bg, color: t.text,
      display: 'flex', flexDirection: 'column',
      fontFamily: FONTS.ui, position: 'relative', overflow: 'hidden',
    }}>
      <TraevyStatusBar t={t} dark={dark} time={time} />
      <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
        {children}
      </div>
      <TraevyNavBar t={t} />
    </div>
  );
}

// ── Icon set (consistent stroke 1.6, lucide-ish) ────────────
const Icon = ({ name, size = 22, color = 'currentColor', strokeWidth = 1.6 }) => {
  const p = {
    play: <polygon points="6,4 19,12 6,20" fill={color} stroke="none"/>,
    stop: <rect x="6" y="6" width="12" height="12" rx="1" fill={color} stroke="none"/>,
    pause: <g><rect x="6" y="5" width="4" height="14" rx="0.5" fill={color}/><rect x="14" y="5" width="4" height="14" rx="0.5" fill={color}/></g>,
    home: <path d="M3 11l9-8 9 8M5 9.5V20a1 1 0 0 0 1 1h4v-6h4v6h4a1 1 0 0 0 1-1V9.5"/>,
    list: <g><line x1="8" y1="6" x2="20" y2="6"/><line x1="8" y1="12" x2="20" y2="12"/><line x1="8" y1="18" x2="20" y2="18"/><circle cx="4" cy="6" r="1"/><circle cx="4" cy="12" r="1"/><circle cx="4" cy="18" r="1"/></g>,
    stats: <g><line x1="4" y1="20" x2="20" y2="20"/><rect x="6" y="12" width="3" height="6"/><rect x="11" y="8" width="3" height="10"/><rect x="16" y="14" width="3" height="4"/></g>,
    settings: <g><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></g>,
    arrow: <g><line x1="5" y1="12" x2="19" y2="12"/><polyline points="13,6 19,12 13,18"/></g>,
    arrowL: <g><line x1="19" y1="12" x2="5" y2="12"/><polyline points="11,6 5,12 11,18"/></g>,
    chevron: <polyline points="9,6 15,12 9,18"/>,
    chevronD: <polyline points="6,9 12,15 18,9"/>,
    plus: <g><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></g>,
    more: <g><circle cx="12" cy="6" r="1.2" fill={color}/><circle cx="12" cy="12" r="1.2" fill={color}/><circle cx="12" cy="18" r="1.2" fill={color}/></g>,
    pin: <g><path d="M12 21s-7-7.5-7-12.5A7 7 0 0 1 19 8.5C19 13.5 12 21 12 21z"/><circle cx="12" cy="9" r="2.5"/></g>,
    flag: <g><line x1="5" y1="21" x2="5" y2="4"/><path d="M5 4h12l-2 4 2 4H5"/></g>,
    clock: <g><circle cx="12" cy="12" r="9"/><polyline points="12,7 12,12 15.5,14"/></g>,
    car: <g><path d="M5 14h14l-1.5-5a2 2 0 0 0-2-1.5h-7a2 2 0 0 0-2 1.5L5 14z"/><rect x="3" y="14" width="18" height="5" rx="1.5"/><circle cx="7.5" cy="18.5" r="1.4" fill={color}/><circle cx="16.5" cy="18.5" r="1.4" fill={color}/></g>,
    bell: <g><path d="M6 8a6 6 0 0 1 12 0c0 7 3 8 3 8H3s3-1 3-8z"/><path d="M10 21a2 2 0 0 0 4 0"/></g>,
    google: <g stroke="none"><path d="M21.6 12.2c0-.7-.06-1.4-.18-2.05H12v3.88h5.4a4.6 4.6 0 0 1-2 3.03v2.5h3.24c1.9-1.75 3-4.32 3-7.36z" fill="#4285F4"/><path d="M12 22c2.7 0 4.96-.9 6.62-2.43l-3.24-2.5a6.04 6.04 0 0 1-9.05-3.16H2.96v2.58A10 10 0 0 0 12 22z" fill="#34A853"/><path d="M6.34 13.9a6 6 0 0 1 0-3.83V7.5H2.96a10 10 0 0 0 0 9l3.38-2.6z" fill="#FBBC04"/><path d="M12 6.04c1.47-.02 2.88.52 3.96 1.53l2.86-2.86A10 10 0 0 0 2.96 7.5l3.38 2.58A6 6 0 0 1 12 6.04z" fill="#EA4335"/></g>,
    check: <polyline points="4,12 10,18 20,6"/>,
    edit: <g><path d="M14 4l4 4L8 18H4v-4z"/><line x1="13" y1="5" x2="17" y2="9"/></g>,
    trash: <g><polyline points="4,7 20,7"/><path d="M9 7V4h6v3M6 7l1 14a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1l1-14"/></g>,
    cal: <g><rect x="3" y="5" width="18" height="16" rx="2"/><line x1="3" y1="10" x2="21" y2="10"/><line x1="8" y1="3" x2="8" y2="7"/><line x1="16" y1="3" x2="16" y2="7"/></g>,
    map: <g><polygon points="3,6 9,3 15,6 21,3 21,18 15,21 9,18 3,21"/><line x1="9" y1="3" x2="9" y2="18"/><line x1="15" y1="6" x2="15" y2="21"/></g>,
    sun: <g><circle cx="12" cy="12" r="4"/><line x1="12" y1="2" x2="12" y2="4"/><line x1="12" y1="20" x2="12" y2="22"/><line x1="2" y1="12" x2="4" y2="12"/><line x1="20" y1="12" x2="22" y2="12"/><line x1="4.9" y1="4.9" x2="6.3" y2="6.3"/><line x1="17.7" y1="17.7" x2="19.1" y2="19.1"/><line x1="4.9" y1="19.1" x2="6.3" y2="17.7"/><line x1="17.7" y1="6.3" x2="19.1" y2="4.9"/></g>,
    moon: <path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>,
    cloud: <path d="M6 19a4 4 0 0 1 0-8 6 6 0 0 1 11.5 1.5A3.5 3.5 0 0 1 17.5 19H6z"/>,
    user: <g><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></g>,
    refresh: <g><polyline points="20,4 20,9 15,9"/><polyline points="4,20 4,15 9,15"/><path d="M5 9a8 8 0 0 1 14-2M19 15a8 8 0 0 1-14 2"/></g>,
    location: <g><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="2.5" fill={color}/><line x1="12" y1="2" x2="12" y2="5"/><line x1="12" y1="19" x2="12" y2="22"/><line x1="2" y1="12" x2="5" y2="12"/><line x1="19" y1="12" x2="22" y2="12"/></g>,
    navigate: <polygon points="12,3 6,21 12,17 18,21" fill={color} stroke={color} strokeLinejoin="round"/>,
  };
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
      stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
      {p[name]}
    </svg>
  );
};

// Tab bar (bottom)
const TabBar = ({ t, active = 'home' }) => {
  const items = [
    { id: 'home', icon: 'home', label: 'Today' },
    { id: 'history', icon: 'list', label: 'Trips' },
    { id: 'stats', icon: 'stats', label: 'Stats' },
    { id: 'settings', icon: 'settings', label: 'Settings' },
  ];
  return (
    <div style={{
      display: 'flex', borderTop: `1px solid ${t.border}`,
      background: t.bgElev, paddingTop: 6, paddingBottom: 6,
    }}>
      {items.map(it => (
        <div key={it.id} style={{
          flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2,
          padding: '6px 0',
          color: it.id === active ? t.text : t.textMuted,
        }}>
          <Icon name={it.icon} size={22} strokeWidth={it.id === active ? 2 : 1.6}/>
          <span style={{ fontSize: 10.5, fontWeight: it.id === active ? 600 : 500, letterSpacing: 0.1 }}>{it.label}</span>
        </div>
      ))}
    </div>
  );
};

export { Phone, TabBar, Icon };
