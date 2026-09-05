import api from 'mastodon/api';

const observed = new WeakSet<Element>();
const timers = new WeakMap<Element, number>();
const sent = new Set<string>();

function sessionId(): string {
  const existing = sessionStorage.getItem('rinspace.viewSession');
  if (existing) return existing;
  const value = crypto.randomUUID();
  sessionStorage.setItem('rinspace.viewSession', value);
  return value;
}

function sendView(element: Element): void {
  const statusId = element.getAttribute('data-rinspace-status-id');
  if (!statusId || sent.has(statusId) || document.visibilityState !== 'visible') return;
  sent.add(statusId);
  void api().post(`/api/v1/statuses/${statusId}/view`, {
    sessionId: sessionId(),
    recommendationSignal: localStorage.getItem('rinspace.homeFeed') === 'recommended',
  }).catch(() => sent.delete(statusId));
}

function observe(root: ParentNode, intersectionObserver: IntersectionObserver): void {
  for (const element of root.querySelectorAll('[data-rinspace-status-id]')) {
    if (!observed.has(element)) {
      observed.add(element);
      intersectionObserver.observe(element);
    }
  }
}

export function startRinspaceViewTracking(): void {
  if (!('IntersectionObserver' in window) || !('MutationObserver' in window)) return;

  const intersectionObserver = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        const pending = timers.get(entry.target);
        if (entry.isIntersecting && entry.intersectionRatio >= 0.5 && document.visibilityState === 'visible') {
          if (!pending) {
            timers.set(entry.target, window.setTimeout(() => {
              sendView(entry.target);
            }, 1000));
          }
        } else if (pending) {
          window.clearTimeout(pending);
          timers.delete(entry.target);
        }
      }
    },
    { threshold: [0, 0.5, 1] },
  );

  observe(document, intersectionObserver);
  new MutationObserver((records) => {
    for (const record of records) {
      for (const node of record.addedNodes) {
        if (node instanceof Element) {
          if (node.matches('[data-rinspace-status-id]') && !observed.has(node)) {
            observed.add(node);
            intersectionObserver.observe(node);
          }
          observe(node, intersectionObserver);
        }
      }
    }
  }).observe(document.body, { childList: true, subtree: true });
}
