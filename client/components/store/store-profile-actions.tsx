"use client"

import { usePathname, useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Icon } from "@/components/ui/icon"
import { useAuth } from "@/context/auth-context"
import { useToast } from "@/hooks/use-toast"
import { useChatOpen } from "@/hooks/use-chat-open"
import { ReportLinkButton } from "@/components/report/report-link-button"

interface StoreProfileActionsProps {
  storeId: number
  storeName: string
  isFollowing: boolean
  followLoading: boolean
  onToggleFollow: () => void
}

export function StoreProfileActions({
  storeId,
  storeName,
  isFollowing,
  followLoading,
  onToggleFollow,
}: StoreProfileActionsProps) {
  const router = useRouter()
  const pathname = usePathname()
  const { isAuthenticated, getRole } = useAuth()
  const { toast } = useToast()
  const { isBusy, openBuyerStore } = useChatOpen()
  const chatBusyKey = `store-${storeId}`

  const requireBuyer = (): boolean => {
    if (!isAuthenticated || getRole() !== "buyer") {
      router.push(`/login?role=buyer&redirect=${encodeURIComponent(`/store/${storeId}`)}`)
      return false
    }
    return true
  }

  const handleMessage = async () => {
    if (!requireBuyer()) return
    const base = pathname || `/store/${storeId}`
    await openBuyerStore(chatBusyKey, storeId, base)
  }

  const handleShare = async () => {
    const url = typeof window !== "undefined" ? window.location.href : ""
    try {
      if (navigator.share) {
        await navigator.share({ title: storeName, url })
      } else {
        await navigator.clipboard.writeText(url)
        toast({ title: "Link copied to clipboard" })
      }
    } catch {
      try {
        await navigator.clipboard.writeText(url)
        toast({ title: "Link copied to clipboard" })
      } catch {
        toast({ title: "Could not share store", variant: "destructive" })
      }
    }
  }

  return (
    <div className="flex flex-wrap gap-2 px-4 sm:px-6 pb-4">
      {getRole() !== "seller" && (
        <Button
          type="button"
          variant={isFollowing ? "secondary" : "default"}
          size="sm"
          disabled={followLoading}
          onClick={() => {
            if (!requireBuyer()) return
            onToggleFollow()
          }}
          className="gap-1.5"
        >
          <Icon name={isFollowing ? "check" : "plus"} />
          {isFollowing ? "Following" : "Follow"}
        </Button>
      )}
      <Button
        type="button"
        variant="outline"
        size="sm"
        disabled={isBusy(chatBusyKey)}
        onClick={() => void handleMessage()}
        className="gap-1.5"
      >
        {isBusy(chatBusyKey) ? (
          <>
            <span className="w-3.5 h-3.5 border-2 border-current border-t-transparent rounded-full animate-spin" />
            Opening…
          </>
        ) : (
          <>
            <Icon name="envelope" />
            Message
          </>
        )}
      </Button>
      <Button type="button" variant="outline" size="sm" onClick={() => void handleShare()} className="gap-1.5">
        <Icon name="share" />
        Share
      </Button>
      {getRole() === "buyer" && (
        <ReportLinkButton
          reporterRole="buyer"
          params={{
            targetRole: "seller",
            storeId,
            label: storeName,
          }}
        >
          Report store
        </ReportLinkButton>
      )}
    </div>
  )
}
