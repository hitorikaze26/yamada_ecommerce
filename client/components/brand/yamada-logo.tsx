import Image from "next/image"
import Link from "next/link"

type YamadaLogoProps = {
  size?: number
  href?: string
  showName?: boolean
}

export function YamadaLogo({ size = 40, href = "/", showName = true }: YamadaLogoProps) {
  const img = (
    <Image
      src="/logo/logo.png"
      alt="Yamada"
      width={size}
      height={size}
      className="object-contain"
      priority
    />
  )

  const content = (
    <span className="flex items-center gap-2">
      {img}
      {showName && <span className="text-xl font-semibold">Yamada</span>}
    </span>
  )

  if (href) {
    return (
      <Link href={href} className="flex items-center gap-2">
        {content}
      </Link>
    )
  }

  return content
}
