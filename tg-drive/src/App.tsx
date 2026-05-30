import { useState } from 'react'
import { getSession } from '@/lib/telegram'
import { useTheme } from '@/hooks/useTheme'
import Auth from '@/pages/Auth'
import Dashboard from '@/pages/Dashboard'

export default function App() {
  const [authed, setAuthed] = useState(() => !!getSession())

  // Initialize theme on mount (hook manages the class on <html>)
  useTheme()

  if (!authed) {
    return <Auth onAuthSuccess={() => setAuthed(true)} />
  }

  return <Dashboard onLogout={() => setAuthed(false)} />
}
