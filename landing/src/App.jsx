import React, { useState, useEffect } from 'react'
import { ThemeCtx } from './theme.jsx'
import { TOKENS } from './tokens.js'
import { Nav } from './sections/Nav.jsx'
import { Hero } from './sections/Hero.jsx'
import { WhyContext } from './sections/WhyContext.jsx'
import { Insight } from './sections/Insight.jsx'
import { HowItWorks } from './sections/HowItWorks.jsx'
import { StatsPreview } from './sections/StatsPreview.jsx'
import { CTA } from './sections/CTA.jsx'
import { Footer } from './sections/Footer.jsx'

const HEADLINES = {
  overtime: { pre: 'Your commute is ', hi: 'unpaid overtime', post: '.', mono: false },
  lost: { pre: 'You lost ', hi: '4h 12m', post: ' to traffic this week.', mono: true },
  took: { pre: 'Traffic took ', hi: '4h 12m', post: ' of your week.', mono: true },
};

function App() {
  const [theme, setTheme] = useState('system')
  const [sysDark, setSysDark] = useState(() =>
    window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches);

  useEffect(() => {
    if (!window.matchMedia) return;
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const fn = (e) => setSysDark(e.matches);
    mq.addEventListener('change', fn);
    return () => mq.removeEventListener('change', fn);
  }, []);

  const dark = theme === 'system' ? sysDark : theme === 'dark';
  const t = dark ? TOKENS.dark : TOKENS.light;

  useEffect(() => {
    document.body.style.background = t.bg;
    document.body.style.color = t.text;
    document.documentElement.style.colorScheme = dark ? 'dark' : 'light';
  }, [dark, t]);

  const headline = HEADLINES.overtime;

  return (
    <ThemeCtx.Provider value={{ t, theme: dark ? 'dark' : 'light', dark }}>
      <Nav dark={dark} onToggleTheme={() => setTheme(dark ? 'light' : 'dark')}/>
      <main>
        <Hero headline={headline} accent="amber"/>
        <WhyContext/>
        <Insight/>
        <HowItWorks/>
        <StatsPreview/>
        <CTA/>
      </main>
      <Footer/>
    </ThemeCtx.Provider>
  );
}

export { App }
