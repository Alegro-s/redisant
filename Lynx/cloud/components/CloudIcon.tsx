/** Lynx Cloud brand mark — solid blue cloud. */
export function CloudIcon({ size = 28, className }: { size?: number; className?: string }) {
  return (
    <svg
      className={className ?? 'cloud-icon-svg'}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      aria-hidden
    >
      <path
        fill="#1a73e8"
        d="M19.35 10.04A5.49 5.49 0 0 0 18 4a6 6 0 0 0-11.31 2.04A4.5 4.5 0 0 0 3.5 15.5h16A4.5 4.5 0 0 0 19.35 10.04Z"
      />
    </svg>
  );
}
