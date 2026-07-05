import React from 'react'
import { useTheme } from '../theme.jsx'
import { FONTS } from '../tokens.js'
import { Container, Logo } from '../components/ui.jsx'

const SocialItem = ({ label, icon, hoverColor, href = '#' }) => {
  const { t } = useTheme();
  const [hover, setHover] = React.useState(false);
  const live = href !== '#';
  return (
    <a href={href}
      target={live ? '_blank' : undefined}
      rel={live ? 'noopener noreferrer' : undefined}
      aria-label={label}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{ display: 'flex', alignItems: 'center', cursor: 'pointer', transition: 'all 0.2s', textDecoration: 'none', width: 'fit-content' }}
    >
      <div style={{ display: 'flex', position: 'relative', color: hover ? hoverColor : t.textDim, transition: 'color 0.2s', width: 22, height: 22 }}>
        {icon}
        {!live && (
          <span style={{ position: 'absolute', top: -6, right: '70%', fontSize: 6.5, fontWeight: 800, color: t.bg, background: hover ? hoverColor : t.textDim, padding: '1px 3px', borderRadius: 100, letterSpacing: '0.04em', transition: 'background 0.2s', zIndex: 1 }}>SOON</span>
        )}
      </div>
    </a>
  );
};

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
        <div className="footer-grid" style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr 1fr 1fr 1fr', gap: 40 }}>
          <div style={{ maxWidth: 260 }}>
            <Logo markSize={26} wordSize={16}/>
            <p style={{ margin: '18px 0 0', fontSize: 14, lineHeight: 1.6, color: t.textMuted }}>
              See how much of your day belongs to traffic — and take some of it back.
            </p>
          </div>
          {col('Product', [['How it works', '#how'], ['The split', '#insight'], ['Insights', '#insights'], ['Get the app', '#waitlist']])}
          {col('Company', [['About', '#'], ['Privacy', '#'], ['connect@traevy.com', 'mailto:connect@traevy.com']])}
          <div>
            <div style={{ fontSize: 12, fontWeight: 600, letterSpacing: '0.12em', textTransform: 'uppercase', color: t.textMuted, marginBottom: 14 }}>Socials</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
              {[
                { label: 'Instagram', hoverColor: '#E1306C', href: 'https://instagram.com/traevyapp', icon: <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="2" y="2" width="20" height="20" rx="5" ry="5"></rect><path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"></path><line x1="17.5" y1="6.5" x2="17.51" y2="6.5"></line></svg> },
                { label: 'Reddit', hoverColor: '#FF4500', href: 'https://reddit.com/user/traevyapp', icon: <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0zm5.01 4.744c.688 0 1.25.561 1.25 1.249a1.25 1.25 0 0 1-2.498.056l-2.597-.547-.8 3.747c1.824.07 3.48.632 4.674 1.488.308-.309.73-.491 1.207-.491.968 0 1.754.786 1.754 1.754 0 .716-.435 1.333-1.01 1.614a3.111 3.111 0 0 1 .042.52c0 2.694-3.13 4.87-7.004 4.87-3.874 0-7.004-2.176-7.004-4.87 0-.183.015-.366.043-.534A1.748 1.748 0 0 1 4.028 12c0-.968.786-1.754 1.754-1.754.463 0 .898.196 1.207.49 1.207-.883 2.878-1.43 4.744-1.487l.885-4.182a.342.342 0 0 1 .14-.197.35.35 0 0 1 .238-.042l2.906.617a1.214 1.214 0 0 1 1.108-.701zM9.25 12C8.561 12 8 12.562 8 13.25c0 .687.561 1.248 1.25 1.248.687 0 1.248-.561 1.248-1.249 0-.688-.561-1.249-1.249-1.249zm5.5 0c-.687 0-1.248.561-1.248 1.25 0 .687.561 1.248 1.249 1.248.688 0 1.249-.561 1.249-1.249 0-.687-.562-1.249-1.25-1.249zm-5.466 3.99a.327.327 0 0 0-.231.094.33.33 0 0 0 0 .463c.842.842 2.484.913 2.961.913.477 0 2.105-.056 2.961-.913a.361.361 0 0 0 .029-.463.33.33 0 0 0-.464 0c-.547.533-1.684.73-2.512.73-.828 0-1.979-.196-2.512-.73a.326.326 0 0 0-.232-.095z" /></svg> },
                { label: 'YouTube', hoverColor: '#FF0000', href: 'https://youtube.com/@traevyapp', icon: <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M22.54 6.42a2.78 2.78 0 0 0-1.94-2C18.88 4 12 4 12 4s-6.88 0-8.6.46a2.78 2.78 0 0 0-1.94 2A29 29 0 0 0 1 11.75a29 29 0 0 0 .46 5.33A2.78 2.78 0 0 0 3.4 19c1.72.46 8.6.46 8.6.46s6.88 0 8.6-.46a2.78 2.78 0 0 0 1.94-2 29 29 0 0 0 .46-5.25 29 29 0 0 0-.46-5.33z"></path><polygon points="9.75 15.02 15.5 11.75 9.75 8.48 9.75 15.02"></polygon></svg> },
                { label: 'X (Twitter)', hoverColor: '#1DA1F2', href: 'https://x.com/traevyapp', icon: <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor"><path d="M18.9 2.15h3.68l-8.04 9.19L24 21.85h-7.41l-5.8-7.58-6.64 7.58H.47l8.6-9.83L0 2.15h7.59l5.24 6.93 6.07-6.93zM15.27 19.8h2.04L6.46 4.08H4.28l8.99 15.72z" /></svg> },
                { label: 'Facebook', hoverColor: '#1877F2', icon: <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z"></path></svg> }
              ].map(s => <SocialItem key={s.label} {...s} />)}
            </div>
          </div>
          {/* WHEN_ANDROID_READY: {col('Get the app', [['Install for Android', '#waitlist'], ['Join the iOS waitlist', '#waitlist'], ['Support', '#']])} */}
          {col('Get the app', [['Join the Android waitlist', '#waitlist'], ['Join the iOS waitlist', '#waitlist'], ['Support', '#']])}
        </div>
        <div style={{ height: 1, background: t.border, margin: '44px 0 22px' }}/>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12 }}>
          {/* WHEN_ANDROID_READY: <span style={{ fontSize: 12.5, color: t.textMuted, fontFamily: FONTS.mono }}>© 2026 Traevy · Android now, iOS soon</span> */}
          <span style={{ fontSize: 12.5, color: t.textMuted, fontFamily: FONTS.mono }}>
            © 2026 Traevy · Android & iOS coming soon · <a
              href="mailto:connect@traevy.com"
              style={{ color: 'inherit', textDecoration: 'none' }}
              onMouseEnter={(e) => e.currentTarget.style.color = t.text}
              onMouseLeave={(e) => e.currentTarget.style.color = t.textMuted}
            >connect@traevy.com</a>
          </span>
          <span style={{ fontSize: 12.5, color: t.textMuted }}>Your trips stay on your device until you choose to sync.</span>
        </div>
      </Container>
    </footer>
  );
}

export { Footer }
