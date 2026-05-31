// Traevy landing — shared primitives: logo mark, layout, buttons,
// phone product-shot wrapper, waitlist form. Calm, warm-neutral, no gradients.

import React from 'react'
import { useTheme } from '../theme.jsx'
import { TOKENS, FONTS } from '../tokens.js'
import { Icon } from './Phone.jsx'

// ── Brand mark: a route forming a peak (recreated from the Traevy logo) ──────
// A dashed/dotted triangle in monochrome currentColor so it reads in both themes.
function LogoMark({ size = 26, stroke }) {
  const { t } = useTheme();
  const col = stroke || t.text;
  const p = [
    [size * 0.5, size * 0.12],   // apex
    [size * 0.9, size * 0.84],   // bottom-right
    [size * 0.1, size * 0.84],   // bottom-left
  ];
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} fill="none" aria-hidden="true">
      {/* left edge */}
      <line x1={p[2][0]} y1={p[2][1]} x2={p[0][0]} y2={p[0][1]}
        stroke={col} strokeWidth="1.6" strokeLinecap="round" strokeDasharray="0.2 4.2"/>
      {/* right edge */}
      <line x1={p[0][0]} y1={p[0][1]} x2={p[1][0]} y2={p[1][1]}
        stroke={col} strokeWidth="1.6" strokeLinecap="round" strokeDasharray="0.2 4.2"/>
      {/* base — the road */}
      <line x1={p[2][0]} y1={p[2][1]} x2={p[1][0]} y2={p[1][1]}
        stroke={col} strokeWidth="1.6" strokeLinecap="round" strokeDasharray="0.2 3.4"/>
      {/* node dots at the corners */}
      {p.map((pt, i) => <circle key={i} cx={pt[0]} cy={pt[1]} r="1.5" fill={col}/>)}
    </svg>
  );
}

function Wordmark({ size = 17, color }) {
  const { t } = useTheme();
  return (
    <span style={{
      fontFamily: FONTS.ui, fontWeight: 500, fontSize: size,
      letterSpacing: '0.34em', color: color || t.text, paddingLeft: '0.17em',
    }}>TRAEVY</span>
  );
}

function Logo({ markSize = 24, wordSize = 16, gap = 11 }) {
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap }}>
      <LogoMark size={markSize}/>
      <Wordmark size={wordSize}/>
    </span>
  );
}

// ── Layout ───────────────────────────────────────────────────────────────────
function Container({ children, width = 1120, style }) {
  return (
    <div style={{ width: '100%', maxWidth: width, margin: '0 auto', padding: '0 32px', ...style }}>
      {children}
    </div>
  );
}

function Eyebrow({ children, color }) {
  const { t } = useTheme();
  return (
    <div style={{
      fontSize: 12, fontWeight: 600, letterSpacing: '0.16em', textTransform: 'uppercase',
      color: color || t.textMuted, fontFamily: FONTS.ui,
    }}>{children}</div>
  );
}

// ── Buttons ───────────────────────────────────────────────────────────────────
function Button({ children, variant = 'primary', onClick, size = 'md', style, full }) {
  const { t } = useTheme();
  const [hover, setHover] = React.useState(false);
  const pad = size === 'lg' ? '15px 26px' : size === 'sm' ? '9px 16px' : '12px 22px';
  const fs = size === 'lg' ? 15.5 : size === 'sm' ? 13.5 : 14.5;
  const base = {
    display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 9,
    padding: pad, fontSize: fs, fontWeight: 600, fontFamily: FONTS.ui,
    borderRadius: 13, cursor: 'pointer', border: '1px solid transparent',
    transition: 'transform .14s ease, background .14s ease, border-color .14s ease',
    width: full ? '100%' : 'auto', whiteSpace: 'nowrap', letterSpacing: 0.1,
    transform: hover ? 'translateY(-1px)' : 'none',
  };
  const variants = {
    primary: { background: t.text, color: t.bg, borderColor: t.text },
    secondary: { background: 'transparent', color: t.text, borderColor: t.borderStr,
      ...(hover ? { background: t.surface } : {}) },
    ghost: { background: 'transparent', color: t.textDim, borderColor: 'transparent',
      ...(hover ? { color: t.text } : {}) },
  };
  return (
    <button onClick={onClick} onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}
      style={{ ...base, ...variants[variant], ...style }}>
      {children}
    </button>
  );
}

