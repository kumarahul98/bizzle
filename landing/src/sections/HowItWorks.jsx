import React from 'react'
import { useTheme } from '../theme.jsx'
import { FONTS } from '../tokens.js'
import { Container, Eyebrow, PhoneShot } from '../components/ui.jsx'
import { ScreenHome } from '../screens/ScreenHome.jsx'
import { ScreenRecordingB } from '../screens/ScreenRecordingB.jsx'
import { ScreenTripDetail } from '../screens/ScreenTripDetail.jsx'

function HowItWorks() {
  const { t, dark } = useTheme();
  const steps = [
    { n: '01', title: 'Record', desc: 'One tap when you leave, one tap when you arrive. Traevy runs quietly in the background — no maps to fiddle with.', screen: <ScreenHome dark={dark}/> },
    { n: '02', title: 'Auto-detect', desc: 'It watches your speed and splits moving from stuck on its own. Idling at a light, crawling on the ring road — all counted.', screen: <ScreenRecordingB dark={dark}/> },
    { n: '03', title: 'Review', desc: 'Every trip gets a timeline showing exactly where the minutes went, and how much of it was traffic.', screen: <ScreenTripDetail dark={dark}/> },
  ];
  return (
    <section id="how" style={{ paddingTop: 96, paddingBottom: 96 }}>
      <Container width={1180}>
        <div style={{ textAlign: 'center', maxWidth: 600, margin: '0 auto 56px' }}>
          <Eyebrow>How it works</Eyebrow>
          <h2 style={{ margin: '14px 0 0', fontFamily: FONTS.ui, fontWeight: 700,
            fontSize: 'clamp(28px, 3.4vw, 40px)', lineHeight: 1.1, letterSpacing: '-0.02em', color: t.text }}>
            Three taps a day. That's it.
          </h2>
          <p style={{ margin: '16px auto 0', maxWidth: 460, fontSize: 17, lineHeight: 1.6, color: t.textDim }}>
            No setup, no manual logging. Traevy does the measuring so you can just drive.
          </p>
        </div>

        <div className="how-grid" style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 40 }}>
          {steps.map((s) => (
            <div key={s.n} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
              <div style={{
                padding: 14, borderRadius: 28, background: t.surface,
                border: `1px solid ${t.border}`, marginBottom: 24,
              }}>
                <PhoneShot scale={0.46} float>{s.screen}</PhoneShot>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
                <span style={{ fontFamily: FONTS.mono, fontSize: 13, fontWeight: 600, color: t.textMuted }}>{s.n}</span>
                <span style={{ width: 5, height: 5, borderRadius: 3, background: t.borderStr }}/>
                <span style={{ fontSize: 19, fontWeight: 700, color: t.text, letterSpacing: '-0.01em' }}>{s.title}</span>
              </div>
              <p style={{ margin: 0, maxWidth: 300, fontSize: 14.5, lineHeight: 1.55, color: t.textDim }}>{s.desc}</p>
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}

export { HowItWorks }
