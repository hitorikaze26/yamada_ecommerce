"use client"

import React from "react"
import styled from "styled-components"

interface LoaderProps {
  size?: number | string
  color?: string
}

const Loader: React.FC<LoaderProps> = ({ size = 70, color }) => {
  const cssSize = typeof size === "number" ? `${size}px` : size

  return (
    <StyledWrapper
      style={{
        // CSS variables used inside StyledWrapper
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        ...(cssSize ? ({ "--loader-size": cssSize } as any) : {}),
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        ...(color ? ({ "--loader-color": color } as any) : {}),
      }}
    >
      <div className="loader">
        <span />
        <span />
        <span />
        <span />
        <span />
        <span />
      </div>
    </StyledWrapper>
  )
}

const StyledWrapper = styled.div`
  position: fixed;
  inset: 0;
  z-index: 50;
  display: flex;
  align-items: center;
  justify-content: center;
  background: radial-gradient(circle at top, rgba(0, 0, 0, 0.06), transparent 55%),
    radial-gradient(circle at bottom, rgba(0, 0, 0, 0.12), transparent 60%);

  .loader {
    --color: var(--loader-color, var(--muted-foreground, #a5a5b0));
    --size: var(--loader-size, 70px);
    width: var(--size);
    height: var(--size);
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 5px;
  }

  .loader span {
    width: 100%;
    height: 100%;
    background-color: var(--color);
    animation: keyframes-blink 0.6s alternate infinite linear;
  }

  .loader span:nth-child(1) {
    animation-delay: 0ms;
  }

  .loader span:nth-child(2) {
    animation-delay: 200ms;
  }

  .loader span:nth-child(3) {
    animation-delay: 300ms;
  }

  .loader span:nth-child(4) {
    animation-delay: 400ms;
  }

  .loader span:nth-child(5) {
    animation-delay: 500ms;
  }

  .loader span:nth-child(6) {
    animation-delay: 600ms;
  }

  @keyframes keyframes-blink {
    0% {
      opacity: 0.3;
      transform: scale(0.5) rotate(5deg);
    }

    50% {
      opacity: 1;
      transform: scale(1);
    }
  }
`

export default Loader