// ── Phone product shot — scaled bezel that flows in layout ────────────────────
function PhoneShot({ children, scale = 0.8, float = false }) {
  const W = 360, H = 740, b = 9;
  const fw = (W + b * 2) * scale, fh = (H + b * 2) * scale;
  return (
    <div style={{ width: fw, height: fh, position: 'relative', flexShrink: 0 }}>
      <div className={float ? 'traevy-frame float' : 'traevy-frame'} style={{
        width: W, height: H, boxSizing: 'content-box',
        transform: `scale(${scale})`, transformOrigin: 'top left',
        position: 'absolute', top: 0, left: 0,
      }}>
        {children}
      </div>
    </div>
  );
}

// ── Platform glyphs (monochrome, currentColor) ───────────────────────────────
function AndroidGlyph({ size = 18 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <line x1="7.6" y1="2.6" x2="9.4" y2="6" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round"/>
      <line x1="16.4" y1="2.6" x2="14.6" y2="6" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round"/>
      <path d="M5.8 9a6.2 6.2 0 0 1 12.4 0H5.8z"/>
      <rect x="5.8" y="10" width="12.4" height="8.2" rx="1.6"/>
      <rect x="8.5" y="18" width="2.1" height="3.8" rx="1"/>
      <rect x="13.4" y="18" width="2.1" height="3.8" rx="1"/>
      <rect x="2.6" y="10.4" width="1.9" height="6.2" rx="0.95"/>
      <rect x="19.5" y="10.4" width="1.9" height="6.2" rx="0.95"/>
    </svg>
  );
}

function AppleGlyph({ size = 17 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M16.6 12.5c0-2 1.6-2.9 1.7-3-.9-1.4-2.4-1.5-2.9-1.5-1.2-.1-2.4.7-3 .7-.6 0-1.6-.7-2.6-.6-1.3 0-2.6.8-3.3 2-1.4 2.4-.4 6 1 8 .7 1 1.4 2.1 2.4 2 1-.1 1.3-.6 2.5-.6s1.5.6 2.5.6 1.7-.9 2.3-1.9c.4-.6.6-1 .9-1.7-2.3-.9-2-3.5-2-3.5z"/>
      <path d="M14.4 6.4c.5-.7.9-1.6.8-2.5-.8 0-1.7.5-2.3 1.2-.5.6-.9 1.5-.8 2.4.9.1 1.7-.4 2.3-1.1z"/>
    </svg>
  );
}

// ── Platform CTAs: install (Android) + join waitlist (iOS) ────────────────────
function GetActions({ size = 'lg', center = false }) {
  const { t } = useTheme();
  const [showWaitlist, setShowWaitlist] = React.useState(false);
  const big = size === 'lg';
  return (
    <div className="get-actions" style={{ width: '100%' }}>
      <div className="get-actions-row" style={{
        display: 'flex', gap: 12, flexWrap: 'wrap',
        justifyContent: center ? 'center' : 'flex-start',
      }}>
        <a href="#" className="ga-btn" style={{ textDecoration: 'none' }}>
          <Button variant="primary" size={big ? 'lg' : 'md'}>
            <AndroidGlyph size={19}/> Install for Android
          </Button>
        </a>
        <Button variant="secondary" size={big ? 'lg' : 'md'}
          onClick={() => setShowWaitlist((s) => !s)}
          style={showWaitlist ? { borderColor: t.borderStr, background: t.surface } : undefined}>
          <AppleGlyph size={16}/> Join the iOS waitlist
        </Button>
      </div>
      {showWaitlist ? (
        <div style={{ marginTop: 18, display: 'flex', justifyContent: center ? 'center' : 'flex-start' }}>
          <WaitlistForm size={size} platform="iOS"/>
        </div>
      ) : (
        <div style={{
          marginTop: 14, fontSize: 12.5, color: t.textMuted,
          textAlign: center ? 'center' : 'left',
          display: 'flex', gap: 7, alignItems: 'center',
          justifyContent: center ? 'center' : 'flex-start',
        }}>
          <Icon name="check" size={13} color={t.moving} strokeWidth={2.4}/>
          Free on Android · iOS coming soon
        </div>
      )}
    </div>
  );
}

