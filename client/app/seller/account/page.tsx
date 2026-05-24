import { redirect } from "next/navigation"

/** Legacy hub removed — send old links to seller dashboard. */
export default function SellerAccountRedirectPage() {
  redirect("/seller")
}
