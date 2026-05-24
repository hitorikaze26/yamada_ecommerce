import { redirect } from "next/navigation"

/** Canonical buyer order list lives under the account sidebar. */
export default function OrdersIndexPage() {
  redirect("/buyer/orders")
}