// ── Waitlist form — calm, factual, with validation + success state ────────────
function WaitlistForm({ size = 'md', onJoined, platform = 'iOS' }) {
  const { t } = useTheme();
  const [email, setEmail] = React.useState('');
  const [state, setState] = React.useState('idle'); // idle | error | done
  const [focus, setFocus] = React.useState(false);
  const submit = (e) => {
    e.preventDefault();
    const ok = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
    if (!ok) { setState('error'); return; }
    setState('done');
    onJoined && onJoined();
  };
  if (state === 'done') {
    return (
      <div style={{
        display: 'flex', alignItems: 'center', gap: 12,
        padding: '14px 18px', borderRadius: 14,
        background: t.movingBg, border: `1px solid ${t.moving}33`,
        maxWidth: 460, width: '100%',
      }}>
        <div style={{
          width: 26, height: 26, borderRadius: 13, flexShrink: 0,
          background: t.moving, color: t.bgElev,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}><Icon name="check" size={15} color={t.bgElev} strokeWidth={2.6}/></div>
        <div>
          <div style={{ fontSize: 14.5, fontWeight: 600, color: t.text }}>You're on the {platform} list.</div>
          <div style={{ fontSize: 13, color: t.textDim, marginTop: 1 }}>
            We'll email <span style={{ fontFamily: FONTS.mono, color: t.text }}>{email.trim()}</span> when Traevy lands on {platform}.
          </div>
        </div>
      </div>
    );
  }
  const big = size === 'lg';
  return (
    <form className="waitlist-form" onSubmit={submit} style={{ maxWidth: 460, width: '100%' }} noValidate>
      <div className="waitlist-row" style={{
        display: 'flex', gap: 8, alignItems: 'stretch',
        background: t.bgElev, borderRadius: 15, padding: 6,
        border: `1px solid ${state === 'error' ? t.danger : focus ? t.borderStr : t.border}`,
        transition: 'border-color .14s ease',
      }}>
        <input
          type="email" value={email} placeholder="you@email.com" inputMode="email" autoComplete="email"
          onChange={(e) => { setEmail(e.target.value); if (state === 'error') setState('idle'); }}
          onFocus={() => setFocus(true)} onBlur={() => setFocus(false)}
          style={{
            flex: 1, minWidth: 0, border: 'none', outline: 'none', background: 'transparent',
            fontFamily: FONTS.ui, fontSize: big ? 15.5 : 14.5, color: t.text,
            padding: big ? '12px 14px' : '10px 12px',
          }}
        />
        <Button variant="primary" size={big ? 'lg' : 'md'} style={{ borderRadius: 11 }}>
          <AppleGlyph size={15}/> Notify me
        </Button>
      </div>
      <div style={{
        marginTop: 9, fontSize: 12.5, minHeight: 17,
        color: state === 'error' ? t.danger : t.textMuted,
        display: 'flex', alignItems: 'center', gap: 6,
      }}>
        {state === 'error'
          ? 'Enter a valid email address.'
          : `One email when the ${platform} app is ready. No spam.`}
      </div>
    </form>
  );
}

export { LogoMark, Wordmark, Logo, Container, Eyebrow, Button, PhoneShot, AndroidGlyph, AppleGlyph, GetActions, WaitlistForm };
