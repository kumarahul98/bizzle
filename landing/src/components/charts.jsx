// Charts + small data viz primitives for Traevy stats screens.

import React from 'react'
import { TOKENS, FONTS } from '../tokens.js'
import { Icon } from './Phone.jsx'

// Mini bar chart — 28-day daily commute time
function TrendBars({ t, data, height = 90, highlight = -1 }) {
  const max = Math.max(...data);
  return (
    <div style={{
      display: 'flex', alignItems: 'flex-end', gap: 2.5,
      height, width: '100%',
    }}>
      {data.map((v, i) => {
        const h = (v / max) * 100;
        const isToday = i === data.length - 1;
        const isHi = i === highlight;
        return (
          <div key={i} style={{
            flex: 1, height: `${h}%`, minHeight: 3,
            borderRadius: '2px 2px 0 0',
            background: isToday ? t.accent : isHi ? t.stuck : t.borderStr,
            opacity: isToday || isHi ? 1 : 0.65,
          }}/>
        );
      })}
    </div>
  );
}

// Stuck vs moving stacked bar (1 row)
function StuckBar({ t, moving, stuck, height = 14, label = false }) {
  const total = moving + stuck;
  const mv = (moving/total)*100;
  return (
    <div>
      <div style={{
        display: 'flex', height, borderRadius: height/2, overflow: 'hidden',
        background: t.surface2,
      }}>
        <div style={{ width: `${mv}%`, background: t.moving }}/>
        <div style={{ flex: 1, background: t.stuck }}/>
      </div>
      {label && (
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6,
          fontFamily: FONTS.mono, fontSize: 11, color: t.textDim }}>
          <span><span style={{ color: t.moving, fontWeight: 600 }}>●</span> {moving}m moving</span>
          <span><span style={{ color: t.stuck, fontWeight: 600 }}>●</span> {stuck}m stuck</span>
        </div>
      )}
    </div>
  );
}

// Weekday averages chart — 5 vertical bars Mon-Fri
function WeekdayChart({ t, days }) {
  const max = Math.max(...days.map(d => d.minutes));
  const labels = ['Mon','Tue','Wed','Thu','Fri'];
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', height: 120, gap: 12 }}>
      {days.map((d, i) => {
        const h = (d.minutes / max) * 100;
        const isWorst = d.tag === 'worst';
        const isBest = d.tag === 'best';
        return (
          <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, height: '100%' }}>
            <div style={{ flex: 1, width: '100%', display: 'flex', alignItems: 'flex-end' }}>
              <div style={{
                width: '100%', height: `${h}%`,
                borderRadius: 4,
                background: isWorst ? t.stuck : isBest ? t.moving : t.borderStr,
                position: 'relative',
              }}>
                {(isWorst || isBest) && (
                  <div style={{
                    position: 'absolute', top: -18, left: '50%', transform: 'translateX(-50%)',
                    fontFamily: FONTS.mono, fontSize: 11, fontWeight: 600,
                    color: isWorst ? t.stuck : t.moving, whiteSpace: 'nowrap',
                  }}>{d.minutes}m</div>
                )}
              </div>
            </div>
            <div style={{ fontSize: 11, fontWeight: 500, color: t.textDim, letterSpacing: 0.3 }}>{labels[i]}</div>
          </div>
        );
      })}
    </div>
  );
}

// Donut for moving vs stuck percent
function Donut({ t, moving, stuck, size = 110, stroke = 14 }) {
  const total = moving + stuck;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const movC = (moving/total) * c;
  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={t.stuck} strokeWidth={stroke}/>
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={t.moving} strokeWidth={stroke}
          strokeDasharray={`${movC} ${c}`} strokeLinecap="butt"/>
      </svg>
      <div style={{
        position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center',
      }}>
        <div style={{ fontFamily: FONTS.mono, fontSize: 22, fontWeight: 600, letterSpacing: -0.5 }}>
          {Math.round((stuck/total)*100)}%
        </div>
        <div style={{ fontSize: 10, color: t.textDim, marginTop: -2 }}>stuck</div>
      </div>
    </div>
  );
}

// Trip card row
function TripRow({ t, dir = 'office', start = '08:12', end = '08:47', dur = '35m', dist = '6.2 km', stuck = '7m', divider = true }) {
  const isOffice = dir === 'office';
  return (
    <div style={{
      display: 'flex', alignItems: 'center', padding: '14px 20px', gap: 14,
      borderBottom: divider ? `1px solid ${t.border}` : 'none',
    }}>
      <div style={{
        width: 36, height: 36, borderRadius: 18,
        background: isOffice ? t.accentBg : t.movingBg,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: isOffice ? t.accent : t.moving,
      }}>
        <Icon name={isOffice ? 'arrow' : 'arrowL'} size={18} strokeWidth={2}/>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8 }}>
          <span style={{ fontWeight: 600, fontSize: 15 }}>{isOffice ? 'To office' : 'To home'}</span>
          <span style={{ fontFamily: FONTS.mono, fontSize: 13, fontWeight: 600, color: t.text }}>{dur}</span>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 3, fontSize: 12, color: t.textDim, fontFamily: FONTS.mono }}>
          <span>{start} → {end} · {dist}</span>
          <span style={{ color: t.stuck, fontWeight: 600 }}>{stuck} stuck</span>
        </div>
      </div>
    </div>
  );
}

export { TrendBars, StuckBar, WeekdayChart, Donut, TripRow };
