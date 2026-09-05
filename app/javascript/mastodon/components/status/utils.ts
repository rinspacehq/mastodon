import type { AccountStatusShape, StatusShape } from '@/mastodon/models/status';
import { statusPath } from '@/mastodon/utils/status_path';

export function statusLink({
  id,
}: Pick<StatusShape | AccountStatusShape, 'id'>) {
  return statusPath({ id, url: null });
}
