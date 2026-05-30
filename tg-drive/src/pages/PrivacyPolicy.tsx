interface Props {
  onBack: () => void
}

export default function PrivacyPolicy({ onBack }: Props) {
  return (
    <div className="min-h-screen flex flex-col" style={{ background: 'var(--color-surface)', color: 'var(--color-text)' }}>
      <header className="h-14 border-b px-4 flex items-center gap-3 flex-shrink-0" style={{ background: 'var(--color-header-bg)', borderColor: 'var(--color-border)' }}>
        <button
          onClick={onBack}
          className="flex items-center gap-1.5 text-sm transition-colors"
          style={{ color: 'var(--color-accent)' }}
          onMouseEnter={(e) => e.currentTarget.style.opacity = '0.8'}
          onMouseLeave={(e) => e.currentTarget.style.opacity = '1'}
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
          Back to App
        </button>
        <h1 className="text-sm font-bold" style={{ color: 'var(--color-text)' }}>Privacy Policy</h1>
      </header>

      <main className="flex-1 overflow-y-auto px-6 py-8 max-w-2xl mx-auto w-full">
        <h1 className="text-2xl font-bold mb-1" style={{ color: 'var(--color-text)' }}>TeleDrive Privacy Policy</h1>
        <p className="text-sm mb-8" style={{ color: 'var(--color-text-tertiary)' }}>Last updated: May 2026</p>

        <Section title="1. Overview">
          TeleDrive is a personal cloud storage application that uses Telegram's infrastructure to store your files. We are committed to protecting your privacy.
        </Section>

        <Section title="2. Data We Collect">
          <ul className="list-disc pl-5 space-y-1">
            <li>Your Telegram phone number (used only for authentication)</li>
            <li>Telegram session string (stored locally on your device only, never sent to our servers)</li>
            <li>API credentials (stored locally on your device)</li>
          </ul>
          <p className="mt-2">We do NOT collect, store, or transmit any personal data to our own servers.</p>
        </Section>

        <Section title="3. How Your Data Is Stored">
          <ul className="list-disc pl-5 space-y-1">
            <li>All files are stored directly in YOUR Telegram account (Saved Messages and private channels you create)</li>
            <li>Your session string is stored only in your device's local storage</li>
            <li>We have zero access to your files, messages, or account</li>
          </ul>
        </Section>

        <Section title="4. Third Party Services">
          TeleDrive uses Telegram's MTProto API to function. Your use of TeleDrive is also subject to Telegram's Privacy Policy at{' '}
          <a
            href="https://telegram.org/privacy"
            target="_blank"
            rel="noopener noreferrer"
            style={{ color: 'var(--color-accent)' }}
            className="underline hover:opacity-80 transition-opacity"
          >
            telegram.org/privacy
          </a>.
        </Section>

        <Section title="5. File Access">
          <ul className="list-disc pl-5 space-y-1">
            <li>We only access files you explicitly upload or interact with through the app</li>
            <li>We never scan, index, or analyze your file contents</li>
            <li>We never share your files with anyone</li>
          </ul>
        </Section>

        <Section title="6. Children's Privacy">
          TeleDrive is not intended for users under 13 years of age.
        </Section>

        <Section title="7. Changes to This Policy">
          We may update this policy. Continued use of the app after changes means you accept the new policy.
        </Section>

        <Section title="8. Contact">
          For privacy concerns contact:{' '}
          <a
            href="mailto:rohandalvi369@gmail.com"
            style={{ color: 'var(--color-accent)' }}
            className="underline hover:opacity-80 transition-opacity"
          >
            rohandalvi369@gmail.com
          </a>
        </Section>
      </main>
    </div>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="mb-6">
      <h2 className="text-lg font-semibold mb-2" style={{ color: 'var(--color-text)' }}>{title}</h2>
      <div className="text-sm leading-relaxed" style={{ color: 'var(--color-text-secondary, #a1a1aa)' }}>
        {children}
      </div>
    </div>
  )
}
