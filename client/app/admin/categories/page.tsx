"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { Icon } from "@/components/ui/icon"
import { adminApi } from "@/lib/api"
import { getAdminFetchError, unwrapAdminList } from "@/lib/admin-fetch"
import { CATEGORIES, type CategoryId } from "@/lib/types"

interface AdminCategoryRow {
  id: number
  name: string
  productCount: number
}

export default function AdminCategoriesPage() {
  const [categories, setCategories] = useState<AdminCategoryRow[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchCategories = async () => {
      setIsLoading(true)
      setError(null)
      try {
        const res = await adminApi.getCategories()
        setCategories(unwrapAdminList<AdminCategoryRow>(res.data, ["categories"]))
      } catch (err) {
        console.error("Failed to load categories", err)
        setError(getAdminFetchError(err, "Failed to load categories. Please try again."))
      } finally {
        setIsLoading(false)
      }
    }

    fetchCategories()
  }, [])

  const resolveCategoryId = (name: string): CategoryId | null => {
    // Map DB names to CategoryId using the known CATEGORIES list and CATEGORY_NAME_TO_ID on backend
    // Here we try to match by lowercased, trimmed name
    const lower = name.toLowerCase().trim()
    const match = CATEGORIES.find((c) => c.name.toLowerCase().trim() === lower)
    return match?.id ?? null
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold mb-2">Categories</h1>
        <p className="text-muted-foreground">Overview of all categories and how many products each has.</p>
      </div>

      {isLoading && <div className="bg-card border rounded-2xl p-6">Loading categories...</div>}

      {error && !isLoading && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
          {error}
        </div>
      )}

      {!isLoading && !error && (
        <div className="bg-card border rounded-2xl p-0 overflow-hidden">
          <div className="border-b px-6 py-4 flex items-center justify-between">
            <h2 className="text-lg font-semibold">Category List</h2>
            <span className="text-sm text-muted-foreground">{categories.length} categories</span>
          </div>

          {categories.length === 0 ? (
            <div className="px-6 py-8 text-sm text-muted-foreground">No categories found.</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full text-sm">
                <thead className="bg-muted/60">
                  <tr>
                    <th className="px-6 py-3 text-left font-medium text-xs text-muted-foreground uppercase tracking-wide">
                      Name
                    </th>
                    <th className="px-6 py-3 text-left font-medium text-xs text-muted-foreground uppercase tracking-wide">
                      Products
                    </th>
                    <th className="px-6 py-3 text-right font-medium text-xs text-muted-foreground uppercase tracking-wide">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {categories.map((cat) => {
                    const categoryId = resolveCategoryId(cat.name)

                    return (
                      <tr key={cat.id} className="border-t hover:bg-muted/40">
                        <td className="px-6 py-3">
                          <div className="flex items-center gap-2">
                            <span className="font-medium">{cat.name}</span>
                          </div>
                        </td>
                        <td className="px-6 py-3">
                          <span className="inline-flex items-center gap-1 text-sm">
                            <Icon name="box" className="text-muted-foreground" />
                            {cat.productCount}
                          </span>
                        </td>
                        <td className="px-6 py-3 text-right">
                          <div className="flex items-center justify-end gap-2">
                            {categoryId && (
                              <Link
                                href={`/category/${categoryId}`}
                                className="inline-flex items-center gap-1 text-xs font-medium text-primary hover:underline"
                              >
                                <Icon name="external-link" className="w-3 h-3" />
                                View in storefront
                              </Link>
                            )}
                          </div>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
