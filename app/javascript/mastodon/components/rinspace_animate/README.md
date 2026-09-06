# Rinspace Animate UI adaptations

These application-specific components are based on the Animate UI catalog at
`imskyleen/animate-ui`, pinned to commit
`efeb96ffd7a3b7a4868667e4ac3c346620fb3044`.

The local components preserve Mastodon's application state and accessibility
ownership instead of copying an upstream demo composition:

- `button.tsx` and `icon_button.tsx` add intent feedback to existing actions;
- `theme_toggler.tsx` remains controlled by Mastodon's theme state;
- `dialog.tsx` supplies only overlay and entry presentation while Mastodon's
  modal root retains inert handling, focus, keyboard, history and Redux state;
- `splitting_text.tsx` is retained for approved non-brand placements; the
  Rinspace topbar brand text is deliberately static.

The source catalog's license and Commons Clause condition are reproduced in
[`LICENSE.md`](./LICENSE.md). These files are shipped only as adapted parts of
the Rinspace application, not as a standalone component-library product.
