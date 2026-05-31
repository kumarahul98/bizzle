// Faux map with streets + labels + a route line.
// Hand-drawn look, calm transit aesthetic.

import React from 'react'
import { TOKENS, FONTS } from '../tokens.js'
import { Icon } from './Phone.jsx'

function FauxMap({ t, height = 220, route = 'commute', interactive = true, showLabels = true, zoom = 1 }) {
  // Route encoded as a polyline list of {x, y, traffic} where traffic 0/1
  // determines green vs amber. Shape evokes city → highway → office.
  const W = 360, H = height;

  // Streets — drawn as 2 layers (stroke + lighter fill) for that map look.
  const streets = [
    // Big arteries
    { d: 'M0 70 L360 90', w: 14, label: 'BANNERGHATTA RD', lx: 70, ly: 64 },
    { d: 'M120 0 L140 240', w: 12, label: '', lx: 0, ly: 0 },
    { d: 'M0 160 L360 175', w: 11, label: 'OUTER RING RD', lx: 200, ly: 154 },
    { d: 'M260 0 L280 240', w: 11, label: '', lx: 0, ly: 0 },
    // Smaller streets
    { d: 'M0 30 L360 35', w: 5 },
    { d: 'M0 110 L360 125', w: 6 },
    { d: 'M0 200 L360 220', w: 5 },
    { d: 'M50 0 L60 240', w: 5 },
    { d: 'M190 0 L200 240', w: 6 },
    { d: 'M320 0 L330 240', w: 5 },
    // Diagonals
    { d: 'M40 240 Q150 170 240 240', w: 5 },
  ].map(s => ({ ...s, w: s.w * zoom * 0.85 }));

  // Park polygon
  const park = 'M30 130 L100 125 L105 158 L40 162 Z';
  // Water sliver
  const water = 'M260 100 Q300 105 360 100 L360 130 Q300 135 260 130 Z';

  // Route — start dot to end dot, with one "stuck" middle segment
  const routePts = route === 'commute'
    ? [
        { x: 30, y: 195, m: true },   // home
        { x: 60, y: 175, m: true },
        { x: 100, y: 165, m: true },
        { x: 145, y: 165, m: true },
        { x: 175, y: 168, m: false }, // stuck
        { x: 210, y: 165, m: false },
        { x: 245, y: 158, m: false },
        { x: 275, y: 130, m: true },
        { x: 295, y: 95, m: true },
        { x: 320, y: 60, m: true },   // office
      ]
    : [];

  const segs = [];
  for (let i = 0; i < routePts.length - 1; i++) {
    segs.push({ a: routePts[i], b: routePts[i+1], m: routePts[i].m && routePts[i+1].m });
  }

  return (
    <div style={{
      position: 'relative', width: '100%', height,
      background: t.mapBg, overflow: 'hidden',
      fontFamily: FONTS.ui,
    }}>
      <svg width="100%" height={H} viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="xMidYMid slice">
        {/* park */}
        <path d={park} fill={t.mapPark} />
        {/* water */}
        <path d={water} fill={t.mapWater} />
        {/* street strokes (border) */}
        {streets.map((s, i) => (
          <path key={'s'+i} d={s.d} stroke={t.mapStroke} strokeWidth={s.w + 2} strokeLinecap="butt" fill="none" />
        ))}
        {/* street fills */}
        {streets.map((s, i) => (
          <path key={'f'+i} d={s.d} stroke={t.mapStreet} strokeWidth={s.w} strokeLinecap="butt" fill="none" />
        ))}

        {/* route */}
        {segs.map((s, i) => (
          <line key={'r'+i} x1={s.a.x} y1={s.a.y} x2={s.b.x} y2={s.b.y}
            stroke={s.m ? t.routeMov : t.routeStuck} strokeWidth="4.5" strokeLinecap="round"/>
        ))}

        {/* start pin (home) */}
        <circle cx={routePts[0]?.x} cy={routePts[0]?.y} r="6" fill={t.bgElev} stroke={t.text} strokeWidth="2"/>
        <circle cx={routePts[0]?.x} cy={routePts[0]?.y} r="2.5" fill={t.text}/>
        {/* end pin (office) */}
        <g transform={`translate(${routePts.at(-1)?.x - 10} ${routePts.at(-1)?.y - 22})`}>
          <path d="M10 22 L10 22 C10 22 0 13 0 7 a10 10 0 0 1 20 0 c0 6 -10 15 -10 15z"
            fill={t.routeMov} stroke={t.bgElev} strokeWidth="2"/>
          <circle cx="10" cy="7.5" r="3" fill={t.bgElev}/>
        </g>

        {/* labels */}
        {showLabels && streets.filter(s => s.label).map((s, i) => (
          <text key={'l'+i} x={s.lx} y={s.ly}
            fontFamily={FONTS.ui} fontSize="8.5" fontWeight="600"
            fill={t.mapLabel} letterSpacing="0.6">{s.label}</text>
        ))}
        {showLabels && (
          <>
            <text x="50" y="148" fontFamily={FONTS.ui} fontSize="8.5" fontWeight="500" fill={t.mapLabel} fillOpacity="0.7" letterSpacing="0.4">CUBBON PARK</text>
            <text x="280" y="118" fontFamily={FONTS.ui} fontSize="8.5" fontWeight="500" fill={t.mapLabel} fillOpacity="0.6">ULSOOR LAKE</text>
          </>
        )}
      </svg>

      {/* corner controls */}
      {interactive && (
        <div style={{ position: 'absolute', right: 12, top: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
          <div style={{
            width: 36, height: 36, borderRadius: 8, background: t.bgElev,
            border: `1px solid ${t.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: t.text, boxShadow: '0 2px 6px rgba(0,0,0,0.06)',
          }}>
            <Icon name="navigate" size={16} color={t.accent}/>
          </div>
        </div>
      )}
    </div>
  );
}

export { FauxMap };
