import React from 'react';
import { TOKENS, FONTS } from '../tokens.js';
import { Phone, TabBar } from '../components/Phone.jsx';
import { Donut, TrendBars, WeekdayChart } from '../components/charts.jsx';

const trendData28 = [42, 38, 51, 33, 45, 0, 0, 39, 44, 36, 41, 47, 0, 0, 36, 38, 41, 35, 42, 0, 0, 40, 33, 39, 36, 44, 0, 82];

function ScreenStatsA({ dark = false }) {
  const t = dark ? TOKENS.dark : TOKENS.light;
  return (
    <Phone dark={dark} time="20:20">
      <div style={{ padding: '14px 20px 12px' }}>
        <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: -0.6 }}>Stats</div>
        <div style={{ fontSize: 12, color: t.textDim, marginTop: 2 }}>Last 28 days · 22 trips</div>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '4px 20px 16px' }}>
        {/* Hero card */}
        <div style={{
          background: t.bgElev, border: `1px solid ${t.border}`, borderRadius: 18,
          padding: 20, marginBottom: 14,
        }}>
          <div style={{ fontSize: 12, color: t.textDim, fontWeight: 500 }}>You lost</div>
          <div style={{
            fontFamily: FONTS.mono, fontSize: 56, fontWeight: 600, letterSpacing: -2.5,
            color: t.stuck, lineHeight: 1, marginTop: 4,
          }}>4h 12m</div>
          <div style={{ fontSize: 14, fontWeight: 500, marginTop: 4 }}>to traffic this week.</div>
          <div style={{ fontSize: 12, color: t.textDim, marginTop: 2 }}>+22m vs last week</div>
        </div>

        {/* Donut */}
        <div style={{
          background: t.bgElev, border: `1px solid ${t.border}`, borderRadius: 18,
          padding: 18, marginBottom: 14,
          display: 'flex', alignItems: 'center', gap: 18,
        }}>
          <Donut t={t} moving={318} stuck={252}/>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 12, fontWeight: 600, color: t.textMuted, letterSpacing: 0.5, textTransform: 'uppercase' }}>This week</div>
            <div style={{ fontFamily: FONTS.mono, fontSize: 22, fontWeight: 600, marginTop: 2 }}>9h 30m</div>
            <div style={{ marginTop: 8, display: 'flex', gap: 12, fontSize: 11.5, color: t.textDim, fontFamily: FONTS.mono }}>
              <span><span style={{ color: t.moving }}>●</span> 5h 18m mov</span>
              <span><span style={{ color: t.stuck }}>●</span> 4h 12m stuck</span>
            </div>
          </div>
        </div>

        {/* 28-day trend */}
        <div style={{
          background: t.bgElev, border: `1px solid ${t.border}`, borderRadius: 18,
          padding: 18, marginBottom: 14,
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 14 }}>
            <div>
              <div style={{ fontSize: 12, fontWeight: 600, color: t.textMuted, letterSpacing: 0.5, textTransform: 'uppercase' }}>28-day trend</div>
              <div style={{ fontSize: 11, color: t.textDim, marginTop: 2 }}>Daily commute time</div>
            </div>
            <div style={{ fontFamily: FONTS.mono, fontSize: 11, color: t.textDim }}>min</div>
          </div>
          <TrendBars t={t} data={trendData28} height={84}/>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, fontFamily: FONTS.mono, fontSize: 10.5, color: t.textMuted }}>
            <span>Apr 1</span><span>Apr 14</span><span>Apr 28</span>
          </div>
        </div>

        {/* Weekday averages */}
        <div style={{
          background: t.bgElev, border: `1px solid ${t.border}`, borderRadius: 18,
          padding: 18,
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 16 }}>
            <div style={{ fontSize: 12, fontWeight: 600, color: t.textMuted, letterSpacing: 0.5, textTransform: 'uppercase' }}>Weekday averages</div>
          </div>
          <WeekdayChart t={t} days={[
            { minutes: 52, tag: 'worst' },
            { minutes: 41 }, { minutes: 29, tag: 'best' },
            { minutes: 38 }, { minutes: 45 },
          ]}/>
          <div style={{ display: 'flex', gap: 16, marginTop: 14, fontSize: 12, color: t.textDim }}>
            <div>Worst <span style={{ color: t.stuck, fontWeight: 600, fontFamily: FONTS.mono }}>Mon · 52m</span></div>
            <div>Best <span style={{ color: t.moving, fontWeight: 600, fontFamily: FONTS.mono }}>Wed · 29m</span></div>
          </div>
        </div>
      </div>
      <TabBar t={t} active="stats"/>
    </Phone>
  );
}

export { ScreenStatsA };
