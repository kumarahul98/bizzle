// Traevy landing — Insight section (+ co-located Legend helper)

import React from 'react'
import { useTheme } from '../theme.jsx'
import { FONTS } from '../tokens.js'
import { Container, Eyebrow } from '../components/ui.jsx'
import { Donut } from '../components/charts.jsx'

function Legend({ t, color, label, sub }) {
  return (
    <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
      <span style={{ width: 12, height: 12, borderRadius: 4, background: color, marginTop: 4, flexShrink: 0 }}/>
      <div>
        <div style={{ fontSize: 14, fontWeight: 600, color: t.text }}>{label}</div>
        <div style={{ fontSize: 12.5, color: t.textMuted, marginTop: 1 }}>{sub}</div>
      </div>
    </div>
  );
}

function Insight() {
  const { t, dark } = useTheme();
  const movMin = 318, stuckMin = 252, total = movMin + stuckMin;
  const stuckPct = Math.round((stuckMin / total) * 100);
  return (
    <section id="insight" style={{ background: t.surface, borderTop: `1px solid ${t.border}`, borderBottom: `1px solid ${t.border}` }}>
      <Container width={1180} style={{ paddingTop: 88, paddingBottom: 88 }}>
        <div className="insight-grid" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 64, alignItems: 'center' }}>
          <div>
            <Eyebrow color={t.stuck}>The split</Eyebrow>
            <h2 style={{ margin: '14px 0 0', fontFamily: FONTS.ui, fontWeight: 700,
              fontSize: 'clamp(28px, 3.4vw, 40px)', lineHeight: 1.1, letterSpacing: '-0.02em', color: t.text, textWrap: 'balance' }}>
              Not all commute time is equal.
            </h2>
            <p style={{ margin: '18px 0 0', maxWidth: 440, fontSize: 17, lineHeight: 1.6, color: t.textDim }}>
              Half an hour of steady driving feels nothing like half an hour crawling bumper to bumper.
              Traevy detects when you've stopped moving and counts it separately — so the
              cost of traffic stops hiding inside your total trip time.
            </p>
            <div style={{ marginTop: 28, display: 'flex', gap: 14 }}>
              <Legend t={t} color={t.moving} label="Moving" sub="Actually getting somewhere"/>
              <Legend t={t} color={t.stuck} label="Stuck" sub="Stopped, idling, crawling"/>
            </div>
          </div>

          {/* viz card */}
          <div style={{ background: t.bgElev, border: `1px solid ${t.border}`, borderRadius: 22, padding: 30,
            boxShadow: dark ? 'none' : '0 1px 2px rgba(0,0,0,0.03)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 18 }}>
              <Eyebrow>This week</Eyebrow>
              <span style={{ fontFamily: FONTS.mono, fontSize: 14, color: t.textDim }}>9h 30m total</span>
            </div>
            {/* big stacked bar */}
            <div style={{ display: 'flex', height: 30, borderRadius: 9, overflow: 'hidden', background: t.surface2 }}>
              <div style={{ width: `${(movMin/total)*100}%`, background: t.moving }}/>
              <div style={{ flex: 1, background: t.stuck }}/>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10, fontFamily: FONTS.mono, fontSize: 13 }}>
              <span style={{ color: t.moving, fontWeight: 600 }}>5h 18m moving</span>
              <span style={{ color: t.stuck, fontWeight: 600 }}>4h 12m stuck</span>
            </div>

            <div style={{ height: 1, background: t.border, margin: '26px 0' }}/>

            <div style={{ display: 'flex', alignItems: 'center', gap: 22 }}>
              <Donut t={t} moving={movMin} stuck={stuckMin} size={120} stroke={16}/>
              <div>
                <div style={{ fontFamily: FONTS.mono, fontSize: 'clamp(34px, 4vw, 46px)', fontWeight: 600,
                  color: t.stuck, letterSpacing: '-0.04em', lineHeight: 1 }}>{stuckPct}%</div>
                <div style={{ fontSize: 15, color: t.text, fontWeight: 500, marginTop: 8, lineHeight: 1.45, maxWidth: 220 }}>
                  of your commute this week was spent completely stuck.
                </div>
              </div>
            </div>
          </div>
        </div>
      </Container>
    </section>
  );
}

export { Insight }
