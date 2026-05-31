import React from 'react'
import { useTheme } from '../theme.jsx'
import { FONTS } from '../tokens.js'
import { Container, Logo } from '../components/ui.jsx'

function Footer() {
  const { t } = useTheme();
  const col = (title, items) => (
    <div>
      <div style={{ fontSize: 12, fontWeight: 600, letterSpacing: '0.12em', textTransform: 'uppercase', color: t.textMuted, marginBottom: 14 }}>{title}</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 11 }}>
        {items.map(([label, href]) => (
          <a key={label} href={href} style={{ fontSize: 14, color: t.textDim, textDecoration: 'none', width: 'fit-content' }}
            onMouseEnter={(e) => e.currentTarget.style.color = t.text}
            onMouseLeave={(e) => e.currentTarget.style.color = t.textDim}>{label}</a>
        ))}
      </div>
    </div>
  );
  return (
    <footer style={{ background: t.bg, borderTop: `1px solid ${t.border}` }}>
      <Container width={1180} style={{ paddingTop: 64, paddingBottom: 40 }}>
        <div className="footer-grid" style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr 1fr 1fr', gap: 40 }}>
          <div style={{ maxWidth: 260 }}>
            <Logo markSize={26} wordSize={16}/>
            <p style={{ margin: '18px 0 0', fontSize: 14, lineHeight: 1.6, color: t.textMuted }}>
              See how much of your day belongs to traffic — and take some of it back.
            </p>
          </div>
          {col('Product', [['How it works', '#how'], ['The split', '#insight'], ['Insights', '#insights'], ['Get the app', '#waitlist']])}
          {col('Company', [['About', '#'], ['Privacy', '#'], ['Contact', '#']])}
          {col('Get the app', [['Install for Android', '#waitlist'], ['Join the iOS waitlist', '#waitlist'], ['Support', '#']])}
        </div>
        <div style={{ height: 1, background: t.border, margin: '44px 0 22px' }}/>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12 }}>
          <span style={{ fontSize: 12.5, color: t.textMuted, fontFamily: FONTS.mono }}>© 2026 Traevy · Android now, iOS soon</span>
          <span style={{ fontSize: 12.5, color: t.textMuted }}>Your trips stay on your device until you choose to sync.</span>
        </div>
      </Container>
    </footer>
  );
}

export { Footer }
