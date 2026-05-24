"use client"

import styled from "styled-components"

// Themed primary CTA button using the hover effect you provided
// Can be used as <HeroButton> or polymorphically: <HeroButton as={Link} href="/...">...
export const HeroButton = styled.button`
  padding: 0.65em 1.6em;
  border: none;
  border-radius: 9999px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  cursor: pointer;
  font-size: 0.75rem;
  position: relative;
  overflow: hidden;
  outline: 2px solid var(--primary);
  color: var(--primary);
  background: transparent;
  transition: all 250ms ease;
  z-index: 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.35rem;
  white-space: nowrap;

  &:hover {
    color: var(--primary-foreground);
    transform: scale(1.03);
    outline-color: var(--primary);
    box-shadow: 0 10px 18px rgba(0, 0, 0, 0.16);
  }

  &::before {
    content: "";
    position: absolute;
    left: -50px;
    top: 0;
    width: 0;
    height: 100%;
    background-color: var(--primary);
    transform: skewX(45deg);
    z-index: -1;
    transition: width 250ms ease;
  }

  &:hover::before {
    width: 250%;
  }
`
