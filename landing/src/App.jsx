import React, { useState, useEffect } from 'react'
import { Outlet } from 'react-router-dom'
import { ThemeCtx } from './theme.jsx'
import { TOKENS } from './tokens.js'
import { Nav } from './sections/Nav.jsx'
import { Footer } from './sections/Footer.jsx'

export function AppLayout() {
  const [theme, setTheme] = useState('system')
  const [sysDark, setSysDark] = useState(() =>
    typeof window !== 'undefined' && window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches);

  useEffect(() => {
    if (typeof window === 'undefined' || !window.matchMedia) return;
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const fn = (e) => setSysDark(e.matches);
    mq.addEventListener('change', fn);
    return () => mq.removeEventListener('change', fn);
  }, []);

  const dark = theme === 'system' ? sysDark : theme === 'dark';
  const t = dark ? TOKENS.dark : TOKENS.light;

  useEffect(() => {
    if (typeof document !== 'undefined') {
      document.body.style.background = t.bg;
      document.body.style.color = t.text;
      document.documentElement.style.colorScheme = dark ? 'dark' : 'light';
    }
  }, [dark, t]);

  return (
    <ThemeCtx.Provider value={{ t, theme: dark ? 'dark' : 'light', dark }}>
      <Nav dark={dark} onToggleTheme={() => setTheme(dark ? 'light' : 'dark')}/>
      <Outlet />
      <Footer/>
    </ThemeCtx.Provider>
  )
}
