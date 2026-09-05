# Rinspace strict local-only boundary

Rinspace phase one uses Mastodon as a local community engine, not as a federated server. Mastodon's upstream limited-federation mode is an allow-list federation mode; it is not a zero-federation control. This fork therefore enforces a separate gate that ordinary administrators cannot enable or disable.

## Enforced layers

- **Edge:** known ActivityPub, WebFinger, NodeInfo, relay, FASP and remote-interaction paths, plus ActivityStreams content negotiation, return a non-cacheable `404` before Rails.
- **Application:** Rack repeats the ingress block. Remote account/status resolution, URL fetching, FASP search, remote search results and remote public feeds fail closed. The shared HTTP client rejects every non-local destination; approved non-federation services must use a separately allow-listed egress proxy.
- **Workers:** federation delivery and resolver jobs are discarded both when enqueued and before execution. Direct delivery execution contains a second guard.
- **Network:** the example Kubernetes policy permits DNS and named in-namespace data services only. The sole external route is a destination-filtering egress proxy.

`RINSPACE_LOCAL_ONLY` defaults to `true` outside tests. A false production or development value aborts boot. Tests default it to false so the upstream suite remains meaningful; Rinspace negative specs explicitly turn it on.

## Zero-baseline release gate

Run:

```sh
RINSPACE_LOCAL_ONLY=true bundle exec rake rinspace:local_only:audit
```

The audit fails if the gate is off or if any remote account, remote status, relay, FASP provider or blocked background job exists. Existing federated data must be handled by a separately approved migration; this task does not delete it.

The structured events `rinspace.local_only.blocked` and `rinspace.local_only.blocked.metric` contain only layer/source and a query-free target. Alert on any event in production. Useful layers are `inbound`, `outbound`, `application`, `queue` and `delivery`. The expected rate is exactly zero after edge and egress controls are active; a non-zero event means an outer control failed and should close community traffic.

## Negative verification

- ActivityStreams requests to ordinary profile paths return `404` while HTML profile requests continue to work.
- federation discovery and protocol namespaces return `404` at both edge and Rack layers.
- remote handle and URL searches do not perform HTTP requests or return cached remote records.
- local/public/tag/link feeds contain only local statuses; explicitly remote feeds are empty.
- FASP and federation delivery/resolver jobs never enter or execute from Sidekiq.
- the application HTTP client cannot connect to a public host in strict mode.

REST and streaming are additionally protected by the zero-remote-data release audit. A release must not rely on filtering every serializer after remote records have already entered the database.

## Rollback and future federation

Rollback is the previous complete immutable stack release: application, workers, edge and egress policy together. Never disable just one layer. Enabling federation is intentionally not an environment-only operation; it requires a new specification, threat/legal review, code changes, migration plan and production authorization.
