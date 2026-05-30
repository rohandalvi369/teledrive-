import { useState, useCallback } from 'react'
import { getSession } from '@/lib/telegram'
import { useTheme } from '@/hooks/useTheme'
import Auth from '@/pages/Auth'
import Dashboard from '@/pages/Dashboard'
import PrivacyPolicy from '@/pages/PrivacyPolicy'

type Page = 'auth' | 'dashboard' | 'privacy'

export default function App() {
  const [page, setPage] = useState<Page>(() => {
    if (window.location.pathname === '/privacy') return 'privacy'
    return getSession() ? 'dashboard' : 'auth'
  })

  useTheme()

  const goToPrivacy = useCallback(() => {
    window.history.pushState({}, '', '/privacy')
    setPage('privacy')
  }, [])

  const goBack = useCallback(() => {
    window.history.pushState({}, '', '/')
    if (getSession()) {
      setPage('dashboard')
    } else {
      setPage('auth')
    }
  }, [])

  if (page === 'privacy') {
    return <PrivacyPolicy onBack={goBack} />
  }

  if (page === 'auth' || !getSession()) {
    return <Auth onAuthSuccess={() => setPage('dashboard')} />
  }

  return <Dashboard onLogout={() => setPage('auth')} onShowPrivacy={goToPrivacy} />
}
