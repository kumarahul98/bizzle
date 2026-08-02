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
//
// The "Deleting your data" section carries id="delete-account" and doubles as
// the account-deletion URL required by Google Play's User Data policy
// (https://traevy.com/privacy#delete-account). Play requires a route to
// request deletion that does NOT depend on reinstalling the app, which is why
// the email fallback must stay alongside the in-app steps. Do not remove that
// id or the email route without providing another public deletion URL first.

const LAST_UPDATED = 'August 2, 2026'
const CONTACT_EMAIL = 'connect@traevy.com'
// Days a deleted trip stays recoverable in the in-app Trash before it is
// purged from the device. Mirrors kTrashRetentionDays in the app's
// lib/config/constants.dart — keep the two in step.
const TRASH_RETENTION_DAYS = 30

export function Privacy() {
  const { t } = useContext(ThemeCtx)

  // `id` is set on the deletion heading so /privacy#delete-account resolves —
  // that anchor is the URL submitted to Play. scrollMarginTop keeps the
  // heading clear of the viewport edge when the browser jumps to it.
  const H = ({ children, id }) => (
    <h2 id={id} style={{ fontSize: '1.375rem', fontWeight: 600, letterSpacing: '-0.02em', color: t.text, margin: '44px 0 14px', scrollMarginTop: 24 }}>
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
            direction. When you open the Home or Office location picker, the app also reads your
            current position once to centre the map on you; that reading is used only to position
            the map and is never stored unless you confirm it as a saved location.
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
          Continuous location is only collected during an active recording session that you start,
          and while the reminder or auto-label features you have enabled require it. The only other
          time the app reads your position is the single reading taken when you open the Home or
          Office location picker, described above. A persistent notification is shown while a trip
          is recording so it is always clear when location is being captured.
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
            You can delete any trip in the app. A deleted trip moves to Trash, where it stays
            recoverable for {TRASH_RETENTION_DAYS} days before it is removed from your device.
            From the moment you delete it, it is excluded from cloud sync and restore, so it no
            longer appears on any device. The underlying backup record is
            <Strong> retained on our backend</Strong> rather than immediately erased; to have it
            and all associated cloud data permanently removed, delete your account as described
            below.
          </LI>
          <LI>You can clear your Home and Office locations at any time from Settings.</LI>
          <LI>You can use the app entirely offline, without an account, so that no data leaves your device.</LI>
        </UL>

        <H id="delete-account">Deleting your data and your account</H>
        <P>
          You can delete your data directly in the app, without contacting us. Both options live in{' '}
          <Strong>Settings</Strong>:
        </P>
        <UL>
          <LI>
            <Strong>Delete all data</Strong> — removes every trip from your device and also erases
            those trips from our backend, including any trips still sitting in Trash. Your account
            itself is kept, so you can carry on with a clean slate. This cannot be undone.
          </LI>
          <LI>
            <Strong>Delete account</Strong> — signs you out and permanently erases your account
            along with <Strong>every trip we hold for it</Strong>, including trips still sitting in
            Trash. Because the account can never sign in again, these records are erased outright
            rather than retained as backups. Your Home and Office coordinates and your synced
            preferences are removed with them. This cannot be undone.
          </LI>
        </UL>
        <P>
          If you have already uninstalled the app, or cannot reach these options for any reason,
          email us at{' '}
          <a href={`mailto:${CONTACT_EMAIL}`} style={{ color: t.accent, fontWeight: 600, textDecoration: 'none' }}>
            {CONTACT_EMAIL}
          </a>{' '}
          from the address associated with your Google sign-in and ask us to delete your account.
          We will confirm the request and erase your account and all associated cloud data within
          30 days.
        </P>
        <P>
          Data held only on your device — trips you recorded while signed out, and app preferences
          such as theme and reminder times — is removed when you uninstall the app.
        </P>

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
