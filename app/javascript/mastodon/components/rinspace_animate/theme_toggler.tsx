import { Moon, Sun } from 'lucide-react';
import { AnimatePresence, motion, useReducedMotion } from 'motion/react';

import { AnimateIconButton } from './icon_button';

/** Controlled adaptation of pinned Animate UI Theme Toggler; storage remains app-owned. */
export const AnimateThemeToggler = ({
  resolved,
  onToggle,
  label,
  className = '',
}: {
  resolved: 'light' | 'dark';
  onToggle: () => void;
  label: string;
  className?: string;
}) => {
  const reducedMotion = useReducedMotion();
  return (
    <AnimateIconButton
      className={className}
      icon={
        <AnimatePresence initial={false} mode='wait'>
          <motion.span
            key={resolved}
            initial={
              reducedMotion ? false : { opacity: 0, rotate: -70, scale: 0.65 }
            }
            animate={{ opacity: 1, rotate: 0, scale: 1 }}
            exit={
              reducedMotion
                ? { opacity: 1 }
                : { opacity: 0, rotate: 70, scale: 0.65 }
            }
            transition={{ duration: reducedMotion ? 0 : 0.16 }}
          >
            {resolved === 'light' ? <Moon /> : <Sun />}
          </motion.span>
        </AnimatePresence>
      }
      label={label}
      onClick={onToggle}
    />
  );
};
