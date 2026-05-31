import React from 'react'
import { useTheme } from '../theme.jsx'
import { FONTS } from '../tokens.js'
import { Container, Eyebrow, PhoneShot } from '../components/ui.jsx'
import { ScreenStatsB } from '../screens/ScreenStatsB.jsx'

const TREND_28 = [42, 38, 51, 33, 45, 0, 0, 39, 44, 36, 41, 47, 0, 0, 36, 38, 41, 35, 42, 0, 0, 40, 33, 39, 36, 44, 0, 82];

function InsightCard({ t, label, value, sub, tone }) {
  return (
    <div style={{ background: t.bgElev, border: `1px solid ${t.border}`, borderRadius: 16, padding: '18px 20px' }}>
      <Eyebrow>{label}</Eyebrow>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginTop: 10 }}>
        <span style={{ fontSize: 26, fontWeight: 700, color: t.text, letterSpacing: '-0.01em' }}>{value}</span>
        <span style={{ width: 8, height: 8, borderRadius: 4, background: tone }}/>
      </div>
      <div style={{ fontFamily: FONTS.mono, fontSize: 12.5, color: t.textDim, marginTop: 6 }}>{sub}</div>
    </div>
  );
}

function StatsPreview() {
  const { t, dark } = useTheme();
  const max = Math.max(...TREND_28);
  return (
    <section id="insights" style={{ background: t.surface, borderTop: `1px solid ${t.border}`, borderBottom: `1px solid ${t.border}`, paddingTop: 88, paddingBottom: 88 }}>
      <Container width={1180}>
        <div className="stats-grid" style={{ display: 'grid', gridTemplateColumns: '0.85fr 1.15fr', gap: 60, alignItems: 'center' }}>
          {/* left: phone */}
          <div className="stats-phone" style={{ display: 'flex', justifyContent: 'center' }}>
            <PhoneShot scale={0.74} float><ScreenStatsB dark={dark}/></PhoneShot>
          </div>

          {/* right: copy + insight cards + trend */}
          <div>
            <Eyebrow>Insights</Eyebrow>
            <h2 style={{ margin: '14px 0 0', fontFamily: FONTS.ui, fontWeight: 700,
              fontSize: 'clamp(28px, 3.4vw, 40px)', lineHeight: 1.1, letterSpacing: '-0.02em', color: t.text, textWrap: 'balance' }}>
              Patterns you can't see from inside the car.
            </h2>
            <p style={{ margin: '16px 0 28px', maxWidth: 460, fontSize: 17, lineHeight: 1.6, color: t.textDim }}>
              A week of trips becomes a clear picture: which days cost you most, when traffic is worst,
              and whether it's getting better or worse.
            </p>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginBottom: 14 }}>
              <InsightCard t={t} label="Worst day" value="Mon" sub="52m · 14m stuck" tone={t.stuck}/>
              <InsightCard t={t} label="Best day" value="Wed" sub="29m · 3m stuck" tone={t.moving}/>
            </div>

            {/* trend card */}
            <div style={{ background: t.bgElev, border: `1px solid ${t.border}`, borderRadius: 18, padding: 22 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 16 }}>
                <div>
                  <Eyebrow>28-day trend</Eyebrow>
                  <div style={{ fontSize: 12.5, color: t.textDim, marginTop: 4 }}>Daily commute time, in minutes</div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, color: t.textDim }}>
                  <span style={{ width: 9, height: 9, borderRadius: 2, background: t.accent }}/> today
                </div>
              </div>
              <div style={{ display: 'flex', alignItems: 'flex-end', gap: 3, height: 92 }}>
                {TREND_28.map((v, i) => (
                  <div key={i} title={v ? `${v} min` : 'no trips'} style={{
                    flex: 1, height: `${Math.max((v / max) * 100, v ? 4 : 2)}%`,
                    minHeight: v ? 4 : 2, borderRadius: '3px 3px 0 0',
                    background: i === TREND_28.length - 1 ? t.accent : v ? t.borderStr : t.surface2,
                    opacity: i === TREND_28.length - 1 ? 1 : 0.85,
                  }}/>
                ))}
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10, fontFamily: FONTS.mono, fontSize: 11.5, color: t.textMuted }}>
                <span>Apr 1</span><span>Apr 14</span><span>Apr 28</span>
              </div>
            </div>
          </div>
        </div>
      </Container>
    </section>
  );
}

export { StatsPreview }
