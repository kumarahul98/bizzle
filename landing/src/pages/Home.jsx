import React from 'react'
import { Hero } from '../sections/Hero.jsx'
import { WhyContext } from '../sections/WhyContext.jsx'
import { Insight } from '../sections/Insight.jsx'
import { HowItWorks } from '../sections/HowItWorks.jsx'
import { StatsPreview } from '../sections/StatsPreview.jsx'
import { CTA } from '../sections/CTA.jsx'

const HEADLINES = {
  overtime: { pre: 'Your commute is ', hi: 'unpaid overtime', post: '.', mono: false },
};

export function Home() {
  return (
    <main>
      <Hero headline={HEADLINES.overtime} accent="amber"/>
      <WhyContext/>
      <Insight/>
      <HowItWorks/>
      <StatsPreview/>
      <CTA/>
    </main>
  )
}
