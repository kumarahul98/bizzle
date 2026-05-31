import React from 'react';
import { TOKENS, FONTS } from '../tokens.js';
import { Phone, TabBar, Icon } from '../components/Phone.jsx';
import { TripRow, StuckBar } from '../components/charts.jsx';

function ScreenHome({ dark = false }) {
  const t = dark ? TOKENS.dark : TOKENS.light;
  return (
    <Phone dark={dark} time="20:14">
      {/* header */}
      <div style={{ padding: '14px 20px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 11, fontWeight: 600, color: t.textMuted, letterSpacing: 1, textTransform: 'uppercase' }}>Mon · 28 Apr</div>
          <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: -0.6, marginTop: 2 }}>Hi, Rahul</div>
        </div>
        <div style={{
          width: 36, height: 36, borderRadius: 18, background: t.surface,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontFamily: FONTS.mono, fontWeight: 600, fontSize: 13, color: t.textDim,
        }}>R</div>
      </div>

      {/* hero record button */}
      <div style={{ padding: '8px 20px 20px' }}>
        <div style={{
          background: t.bgElev, border: `1px solid ${t.border}`,
          borderRadius: 24, padding: '24px 20px 20px',
          display: 'flex', flexDirection: 'column', alignItems: 'center',
        }}>
          <div style={{ fontSize: 12, color: t.textDim, fontWeight: 500, marginBottom: 14, letterSpacing: 0.4, textTransform: 'uppercase' }}>
            Ready to record
          </div>
          <div style={{
            width: 124, height: 124, borderRadius: 62,
            background: t.record, color: '#fff',
            display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
            boxShadow: `0 12px 32px ${dark ? 'rgba(0,0,0,0.4)' : 'rgba(180, 60, 40, 0.25)'}`,
          }}>
            <Icon name="play" size={36} color="#fff"/>
            <div style={{ fontSize: 13, fontWeight: 600, letterSpacing: 0.6, marginTop: 4 }}>START</div>
          </div>
          <div style={{ marginTop: 16, fontSize: 12.5, color: t.textDim }}>
            Auto-labelled <span style={{ color: t.text, fontWeight: 600 }}>To home</span> · 20:14
          </div>
        </div>
      </div>

      {/* today's trips */}
      <div style={{ flex: 1, overflow: 'auto', padding: '4px 20px 16px' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10 }}>
          <div style={{ fontSize: 12, fontWeight: 600, color: t.textMuted, letterSpacing: 1, textTransform: 'uppercase' }}>Today</div>
          <div style={{ fontFamily: FONTS.mono, fontSize: 12, color: t.textDim }}>1 of 2 recorded</div>
        </div>

        <div style={{ background: t.bgElev, border: `1px solid ${t.border}`, borderRadius: 16, overflow: 'hidden' }}>
          <TripRow t={t} dir="office" start="08:12" end="08:47" dur="35m" dist="6.2 km" stuck="7m"/>
          <div style={{
            display: 'flex', alignItems: 'center', padding: '14px 20px', gap: 14,
            background: t.surface,
          }}>
            <div style={{
              width: 36, height: 36, borderRadius: 18,
              border: `1.5px dashed ${t.borderStr}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: t.textMuted,
            }}>
              <Icon name="plus" size={16} strokeWidth={2}/>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontWeight: 600, fontSize: 14, color: t.textDim }}>Evening commute</div>
              <div style={{ fontSize: 12, color: t.textMuted, marginTop: 2 }}>Tap START or add manually</div>
            </div>
          </div>
        </div>

        {/* week pulse */}
        <div style={{ marginTop: 18, display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10 }}>
          <div style={{ fontSize: 12, fontWeight: 600, color: t.textMuted, letterSpacing: 1, textTransform: 'uppercase' }}>This week</div>
          <div style={{ fontSize: 12, fontWeight: 600, color: t.accent }}>See stats →</div>
        </div>

        <div style={{
          background: t.bgElev, border: `1px solid ${t.border}`, borderRadius: 16,
          padding: 18,
        }}>
          <div style={{ fontSize: 13, color: t.textDim }}>You lost</div>
          <div style={{
            fontFamily: FONTS.mono, fontSize: 38, fontWeight: 600, letterSpacing: -1.5,
            color: t.stuck, lineHeight: 1, marginTop: 4,
          }}>4h 12m</div>
          <div style={{ fontSize: 13, color: t.text, marginTop: 4, fontWeight: 500 }}>
            to traffic this week.
          </div>
          <div style={{ marginTop: 14 }}>
            <StuckBar t={t} moving={318} stuck={252}/>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, fontFamily: FONTS.mono, fontSize: 11.5, color: t.textDim }}>
              <span>5h 18m moving</span>
              <span>9h 30m total</span>
            </div>
          </div>
        </div>
      </div>

      <TabBar t={t} active="home"/>
    </Phone>
  );
}

export { ScreenHome };
