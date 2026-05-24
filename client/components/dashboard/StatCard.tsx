"use client"

import React from "react"
import styled from "styled-components"
import { Icon } from "@/components/ui/icon"

interface StatCardProps {
  title: string
  value: string | number
  percent?: string
  trend?: "up" | "down" | "neutral"
  fillPercent?: number
  icon: string
  pillColor?: string
  barColor?: string
}

const StatCard: React.FC<StatCardProps> = ({
  title,
  value,
  percent,
  trend = "neutral",
  fillPercent = 0,
  icon,
  pillColor = "#10B981",
  barColor = "#10B981",
}) => {
  const clampedFill = Math.max(0, Math.min(fillPercent, 100))

  return (
    <StyledWrapper>
      <div className="card">
        <div className="title">
          <span style={{ backgroundColor: pillColor }}>
            <Icon name={icon} />
          </span>
          <p className="title-text">{title}</p>
          {percent && (
            <p
              className={
                "percent " +
                (trend === "up"
                  ? "percent-up"
                  : trend === "down"
                  ? "percent-down"
                  : "")
              }
            >
              {percent}
            </p>
          )}
        </div>
        <div className="data">
          <p>{value}</p>
          <div className="range">
            <div
              className="fill"
              style={{ width: `${clampedFill}%`, backgroundColor: barColor }}
            />
          </div>
        </div>
      </div>
    </StyledWrapper>
  )
}

const StyledWrapper = styled.div`
  .card {
    width: 100%;
    padding: 1.1rem 1.25rem;
    background-color: var(--card);
    border-radius: 1.25rem;
    border: 1px solid var(--border);
    box-shadow: 0 10px 20px rgba(15, 23, 42, 0.06);
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .title {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .title span {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0.45rem;
    width: 2.25rem;
    height: 2.25rem;
    border-radius: 9999px;
    flex-shrink: 0;
  }

  .title span svg {
    position: static;
    transform: none;
    color: #ffffff;
    width: 1.25rem;
    height: 1.25rem;
  }

  .title-text {
    flex: 1;
    margin-left: 0.25rem;
    color: var(--card-foreground);
    font-size: 0.95rem;
    font-weight: 600;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .percent {
    margin-left: 0.5rem;
    color: #16a34a;
    font-weight: 600;
    display: flex;
    align-items: center;
    font-size: 0.8rem;
    flex-shrink: 0;
  }

  .percent-up {
    color: #16a34a;
  }

  .percent-down {
    color: var(--destructive);
  }

  .data {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .data p {
    margin: 0.25rem 0 0.35rem 0;
    color: var(--card-foreground);
    font-size: 1.75rem;
    line-height: 2rem;
    font-weight: 700;
    text-align: left;
  }

  .data .range {
    position: relative;
    background-color: var(--muted);
    width: 100%;
    height: 0.45rem;
    border-radius: 9999px;
    overflow: hidden;
  }

  .data .range .fill {
    position: absolute;
    top: 0;
    left: 0;
    height: 100%;
    border-radius: 9999px;
  }
`

export default StatCard
