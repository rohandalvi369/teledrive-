import { useState, useRef, useCallback } from 'react'
import { createClient, setSession } from '@/lib/telegram'

type Step = 'phone' | 'code' | 'password'

interface Props {
  onAuthSuccess: () => void
}

let resolveCode: ((v: string) => void) | null = null
let resolvePassword: ((v: string) => void) | null = null

export default function Auth({ onAuthSuccess }: Props) {
  const [step, setStep] = useState<Step>('phone')
  const [phone, setPhone] = useState('')
  const [code, setCode] = useState('')
  const [pwd, setPwd] = useState('')
  const [hint, setHint] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const running = useRef(false)

  const handleStartAuth = useCallback(async () => {
    if (running.current) return
    running.current = true
    setLoading(true)
    setError('')

    try {
      const { client, stringSession } = createClient()

      resolveCode = null
      resolvePassword = null

      await client.start({
        phoneNumber: phone,
        phoneCode: async () => {
          setStep('code')
          return new Promise(r => { resolveCode = r })
        },
        password: async (hint?: string) => {
          if (hint) setHint(hint)
          setStep('password')
          return new Promise(r => { resolvePassword = r })
        },
        onError: (err) => {
          setError(err.message)
        },
      })

      setSession(stringSession.save() as string)
      onAuthSuccess()
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Authentication failed'
      setError(msg)
      setStep('phone')
    } finally {
      setLoading(false)
      running.current = false
    }
  }, [phone, onAuthSuccess])

  const handleSubmitCode = () => {
    if (resolveCode && code) {
      resolveCode(code)
      resolveCode = null
      setLoading(true)
    }
  }

  const handleSubmitPassword = () => {
    if (resolvePassword && pwd) {
      resolvePassword(pwd)
      resolvePassword = null
      setLoading(true)
    }
  }

  const inputCls = "w-full px-3 py-2 rounded-lg bg-white dark:bg-zinc-800 border border-zinc-300 dark:border-zinc-700 text-zinc-800 dark:text-zinc-100 placeholder-zinc-400 dark:placeholder-zinc-500 focus:outline-none focus:border-indigo-400 dark:focus:border-indigo-500"
  const btnCls = "w-full py-2 rounded-lg bg-indigo-500 dark:bg-indigo-600 text-white font-medium hover:bg-indigo-400 dark:hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"

  return (
    <div className="min-h-screen flex items-center justify-center bg-zinc-50 dark:bg-zinc-950 p-4">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <h1 className="text-2xl font-bold text-zinc-800 dark:text-zinc-100">tg-drive</h1>
          <p className="text-zinc-500 dark:text-zinc-500 text-sm mt-1">Telegram MTProto Auth</p>
        </div>

        {error && (
          <div className="mb-4 p-3 rounded-lg bg-red-50 dark:bg-red-900/40 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-300 text-sm">
            {error}
          </div>
        )}

        {step === 'phone' && (
          <div className="space-y-4">
            <div>
              <label className="block text-sm text-zinc-500 dark:text-zinc-400 mb-1">Phone Number</label>
              <input
                type="tel"
                value={phone}
                onChange={e => setPhone(e.target.value)}
                placeholder="+1234567890"
                className={inputCls}
                disabled={loading}
              />
            </div>
            <button
              onClick={handleStartAuth}
              disabled={loading || !phone.trim()}
              className={btnCls}
            >
              {loading ? 'Connecting...' : 'Sign In'}
            </button>
          </div>
        )}

        {step === 'code' && (
          <div className="space-y-4">
            <p className="text-sm text-zinc-500 dark:text-zinc-400">Enter the code sent to your Telegram</p>
            <input
              type="text"
              inputMode="numeric"
              value={code}
              onChange={e => setCode(e.target.value)}
              placeholder="12345"
              className={inputCls}
              autoFocus
            />
            <button
              onClick={handleSubmitCode}
              disabled={!code.trim()}
              className={btnCls}
            >
              Verify Code
            </button>
          </div>
        )}

        {step === 'password' && (
          <div className="space-y-4">
            <p className="text-sm text-zinc-500 dark:text-zinc-400">Two-factor authentication required</p>
            {hint && (
              <p className="text-xs text-zinc-400 dark:text-zinc-500">Hint: {hint}</p>
            )}
            <input
              type="password"
              value={pwd}
              onChange={e => setPwd(e.target.value)}
              placeholder="Enter your 2FA password"
              className={inputCls}
              autoFocus
            />
            <button
              onClick={handleSubmitPassword}
              disabled={!pwd.trim()}
              className={btnCls}
            >
              Sign In
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
