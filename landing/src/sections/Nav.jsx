// Traevy landing — Nav section

import React from 'react'
import { Link, useLocation } from 'react-router-dom'
import { useTheme } from '../theme.jsx'
import { FONTS } from '../tokens.js'
import { Logo, Container, Button } from '../components/ui.jsx'
import { Icon } from '../components/Phone.jsx'

function Nav({ onToggleTheme, dark }) {
  const { t } = useTheme();
  const location = useLocation();
  const [scrolled, setScrolled] = React.useState(false);
  
  React.useEffect(() => {
    const el = document.scrollingElement || document.documentElement;
    const onScroll = () => setScrolled((window.scrollY || el.scrollTop) > 12);
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
    return () => window.removeEventListener('scroll', onScroll);
  }, []);
  
  const isHome = location.pathname === '/';
  
  // If we are on the home page, use a standard anchor for smooth scrolling.
  // Otherwise, use a React Router link to navigate to the home page with the hash.
  const link = (label, hash, isPagePath = false) => {
    const Component = (isHome && !isPagePath) ? 'a' : Link;
    const props = (isHome && !isPagePath) ? { href: hash } : { to: isPagePath ? hash : `/${hash}` };
    
    return (
      <Component {...props} style={{
        fontSize: 14, fontWeight: 500, color: t.textDim, textDecoration: 'none',
        fontFamily: FONTS.ui, padding: '6px 2px', transition: 'color .14s ease',
      }}
        onMouseEnter={(e) => e.currentTarget.style.color = t.text}
        onMouseLeave={(e) => e.currentTarget.style.color = t.textDim}
      >
        {label}
      </Component>
    );
  };
  
  return (
    <header style={{
      position: 'sticky', top: 0, zIndex: 50,
      background: scrolled ? (dark ? 'oklch(0.16 0.006 250 / 0.82)' : 'oklch(0.985 0.003 80 / 0.82)') : 'transparent',
      backdropFilter: scrolled ? 'saturate(140%) blur(14px)' : 'none',
      WebkitBackdropFilter: scrolled ? 'saturate(140%) blur(14px)' : 'none',
      borderBottom: `1px solid ${scrolled ? t.border : 'transparent'}`,
      transition: 'background .2s ease, border-color .2s ease',
    }}>
      <Container width={1180} style={{
        height: 70, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <Link to="/" style={{ textDecoration: 'none' }}><Logo/></Link>
        <nav style={{ display: 'flex', alignItems: 'center', gap: 30 }} className="nav-links">
          {link('The cost', '#why')}
          {link('How it works', '#how')}
          {link('Insights', '#insights')}
          {link('Blog', '/blog', true)}
        </nav>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <button onClick={onToggleTheme} aria-label="Toggle theme" style={{
            width: 38, height: 38, borderRadius: 11, cursor: 'pointer',
            background: 'transparent', border: `1px solid ${t.border}`, color: t.textDim,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <Icon name={dark ? 'sun' : 'moon'} size={17} color={t.textDim}/>
          </button>
          {isHome ? (
            <a href="#waitlist" style={{ textDecoration: 'none' }} className="nav-cta">
              <Button variant="primary" size="sm">Get the app</Button>
            </a>
          ) : (
            <Link to="/#waitlist" style={{ textDecoration: 'none' }} className="nav-cta">
              <Button variant="primary" size="sm">Get the app</Button>
            </Link>
          )}
        </div>
      </Container>
    </header>
  );
}

export { Nav }
