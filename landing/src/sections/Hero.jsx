// Traevy landing — Hero section

import React from 'react'
import { useTheme } from '../theme.jsx'
import { FONTS } from '../tokens.js'
import { Container, Eyebrow, GetActions, PhoneShot } from '../components/ui.jsx'
import { Icon } from '../components/Phone.jsx'
import { ScreenStatsA } from '../screens/ScreenStatsA.jsx'
import { ScreenHome } from '../screens/ScreenHome.jsx'

function Hero({ headline, accent }) {
  const { t, dark } = useTheme();
  const accentColor = accent === 'green' ? t.moving : accent === 'balanced' ? t.text : t.stuck;
  return (
    <section id="top" style={{ position: 'relative', overflow: 'hidden' }}>
      <Container width={1180} style={{ paddingTop: 64, paddingBottom: 96 }}>
        <div className="hero-grid" style={{
          display: 'grid', gridTemplateColumns: '1.05fr 0.95fr', gap: 56, alignItems: 'center',
        }}>
          {/* left */}
          <div className="hero-copy">
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 9,
              padding: '6px 13px 6px 9px', borderRadius: 100,
              background: t.surface, border: `1px solid ${t.border}`, marginBottom: 26 }}>
              <span style={{ width: 7, height: 7, borderRadius: 4, background: t.moving }}/>
              <span style={{ fontSize: 12.5, fontWeight: 600, color: t.textDim, letterSpacing: 0.2 }}>
                {/* WHEN_ANDROID_READY: Commute tracker · Android now, iOS soon */}
                Commute tracker · Android & iOS coming soon
              </span>
            </div>

            <h1 style={{
              margin: 0, fontFamily: FONTS.ui, fontWeight: 700,
              fontSize: 'clamp(38px, 5vw, 60px)', lineHeight: 1.04, letterSpacing: '-0.025em',
              color: t.text, textWrap: 'balance',
            }}>
              {headline.pre}
              {headline.mono ? (
                <span style={{ fontFamily: FONTS.mono, fontWeight: 600, color: accentColor, letterSpacing: '-0.04em', wordSpacing: '-0.18em', whiteSpace: 'nowrap' }}>
                  {headline.hi}
                </span>
              ) : (
                <span style={{ color: accentColor }}>{headline.hi}</span>
              )}
              {headline.post}
            </h1>

            <p style={{
              margin: '22px 0 0', maxWidth: 480, fontSize: 'clamp(16px, 1.5vw, 18px)',
              lineHeight: 1.6, color: t.textDim, fontFamily: FONTS.ui,
            }}>
              Traevy tracks every commute with one tap, then automatically splits the time you spent
              <span style={{ color: t.moving, fontWeight: 600 }}> moving</span> from the time you spent
              <span style={{ color: t.stuck, fontWeight: 600 }}> stuck</span>. Finally, a number for what traffic actually costs you.
            </p>

            {!headline.mono && (
              <div style={{ marginTop: 20, display: 'flex', alignItems: 'baseline', gap: 10, flexWrap: 'wrap' }}>
                <span style={{ fontFamily: FONTS.mono, fontWeight: 600, fontSize: 20, color: t.stuck, letterSpacing: '-0.03em', wordSpacing: '-0.12em', whiteSpace: 'nowrap' }}>4h 12m</span>
                <span style={{ fontSize: 15, color: t.textDim }}>of last week disappeared while you sat still.</span>
              </div>
            )}

            <div id="waitlist-hero" style={{ marginTop: 32 }}>
              <GetActions size="lg"/>
            </div>

            <div className="hero-features" style={{ marginTop: 26, display: 'flex', gap: 22, flexWrap: 'wrap' }}>
              {['Works offline', 'One-tap recording', 'Trips stay on device'].map(s => (
                <div key={s} style={{ display: 'flex', alignItems: 'center', gap: 7,
                  fontSize: 13, color: t.textMuted, fontWeight: 500 }}>
                  <Icon name="check" size={14} color={t.moving} strokeWidth={2.4}/> {s}
                </div>
              ))}
            </div>
          </div>

          {/* right — product shots */}
          <div className="hero-art" style={{ position: 'relative', display: 'flex', justifyContent: 'center' }}>
            <div className="hero-halo" style={{
              position: 'absolute', width: 360, height: 360, borderRadius: '50%',
              background: t.surface, top: '50%', left: '50%', transform: 'translate(-50%,-46%)', zIndex: 0,
            }}/>
            <div className="hero-phones" style={{ position: 'relative', zIndex: 1, display: 'flex', alignItems: 'flex-end' }}>
              <div className="hero-phone-back" style={{ marginRight: -88, marginBottom: 46, opacity: 0.96 }}>
                <PhoneShot scale={0.62} float><ScreenStatsA dark={dark}/></PhoneShot>
              </div>
              <PhoneShot scale={0.78} float><ScreenHome dark={dark}/></PhoneShot>
            </div>
          </div>
        </div>
      </Container>
    </section>
  );
}

export { Hero }
