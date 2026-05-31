import React from 'react'
import { TOKENS, FONTS } from '../tokens.js'
import { Phone, Icon } from '../components/Phone.jsx'
import { FauxMap } from '../components/FauxMap.jsx'

// Variation B — full-bleed map, floating bottom sheet
function ScreenRecordingB({ dark = false }) {
  const t = dark ? TOKENS.dark : TOKENS.light;
  return (
    <Phone dark={dark} time="8:34">
      <div style={{ position: 'relative', flex: 1, overflow: 'hidden' }}>
        <FauxMap t={t} height={520} showLabels={true}/>

        {/* top pill */}
        <div style={{ position: 'absolute', top: 14, left: 20, right: 20, display: 'flex', justifyContent: 'space-between' }}>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 8,
            padding: '8px 14px', borderRadius: 100,
            background: t.bgElev, border: `1px solid ${t.border}`,
            boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
          }}>
            <span style={{ width: 7, height: 7, borderRadius: 4, background: t.record }}/>
            <span style={{ fontSize: 12, fontWeight: 600, color: t.text }}>To office</span>
          </div>
          <div style={{
            width: 36, height: 36, borderRadius: 18, background: t.bgElev,
            border: `1px solid ${t.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
          }}>
            <Icon name="pause" size={16} color={t.text}/>
          </div>
        </div>

        {/* bottom sheet */}
        <div style={{
          position: 'absolute', bottom: 0, left: 0, right: 0,
          background: t.bgElev,
          borderRadius: '24px 24px 0 0',
          padding: '12px 20px 20px',
          boxShadow: '0 -10px 30px rgba(0,0,0,0.08)',
        }}>
          <div style={{ width: 36, height: 4, borderRadius: 2, background: t.border, margin: '0 auto 14px' }}/>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginBottom: 14 }}>
            <div style={{
              fontFamily: FONTS.mono, fontSize: 38, fontWeight: 500, letterSpacing: -1.5, lineHeight: 1,
            }}>00:22:14</div>
            <div style={{ fontSize: 12, color: t.textDim, marginLeft: 'auto' }}>elapsed</div>
          </div>
          <div style={{ display: 'flex', gap: 24, paddingBottom: 14, borderBottom: `1px solid ${t.border}` }}>
            <div>
              <div style={{ fontSize: 10.5, fontWeight: 600, color: t.textMuted, letterSpacing: 0.6, textTransform: 'uppercase' }}>Distance</div>
              <div style={{ fontFamily: FONTS.mono, fontSize: 16, fontWeight: 600, marginTop: 2 }}>4.1 km</div>
            </div>
            <div>
              <div style={{ fontSize: 10.5, fontWeight: 600, color: t.textMuted, letterSpacing: 0.6, textTransform: 'uppercase' }}>Speed</div>
              <div style={{ fontFamily: FONTS.mono, fontSize: 16, fontWeight: 600, marginTop: 2 }}>38 km/h</div>
            </div>
            <div>
              <div style={{ fontSize: 10.5, fontWeight: 600, color: t.textMuted, letterSpacing: 0.6, textTransform: 'uppercase' }}>Stuck</div>
              <div style={{ fontFamily: FONTS.mono, fontSize: 16, fontWeight: 600, color: t.stuck, marginTop: 2 }}>4m</div>
            </div>
          </div>
          <div style={{
            marginTop: 14, background: t.record, color: '#fff',
            padding: '16px 20px', borderRadius: 14,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
          }}>
            <Icon name="stop" size={14} color="#fff"/>
            <span style={{ fontWeight: 600, fontSize: 14, letterSpacing: 0.4, textTransform: 'uppercase' }}>End trip</span>
          </div>
        </div>
      </div>
    </Phone>
  );
}

export { ScreenRecordingB }
