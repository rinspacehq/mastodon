import type { Meta, StoryObj } from '@storybook/react-vite';

import { accountFactoryImmutable } from '@/testing/factories';

import { RedesignNavigationPanel } from '.';

const meta = {
  title: 'Redesign/NavigationPanel',
  component: RedesignNavigationPanel,
  render(args) {
    return (
      <div
        style={{
          width: 320,
          height: 600,
          backgroundColor: 'var(--color-bg-blend)',
        }}
      >
        <RedesignNavigationPanel {...args} />
      </div>
    );
  },
  args: {
    siteName: 'Site name',
  },
  parameters: {
    redesign: true,
    state: {
      accounts: {
        '123': accountFactoryImmutable(),
      },
    },
  },
} satisfies Meta<typeof RedesignNavigationPanel>;

export default meta;

type Story = StoryObj<typeof meta>;

export const Default: Story = {};
