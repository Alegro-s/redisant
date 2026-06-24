import { useEffect } from 'react';

/** Scroll-triggered reveal + overlap stacking for Club marketing sections. */
export function useClubScrollReveal() {
  useEffect(() => {
    const nodes = document.querySelectorAll<HTMLElement>('.club-scroll-stack > *');
    if (!nodes.length) return;

    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) {
            e.target.classList.add('club-in-view');
          }
        }
      },
      { rootMargin: '0px 0px -8% 0px', threshold: 0.12 },
    );

    nodes.forEach((n) => io.observe(n));
    return () => io.disconnect();
  }, []);
}
