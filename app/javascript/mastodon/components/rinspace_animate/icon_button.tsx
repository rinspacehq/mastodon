import { forwardRef } from 'react';
import type { ButtonHTMLAttributes, ReactNode } from 'react';

import { motion, useReducedMotion } from 'motion/react';
import type { HTMLMotionProps } from 'motion/react';

export interface AnimateIconButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  active?: boolean;
  icon: ReactNode;
  label: string;
}

/** Intent animation derived from Animate UI's animated Lucide control pattern. */
export const AnimateIconButton = forwardRef<
  HTMLButtonElement,
  AnimateIconButtonProps
>(function AnimateIconButton(
  { active, className = '', icon, label, type = 'button', ...props },
  ref,
) {
  const reducedMotion = useReducedMotion();
  const isActive = active ?? false;
  const motionProps = props as Omit<HTMLMotionProps<'button'>, 'children'>;
  return (
    <motion.button
      ref={ref}
      aria-label={label}
      aria-pressed={active}
      className={`rin-animate-icon-button ${className}`.trim()}
      data-active={isActive || undefined}
      type={type}
      whileHover={reducedMotion ? undefined : 'hover'}
      whileTap={reducedMotion ? undefined : 'tap'}
      initial={false}
      {...motionProps}
    >
      <motion.span
        aria-hidden='true'
        variants={{
          hover: { rotate: isActive ? -6 : 6, scale: 1.08 },
          tap: { scale: 0.86 },
        }}
        transition={
          reducedMotion
            ? { duration: 0 }
            : { type: 'spring', stiffness: 520, damping: 28 }
        }
      >
        {icon}
      </motion.span>
    </motion.button>
  );
});
