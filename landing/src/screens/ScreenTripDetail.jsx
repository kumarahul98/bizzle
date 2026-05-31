import React from 'react'
import { TOKENS, FONTS } from '../tokens.js'
import { Phone, Icon } from '../components/Phone.jsx'
import { FauxMap } from '../components/FauxMap.jsx'
import { StuckBar } from '../components/charts.jsx'

function ScreenTripDetail({ dark = false }) {
  const t = dark ? TOKENS.dark : TOKENS.light;
  return (
    <Phone dark={dark} time="20:18">
      <div style={{ padding: '12px 20px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{
          width: 36, height: 36, borderRadius: 18,
          background: t.surface, display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}><Icon name="arrowL" size={18} color={t.text}/></div>
        <div style={{ fontSize: 13, fontWeight: 600, color: t.textDim }}>Mon, 28 Apr · 18:05</div>
        <div style={{
          width: 36, height: 36, borderRadius: 18,
          background: t.surface, display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}><Icon name="more" size={18} color={t.text}/></div>
      </div>

      <div style={{ flex: 1, overflow: 'auto' }}>
        <FauxMap t={t} height={210}/>

        {/* Title */}
        <div style={{ padding: '20px 20px 12px' }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: t.textMuted, letterSpacing: 1, textTransform: 'uppercase' }}>Evening commute</div>
          <div style={{ fontSize: 24, fontWeight: 700, letterSpacing: -0.6, marginTop: 2 }}>To home</div>
        </div>

        {/* hero stats — duration + stuck breakdown */}
        <div style={{ padding: '0 20px' }}>
          <div style={{
            background: t.bgElev, border: `1px solid ${t.border}`, borderRadius: 16,
            padding: 18,
          }}>
            <div style={{ display: 'flex', gap: 24, marginBottom: 16 }}>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 11, fontWeight: 600, color: t.textMuted, letterSpacing: 0.6, textTransform: 'uppercase' }}>Duration</div>
                <div style={{ fontFamily: FONTS.mono, fontSize: 28, fontWeight: 600, letterSpacing: -1, marginTop: 4 }}>47m</div>
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 11, fontWeight: 600, color: t.textMuted, letterSpacing: 0.6, textTransform: 'uppercase' }}>Distance</div>
                <div style={{ fontFamily: FONTS.mono, fontSize: 28, fontWeight: 600, letterSpacing: -1, marginTop: 4 }}>6.4 km</div>
              </div>
            </div>
            <StuckBar t={t} moving={29} stuck={18}/>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10, fontFamily: FONTS.mono, fontSize: 12 }}>
              <span style={{ color: t.textDim }}><span style={{ color: t.moving, fontWeight: 700 }}>●</span> 29m moving</span>
              <span style={{ color: t.textDim }}><span style={{ color: t.stuck, fontWeight: 700 }}>●</span> 18m stuck</span>
            </div>
          </div>
        </div>

        {/* Pointed insight */}
        <div style={{ padding: '14px 20px 0' }}>
          <div style={{
            background: t.stuckBg, borderRadius: 14, padding: '14px 16px',
            display: 'flex', gap: 12, alignItems: 'flex-start',
          }}>
            <Icon name="clock" size={18} color={t.stuck}/>
            <div style={{ fontSize: 13, lineHeight: 1.45, color: t.text }}>
              You lost <span style={{ fontWeight: 700, color: t.stuck }}>18 minutes</span> stuck in traffic. That's <span style={{ fontWeight: 700 }}>38%</span> of this trip.
            </div>
          </div>
        </div>

        {/* Timeline */}
        <div style={{ padding: '14px 20px 0' }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: t.textMuted, letterSpacing: 1, textTransform: 'uppercase', marginBottom: 10 }}>Timeline</div>
          {[
            { time: '18:05', label: 'Started recording', tone: 'text', icon: 'pin' },
            { time: '18:14', label: 'Stuck on Outer Ring Rd', dur: '11m', tone: 'stuck', icon: 'clock' },
            { time: '18:33', label: 'Stuck near Dairy Circle', dur: '7m', tone: 'stuck', icon: 'clock' },
            { time: '18:52', label: 'Arrived home', tone: 'text', icon: 'flag' },
          ].map((row, i) => (
            <div key={i} style={{ display: 'flex', gap: 12, padding: '8px 0', alignItems: 'center' }}>
              <div style={{ fontFamily: FONTS.mono, fontSize: 12, color: t.textDim, width: 44 }}>{row.time}</div>
              <div style={{
                width: 28, height: 28, borderRadius: 14,
                background: row.tone === 'stuck' ? t.stuckBg : t.surface,
                color: row.tone === 'stuck' ? t.stuck : t.textDim,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}><Icon name={row.icon} size={14} strokeWidth={2}/></div>
              <div style={{ flex: 1, fontSize: 13.5, fontWeight: 500 }}>{row.label}</div>
              {row.dur && <div style={{ fontFamily: FONTS.mono, fontSize: 12, fontWeight: 600, color: t.stuck }}>{row.dur}</div>}
            </div>
          ))}
        </div>

        <div style={{ padding: '16px 20px 24px', display: 'flex', gap: 10 }}>
          <div style={{
            flex: 1, padding: '12px', borderRadius: 12,
            border: `1px solid ${t.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            fontSize: 13, fontWeight: 600,
          }}><Icon name="edit" size={14} color={t.text}/> Edit</div>
          <div style={{
            flex: 1, padding: '12px', borderRadius: 12,
            border: `1px solid ${t.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            fontSize: 13, fontWeight: 600, color: t.danger,
          }}><Icon name="trash" size={14} color={t.danger}/> Delete</div>
        </div>
      </div>
    </Phone>
  );
}

export { ScreenTripDetail }
