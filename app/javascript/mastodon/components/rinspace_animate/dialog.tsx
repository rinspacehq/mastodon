import type { CSSProperties, FC, ReactNode } from 'react';

import { motion, useReducedMotion } from 'motion/react';

export type AnimateDialogMode = 'standard' | 'immersive';

interface AnimateDialogLayerProps {
  backgroundColor: CSSProperties['backgroundColor'];
  children: ReactNode;
  mode?: AnimateDialogMode;
  onOverlayClick: () => void;
}

/**
 * Animate UI Dialog presentation adapted for Mastodon's existing modal root.
 *
 * Source basis: imskyleen/animate-ui@efeb96ffd7a3b7a4868667e4ac3c346620fb3044,
 * `primitives/radix/dialog`. Mastodon continues to own inert handling, focus,
 * Escape/Tab behavior, history buffering and the Redux modal lifecycle.
 */
export const AnimateDialogLayer: FC<AnimateDialogLayerProps> = ({
  backgroundColor,
  children,
  mode = 'standard',
  onOverlayClick,
}) => {
  const reducedMotion = useReducedMotion();
  const standard = mode === 'standard';
  const overlayOpacity = backgroundColor ? 0.9 : 1;

  return (
    <div style={{ pointerEvents: 'auto' }}>
      <motion.div
        role='presentation'
        className='modal-root__overlay'
        data-slot='dialog-overlay'
        data-rinspace-animate-ui='dialog'
        initial={reducedMotion ? false : { opacity: 0, filter: 'blur(4px)' }}
        animate={{ opacity: overlayOpacity, filter: 'blur(0px)' }}
        transition={{ duration: reducedMotion ? 0 : 0.2, ease: 'easeInOut' }}
        onClick={onOverlayClick}
        style={{ backgroundColor }}
      />
      <motion.div
        role='dialog'
        className='modal-root__container'
        data-slot='dialog-content'
        data-rinspace-animate-ui='dialog'
        data-rinspace-dialog-mode={mode}
        initial={
          reducedMotion
            ? false
            : {
                opacity: 0,
                filter: standard ? 'blur(3px)' : 'blur(1px)',
                y: standard ? 10 : 0,
              }
        }
        animate={{ opacity: 1, filter: 'blur(0px)', y: 0 }}
        transition={
          reducedMotion
            ? { duration: 0 }
            : standard
              ? { type: 'spring', stiffness: 280, damping: 28 }
              : { duration: 0.16, ease: 'easeOut' }
        }
      >
        {children}
      </motion.div>
    </div>
  );
};
