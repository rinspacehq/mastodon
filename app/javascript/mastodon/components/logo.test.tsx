import { IntlProvider } from 'react-intl';

import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import { WordmarkLogo } from './logo';

describe('WordmarkLogo', () => {
  it.each([
    ['en', 'Rinspace'],
    ['zh-CN', '芥子环'],
  ])('uses the localized Rinspace brand name for %s', (locale, brandName) => {
    render(
      <IntlProvider
        locale={locale}
        messages={{ 'rinspace.world.brand_name': brandName }}
      >
        <WordmarkLogo />
      </IntlProvider>,
    );

    expect(screen.getByTitle(brandName)).toBeTruthy();
    expect(screen.getAllByText(brandName)).toHaveLength(2);
  });
});
