import type { ReactNode } from 'react';

/** Иконки в стиле Phosphor (как в приложении ТГПУ Профиль) */
type IconProps = { className?: string };

function Icon({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 256 256"
      width="24"
      height="24"
      fill="none"
      stroke="currentColor"
      strokeWidth="16"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      {children}
    </svg>
  );
}

export function TspuIconSchedule({ className }: IconProps) {
  return (
    <Icon className={className}>
      <rect x="40" y="48" width="176" height="176" rx="16" />
      <line x1="88" y1="24" x2="88" y2="72" />
      <line x1="168" y1="24" x2="168" y2="72" />
      <line x1="40" y1="104" x2="216" y2="104" />
      <line x1="88" y1="144" x2="168" y2="144" />
    </Icon>
  );
}

export function TspuIconGrades({ className }: IconProps) {
  return (
    <Icon className={className}>
      <path d="M128 24 L216 72 V152 C216 192 128 232 128 232 C128 232 40 192 40 152 V72 Z" />
      <polyline points="96,128 120,152 168,96" />
    </Icon>
  );
}

export function TspuIconPortfolio({ className }: IconProps) {
  return (
    <Icon className={className}>
      <path d="M48 64 H208 V208 H48 Z" />
      <polyline points="48,96 128,136 208,96" />
      <line x1="128" y1="136" x2="128" y2="208" />
    </Icon>
  );
}

export function TspuIconMoodle({ className }: IconProps) {
  return (
    <Icon className={className}>
      <path d="M88 208 C88 168 112 136 128 104 C144 136 168 168 168 208" />
      <path d="M64 208 H192" />
      <circle cx="128" cy="72" r="24" />
    </Icon>
  );
}

export function TspuIconCampus({ className }: IconProps) {
  return (
    <Icon className={className}>
      <path d="M32 120 L128 48 L224 120 V208 H32 Z" />
      <rect x="104" y="144" width="48" height="64" />
    </Icon>
  );
}

export function TspuIconMax({ className }: IconProps) {
  return (
    <Icon className={className}>
      <circle cx="128" cy="128" r="96" />
      <ellipse cx="128" cy="128" rx="40" ry="96" />
      <line x1="32" y1="128" x2="224" y2="128" />
    </Icon>
  );
}

export type TspuFeatureIcon =
  | 'schedule'
  | 'grades'
  | 'portfolio'
  | 'moodle'
  | 'campus'
  | 'max';

const map = {
  schedule: TspuIconSchedule,
  grades: TspuIconGrades,
  portfolio: TspuIconPortfolio,
  moodle: TspuIconMoodle,
  campus: TspuIconCampus,
  max: TspuIconMax,
} as const;

export function TspuFeatureIcon({ id, className }: { id: TspuFeatureIcon; className?: string }) {
  const C = map[id];
  return <C className={className} />;
}
