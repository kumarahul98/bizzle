// Traevy landing — WhyContext section (+ co-located BigStat helper)

import React from 'react'
import { useTheme } from '../theme.jsx'
import { FONTS } from '../tokens.js'
import { Container, Eyebrow } from '../components/ui.jsx'

function BigStat({ value, unit, body, cite }) {
  const { t } = useTheme();
  return (
    <div style={{ background: t.bgElev, border: `1px solid ${t.border}`, borderRadius: 22, padding: 32 }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
        <span style={{ fontFamily: FONTS.mono, fontWeight: 600, fontSize: 'clamp(46px, 7vw, 76px)',
          letterSpacing: '-0.05em', color: t.stuck, lineHeight: 0.9 }}>{value}</span>
        {unit && <span style={{ fontFamily: FONTS.mono, fontWeight: 600, fontSize: 'clamp(20px, 2.6vw, 30px)',
          color: t.stuck, letterSpacing: '-0.02em' }}>{unit}</span>}
      </div>
      <p style={{ margin: '20px 0 0', fontSize: 16, lineHeight: 1.55, color: t.textDim, maxWidth: 380 }}>{body}</p>
      {cite && <div style={{ marginTop: 16, fontFamily: FONTS.mono, fontSize: 12, color: t.textMuted, letterSpacing: 0.3 }}>{cite}</div>}
    </div>
  );
}

function WhyContext() {
  const { t } = useTheme();
  return (
    <section id="why" style={{ paddingTop: 96, paddingBottom: 96, borderTop: `1px solid ${t.border}` }}>
      <Container width={1180}>
        <div style={{ maxWidth: 760, margin: '0 auto 56px', textAlign: 'center' }}>
          <Eyebrow color={t.stuck}>The return to office</Eyebrow>
          <h2 style={{ margin: '14px 0 0', fontFamily: FONTS.ui, fontWeight: 700,
            fontSize: 'clamp(30px, 4.4vw, 52px)', lineHeight: 1.05, letterSpacing: '-0.025em', color: t.text, textWrap: 'balance' }}>
            The office is back. <span style={{ color: t.stuck }}>The traffic came with it.</span>
          </h2>
          <p style={{ margin: '20px auto 0', maxWidth: 560, fontSize: 17.5, lineHeight: 1.6, color: t.textDim }}>
            India's IT companies are calling everyone in, five days a week. For most people the
            commute is longer now than it ever was before the pandemic.
          </p>
        </div>
        <div className="why-grid" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24, maxWidth: 920, margin: '0 auto' }}>
          <BigStat value="2" unit="hrs"
            body="Average daily commute for Indian IT employees on office days — higher than it was pre-COVID."
            cite="HFS Research, 2026"/>
          <BigStat value="~10" unit="hrs"
            body="In transit every week on a five-day office schedule. More than a full working day — gone before you've done any work."/>
        </div>
      </Container>
    </section>
  );
}

export { WhyContext }
