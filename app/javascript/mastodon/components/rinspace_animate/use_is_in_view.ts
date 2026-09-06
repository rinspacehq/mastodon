import { useEffect, useImperativeHandle, useRef, useState } from 'react';
import type { Ref } from 'react';

/**
 * Small app-owned boundary used by the pinned Animate UI text primitive. It
 * avoids creating an observer when in-view animation was not requested and
 * keeps the component usable in SSR and deterministic tests.
 */
export interface UseIsInViewOptions {
  inView?: boolean;
  inViewOnce?: boolean;
  inViewMargin?: string;
}

export function useIsInView<T extends HTMLElement = HTMLElement>(
  ref: Ref<T>,
  options: UseIsInViewOptions = {},
) {
  const { inView = false, inViewOnce = false, inViewMargin = '0px' } = options;
  const localRef = useRef<T>(null);
  const [observed, setObserved] = useState(false);
  useImperativeHandle(ref, () => localRef.current as T);

  useEffect(() => {
    const node = localRef.current;
    if (!inView || !node || typeof IntersectionObserver === 'undefined') {
      return undefined;
    }

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (!entry?.isIntersecting) return;
        setObserved(true);
        if (inViewOnce) observer.disconnect();
      },
      { rootMargin: inViewMargin },
    );
    observer.observe(node);
    return () => {
      observer.disconnect();
    };
  }, [inView, inViewMargin, inViewOnce]);

  return { ref: localRef, isInView: !inView || observed };
}
