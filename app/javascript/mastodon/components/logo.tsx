import type React from 'react';

import { useIntl } from 'react-intl';

import classNames from 'classnames';

import rinspaceMark from '@/images/rinspace-mark-128.png';

const brandNameMessage = {
  id: 'rinspace.world.brand_name',
  defaultMessage: 'Rinspace',
};

export const WordmarkLogo: React.FC = () => {
  const intl = useIntl();
  const brandName = intl.formatMessage(brandNameMessage);

  return (
    <svg viewBox='0 0 261 66' className='logo logo--wordmark' role='img'>
      <title>{brandName}</title>
      <image href={rinspaceMark} x='2' y='4' width='58' height='58' />
      <text
        x='72'
        y='44'
        fill='currentColor'
        fontFamily='Georgia, Noto Serif SC, serif'
        fontSize='34'
        fontWeight='700'
      >
        {brandName}
      </text>
    </svg>
  );
};

export const IconLogo: React.FC<React.ComponentPropsWithRef<'svg'>> = ({
  className,
  role = 'img',
  ...otherProps
}) => (
  <svg
    viewBox='0 0 79 79'
    className={classNames('logo logo--icon', className)}
    role={role}
    {...otherProps}
  >
    {role !== 'presentation' && <title>Rinspace</title>}
    <image href={rinspaceMark} width='79' height='79' />
  </svg>
);

export const SymbolLogo: React.FC = () => (
  <img src={rinspaceMark} alt='Rinspace' className='logo logo--icon' />
);
