import React, { useContext } from 'react'
import { Head as Helmet } from 'vite-react-ssg'
import { ThemeCtx } from '../theme'
import { Container } from '../components/ui.jsx'

// Privacy policy for the Traevy Android app. Reachable only by direct URL
// (/privacy) — intentionally not linked from the site nav or footer. This is
// the URL pasted into the Play Console Data Safety form and the store listing's
// privacy-policy field, so its disclosures must stay accurate to what the app
// actually collects (precise Home/Office coordinates + commute routes, stored
// in Firebase and linked to the signed-in Google account).

const LAST_UPDATED = 'July 26, 2026'
const CONTACT_EMAIL = 'connect@traevy.com'

export function Privacy() {
  const { t } = useContext(ThemeCtx)

  const H = ({ children }) => (
    <h2 style={{ fontSize: '1.375rem', fontWeight: 600, letterSpacing: '-0.02em', color: t.text, margin: '44px 0 14px' }}>
      {children}
    </h2>
  )
  const P = ({ children }) => (
    <p style={{ color: t.textDim, lineHeight: 1.7, fontSize: '15.5px', margin: '0 0 16px' }}>
      {children}
    </p>
  )
  const LI = ({ children }) => (
    <li style={{ color: t.textDim, lineHeight: 1.7, fontSize: '15.5px', marginBottom: 10 }}>
      {children}
    </li>
  )
  const UL = ({ children }) => (
    <ul style={{ margin: '0 0 16px', paddingLeft: 22 }}>{children}</ul>
  )
  const Strong = ({ children }) => (
    <strong style={{ color: t.text, fontWeight: 600 }}>{children}</strong>
  )

  return (
    <Container width={760} style={{ padding: '72px 32px 120px' }}>
      <Helmet>
        <title>Privacy Policy | Traevy</title>
        <meta name="description" content="How the Traevy commute-tracking app collects, uses, stores, and protects your data." />
        <meta name="robots" content="noindex" />
      </Helmet>

      <h1 style={{ fontSize: '2.75rem', margin: 0, fontWeight: 700, letterSpacing: '-0.04em', color: t.text }}>
        Privacy Policy
      </h1>
      <p style={{ color: t.textMuted, fontSize: '0.95rem', margin: '12px 0 0' }}>
        Last updated: {LAST_UPDATED}
      </p>

      <div style={{ marginTop: 28 }}>
        <P>
          Traevy is an Android app that tracks your daily commutes and shows you how much
          time you spend stuck in traffic. This policy explains what the app collects, why,
          where it is stored, and the choices you have. Traevy is designed to be
          <Strong> local-first</Strong>: your trips live on your device, and the cloud is
          used only as an optional backup tied to your account.
        </P>

        <H>Who we are</H>
        <P>
          Traevy ("we", "us", "the app") is the data controller for the information described
          below. For any privacy question or request, contact us at{' '}
          <a href={`mailto:${CONTACT_EMAIL}`} style={{ color: t.accent, fontWeight: 600, textDecoration: 'none' }}>
            {CONTACT_EMAIL}
          </a>.
        </P>

        <H>Information we collect</H>
        <UL>
          <LI>
            <Strong>Account information.</Strong> When you sign in with Google, we receive your
            Google account identifier and email address through Firebase Authentication. Signing
            in is optional — the app is fully usable without an account, in which case no account
            information is collected.
          </LI>
          <LI>
            <Strong>Precise location.</Strong> While you are actively recording a trip, the app
            collects precise GPS location in the background to compute your route, distance, speed,
            and the moving-versus-stuck-in-traffic breakdown. If you set Home and Office locations,
            those precise coordinates are stored so the app can automatically label a trip's
            direction.
          </LI>
          <LI>
            <Strong>Trip data.</Strong> Start and end times, duration, distance, the recorded
            route, break/pause segments, traffic breakdown, and the direction label for each
            commute you record or enter manually.
          </LI>
          <LI>
            <Strong>App preferences.</Strong> Settings such as theme, reminder times, auto-pause,
            and the cutoff hours used for direction labeling.
          </LI>
        </UL>
        <P>
          We do <Strong>not</Strong> collect your contacts, photos, microphone, advertising
          identifiers, or browsing activity, and Traevy contains no third-party advertising.
        </P>

        <H>How location is used</H>
        <P>
          Location is only collected during an active recording session that you start, and while
          the reminder or auto-label features you have enabled require it. A persistent notification
          is shown while a trip is recording so it is always clear when location is being captured.
          We never write raw coordinates to logs. Location is used solely to produce your commute
          stats and direction labels — it is not used for profiling, advertising, or tracking you
          across other apps or services.
        </P>

        <H>Where your data is stored</H>
        <P>
          Your trips are stored <Strong>on your device</Strong> as the source of truth. If you are
          signed in, your trips and your Home/Office coordinates are also backed up to our cloud
          backend so you can restore them on a new device. This backup is
          <Strong> linked to your account</Strong>. If you use the app without signing in, nothing
          is uploaded and all data stays on your device.
        </P>

        <H>How we share information</H>
        <P>
          We do <Strong>not</Strong> sell your data and we do <Strong>not</Strong> share it with
          third parties for their own purposes. The only processor involved is the third-party
          cloud provider that hosts our backend, which stores your backed-up data and handles
          sign-in on our behalf under its data-processing terms. We may disclose information if
          required by law.
        </P>

        <H>Data retention and your choices</H>
        <UL>
          <LI>
            You can delete any trip in the app. Deleting a trip removes it from your device and
            it is then excluded from cloud sync and restore, so it no longer appears on any
            device. The underlying backup record is <Strong>retained on our backend</Strong>
            rather than immediately erased; to have it and all associated cloud data permanently
            removed, request full account deletion below.
          </LI>
          <LI>You can clear your Home and Office locations at any time from Settings.</LI>
          <LI>You can use the app entirely offline, without an account, so that no data leaves your device.</LI>
          <LI>
            To request deletion of your account and all associated cloud data, email us at{' '}
            <a href={`mailto:${CONTACT_EMAIL}`} style={{ color: t.accent, fontWeight: 600, textDecoration: 'none' }}>
              {CONTACT_EMAIL}
            </a>.
          </LI>
        </UL>

        <H>Security</H>
        <P>
          Authentication tokens are stored in the Android Keystore (secure storage). Data in transit
          to our backend is encrypted over HTTPS, and access to your backed-up trips is restricted to
          your authenticated account.
        </P>

        <H>Children</H>
        <P>
          Traevy is a general-audience app — people of any age can use it. It is not, however,
          directed at or designed for young children, and we do not knowingly collect personal
          information from children under 13 (or the minimum age of digital consent in their
          region). If you believe a child has provided us personal information, contact us and we
          will delete it.
        </P>

        <H>Changes to this policy</H>
        <P>
          We may update this policy as the app evolves. Material changes will be reflected here with
          an updated "Last updated" date.
        </P>

        <H>Contact</H>
        <P>
          Questions or requests? Reach us at{' '}
          <a href={`mailto:${CONTACT_EMAIL}`} style={{ color: t.accent, fontWeight: 600, textDecoration: 'none' }}>
            {CONTACT_EMAIL}
          </a>.
        </P>
      </div>
    </Container>
  )
}
