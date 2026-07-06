import React from 'react'
import { useTheme, ThemeCtx } from '../theme.jsx'
import { TOKENS, FONTS } from '../tokens.js'
import { Container, GetActions } from '../components/ui.jsx'

function CTA() {
  const { dark } = useTheme();
  const inv = dark ? TOKENS.light : TOKENS.dark;
  const ctxVal = { t: inv, theme: dark ? 'light' : 'dark', dark: !dark };
  return (
    <ThemeCtx.Provider value={ctxVal}>
      <section id="waitlist" style={{ background: inv.bg, paddingTop: 96, paddingBottom: 96 }}>
        <Container width={820} style={{ textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <h2 style={{ margin: 0, fontFamily: FONTS.ui, fontWeight: 700,
            fontSize: 'clamp(30px, 4vw, 46px)', lineHeight: 1.08, letterSpacing: '-0.025em', color: inv.text, textWrap: 'balance', maxWidth: 640 }}>
            Stop guessing what traffic costs you.
          </h2>
          <p style={{ margin: '18px 0 32px', maxWidth: 520, fontSize: 17.5, lineHeight: 1.6, color: inv.textDim }}>
            {/* WHEN_ANDROID_READY: Free on Android today. iOS is on the way — leave your email and we'll tell you the moment it's ready. */}
            Android and iOS are on the way — leave your email and we'll tell you the moment they're ready.
          </p>
          <div style={{ display: 'flex', justifyContent: 'center', width: '100%' }}>
            <GetActions size="lg" center/>
          </div>
        </Container>
      </section>
    </ThemeCtx.Provider>
  );
}

export { CTA }
