import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { AnimateDialogLayer } from './dialog';

describe('AnimateDialogLayer', () => {
  it.each(['standard', 'immersive'] as const)(
    'keeps Mastodon dialog semantics in %s mode',
    (mode) => {
      const onOverlayClick = vi.fn();
      const { container } = render(
        <AnimateDialogLayer
          backgroundColor='rgb(1, 2, 3)'
          mode={mode}
          onOverlayClick={onOverlayClick}
        >
          <button type='button'>Keep the existing action</button>
        </AnimateDialogLayer>,
      );

      expect(
        screen.getByRole('dialog').getAttribute('data-rinspace-dialog-mode'),
      ).toBe(mode);
      expect(screen.getByRole('button').textContent).toBe(
        'Keep the existing action',
      );

      const overlay = container.querySelector('[data-slot="dialog-overlay"]');
      if (!overlay) throw new Error('Dialog overlay was not rendered');
      expect(overlay.getAttribute('data-rinspace-animate-ui')).toBe('dialog');
      fireEvent.click(overlay);
      expect(onOverlayClick).toHaveBeenCalledOnce();
    },
  );
});
