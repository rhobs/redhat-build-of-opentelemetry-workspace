# Regression Detection Report

## Metadata

| Field | Value |
|---|---|
| Downstream base | operator `7fb513848c6d4ea79b277352fc13ce11eb734b1a` (v0.158.0), collector `v0.158.0` |
| Upstream target | origin/main (latest release: v0.163.0) |
| Release branch | rhosdt-0.158 |
| Components in build | 58 |
| Documented components | 54 |
| Critical | 14 |
| High | 20 |
| Medium | 30 |
| Low | 23 |
| Total | 87 |

## Contents

- [Critical (14)](#critical)
- [High (20)](#high)
- [Medium (30)](#medium)
- [Low (23)](#low)
- [Confirmed Coverage Gaps](#confirmed-coverage-gaps)
- [Skill Improvement Recommendations](#skill-improvement-recommendations)

## Critical

#### CRIT-1 — Deprecated confighttp keepalive keys removed from client and server config

| Field | Value |
|---|---|
| Category | REMOVED_API |
| Component | confighttp (core): all HTTP receivers/exporters (otlp http, otlphttp, jaeger, zipkin, prometheusremotewrite, ...) |
| Component type | core |
| Detection methods | changelog, code-diff, feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector/pull/15973 |
| Affected config fields | idle_conn_timeout, max_idle_conns, max_idle_conns_per_host, disable_keep_alives, idle_timeout, keep_alives_enabled, keepalive |
| Has test coverage | true |

Description: Core PR #15973 (v0.165.0) removed the flat client keys idle_conn_timeout, max_idle_conns, max_idle_conns_per_host and disable_keep_alives, which were deprecated in v0.160.0. The code diff shows the server keys idle_timeout and keep_alives_enabled are gone from the generated structs too, so any of these old keys now fails with 'has invalid keys' at startup. The new keepalive: sub-block (client: enabled, idle_conn_timeout, max_idle_conns, max_idle_conns_per_host; server: enabled, idle_timeout) is the only way to set them. The new pkg.confighttp.PrioritizeNewKeepalive gate was registered directly as Stable (v0.162.0), which makes keepalive the default and cannot be turned off. Core also added the Alpha gate pkg.exporterhelper.queueBatchEnabled; promoting it would turn on exporter batching by default.

Recommended action: Release-note as breaking. Move docs, examples and customer-facing CR samples to keepalive.*. Consider an operator webhook warning or a config migration that rewrites the legacy keys. Track pkg.exporterhelper.queueBatchEnabled.

#### CRIT-2 — resource_to_telemetry_conversion disabled by default (new DisableResourceToTelemetryConversion gate added as Beta)

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | prometheusexporter |
| Component type | exporter |
| Detection methods | changelog, code-diff, feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/52937 |
| Affected config fields | resource_to_telemetry_conversion, resource_constant_labels, sending_queue |
| Has test coverage | true |

Description: The new gate exporter.prometheus.DisableResourceToTelemetryConversion is Beta, so it is on by default. With it on, Config.Validate returns an error whenever resource_to_telemetry_conversion is set and tells users to use resource_constant_labels (included/excluded patterns) instead. The product docs (otel-exporters-prometheus-exporter.adoc and otel-config-send-metrics-monitoring-stack.adoc) configure resource_to_telemetry_conversion.enabled: true, so collectors that follow them will fail to start. sending_queue is also deprecated, behind the Alpha gate DisableSendingQueue. The changelog still lists this as a pending entry, but the code is already on main.

Recommended action: Before the rebase, move docs and examples to resource_constant_labels (included: ['*']), or ship with --feature-gates=-exporter.prometheus.DisableResourceToTelemetryConversion and add a release note. Add an e2e test that uses the documented monitoring-stack config.

#### CRIT-3 — add_metric_suffixes now always ignored; DisableAddMetricSuffixes gate is Stable

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | prometheusexporter |
| Component type | exporter |
| Detection methods | code-diff, feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/52937 |
| Affected config fields | add_metric_suffixes, translation_strategy |
| Has test coverage | true |

Description: The gate exporter.prometheusexporter.DisableAddMetricSuffixes moved from Beta to Stable (to be removed in v0.167.0), and disabling it is a startup error. add_metric_suffixes: false no longer has any effect, because translation_strategy alone now controls metric naming. Users who relied on the old flag will see their exported metric names change.

Recommended action: Release-note as breaking. Remove add_metric_suffixes from the docs and tell users to set translation_strategy explicitly.

#### CRIT-4 — extract.deployment_name_from_replicaset removed (startup failure); duplicate pod associations rejected

| Field | Value |
|---|---|
| Category | REMOVED_API |
| Component | k8sattributesprocessor |
| Component type | processor |
| Detection methods | changelog, code-diff |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/45871 |
| Affected config fields | extract.deployment_name_from_replicaset, pod_association, exclude.pods, kubelet |
| Has test coverage | true |

Description: v0.160.0 removed the deprecated deployment_name_from_replicaset key; the behavior it controlled is now always on. Configs that still set the key, to true or false, fail at startup with an unknown-key error. Validate() now also rejects duplicate pod_association entries (order does not matter) and invalid exclude.pods regexes. Additions: a kubelet block (gated by EnableKubeletPodSource), new extract 'from' values replicaset and cronjob, and semconv 1.44.

Recommended action: Search docs, operator-generated configs and samples for deployment_name_from_replicaset and for duplicate associations. Add an upgrade note.

#### CRIT-5 — k8sattributes emits stable k8s semconv names by default (EmitV1K8sConventions/DontEmitV0K8sConventions now Beta)

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | k8sattributesprocessor |
| Component type | processor |
| Detection methods | changelog, feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/49152 |
| Affected config fields | extract.labels, extract.annotations |
| Has test coverage | true |

Description: In v0.161.0 both gates moved from Alpha to Beta, so they are on by default. Legacy attribute names such as k8s.pod.labels.* are no longer emitted; k8s.pod.label.* is emitted instead. Dashboards, routing rules, filter rules and console plugin queries keyed on the legacy names will silently stop matching.

Recommended action: Add a release note and update the docs. Verify the console plugin and Tempo/Loki queries against the new names. Document dual emission as a migration step (--feature-gates=-processor.k8sattributes.DontEmitV0K8sConventions) and the full opt-out flags.

#### CRIT-6 — ordering_criteria.top_n: 0 now means all files; filelog.protobufCheckpointEncoding gate promoted to Stable then removed

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | filelogreceiver |
| Component type | receiver |
| Detection methods | changelog, feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/52388 |
| Affected config fields | ordering_criteria.top_n, ordering_criteria.sort_by, storage |
| Has test coverage | true |

Description: v0.159.0: top_n: 0 now matches all files instead of behaving like 1, and the implicit top_n default with sort_by is deprecated (Alpha gate filelog.requireExplicitTopN). v0.164.0: checkpoints are always written as protobuf. Existing JSON checkpoints are read and rewritten, so an older collector cannot read them after a downgrade. v0.165.0 removed the gate, so --feature-gates references to filelog.protobufCheckpointEncoding now fail.

Recommended action: Document the new top_n semantics and the one-way checkpoint migration (no rollback with the same file_storage). Test the upgrade with existing checkpoints. Remove the gate from any shipped flags, CRs and examples.

#### CRIT-7 — OTTL gates removed, Base64Decode removed, set() writes nil, stricter parse-time validation

| Field | Value |
|---|---|
| Category | REMOVED_API |
| Component | transformprocessor / filterprocessor / routingconnector (pkg/ottl) |
| Component type | processor |
| Detection methods | changelog, feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/51089 |
| Affected config fields | error_mode, statements |
| Has test coverage | true |

Description: Removed gates: ottl.PanicDuplicateName and ottl.contexts.enableOTelColContext (both Beta at base), and processor.transform.defaultErrorModeIgnore and processor.filter.defaultErrorModeIgnore (both Stable at base). Any --feature-gates flag that names them now fails startup. Base64Decode was removed in v0.161.0; use Decode(..., "base64"). ottl.set.allowNil went to Stable and was then removed, so set(x, nil) now writes nil instead of doing nothing. Parse-time validation is stricter for slice arguments, lists and lambdas, so statements that used to load may now fail at startup. The With*FunctionsNew factory options were removed from the Go API.

Recommended action: Make sure the operator, docs and examples set none of the removed gates and do not use Base64Decode. Release-note the change in set() nil semantics and the stricter validation.

#### CRIT-8 — flatten_data removed, replaced by flatten.log

| Field | Value |
|---|---|
| Category | REMOVED_API |
| Component | transformprocessor |
| Component type | processor |
| Detection methods | code-diff, changelog |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/52440 |
| Affected config fields | flatten_data, flatten.log |
| Has test coverage | true |

Description: #51766 replaced flatten_data with flatten: {log: true}, and #52440 (v0.165.0) removed the deprecated option. Configs that still use flatten_data fail with an unknown-key error.

Recommended action: Release-note the removal. Update the docs to flatten.log, which still requires the transform.flatten.logs gate.

#### CRIT-9 — Default error_mode permanently ignore (defaultErrorModeIgnore Stable); OTTL parsed in Validate

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | routingconnector |
| Component type | connector |
| Detection methods | code-diff, feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/52352 |
| Affected config fields | error_mode, table |
| Has test coverage | true |

Description: connector.routing.defaultErrorModeIgnore moved from Beta to Stable (removal in v0.166.0), so the default error_mode is now always ignore instead of propagate and cannot be reverted. The product doc otel-connectors-routing-connector.adoc still says 'The default is propagate'. Config.Validate now parses all routing OTTL statements, so invalid statements fail during config validation.

Recommended action: Update the routing connector docs to say the default is ignore. Users who rely on propagate must set error_mode: propagate explicitly. Add a release note.

#### CRIT-10 — PermissiveLabelSanitization goes from Alpha to Stable: labels with leading or consecutive underscores preserved

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | prometheusexporter / prometheusremotewriteexporter / prometheusreceiver (pkg/translator/prometheus) |
| Component type | exporter |
| Detection methods | changelog, feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/52206 |
| Affected config fields | — |
| Has test coverage | true |

Description: The gate was Alpha at v0.158.0, moved to Beta in v0.162.0 and became Stable in v0.164.0, so it goes from off to permanently on in a single rebase. Labels like _foo are no longer rewritten to key_foo, which changes series identity for existing PromQL queries, recording rules and alerts. Disabling the gate is now a startup error.

Recommended action: Release-note the label name change. Remove -pkg.translator.prometheus.PermissiveLabelSanitization from any configured flags. Check dashboards and alerts that use key_-prefixed labels, and add a regression test that compares label output before and after.

#### CRIT-11 — IgnoreScopeInfoMetric gate removed; __scheme__/__metrics_path__ labels kept as attributes

| Field | Value |
|---|---|
| Category | REMOVED_API |
| Component | prometheusreceiver |
| Component type | receiver |
| Detection methods | changelog, feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/52201 |
| Affected config fields | — |
| Has test coverage | true |

Description: receiver.prometheusreceiver.IgnoreScopeInfoMetric was Beta at base, became Stable and was then removed. Scope attributes now come only from otel_scope_-prefixed labels, and --feature-gates=-receiver.prometheusreceiver.IgnoreScopeInfoMetric fails at startup. From v0.165.0, __scheme__ and __metrics_path__ are no longer dropped from datapoint attributes, which adds attributes and changes cardinality and series identity. Keepalive is also on by default for scrape clients.

Recommended action: Release-note the change. Test the TargetAllocator plus prometheusreceiver flow. Recommend metric_relabel_configs or a transform to drop the new attributes, and remove the gate flag.

#### CRIT-12 — Zipkin and Jaeger translators emit new semconv attribute names by default

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | zipkinreceiver / jaegerreceiver (pkg/translator/zipkin, pkg/translator/jaeger) |
| Component type | receiver |
| Detection methods | changelog, feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/52251 |
| Affected config fields | — |
| Has test coverage | true |

Description: Zipkin network conventions are now Stable and cannot be disabled: network.local.address, network.peer.address and service.peer.name replace net.host.ip, net.peer.ip and peer.service. The Zipkin HTTP, Scope and CloudResource gates moved from Alpha to Beta, so http.response.status_code, otel.scope.name/version and cloud.resource_id replace the old keys by default. The Jaeger EmitV1HttpConventions and DontEmitV0HttpConventions gates moved from Alpha to Beta, so http.response.status_code replaces http.status_code.

Recommended action: Release-note the renames. Check Tempo and console queries and spanmetrics dimensions that use peer.service, net.peer.ip or http.status_code. Document the rollback flags for the gates that are still Beta.

#### CRIT-13 — Kafka Receiver doc uses removed top-level `topic` field

| Field | Value |
|---|---|
| Category | DOC_STALE |
| Component | kafkareceiver |
| Component type | receiver |
| Detection methods | doc-validation |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/46232 |
| Affected config fields | topic, traces.topics, metrics.topics, logs.topics, profiles.topics, <signal>.exclude_topics |
| Has test coverage | true |

Description: otel-receivers-kafka-receiver.adoc shows a top-level topic: otlp_spans. That field was removed in v0.147.0 (#46232); topics are now set per signal with <signal>.topics and <signal>.exclude_topics. The shipped v0.158.0 already rejects the documented config.

Recommended action: Replace the example with traces: {topics: [otlp_spans], encoding: otlp_proto} and the matching entries for the other signals. Document per-signal topics and exclude_topics, and backport the fix to the docs for the current 0.158 release.

#### CRIT-14 — Kafka Exporter doc uses removed top-level `topic` field

| Field | Value |
|---|---|
| Category | DOC_STALE |
| Component | kafkaexporter |
| Component type | exporter |
| Detection methods | doc-validation |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/46917 |
| Affected config fields | topic, traces.topic, metrics.topic, logs.topic, profiles.topic |
| Has test coverage | true |

Description: otel-exporters-kafka-exporter.adoc shows a top-level topic. That field was removed in v0.148.0 (#46917) and is now <signal>.topic. The shipped v0.158.0 already rejects the documented config. The doc also wrongly describes the field as the 'topic to read from'.

Recommended action: Move topic under traces:, metrics: and logs: in the example, and change the description to 'topic to write to'.

## High

#### HIGH-1 — CPU usage computed from cpu.time rate (cpuUsageScrapeBased Beta); deprecated resource attributes removed

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | kubeletstatsreceiver |
| Component type | receiver |
| Detection methods | changelog, feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/50789 |
| Affected config fields | metrics.k8s.pod.cpu.node.utilization, resource_attributes |
| Has test coverage | true |

Description: receiver.kubeletstats.cpuUsageScrapeBased moved from Alpha to Beta. cpu.usage and the utilization metrics derived from it are now rates of *.cpu.time, so values change and the first scrape reports no data point. v0.164.0 removed the resource attributes aws.volume.id, fs.type, gce.pd.name, glusterfs.* and partition. v0.162.0 deprecated the *.node.utilization metrics.

Recommended action: Release-note the change. Re-verify kubeletstats dashboards and e2e assertions. Offer --feature-gates=-receiver.kubeletstats.cpuUsageScrapeBased as a rollback.

#### HIGH-2 — Kafka config cleanup: deprecated auth and client options removed; SASL+Kerberos rejected; metadata retry honored

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | kafkareceiver / kafkaexporter |
| Component type | receiver |
| Detection methods | changelog |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/50381 |
| Affected config fields | auth.tls, auth.plain_text, auth.sasl.version, group_rebalance_strategy, resolve_canonical_bootstrap_servers_only, metadata.retry.max, encoding, partition_processing.max_buffered_batches |
| Has test coverage | — |

Description: v0.160.0 removed auth.tls, auth.plain_text, auth.sasl.version, group_rebalance_strategy and resolve_canonical_bootstrap_servers_only. v0.161.0 rejects configs that set both auth.sasl and auth.kerberos. v0.162.0 applies metadata.retry, with the default raised to 20. v0.164.0 deprecated the jaeger_proto, jaeger_json and json encodings and partition_processing.max_buffered_batches.

Recommended action: Update the Kafka docs and examples to use top-level tls and group_rebalance_strategies. Flag the encoding deprecation.

#### HIGH-3 — Kafka Receiver doc uses removed `auth.plain_text`

| Field | Value |
|---|---|
| Category | DOC_STALE |
| Component | kafkareceiver |
| Component type | receiver |
| Detection methods | doc-validation |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/50202 |
| Affected config fields | auth.plain_text, auth.sasl.mechanism, auth.sasl.username, auth.sasl.password |
| Has test coverage | true |

Description: The doc uses auth.plain_text.{username,password}, which was removed from configkafka in v0.160.0 (#50202). v0.158.0 still accepts it, so the documented config breaks on the next rebase.

Recommended action: Replace it with auth.sasl and mechanism: PLAIN, and document the supported SASL mechanisms. Do this before the rebase to 0.160 or later.

#### HIGH-4 — Kafka Exporter doc uses removed `auth.plain_text`

| Field | Value |
|---|---|
| Category | DOC_STALE |
| Component | kafkaexporter |
| Component type | exporter |
| Detection methods | doc-validation |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/50202 |
| Affected config fields | auth.plain_text, auth.sasl |
| Has test coverage | true |

Description: otel-exporters-kafka-exporter.adoc uses auth.plain_text, which was removed from pkg/kafka/configkafka in v0.160.0 (#50202).

Recommended action: Switch the example to auth.sasl with mechanism: PLAIN.

#### HIGH-5 — Operator and operand NetworkPolicies disabled by default (gates demoted from Beta to Alpha)

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | opentelemetry-operator |
| Component type | operator |
| Detection methods | changelog, feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-operator/pull/5664 |
| Affected config fields | — |
| Has test coverage | false |

Description: In 0.160.0, operator.networkpolicy and operand.networkpolicy moved back to Alpha because the generated policies could block access to the API server. After an upgrade, clusters that relied on these policies will no longer have them, which reverses a security-hardening default. 0.161.0 also needs a watch permission on discovery.k8s.io endpointslices.

Recommended action: Decide the downstream default in the CSV args, for example --feature-gates=+operator.networkpolicy,+operand.networkpolicy. Update the RBAC, specs, docs and e2e tests that expect NetworkPolicies.

#### HIGH-6 — --create-rbac-permissions flag removed; RBAC escalation check covers namespaced rules; OpAMP Bridge IDs change

| Field | Value |
|---|---|
| Category | REMOVED_API |
| Component | opentelemetry-operator |
| Component type | operator |
| Detection methods | changelog, code-diff |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-operator/pull/5721 |
| Affected config fields | --create-rbac-permissions |
| Has test coverage | true |

Description: PR #5721 removed the deprecated flag, and RBAC creation is now always autodetected. A deployment that still passes the flag fails to start. The webhook's privilege-escalation check now also covers namespaced Role and RoleBinding rules (k8sattributes filter.namespace), so non-admin users may be denied when they create collectors. OpAMP Bridge instance IDs are now derived from the cluster ID, and the bridge needs get on the kube-system namespace. The pod-mutation webhook RBAC adds batch/cronjobs.

Recommended action: Check that the downstream CSV and bundle do not pass the flag. Add the kube-system get permission for the OpAMP Bridge. Test collector creation by non-admin users with k8sattributes filter.namespace, and add a release note.

#### HIGH-7 — TargetAllocator filterStrategy became a pointer; new 'none' value; explicit empty string preserved; invalid values rejected

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | opentelemetry-operator (target allocator) |
| Component type | operator |
| Detection methods | changelog, code-diff |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-operator/pull/5462 |
| Affected config fields | spec.targetAllocator.filterStrategy, spec.filterStrategy, allocation_fallback_strategy |
| Has test coverage | true |

Description: FilterStrategy is now a pointer in the Go API. The CRD schema stays compatible, but Go consumers such as multicluster-observability-addon may break at compile time. The enum is now "", none and relabel-config. An explicit "" used to be lost during reconciliation; it is now preserved and disables filtering. The TA rejects unknown values at startup. allocation_fallback_strategy is deprecated in favor of allocation_strategy_config.per_node.fallback_strategy.name.

Recommended action: Check downstream Go consumers for compile breakage. Release-note the behavior for users who set "" (recommend 'none'), and update the TA docs.

#### HIGH-8 — NodeJS auto-instrumentation upgrades blocked across 0.79.0 (breaking semconv changes)

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | opentelemetry-operator (auto-instrumentation NodeJS) |
| Component type | auto_instrumentation |
| Detection methods | changelog, issues |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-operator/pull/5778 |
| Affected config fields | spec.nodejs.image |
| Has test coverage | true |

Description: Since 0.162.0 (#5778), the operator does not automatically upgrade NodeJS instrumentation across 0.79.0, because that version changes the HTTP, network and DB semantic conventions. Users have to set spec.nodejs.image manually. 0.163.0 also blocks upgrades to breaking versions when images are pinned by digest. The default agent version was then bumped to v0.82.0 and later.

Recommended action: Check which NodeJS image the product ships and how existing Instrumentation CRs upgrade. Add release notes with migration guidance.

#### HIGH-9 — Redaction summary attribute ownership changed for chained processors; md5/sha1 rejected in FIPS mode

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | redactionprocessor |
| Component type | processor |
| Detection methods | changelog, code-diff |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/50770 |
| Affected config fields | summary, allow_all_keys, allowed_keys, hash_function, masking_string |
| Has test coverage | true |

Description: Since v0.163.0, a processor whose summary is not debug or info no longer protects summary attributes set by an upstream processor, so a downstream processor with allow_all_keys: false removes them. A body key named after a summary attribute is now redacted. Since v0.165.0, Validate rejects hash_function md5 or sha1 in FIPS 140-3 mode, which matters on FIPS OpenShift. There is also a new masking_string field.

Recommended action: Add a release note for chained redaction setups. Document that md5/sha1 are unavailable under FIPS, and add a FIPS test case.

#### HIGH-10 — HTTP server timeout and keepalive overrides removed; confighttp defaults now apply

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | jaegerreceiver / zipkinreceiver / prometheusremotewritereceiver / healthcheckextension / jaegerremotesampling |
| Component type | receiver |
| Detection methods | changelog, code-diff |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/51211 |
| Affected config fields | write_timeout, read_header_timeout, keepalive, idle_timeout, keep_alives_enabled |
| Has test coverage | true |

Description: These factories used to force WriteTimeout=0, ReadHeaderTimeout=0, IdleTimeout=0 and keepalive off. Since v0.162.0 they use the confighttp defaults: write_timeout 30s, read_header_timeout 1m, keepalive on with a 1m idle timeout. Slow or long-running requests may now be cut off at 30s. The prometheusreceiver's TA HTTP client no longer forces its old connection settings either.

Recommended action: Release-note the change. Verify Jaeger thrift HTTP, Zipkin and PRW ingestion under load, including behind Routes and load balancers. Document how to restore the old values.

#### HIGH-11 — Top-level sending_queue enabled by default

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | loadbalancingexporter |
| Component type | exporter |
| Detection methods | code-diff |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/51829 |
| Affected config fields | sending_queue, routing_key |
| Has test coverage | true |

Description: The default config changed from configoptional.Default to configoptional.Some, so the exporter now queues by default (queue_size 1000, 10 consumers) on top of the per-backend OTLP exporter settings. This changes memory use and delivery semantics. A new routing_key 'randomness' was also added.

Recommended action: Release-note the change. Validate tail-sampling and load-balancing topologies, and document sending_queue.enabled: false to restore the old behavior.

#### HIGH-12 — Exporter-helper batching enabled by default

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | awscloudwatchlogsexporter |
| Component type | exporter |
| Detection methods | code-diff |
| Upstream PR | — |
| Affected config fields | sending_queue.batch, max_event_payload_bytes |
| Has test coverage | true |

Description: The default queue config now enables batching. A new max_event_payload_bytes field was added (default 256 KiB, maximum 1 MiB, validated).

Recommended action: Release-note the change and verify log delivery latency in AWS scenarios.

#### HIGH-13 — Collector ConfigMap rendered with go.yaml.in/yaml/v3; webhook rejects unrenderable configs; TLS curve_preferences injected

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | opentelemetry-operator (collector config rendering) |
| Component type | operator |
| Detection methods | code-diff, changelog |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-operator/pull/5615 |
| Affected config fields | spec.config |
| Has test coverage | true |

Description: Since 0.160.0 the ConfigMap is rendered with go.yaml.in/yaml/v3 (2-space indentation, quoting changes, float-to-int normalization). Its content and hash change, which will probably roll out every managed collector on operator upgrade. The webhook now rejects configs that fail RenderYAML. 0.162.0 injects curve_preferences from the cluster TLS profile into receivers and extensions that have tls blocks, leaves an unparseable service.telemetry unchanged and no longer adds the default Prometheus reader. 0.161.0 skips GOMEMLIMIT and GOMAXPROCS when cgroup_runtime is configured.

Recommended action: Test an operator upgrade from the current downstream version: confirm the collector rollouts are acceptable and that no existing CR is rejected. Validate custom and FIPS TLS profiles, check the e2e tests that assert ConfigMap contents, and add a release note.

#### HIGH-14 — Internal telemetry switched to new-format metrics (enableNewFormatMetrics/disableOldFormatMetrics Beta)

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | k8sattributesprocessor |
| Component type | processor |
| Detection methods | feature-gates, changelog |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/50539 |
| Affected config fields | — |
| Has test coverage | true |

Description: Both gates moved from Alpha to Beta in v0.160.0. The processor now emits its internal metrics in the new format by default and no longer emits the old-format metrics.

Recommended action: Update any monitoring and alerts on the k8sattributes internal metrics.

#### HIGH-15 — pkg.stanza.addDefaultScopeName added as Beta: default scope name on logs

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | filelogreceiver / journaldreceiver (pkg/stanza) |
| Component type | receiver |
| Detection methods | feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/51160 |
| Affected config fields | — |
| Has test coverage | true |

Description: Stanza-based receivers now add a default scope name and version to log entries that have none. This changes the scope of the produced logs by default.

Recommended action: Check Loki and logging pipelines and filters that match on an empty scope, and add a release note.

#### HIGH-16 — filelog.allowFileDeletion, mtimeSortType and windows.caseInsensitive moved from Alpha to Beta

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | filelogreceiver |
| Component type | receiver |
| Detection methods | feature-gates, changelog |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/50266 |
| Affected config fields | — |
| Has test coverage | true |

Description: delete_after_read and ordering_criteria with mode=mtime can now be used without enabling a gate. caseInsensitive only affects Windows.

Recommended action: Decide whether delete_after_read and mtime ordering are supported in the product, and document them or mark them unsupported.

#### HIGH-17 — exporter.awsxray.EmitV1DBConventions added as Beta

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | awsxrayexporter |
| Component type | exporter |
| Detection methods | feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/52584 |
| Affected config fields | — |
| Has test coverage | true |

Description: By default the exporter now reads db.namespace, db.system.name, db.query.text and user.name instead of db.name, db.system, db.statement and db.user. Spans that only carry the old keys lose their X-Ray SQL metadata.

Recommended action: Add a release note.

#### HIGH-18 — Start() hangs the collector forever when informer sync times out with wait_for_metadata

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | k8sattributesprocessor |
| Component type | processor |
| Detection methods | issues |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/52777 |
| Affected config fields | — |
| Has test coverage | false |

Description: If the cache does not sync before wait_for_metadata_timeout, the processor reports a FatalErrorEvent, and during startup that call blocks forever. The collector never exits, health_check stays at 503 and nothing is logged. The issue is open; the root cause is core collector issue #16309.

Recommended action: Check whether the docs or examples use wait_for_metadata. Track the upstream fix and consider a known-issue note.

#### HIGH-19 — OTTL comparison of uncomparable types panics and crashes the collector

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | pkg/ottl (transformprocessor, filterprocessor) |
| Component type | processor |
| Detection methods | issues |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/52946 |
| Affected config fields | — |
| Has test coverage | false |

Description: An == or != comparison where both sides have the same uncomparable type, such as the slice returned by Split, panics. With the OTLP gRPC receiver the panic is not recovered and the process exits; error_mode: ignore does not help. The issue is open.

Recommended action: Track the fix and backport it. Document a workaround (avoid comparing slices or maps).

#### HIGH-20 — Minimum Go version raised from 1.25 to 1.26

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-collector / contrib (all modules) |
| Component type | core |
| Detection methods | dependencies, changelog |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/50394 |
| Affected config fields | — |
| Has test coverage | — |

Description: Since v0.160.0, the go directive in the core and contrib go.mod files is 1.26.0, so downstream builds need a Go 1.26 toolchain.

Recommended action: Make sure the ART/Konflux builder image (ocp/builder:rhel-9-golang-*) provides Go 1.26 or newer before the rebase.

## Medium

#### MED-1 — Docs use deprecated component type names (aliases only upstream)

| Field | Value |
|---|---|
| Category | COMPONENT_DRIFT |
| Component | filelogreceiver / kubeletstatsreceiver / loadbalancingexporter (and others) |
| Component type | core |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | filelog, kubeletstats, loadbalancing, k8sattributes, resourcedetection, otlp (exporter), spanmetrics, hostmetrics, k8sobjects, prometheusremotewrite, googleclientauth |
| Has test coverage | false |

Description: Upstream now uses snake_case type names and keeps the old names only as deprecated aliases: filelog->file_log, kubeletstats->kubelet_stats, loadbalancing->load_balancing, k8sattributes->k8s_attributes, resourcedetection->resource_detection, otlp exporter->otlp_grpc, and more. The docs are inconsistent, because some modules already use otlp_grpc/otlp_http. Configs that use the old names log deprecation warnings and will break when the aliases are removed.

Recommended action: Before switching the docs, verify that operator parsing, RBAC and port inference recognize the new names. Then update the examples and note that the old names are deprecated aliases.

#### MED-2 — googleclientauth renamed to google_client_auth (alias kept)

| Field | Value |
|---|---|
| Category | DEPRECATION |
| Component | googleclientauthextension |
| Component type | extension |
| Detection methods | changelog, code-diff |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/45339 |
| Affected config fields | extensions.googleclientauth |
| Has test coverage | true |

Description: In v0.164.0 the type was renamed and googleclientauth kept as a deprecated alias. The implementation moved in-tree, and v0.165.0 switched credential detection to cloud.google.com/go/auth.

Recommended action: Update the docs to the new name and check that operator component parsing recognizes both names.

#### MED-3 — System detector attribute renames; new openshift removeCloudNameRegion Alpha gate; pending gcp/aks changes

| Field | Value |
|---|---|
| Category | DEPRECATION |
| Component | resourcedetectionprocessor |
| Component type | processor |
| Detection methods | changelog, feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/52806 |
| Affected config fields | detectors, system.resource_attributes |
| Has test coverage | true |

Description: v0.165.0 adds os.build_id and deprecates os.build.id, and changes the z/OS os.type value to zos. The new Alpha gate processor.resourcedetection.openshift.removeCloudNameRegion would stop the openshift detector setting cloud.region on Azure/OpenStack. The eks, k8s_api and kubeadm detectors no longer fail outside Kubernetes. Pending: the gcp task_index attribute becomes an int, and the aks detector stops using HTTP_PROXY.

Recommended action: Check the openshift detector docs and outputs on Azure/OpenStack, track the gate's promotion, and release-note the renames.

#### MED-4 — New retry config (enabled, unbounded elapsed time) and validation

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | resourcedetectionprocessor |
| Component type | processor |
| Detection methods | code-diff |
| Upstream PR | — |
| Affected config fields | retry, timeout |
| Has test coverage | true |

Description: A new retry block is on by default (1s initial interval, 30s max interval, max_elapsed_time 0). Validate now errors when retry is enabled and both timeout and max_elapsed_time are 0, so users who set timeout: 0 fail at startup. New Azure detectors were added.

Recommended action: Verify openshift detector startup and release-note the timeout: 0 validation.

#### MED-5 — Top-level HTTP client settings and resource_to_telemetry_conversion deprecated; new Alpha gates in Prometheus components

| Field | Value |
|---|---|
| Category | DEPRECATION |
| Component | prometheusremotewriteexporter |
| Component type | exporter |
| Detection methods | code-diff, feature-gates |
| Upstream PR | — |
| Affected config fields | http, endpoint, tls, headers, timeout, resource_to_telemetry_conversion, resource_constant_labels |
| Has test coverage | true |

Description: A new nested http: block replaces the top-level client settings (the Alpha gate removeTopLevelHTTPSettings rejects the old ones). resource_to_telemetry_conversion is deprecated for resource_constant_labels (Alpha gate DisableResourceToTelemetryConversion). Other new Alpha gates: DisableSendingQueue, KeepIdentifyingResourceAttributes, CorrectUCUMUnits, UseTargetUrlForServerAddress and disableJobSplit. Once these reach Beta, the documented PRW configs will break.

Recommended action: Move the docs to the http: block and resource_constant_labels before the gates advance.

#### MED-6 — Retry semantics changed: timeout applies per attempt; DeadlineExceeded retried

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | prometheusremotewriteexporter |
| Component type | exporter |
| Detection methods | changelog |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/51983 |
| Affected config fields | timeout, retry_on_failure.max_elapsed_time, wal |
| Has test coverage | — |

Description: v0.164.0 applies timeout to each attempt, so requests are retried until max_elapsed_time. v0.159.0 retries DeadlineExceeded instead of dropping the data. v0.165.0 unblocks the WAL when the head record is rejected, adds failed-batch metrics, and drops exponential histograms that have no sum. Together these can raise load on the remote endpoint.

Recommended action: Add a release note and verify the retry and timeout docs.

#### MED-7 — PRW translation fixes after 0.163 change exported series

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | prometheusremotewriteexporter |
| Component type | exporter |
| Detection methods | issues |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/52938 |
| Affected config fields | — |
| Has test coverage | true |

Description: Several fixes landed after 0.163 and change output labels and series: an otel_scope_schema_url label (#52938), exemplar alignment (#52941), native histogram staleness and missing sum (#52939), native histograms sorted by timestamp (#52944), and memory held by in-flight requests (#52809).

Recommended action: On the next rebase, check how the new label and the exemplar changes affect users and tests.

#### MED-8 — resource_to_telemetry_conversion enabled/exclude_service_attributes deprecated

| Field | Value |
|---|---|
| Category | DEPRECATION |
| Component | awsemfexporter |
| Component type | exporter |
| Detection methods | code-diff |
| Upstream PR | — |
| Affected config fields | resource_to_telemetry_conversion.enabled, resource_to_telemetry_conversion.exclude_service_attributes |
| Has test coverage | true |

Description: The legacy fields now log a deprecation warning, and the Alpha gate DisableLegacyResourceToTelemetryConversion rejects them. The replacement is included/excluded patterns.

Recommended action: Update the docs to included: ['*'].

#### MED-9 — Experimental OTTL functions now gated; new dynamic slice/map key gates

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | transformprocessor / filterprocessor / routingconnector (pkg/ottl) |
| Component type | processor |
| Detection methods | feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/51564 |
| Affected config fields | — |
| Has test coverage | true |

Description: Experimental OTTL functions are rejected unless pkg.ottl.functions.enableExperimental or processor.transform.enableExperimentalFunctions (both Alpha) is enabled. Dynamic slice arguments stay on by default through a Beta gate. enableDynamicMapKeys is Alpha.

Recommended action: Check the documented OTTL examples for functions that are now experimental.

#### MED-10 — Exporter queue and batch telemetry and behavior changes

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | exporterhelper (all queue-based exporters) |
| Component type | core |
| Detection methods | changelog |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector/issues/14674 |
| Affected config fields | — |
| Has test coverage | — |

Description: v0.159.0: the queue batch send size metrics are now recorded after batching and only when batching is enabled; otelcol_exporter_enqueue_size* is new. v0.162.0: the partition idle timeout default rises to 90s, and there is a new cache_size setting. v0.165.0: the service warns when the batch processor is combined with exporterhelper batching.

Recommended action: Update the self-observability dashboards and review default configs that combine the batch processor with sending_queue.batch.

#### MED-11 — Routing changes for data without service.name and for k8s resolver readiness

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | loadbalancingexporter |
| Component type | exporter |
| Detection methods | changelog |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/52483 |
| Affected config fields | — |
| Has test coverage | — |

Description: v0.161.0 skips EndpointSlice endpoints that are not ready and removes stale endpoints. v0.165.0 hashes logs that have no service.name (with routing_key: service) by their resource attributes. A pending entry routes such metrics instead of dropping them and bounds exporter start to 5s.

Recommended action: Note the distribution change for users who rely on routing_key: service.

#### MED-12 — Shutdown can hang after a backend resolution error

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | loadbalancingexporter |
| Component type | exporter |
| Detection methods | issues |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/52745 |
| Affected config fields | — |
| Has test coverage | false |

Description: When exporterAndEndpoint fails partway through, ConsumeLogs and ConsumeMetrics return early without releasing their WaitGroup counts, so Shutdown waits forever. The issue is open.

Recommended action: Track the fix and backport it. Add a shutdown test that runs while resolution fails.

#### MED-13 — Records lost on downstream queue-full rejection (receiver retries an empty batch)

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | routingconnector |
| Component type | connector |
| Detection methods | issues |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/53069 |
| Affected config fields | — |
| Has test coverage | false |

Description: The routing connector moves records out of the input batch. When an exporter rejects its group (for example with ErrQueueIsFull), the receiver's retry resends an empty batch and the rejected records are lost. The issue is open.

Recommended action: Assess the data-loss impact for filelog plus routing pipelines, and backport the fix when it lands.

#### MED-14 — Duplicates during rebalance and shutdown

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | kafkareceiver |
| Component type | receiver |
| Detection methods | issues |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/53066 |
| Affected config fields | — |
| Has test coverage | false |

Description: Reported on 0.165.1: rebalances triggered by autoscaling, and shutdowns, produce duplicate records. Earlier versions are probably affected too. The issue is open.

Recommended action: Monitor, and note the at-least-once semantics in the docs.

#### MED-15 — goccy/go-json v0.10.6 holds ~30 MiB of fixed caches

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | filelogreceiver / journaldreceiver (goccy/go-json) |
| Component type | receiver |
| Detection methods | issues |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/52904 |
| Affected config fields | — |
| Has test coverage | false |

Description: The goccy/go-json decoder and encoder caches use about 33 MiB of heap in v0.163.2; pkg/stanza, pkg/ottl and journald use the library. The upgrade to v0.12.0 is blocked.

Recommended action: Check the downstream memory baseline and track the dependency upgrade.

#### MED-16 — v0.165.0 requires unresolvable hashicorp/consul/api/v2 (reverted in #52874)

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | resourcedetectionprocessor |
| Component type | processor |
| Detection methods | issues |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/pull/52874 |
| Affected config fields | — |
| Has test coverage | true |

Description: v0.165.0 imports a consul/api/v2 tag that was deleted upstream, so builds with GOPROXY=direct, including hermetic ART builds, break.

Recommended action: Skip 0.165.0 and 0.165.1, or rebase onto a version that includes #52874.

#### MED-17 — Delta timestamp collision fix; pending: cumulative histograms start at zero

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | spanmetricsconnector |
| Component type | connector |
| Detection methods | changelog |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/52354 |
| Affected config fields | — |
| Has test coverage | — |

Description: v0.165.0 fixes delta timestamp collisions across resources. A pending entry makes new cumulative duration histogram series report zero on their first flush and drops exemplars collected before that flush.

Recommended action: Check e2e assertions that expect non-zero values on the first flush.

#### MED-18 — count_traces_sampled metric deprecated

| Field | Value |
|---|---|
| Category | DEPRECATION |
| Component | probabilisticsamplerprocessor |
| Component type | processor |
| Detection methods | changelog |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/50954 |
| Affected config fields | — |
| Has test coverage | — |

Description: v0.164.0 adds count_spans_processed and deprecates count_traces_sampled.

Recommended action: Update any self-monitoring dashboards.

#### MED-19 — Stricter config validation

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | fileexporter, k8sleaderelector, hostmetricsreceiver |
| Component type | exporter |
| Detection methods | code-diff |
| Upstream PR | — |
| Affected config fields | rotation, group_by.max_open_files, lease_duration, renew_deadline, retry_period, metadata_collection_interval |
| Has test coverage | true |

Description: fileexporter: rotation values must be non-negative and group_by.max_open_files must be positive. k8sleaderelector: the lease, renew and retry durations must be in the right order and all above zero. hostmetrics: metadata_collection_interval must not be negative.

Recommended action: Low risk. Mention it in the release notes.

#### MED-20 — [pending] OIDC extension rejects JSON-serialized JWTs

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | oidcauthextension |
| Component type | extension |
| Detection methods | changelog |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/52688 |
| Affected config fields | — |
| Has test coverage | — |

Description: A pending entry switches to ParseSignedCompact, so tokens in JWS JSON serialization will be rejected.

Recommended action: Monitor, and add a release note once it lands.

#### MED-21 — Receivers bound to IPv6 addresses get wrong Service/container ports

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | opentelemetry-operator (collector manifests) |
| Component type | operator |
| Detection methods | issues |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-operator/issues/5782 |
| Affected config fields | — |
| Has test coverage | false |

Description: PortFromEndpoint takes the first ':\d+' match in the endpoint, so [fd00:10:244::5]:4317 yields port 10. That produces wrong Services and container ports on IPv6 and dual-stack OCP. The issue is open.

Recommended action: Track the fix, test on IPv6 and dual-stack clusters, and consider a known-issue note.

#### MED-22 — Pod webhook strips unknown pod fields and denies pods on mutator panic

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | opentelemetry-operator (pod webhook) |
| Component type | operator |
| Detection methods | issues |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-operator/issues/5733 |
| Affected config fields | — |
| Has test coverage | false |

Description: #5733: the webhook generates remove patches for pod fields newer than the operator's k8s.io/api version. #5736: a panic in a mutator denies the pod even though failurePolicy is Ignore. Both issues are open.

Recommended action: Track both. #5733 is a risk whenever OCP's Kubernetes version is ahead of the operator's k8s.io/api dependency.

#### MED-23 — Instrumentation fixes merged after operator 0.163 (Java extension pullPolicy, Python platform annotation)

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | opentelemetry-operator (instrumentation) |
| Component type | operator |
| Detection methods | issues |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-operator/issues/5893 |
| Affected config fields | — |
| Has test coverage | true |

Description: #5893: Java extension init containers ignore imagePullPolicy. #5892: an unsupported otel-python-platform annotation stops the pod from starting. Both fixes merged after the 0.163.0 release. Java is GA downstream and Python is TP.

Recommended action: Cherry-pick the fixes into the product branch for a patch release, or pick them up in the next rebase.

#### MED-24 — Default collector and operator versions bumped from 0.158.0 to 0.163.x

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator |
| Component type | core |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | — |

Description: versions.txt now sets the collector to 0.163.2 and the operator, target allocator and OpAMP bridge to 0.163.0, which is five upstream minor releases.

Recommended action: Align the redhat-opentelemetry-collector rebase target with 0.163.x.

#### MED-25 — Auto-instrumentation versions bumped; PHP and Ruby added

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator (auto-instrumentation) |
| Component type | auto_instrumentation |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | — |

Description: Java goes to 2.33.1, NodeJS to 0.83.0-2, Python to 0.66b2 and DotNet to 1.19.1. New entries are PHP 1.4.2 and Ruby 0.1.0.

Recommended action: Update the instrumentation image builds and relatedImages. Decide the support status of PHP and Ruby, and check that the CSV and docs agree.

#### MED-26 — k8s.io/* libraries bumped from v0.36.3 to v0.37.1

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator |
| Component type | core |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | — |

Description: The operator now uses the Kubernetes 1.37 client libraries.

Recommended action: Check client skew against the oldest supported OCP version and run the e2e matrix.

#### MED-27 — controller-runtime bumped from v0.24.1 to v0.25.2

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator |
| Component type | core |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | — |

Description: This is a minor bump of a pre-1.0 library, so it may carry API breaks. openshift/library-go was updated too.

Recommended action: Review the controller-runtime v0.25 release notes and check that the downstream patches still apply.

#### MED-28 — prometheus-operator v0.92.0->v0.94.2 and prometheus v0.312.0->v0.315.1

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator (target allocator) |
| Component type | core |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | — |

Description: Minor bumps to the libraries the target allocator uses for service discovery and the monitoring CRDs.

Recommended action: Run the TA e2e tests for ServiceMonitor, PodMonitor, ScrapeConfig and Probe discovery.

#### MED-29 — buraksezer/consistent major bump from v0.10.0 to v1.1.0

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator (target allocator) |
| Component type | core |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | — |

Description: A major version bump of the library behind the consistent-hashing allocation strategy. It may change the API or how targets are hashed.

Recommended action: Check that target distribution stays stable across an upgrade.

#### MED-30 — Upstream replaced the MinIO fixture with SeaweedFS in the lokistack export test

| Field | Value |
|---|---|
| Category | test-deletion |
| Component | operator/e2e-openshift/export-to-cluster-logging-lokistack |
| Component type | test |
| Detection methods | test-coverage |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | — |

Description: install-minio.yaml was deleted and the assert file renamed to install-seaweedfs-assert.yaml. The test still exists, but its object storage backend changed.

Recommended action: Make sure the SeaweedFS image is available (or mirrored) in product CI and in disconnected environments.

## Low

#### LOW-1 — confighttp README still lists removed keepalive keys as deprecated

| Field | Value |
|---|---|
| Category | DOC_STALE |
| Component | confighttp (core) |
| Component type | core |
| Detection methods | code-diff |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | false |

Description: The README still describes the removed flat keepalive keys as 'Deprecated', and topLevelHTTPClientKeys in prometheusremotewriteexporter still lists them.

Recommended action: Do not rely on the upstream README for migration guidance. Optionally file an upstream doc fix.

#### LOW-2 — Watch restart fixes; k8s_events metric units singular

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | k8seventsreceiver / k8sobjectsreceiver |
| Component type | receiver |
| Detection methods | changelog |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/43928 |
| Affected config fields | — |
| Has test coverage | — |

Description: The receiver now keeps retrying through 410 Gone recovery, and the k8s_events units are now singular. A pending entry restarts a closed watch with backoff instead of stopping.

Recommended action: This is a positive fix. Consider a backport if customers report receivers going silent.

#### LOW-3 — In-cluster k8s API clients ignore environment proxy settings

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | internal/k8sconfig (k8sattributes, k8scluster, k8sobjects, k8sevents, resourcedetection) |
| Component type | processor |
| Detection methods | changelog |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/50937 |
| Affected config fields | — |
| Has test coverage | — |

Description: In-cluster API clients no longer use HTTP_PROXY/HTTPS_PROXY (v0.161.0, plus the EKS detector in v0.164.0).

Recommended action: Add a note for proxy-enabled OpenShift clusters.

#### LOW-4 — Removal warning from the upstream core distro (v0.167.0)

| Field | Value |
|---|---|
| Category | DEPRECATION |
| Component | jaegerreceiver, zipkinreceiver, attributesprocessor, resourceprocessor, spanprocessor |
| Component type | receiver |
| Detection methods | code-diff |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | true |

Description: The removal warning is only logged when BuildInfo matches the upstream otelcol distribution. These components stay in contrib.

Recommended action: Confirm that the downstream BuildInfo differs from otelcol.

#### LOW-5 — Additive CRD fields

| Field | Value |
|---|---|
| Category | NEW_FEATURE |
| Component | opentelemetry-operator CRDs |
| Component type | operator |
| Detection methods | code-diff |
| Upstream PR | — |
| Affected config fields | spec.php, spec.ruby, spec.proxy, spec.telemetry, spec.resizePolicy, spec.revisionHistoryLimit, spec.imagePullSecrets, spec.enableServiceLinks |
| Has test coverage | true |

Description: New fields: Instrumentation php and ruby; OpAMPBridge proxy; TA telemetry and revisionHistoryLimit; and resizePolicy, revisionHistoryLimit (default 10), imagePullSecrets and enableServiceLinks (default true) in the common fields. The new defaults will appear on existing CRs.

Recommended action: Decide the support status of PHP/Ruby and of the new fields.

#### LOW-6 — Additive config fields

| Field | Value |
|---|---|
| Category | NEW_FEATURE |
| Component | kafkareceiver, kafkaexporter, k8sobjectsreceiver, prometheusremotewritereceiver, tailsamplingprocessor, bearertokenauthextension, spanmetricsconnector |
| Component type | receiver |
| Detection methods | code-diff |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | true |

Description: New fields include kafka partition_processing and signal_header, k8sobjects cache_sync_timeout, PRW receiver resource_cache_size, tailsampling num_shards, and bearertokenauth retry_on_failure.

Recommended action: No action required. Optionally document them.

#### LOW-7 — New Alpha gates for system semconv, the k8sobjects informer and the kubelet pod source

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | hostmetricsreceiver / k8sobjectsreceiver / k8sattributesprocessor |
| Component type | receiver |
| Detection methods | feature-gates |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | true |

Description: Off-by-default gates that prepare future migrations. No default changes yet.

Recommended action: Track them for promotion.

#### LOW-8 — New Alpha gates: targetsremainingattributes

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | opentelemetry-operator |
| Component type | operator |
| Detection methods | feature-gates |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-operator/pull/5728 |
| Affected config fields | — |
| Has test coverage | true |

Description: Off-by-default gates that add job.name and k8s.namespace.name to the TA targets_remaining metric.

Recommended action: No action needed. Track them.

#### LOW-9 — Shutdown flush uses an unbounded context

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | logdedupprocessor |
| Component type | processor |
| Detection methods | issues |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/52740 |
| Affected config fields | — |
| Has test coverage | false |

Description: A hung downstream consumer can block Shutdown forever. The reporter says there is no practical impact today. The issue is open.

Recommended action: Monitor.

#### LOW-10 — fileconsumer leaks file handles for files with duplicate fingerprints

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | filelogreceiver (pkg/stanza/fileconsumer) |
| Component type | receiver |
| Detection methods | issues |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/53135 |
| Affected config fields | — |
| Has test coverage | false |

Description: The rejected duplicate's file handle is never closed, so file descriptors grow until GC. The issue is open.

Recommended action: Monitor, and backport the fix if FD exhaustion shows up in the field.

#### LOW-11 — Collector CR fields ignored: revisionHistoryLimit (daemonset), ingressClassName updates, extension Service ipFamilies

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | opentelemetry-operator (collector manifests) |
| Component type | operator |
| Detection methods | issues |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-operator/issues/5889 |
| Affected config fields | — |
| Has test coverage | false |

Description: Three open issues: #5889, #5890 and #5891.

Recommended action: Track the fixes and check whether the docs describe these fields as working.

#### LOW-12 — Target allocator HTTP endpoint bugs and Event '%' formatting fixed after 0.163

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | opentelemetry-operator (target allocator / events) |
| Component type | operator |
| Detection methods | issues |
| Upstream PR | https://github.com/open-telemetry/opentelemetry-operator/issues/5897 |
| Affected config fields | — |
| Has test coverage | true |

Description: Fixed after the release: #5897 (the _link returns 404), #5896 (/debug/target writes two pages) and #5898 (a '%' corrupts Event text).

Recommended action: Pick them up in the next rebase.

#### LOW-13 — New and existing Kafka Receiver options not documented

| Field | Value |
|---|---|
| Category | DOC_MISSING |
| Component | kafkareceiver |
| Component type | receiver |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | partition_processing, dial_timeout, group_id, initial_offset, message_marking, error_backoff |
| Has test coverage | true |

Description: partition_processing, dial_timeout and max_decompress_batch_bytes are new. group_id, initial_offset, message_marking, error_backoff and others already existed but are not documented.

Recommended action: Document the core options. Add partition_processing after the rebase.

#### LOW-14 — New and existing Kafka Exporter options not documented

| Field | Value |
|---|---|
| Category | DOC_MISSING |
| Component | kafkaexporter |
| Component type | exporter |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | signal_header, producer, sending_queue, retry_on_failure, partition_traces_by_id |
| Has test coverage | true |

Description: signal_header is new. producer, sending_queue, retry_on_failure and the partitioning options already existed but are not documented.

Recommended action: Add these options to the parameter list.

#### LOW-15 — Kubernetes Attributes Processor doc covers only `filter`; new `kubelet` block

| Field | Value |
|---|---|
| Category | DOC_MISSING |
| Component | k8sattributesprocessor |
| Component type | processor |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | kubelet, extract, pod_association, wait_for_metadata |
| Has test coverage | true |

Description: The doc does not cover extract, pod_association, the wait_for_metadata options or the new kubelet polling block.

Recommended action: Document extract and pod_association. Evaluate the kubelet mode, including its RBAC needs, before documenting it.

#### LOW-16 — Tail Sampling Processor optional fields not documented

| Field | Value |
|---|---|
| Category | DOC_MISSING |
| Component | tailsamplingprocessor |
| Component type | processor |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | num_shards, decision_cache, invert_match, maximum_trace_size_bytes |
| Has test coverage | true |

Description: num_shards is new. decision_cache, invert_match, maximum_trace_size_bytes and others already existed but are not documented.

Recommended action: Document the commonly used fields.

#### LOW-17 — OTLP Receiver optional fields not documented

| Field | Value |
|---|---|
| Category | DOC_MISSING |
| Component | otlpreceiver |
| Component type | receiver |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | traces_url_path, cors, tls.tpm |
| Has test coverage | true |

Description: The URL path overrides, cors, keepalive and the new tls.tpm block are not documented.

Recommended action: Optionally document them, and state that tls.tpm is unsupported.

#### LOW-18 — Filelog Receiver: new `skip_unmodified_files`; most options undocumented

| Field | Value |
|---|---|
| Category | DOC_MISSING |
| Component | filelogreceiver |
| Component type | receiver |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | skip_unmodified_files, start_at, storage, multiline |
| Has test coverage | true |

Description: skip_unmodified_files is new. start_at, storage, multiline, on_truncate and others are not documented.

Recommended action: Document start_at, storage and multiline.

#### LOW-19 — OTel Go SDK 1.47, opamp-go 0.25, collector featuregate 1.70, new direct pdata dependency

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator |
| Component type | core |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | — |

Description: opamp-go 0.25 affects the OpAMP bridge.

Recommended action: Run the OpAMP bridge e2e tests.

#### LOW-20 — Collector-core dependency refresh: grpc 1.85.0, OTel Go 1.47, koanf 2.4.1

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-collector (all modules) |
| Component type | core |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | — |

Description: Routine dependency updates.

Recommended action: Covered by the normal rebase testing.

#### LOW-21 — cert-manager patch bump from v1.21.1 to v1.21.3

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator |
| Component type | core |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | — |

Description: A patch-level update.

Recommended action: No action beyond normal testing.

#### LOW-22 — New upstream test suite e2e-instrumentation-go and other new tests

| Field | Value |
|---|---|
| Category | new-test-suite |
| Component | operator/e2e-instrumentation-go |
| Component type | test |
| Detection methods | test-coverage |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | — |

Description: New Go-based full-pipeline instrumentation tests, plus PHP/Ruby, TA networkpolicy, mTLS, k8sattributes RBAC, dual-stack and other tests.

Recommended action: Decide whether to add them to the OpenShift CI matrix and the Konflux integration tests.

#### LOW-23 — chronyreceiver has no upstream or QE test

| Field | Value |
|---|---|
| Category | coverage-gap |
| Component | receiver/chronyreceiver |
| Component type | receiver |
| Detection methods | test-coverage |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | false |

Description: chronyreceiver is in the build manifest but is undocumented and has no tests. It is the only component in the build without any test.

Recommended action: Add a QE smoke test if it will be documented, or consider dropping it from the build.


## Confirmed Coverage Gaps

Components and operator features with no test at all — neither upstream nor QE. Anything with at least one of the two is considered covered, since the product build runs both suites.

- receiver/chronyreceiver (receiver) — undocumented, no upstream or QE test


## Skill Improvement Recommendations

*(Deviations from skill steps as written — `None.` if everything worked as described.)*

- [discover] The manifest receivers section has an entry 'gomod: go.opentelemetry.io/obi v0.10.0' (import: go.opentelemetry.io/obi/collector, and a replace to ../.obi-src). It belongs to neither collector_core nor collector_contrib, and the repo enum allows only those two, so I left it out of components. It does have a doc (otel-receivers-obi-receiver.adoc). That doc matches a manifest entry, so I did not list it under documented_but_missing either.
- [discover] The manifest also has 'providers' (confmap env/file/http/https/yaml v1.64.0) and 'replaces' sections, which the instructions do not mention. I left them out of components.
- [discover] The version field keeps the leading 'v' exactly as written in the manifest (e.g. v0.158.0). collector_version comes from dist.version, which is 0.158.0 with no 'v'.
- [setup] openshift-docs is cloned single-branch tracking only standalone-otel-docs-main (remote.origin.fetch = refs/heads/standalone-otel-docs-main), so 'git fetch origin main' only updated FETCH_HEAD (5241c8be) and 'git rev-parse origin/main' failed. The relevant docs ref is origin/standalone-otel-docs-main (1b1645f372c59affaa5e48eed0baa76b001c7857). Instructions should use that branch for openshift-docs.
- [setup] origin/main HEADs: operator 2230ff0ed9bf4d187ec12740c4f0b4a8eb28d290, contrib eb666fc4ebc657fbde303763f7e72ea3c0788af7, core 71b5f8c06caec4b5cc11e8e03d4d72b548dc0e11, qe 5e6062a6e834c163d51936675f3095cce10f6829 (reported here since the schema has no field for them).
- [changelog] Contrib origin/main is already past v1.4.1/v0.165.1. Contrib now releases as v1.x/v0.x pairs (v1.1.0/v0.162.0 through v1.4.1/v0.165.1), so section headers are not plain v0.x. Core uses v1.6x.0/v0.1xx.0 headers. The operator range was given as a commit SHA, which resolved to tag apis/v0.158.0 ('Prepare release 0.158.0').
- [changelog] Contrib changelog component names use underscored forms (e.g. processor/k8s_attributes, receiver/host_metrics, exporter/load_balancing, extension/file_storage), not the source directory names in the instructions. I built a manual mapping regex to filter, and also included the shared packages that affect downstream components (pkg/ottl, pkg/stanza, pkg/fileconsumer, pkg/kafka/configkafka, pkg/prometheus, pkg/translator/prometheusremotewrite, pkg/zipkin, pkg/jaeger, internal/k8sconfig, internal/kafka, internal/aws, scraper/*).
- [changelog] One contrib entry (v0.165.1 `processor/resourcedetection` consul revert) has no colon after the component, so my parser missed it. I caught it by reviewing manually.
- [changelog] Core breaking changes in CHANGELOG-API.md are mostly Go API changes and I did not report them individually. For the user-facing confighttp change I checked commit 9372e2e35 directly to confirm that the YAML client keys were removed.
- [changelog] I read all files with `git show origin/main:<path>` rather than from the working tree, so the analysis does not depend on the local checkout state.
- [changelog] Several components in the downstream list have no entries in this range (e.g. chrony receiver, zpages, headerssetter, oauth2clientauth, metricstarttime, groupbyattrs, count/forward connectors, googlecloud exporter, attributes/resource/span processors). That is expected.
- [code-diff] receiver/filelogreceiver and receiver/otlpjsonfilereceiver have no config.go/factory.go (config lives in filelog.go / file.go), so the prescribed config.go/factory.go diff produced no output for them; they were not further analyzed.
- [code-diff] The most severe breaking change (removal of confighttp client/server keepalive fields) lives in collector-core config/confighttp, not in any contrib component config.go/factory.go; I additionally diffed opentelemetry-collector config/confighttp to explain the removed HTTP timeout/keepalive overrides seen in contrib factories, since the instructions gave a core tag but no core-specific step.
- [code-diff] To classify defaults/feature-gate effects I also inspected metadata.yaml (feature gate stages, type/deprecated_type), .chloggen entries and a few internal files (resourcedetection internal provider, coredistro) beyond config.go/factory.go.
- [code-diff] Webhook and API diffs were run with test files, zz_generated deepcopy and go.mod/go.sum excluded for readability; test coverage flags are based on whether corresponding *_test.go files changed in the diff stat, not on detailed test review.
- [feature-gates] I did not use the suggested 'git diff | grep -A5 -B5 featuregate|MustRegister' as the main method. It produced mostly file headers, and new or removed generated_feature_gates.go files could not be matched to old stages. Instead a small Python script (/tmp/fgscan/scan.py) read every MustRegister(id, featuregate.StageX, ...) call at both refs with git grep and git show, and then the two lists were joined on gate ID. Coverage was checked by counting MustRegister calls; the only calls missed were in a testbed helper and in featuregate/registry.go itself.
- [feature-gates] Several gates moved more than one step within the window, for example PermissiveLabelSanitization Alpha->Beta->Stable, filelog.protobufCheckpointEncoding Beta->Stable->Removed, and ottl.set.allowNil added->Beta->Stable->removed (no net change). The table shows only the net change from base to HEAD; intermediate steps came from git log.
- [feature-gates] The instructions only cover promotions. I also reported newly added Beta or Stable gates, which are on by default with no prior gate, and the operator's NetworkPolicy demotion from Beta to Alpha, because these change defaults too.
- [feature-gates] Shared-package gates (pkg/stanza, pkg/ottl, pkg/translator/jaeger|zipkin|prometheus, core confighttp) do not match the component name list. I mapped them to the downstream components that use them. Gates for components outside the build were filtered out (datadog, servicegraph, azure/aws encodings, faro, sqlserver, kafkametrics, statsd, apache, internal goldendataset).
- [feature-gates] For the most severe findings I read the product docs in openshift-docs to judge real impact. The instructions did not ask for this.
- [issues] Step 3 cannot work as written: open-telemetry/opentelemetry-operator has no 'breaking' label (checked with gh label list), so `gh pr list --label breaking` returns nothing. I used `gh pr list --search "breaking merged:>2026-09-01"` instead and filtered the results by hand.
- [issues] The instructions do not say what the 'downstream base version' is. I took it to be rhosdt-0.163 (the newest ocp-build-data branch; group.yml version 0.163.0; collector manifest 0.163.2) and got the component list from `git show origin/rhosdt-0.163:manifest.yaml` in redhat-opentelemetry-collector. Its main branch still pins 0.158.
- [issues] Supported versus unsupported operator features (OpAMPBridge Not supported, Python TP, Target Allocator GA) came from .ai/spec/what/*.md. The instructions only say 'components in the downstream build'.
- [issues] `--limit 30` returns only the newest bug issues, about the last 2 weeks for contrib and about 2 months for the operator. Older bugs reported since the base may be missing.
- [issues] The revert search ('revert in:title') returns many old or irrelevant results from 2021 to 2025, and the results are not sorted by date. I filtered them by hand by merge date and by the files each PR touches.
- [doc-validation] The mapped source file opentelemetry-collector-contrib/receiver/filelogreceiver/config.go does not exist. The receiver Config is in receiver/filelogreceiver/filelog.go, and its fields come from pkg/stanza/fileconsumer/config.go, matcher/matcher.go and attrs/attrs.go.
- [doc-validation] opentelemetry-collector/receiver/otlpreceiver/config.go no longer has mapstructure tags. The struct is in generated_config.go (schema-generated), and the same applies to config/configtls/generated_config.go.
- [doc-validation] Kafka receiver/exporter config.go files squash configkafka.ClientConfig, so I also read pkg/kafka/configkafka/config.go (where auth.plain_text was removed).
- [doc-validation] Besides comparing against upstream main, I diffed mapstructure tags against the v0.158.0 tag (the version pinned in redhat-opentelemetry-collector/manifest.yaml). This separates fields already broken in the shipped release from future breakage.
- [doc-validation] I chose 6 components for depth (otlpreceiver, kafkareceiver, kafkaexporter, k8sattributesprocessor, tailsamplingprocessor, filelogreceiver) and briefly checked spanmetricsconnector (no field diff since v0.158). Kafka receiver/exporter GA status was not verified against a support matrix.
- [doc-validation] The name-drift check went beyond the three listed pairs: I scanned all core/contrib metadata.yaml files for `deprecated_type` and grepped the docs for each old name. The per-file counts come from a regex that also matches prose/sub-keys (e.g. `otlp` includes receiver uses), so they are approximate. One batch command exited non-zero because of the last loop iteration's test, but its output was complete.
- [dependencies] Collector-core: the root go.mod is not used to build any official binary. The diff there only showed the go directive change (1.25.0->1.26.0) and the removal of all require blocks, so it contains no meaningful dependency bumps. To get real dependency changes I also diffed the per-module go.mod files (pdata/go.mod, confmap/go.mod, otelcol/go.mod, config/configgrpc/go.mod).
- [dependencies] Operator go.mod has no go directive change (1.26.3 at both ends). I confirmed this with git show on both revisions, because the diff alone does not show unchanged lines.
- [test-coverage] Implicit coverage was found mainly with a Python/PyYAML scan instead of the suggested grep. It parsed every YAML document, including collector configs embedded as strings, and recorded component keys only under receivers/processors/exporters/extensions/connectors (plus the service.extensions list), keyed by section. This keeps receiver and exporter apart for shared keys (otlp, prometheus, kafka, prometheus_remote_write). It also avoids false positives from generic keys like file, count, filter, attributes and span. Running the instruction's grep on those keys matched unrelated chainsaw 'file:' steps, k8sattributes 'filter:' blocks and resource 'attributes:' blocks.
- [test-coverage] The grep was then run as a fallback for every candidate still showing 'none'. It found one item the YAML scan missed: prometheusremotewrite exporter in opentelemetry-operator/tests/e2e-prometheuscr/create-sm-prometheus-exporters/05-install.yaml (the parser did not pick it up, probably because of odd indentation in the embedded config). Its upstream status was set to implicit by hand.
- [test-coverage] Many metadata.yaml files have no deprecated_type, but the tests use the old key anyway: health_check / k8sevents-style naming, and tests use 'k8sattributes', 'loadbalancing', 'otlphttp' etc. So the directory name with its receiver/exporter/processor/extension/connector suffix stripped (and underscores removed) was added as a search candidate, on top of type, deprecated_type and the directory name. For extension/storage/filestorage, the last path segment 'filestorage' was used as the directory candidate.
- [test-coverage] The suggested dedicated-directory check (tests/e2e*/<candidate>/) treats any sub-test directory as dedicated, e.g. opentelemetry-operator/tests/e2e-openshift/kafka counts as dedicated for both kafkareceiver and kafkaexporter. This was kept as written.
- [test-coverage] Operator feature QE checks covered .yaml/.yml/.go/.sh/.ts files under distributed-tracing-qe/tests/ and the hits were reviewed by hand. Several keyword hits were thrown out as not real coverage: hand-written ClusterRoles in QE tests (not automatic RBAC), Tempo 'tls_min_version' asserts (not the OpenShift TLS profile), 'horizontalpodautoscalers' in RBAC rules (not autoscaling), DaemonSet maxUnavailable (not PDB), and ServiceMonitors scraped by user workload monitoring (not the TA prometheusCR).
- [test-coverage] In the 'upgrade' check, the only match for 'upgrade' was a README in e2e-mcoa. Per the instructions this does not count, so both upgrade features are qe_test none.
- [test-coverage] The local opentelemetry-operator checkout was taken to match origin/main (2230ff0e). Its tests/e2e-* listing matches the tree at origin/main, so feature discovery was done on the working tree.
