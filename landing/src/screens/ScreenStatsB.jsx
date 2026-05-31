import React from 'react';
import { TOKENS, FONTS } from '../tokens.js';
import { Phone, TabBar } from '../components/Phone.jsx';
import { TrendBars, WeekdayChart } from '../components/charts.jsx';

const trendData28 = [42, 38, 51, 33, 45, 0, 0, 39, 44, 36, 41, 47, 0, 0, 36, 38, 41, 35, 42, 0, 0, 40, 33, 39, 36, 44, 0, 82];

function ScreenStatsB({ dark = false }) {
  const t = dark ? TOKENS.dark : TOKENS.light;
  return (
    <Phone dark={dark} time="20:20">
      <div style={{ padding: '14px 20px 8px' }}>
        <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: -0.6 }}>Stats</div>
      </div>

      {/* tab pills */}
      <div style={{ padding: '0 20px 12px', display: 'flex', gap: 6 }}>
        {['Week', 'Month', '28d', 'All'].map((s, i) => (
          <div key={s} style={{
            padding: '6px 12px', borderRadius: 100,
            background: i === 0 ? t.text : 'transparent',
            color: i === 0 ? t.bg : t.textDim,
            border: i === 0 ? 'none' : `1px solid ${t.border}`,
            fontSize: 12, fontWeight: 600,
          }}>{s}</div>
        ))}
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '4px 20px 16px' }}>
        {/* Big pointed callout */}
        <div style={{
          background: t.text, color: t.bg, borderRadius: 18,
          padding: 22, marginBottom: 12,
        }}>
          <div style={{ fontSize: 13, opacity: 0.65, fontWeight: 500 }}>This week</div>
          <div style={{ fontSize: 20, fontWeight: 600, lineHeight: 1.25, marginTop: 6, letterSpacing: -0.3 }}>
            You lost{' '}
            <span style={{
              fontFamily: FONTS.mono, fontWeight: 700,
              background: t.stuck, color: dark ? t.bg : '#fff',
              padding: '0 8px', borderRadius: 6,
            }}>4h 12m</span>{' '}
            to traffic.
          </div>
          <div style={{ fontSize: 12, opacity: 0.55, marginTop: 10, fontFamily: FONTS.mono }}>
            22m more than last week
          </div>
        </div>

        {/* split rows */}
        <div style={{ background: t.bgElev, border: `1px solid ${t.border}`, borderRadius: 18, marginBottom: 12 }}>
          {[
            { l: 'Avg to office', v: '34m', sub: '5m stuck'},
            { l: 'Avg to home', v: '49m', sub: '17m stuck', tone: 'stuck'},
          ].map((r, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              padding: '16px 18px',
              borderBottom: i === 0 ? `1px solid ${t.border}` : 'none',
            }}>
              <div>
                <div style={{ fontSize: 13, fontWeight: 500 }}>{r.l}</div>
                <div style={{ fontSize: 11.5, color: r.tone === 'stuck' ? t.stuck : t.textDim, marginTop: 2, fontFamily: FONTS.mono, fontWeight: 600 }}>{r.sub}</div>
              </div>
              <div style={{ fontFamily: FONTS.mono, fontSize: 22, fontWeight: 600, letterSpacing: -0.5 }}>{r.v}</div>
            </div>
          ))}
        </div>

        {/* Trend with annotations */}
        <div style={{ background: t.bgElev, border: `1px solid ${t.border}`, borderRadius: 18, padding: 18, marginBottom: 12 }}>
          <div style={{ fontSize: 12, fontWeight: 600, color: t.textMuted, letterSpacing: 0.5, textTransform: 'uppercase', marginBottom: 12 }}>28 days</div>
          <TrendBars t={t} data={trendData28} highlight={26} height={72}/>
          <div style={{
            marginTop: 12, padding: '10px 12px', background: t.stuckBg, borderRadius: 10,
            fontSize: 12, color: t.text, lineHeight: 1.4,
          }}>
            <span style={{ fontWeight: 600 }}>Worst day:</span> Fri 25 Apr — 82 min, 41 stuck.
          </div>
        </div>

        {/* Weekday chart */}
        <div style={{ background: t.bgElev, border: `1px solid ${t.border}`, borderRadius: 18, padding: 18 }}>
          <div style={{ fontSize: 12, fontWeight: 600, color: t.textMuted, letterSpacing: 0.5, textTransform: 'uppercase', marginBottom: 18 }}>By weekday</div>
          <WeekdayChart t={t} days={[
            { minutes: 52, tag: 'worst' },
            { minutes: 41 }, { minutes: 29, tag: 'best' },
            { minutes: 38 }, { minutes: 45 },
          ]}/>
        </div>
      </div>
      <TabBar t={t} active="stats"/>
    </Phone>
  );
}

export { ScreenStatsB };
