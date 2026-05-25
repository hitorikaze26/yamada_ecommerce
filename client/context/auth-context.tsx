"use client"

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react"
import { useRouter } from "next/navigation"
import { authApi } from "@/lib/api"
import type { User, UserRole } from "@/lib/types"
import {
  ROLE_STORAGE_KEY,
  buildUserFromSession,
  dashboardRoutes,
  fetchRoleProfile,
  getLoginErrorMessage,
  parseSessionPayload,
  resolveHydrationRole,
  type AuthSessionDto,
} from "@/lib/auth/session"

interface AuthContextType {
  user: User | null
  isLoading: boolean
  isAuthenticated: boolean
  login: (email: string, password: string, role: UserRole, redirectTo?: string) => Promise<void>
  logout: () => Promise<void>
  getRole: () => UserRole | null
  isVerified: () => boolean
  refreshBuyerProfile: () => Promise<void>
  refreshSellerProfile: () => Promise<void>
  getLoginErrorMessage: (error: unknown) => string
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

const USER_STORAGE_KEY = "yamada-user"
const TOKEN_STORAGE_KEY = "yamada-access-token"

function clearClientAuth() {
  localStorage.removeItem(USER_STORAGE_KEY)
  localStorage.removeItem(TOKEN_STORAGE_KEY)
  localStorage.removeItem(ROLE_STORAGE_KEY)
}

async function hydrateUser(
  session: AuthSessionDto,
  preferredRole: UserRole | null,
  loginVerified?: boolean,
  pathname?: string | null,
): Promise<User | null> {
  const role = resolveHydrationRole(preferredRole, session.roles, pathname)
  if (!role) return null

  const profile = await fetchRoleProfile(role)
  return buildUserFromSession(session, role, profile, loginVerified)
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const router = useRouter()
  const userRef = useRef(user)
  userRef.current = user

  useEffect(() => {
    const checkAuth = async () => {
      try {
        const sessionRes = await authApi.checkSession()
        if (process.env.NODE_ENV !== 'production') {
          try {
            // eslint-disable-next-line no-console
            console.debug('[Auth] checkSession response:', sessionRes.status, sessionRes.data)
          } catch {}
        }
        const session = parseSessionPayload(sessionRes.data as Record<string, unknown>)

        if (!session.user_id || session.roles.length === 0) {
          clearClientAuth()
          setUser(null)
          return
        }

        const storedRole = localStorage.getItem(ROLE_STORAGE_KEY) as UserRole | null
        const pathname =
          typeof window !== "undefined" ? window.location.pathname : null
        const hydrated = await hydrateUser(
          session,
          storedRole,
          session.is_verified,
          pathname,
        )

        if (process.env.NODE_ENV !== 'production') {
          // eslint-disable-next-line no-console
          console.debug('[Auth] hydrated user:', hydrated)
        }
        if (!hydrated) {
          clearClientAuth()
          setUser(null)
          return
        }

        localStorage.setItem(USER_STORAGE_KEY, JSON.stringify(hydrated))
        localStorage.setItem(ROLE_STORAGE_KEY, hydrated.role)
        setUser(hydrated)
      } catch (error: unknown) {
        const status = (error as { response?: { status?: number } })?.response?.status
        if (status === 401 || status === 403) {
          clearClientAuth()
          setUser(null)
        } else {
          try {
            const cached = localStorage.getItem(USER_STORAGE_KEY)
            if (cached) setUser(JSON.parse(cached) as User)
          } catch {
            clearClientAuth()
            setUser(null)
          }
        }
      } finally {
        setIsLoading(false)
      }
    }

    void checkAuth()
  }, [])

  const login = async (
    email: string,
    password: string,
    role: UserRole,
    redirectTo?: string,
  ) => {
    const normalizedEmail = email.trim()
    const response = await authApi.login(normalizedEmail, password, role)
    const data = response.data as Record<string, unknown>
    const accessToken = data.access_token as string | undefined
    const loginVerified = Boolean(data.is_verified)
    const parsed = parseSessionPayload(data)
    const session = {
      ...parsed,
      user_id: parsed.user_id || Number(data.user_id ?? 0),
      email: String(data.email ?? parsed.email ?? normalizedEmail),
      roles: parsed.roles.length > 0 ? parsed.roles : [role],
    }

    if (!accessToken) {
      throw new Error("Missing access token in login response")
    }

    localStorage.setItem(TOKEN_STORAGE_KEY, accessToken)

    const serverRoles = session.roles.length > 0 ? session.roles : [role]
    if (!serverRoles.includes(role)) {
      clearClientAuth()
      throw new Error(getLoginErrorMessage({ response: { status: 403 } }))
    }

    const userData = await hydrateUser(session, role, loginVerified)
    if (!userData) {
      clearClientAuth()
      throw new Error(
        serverRoles.length === 0
          ? "Account has no roles assigned. Contact support."
          : `This account cannot use the ${role} portal. Try a different sign-in link.`,
      )
    }

    localStorage.setItem(USER_STORAGE_KEY, JSON.stringify(userData))
    localStorage.setItem(ROLE_STORAGE_KEY, userData.role)
    setUser(userData)

    const destination =
      redirectTo && redirectTo.startsWith("/") && !redirectTo.startsWith("//")
        ? redirectTo
        : dashboardRoutes[userData.role]

    // Full navigation avoids Next.js soft-route staying on /auth/login after success
    if (typeof window !== "undefined") {
      window.location.assign(destination)
      return
    }
    router.replace(destination)
  }

  const logout = async () => {
    try {
      await authApi.logout()
    } catch {
      // Still clear local session
    } finally {
      const userId = user?.id
      if (userId) {
        const userCartKey = `yamada-cart-${userId}`
        const userCart = localStorage.getItem(userCartKey)
        if (userCart) {
          localStorage.setItem("yamada-cart-guest", userCart)
        }
        localStorage.removeItem(userCartKey)
      }

      clearClientAuth()
      setUser(null)
      router.push("/")
    }
  }

  const getRole = () => user?.role ?? null

  const isVerified = () => !!user?.isVerified

  const refreshBuyerProfile = useCallback(async () => {
    const current = userRef.current
    if (!current || current.role !== "buyer") return
    let session: AuthSessionDto
    try {
      const sessionRes = await authApi.checkSession()
      session = parseSessionPayload(sessionRes.data as Record<string, unknown>)
    } catch (error: unknown) {
      const status = (error as { response?: { status?: number } })?.response?.status
      if (status === 401 || status === 403) {
        clearClientAuth()
        setUser(null)
      }
      return
    }
    const profile = await fetchRoleProfile("buyer")
    const updated = buildUserFromSession(session, "buyer", profile, session.is_verified)
    localStorage.setItem(USER_STORAGE_KEY, JSON.stringify(updated))
    setUser(updated)
  }, [])

  const refreshSellerProfile = useCallback(async () => {
    const current = userRef.current
    if (!current || current.role !== "seller") return
    let session: AuthSessionDto
    try {
      const sessionRes = await authApi.checkSession()
      session = parseSessionPayload(sessionRes.data as Record<string, unknown>)
    } catch (error: unknown) {
      const status = (error as { response?: { status?: number } })?.response?.status
      if (status === 401 || status === 403) {
        clearClientAuth()
        setUser(null)
      }
      return
    }
    const profile = await fetchRoleProfile("seller")
    const updated = buildUserFromSession(session, "seller", profile, session.is_verified)
    localStorage.setItem(USER_STORAGE_KEY, JSON.stringify(updated))
    localStorage.setItem(ROLE_STORAGE_KEY, "seller")
    setUser(updated)
  }, [])

  return (
    <AuthContext.Provider
      value={{
        user,
        isLoading,
        isAuthenticated: !!user,
        login,
        logout,
        getRole,
        isVerified,
        refreshBuyerProfile,
        refreshSellerProfile,
        getLoginErrorMessage,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider")
  }
  return context
}
