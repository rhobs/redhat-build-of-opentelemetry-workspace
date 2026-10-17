# Regression Detection Report

## Metadata

| Field | Value |
|---|---|
| Downstream base | operator `7fb513848c6d4ea79b277352fc13ce11eb734b1a` (v0.158.0), collector `v0.158.0` |
| Upstream target | origin/main (latest release: v0.161.0) |
| Release branch | rhosdt-0.158 |
| Components in build | 58 |
| Documented components | 54 |
| Critical | 10 |
| High | 37 |
| Medium | 37 |
| Low | 28 |
| Total | 112 |

## Contents

- [Critical (10)](#critical)
- [High (37)](#high)
- [Medium (37)](#medium)
- [Low (28)](#low)
- [Confirmed Coverage Gaps](#confirmed-coverage-gaps)
- [Documentation Drift](#documentation-drift)
- [Skill Improvement Recommendations](#skill-improvement-recommendations)

## Critical

#### CRIT-1 — Kafka auth.tls / auth.plain_text and all other deprecated Kafka client options removed

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | kafkaexporter, kafkareceiver (pkg/kafka/configkafka) |
| Component type | exporter |
| Detection methods | changelog, code-diff, issues, doc-validation |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50202, #50381, #50748 |
| Affected config fields | exporters.kafka.auth.plain_text, exporters.kafka.auth.tls, receivers.kafka.auth.plain_text, receivers.kafka.auth.tls, auth.sasl.version, auth.kerberos, resolve_canonical_bootstrap_servers_only, group_rebalance_strategy |
| Has test coverage | false |

Description: contrib v0.160.0 (#50202) removed the deprecated auth.tls and auth.plain_text blocks, and #50381 removed the remaining deprecated configkafka options (resolve_canonical_bootstrap_servers_only, auth.sasl.version, group_rebalance_strategy); v0.161.0 (#50748) additionally rejects auth.sasl together with auth.kerberos. These live in the shared pkg/kafka/configkafka module, so both the downstream kafkaexporter and kafkareceiver are affected. confmap decodes with ErrorUnused=true, so any config still carrying these keys is a hard startup failure, not a warning. openshift-docs otel-exporters-kafka-exporter.adoc and otel-receivers-kafka-receiver.adoc still present auth.plain_text as the supported authentication form, so customers who copied the documented example break on upgrade.

Recommended action: Update both openshift-docs Kafka modules to auth.sasl (mechanism PLAIN) before the rebase, add a release-note migration entry, grep QE manifests and multicluster-observability-addon templates for the removed keys, and add an e2e case asserting a legacy plain_text config is rejected with a clear error.

#### CRIT-2 — k8sattributes semconv v1 feature gates promoted to beta — attribute names change by default

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | k8sattributesprocessor |
| Component type | processor |
| Detection methods | changelog, issues, feature-gates |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#49152 |
| Affected config fields | processor.k8sattributes.EmitV1K8sConventions, processor.k8sattributes.DontEmitV0K8sConventions, k8s.pod.labels, k8s.pod.label |
| Has test coverage | false |

Description: contrib v0.161.0 (#49152) promoted processor.k8sattributes.EmitV1K8sConventions and DontEmitV0K8sConventions from alpha to beta (both ON by default) and promoted the logs/metrics/traces signals to stable. Emitted attributes switch from the legacy plural form (k8s.pod.labels.*) to the stable singular form (k8s.pod.label.*) and the legacy names stop being emitted. Every downstream dashboard, alerting rule, Tempo/Loki query, console-plugin filter and customer processor chain keyed on the old names silently stops matching — data still flows, just under different keys, so there is no error to alert on.

Recommended action: Decide downstream policy explicitly: either ship --feature-gates=-processor.k8sattributes.DontEmitV0K8sConventions,processor.k8sattributes.EmitV1K8sConventions for one release to dual-emit, or accept the change and publish a v0->v1 attribute migration table. Audit openshift-docs, distributed-tracing-console-plugin and logging-view-plugin for hardcoded k8s.pod.labels.*, and add a QE assertion pinning the expected attribute names.

#### CRIT-3 — deployment_name_from_replicaset config option removed — any config containing it is a hard startup failure

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | k8sattributesprocessor |
| Component type | processor |
| Detection methods | changelog, code-diff |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#45871 |
| Affected config fields | processors.k8sattributes.extract.deployment_name_from_replicaset |
| Has test coverage | true |

Description: contrib v0.160.0 (#45871/#50539) removed the deprecated extract.deployment_name_from_replicaset field from ExtractConfig and the corresponding factory option and default. Because confmap rejects unknown keys, a config that still contains this key crashes the collector at startup regardless of its value; deployment names are now always derived from the ReplicaSet name heuristic. The operator's collector webhook does not catch this, so the failure surfaces as a CrashLoopBackOff after upgrade rather than at admission.

Recommended action: Grep openshift-docs, distributed-tracing-qe e2e manifests, operator-generated configs and multicluster-observability-addon for deployment_name_from_replicaset and remove it. Add an upgrade-blocking entry to the release notes and consider a pre-upgrade must-gather check.

#### CRIT-4 — --create-rbac-permissions CLI flag removed; OpAMP bridge instance IDs now derived from cluster ID

| Field | Value |
|---|---|
| Category | REMOVED_API |
| Component | opentelemetry-operator (CLI flags, OpAMP bridge) |
| Component type | core |
| Detection methods | changelog, code-diff, issues |
| Upstream PR | open-telemetry/opentelemetry-operator#2588, #5689 |
| Affected config fields | --create-rbac-permissions, kube-system namespace get, OpAMP agent instance ID |
| Has test coverage | false |

Description: Operator 0.161.0 (#2588) removed the deprecated --create-rbac-permissions flag; RBAC permission creation is now exclusively autodetected at startup and the value moved to cfg.Internal.CreateRBACPermissions. Any downstream CSV, ocp-build-data manifest, CI config or QE manifest still passing the flag makes the operator pod exit with an unknown-flag error. The same release (#5689) changes standalone OpAMP bridge agent instance IDs to be computed from the Kubernetes cluster ID, which breaks agent identity continuity on the OpAMP server and newly requires get on the kube-system namespace.

Recommended action: Grep the rhosdt CSV/config/manager, ocp-build-data, openshift/release CI configs and distributed-tracing-qe for --create-rbac-permissions and remove it before the rebase. Verify RBAC autodetection works under the restricted OpenShift SCC the product ships, add kube-system get to the OpAMP bridge role, and note the instance-ID change in the release notes.

#### CRIT-5 — Minimum Go version raised to 1.26 across core and contrib; Go 1.27 produces a binary that panics at startup

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-collector / opentelemetry-collector-contrib (build toolchain) |
| Component type | core |
| Detection methods | changelog, code-diff, issues, dependencies |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50394, #51868; opentelemetry-collector#15799 |
| Affected config fields | — |
| Has test coverage | false |

Description: contrib v0.160.0 (#50394) raised the minimum Go version to 1.26 and core v0.160.0 (#15799) bumped every go.mod to 1.26.0 (99 modules move 1.25.0 -> 1.26.0, plus one new module already at 1.26.0). Separately contrib #51868 (OPEN) reports that compiling with Go 1.27 yields a binary that panics immediately with 'crypto: RegisterHash of unknown hash function' from SermoDigital/jose — build-clean, runtime-fatal. The usable toolchain window for the rebase is therefore Go 1.26 only, and a stale ART/Konflux builder image fails the build outright.

Recommended action: Confirm RHEL go-toolset 1.26 is available for x86_64, aarch64, ppc64le and s390x in the rhosdt ART group and in konflux-opentelemetry before starting the rebase; update the builder image in redhat-opentelemetry-collector and ocp-build-data, pin away from Go 1.27 until #51868 is resolved, and add a smoke test that actually executes the built binary.

#### CRIT-6 — NetworkPolicy gates shipped ON in the 0.158.0 base were reverted to alpha/off upstream because they can block API server access

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | opentelemetry-operator (operator + collector + target allocator NetworkPolicy) |
| Component type | core |
| Detection methods | issues, changelog, code-diff, feature-gates |
| Upstream PR | open-telemetry/opentelemetry-operator#5654, #5664, #5551 |
| Affected config fields | spec.networkPolicy.enabled, spec.targetAllocator.networkPolicy.enabled, FEATURE_GATES, operator.networkpolicy, operand.networkpolicy |
| Has test coverage | false |

Description: v0.158.0 promoted operator.networkpolicy and operand.networkpolicy to Beta and enabled them by default (#5394); v0.160.0 reverted both to Alpha and disabled them (#5551, #5558, #5621, #5624, #5654, #5664) because the generated policies can block API server access. Downstream rhosdt-3.11 registers both gates at StageBeta and the OpenShift CSV additionally hard-sets FEATURE_GATES: operator.networkpolicy,operand.networkpolicy, so the behaviour is forced on even if the gate default changes. RHOSDT therefore ships, default-on and documented as GA, a feature upstream judged unsafe; after a rebase existing NetworkPolicies may also be reconciled away. Supporting bugs all filed against 0.158.0: #5493, #5551, #5275, #5611, #5657.

Recommended action: Decide deliberately whether RHOSDT keeps network policies on. If keeping them, backport #5493, #5551/#5625, #5611 and #5657 and add the endpointslices watch verb to the CSV; if not, drop the FEATURE_GATES override from the CSV and update the docs. Verify the upgrade path for already-created NetworkPolicy objects.

#### CRIT-7 — Three stable OTTL/transform feature gates removed — passing them aborts collector startup

| Field | Value |
|---|---|
| Category | REMOVED_API |
| Component | transformprocessor / pkg/ottl |
| Component type | processor |
| Detection methods | feature-gates, changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#51242, #51089 |
| Affected config fields | spec.args.feature-gates, processors.transform.error_mode |
| Has test coverage | true |

Description: processor.transform.defaultErrorModeIgnore (removed by #51242), ottl.contexts.enableOTelColContext (promoted stable by #50876 then deleted by #51089) and ottl.PanicDuplicateName (promoted stable by #50873, deleted by #51089) are all gone from the registry. Setting an unregistered gate is a hard error, so any collector started with these in --feature-gates (via spec.args) crash-loops. Functionally: transform error_mode is permanently ignore, OTTL otelcol context inference is permanently on, and duplicate OTTL function-name registration always panics at init.

Recommended action: Grep product docs, distributed-tracing-qe chainsaw tests and shipped OpenTelemetryCollector samples for these gate IDs and strip them from any feature-gates argument list. Add a release-note entry telling users to set error_mode explicitly, and add a start-up smoke test over the full downstream component set to catch an init-time duplicate-name panic.

#### CRIT-8 — receiver.prometheusreceiver.IgnoreScopeInfoMetric promoted Beta -> Stable (removal in v0.164.0)

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | prometheusreceiver |
| Component type | receiver |
| Detection methods | feature-gates, changelog, code-diff |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#47312, #51232 |
| Affected config fields | receiver.prometheusreceiver.IgnoreScopeInfoMetric, receivers.prometheus.config.scrape_configs |
| Has test coverage | true |

Description: contrib v0.162.0 (#47312/#51232) promoted the gate to Stable with WithRegisterToVersion("v0.164.0"). otel_scope_info is no longer consumed for scope-attribute extraction and is converted like any other metric; scope attributes come from otel_scope_-prefixed labels instead. The gate can no longer be disabled, so there is no rollback, and --feature-gates=-receiver.prometheusreceiver.IgnoreScopeInfoMetric now aborts startup. Targets that only publish otel_scope_info lose their scope attributes and gain an extra series.

Recommended action: Verify scope-attribute propagation for the OpenShift user-workload monitoring scrape targets and target-allocator-driven scrapes against the 0.158 baseline. Remove the gate from any QE args, check console plugins and MCOA dashboards for otel_scope_info dependencies, and document the loss of the rollback escape hatch.

#### CRIT-9 — filelog.protobufCheckpointEncoding promoted Beta -> Stable — on-disk checkpoint format locked in, downgrade-unsafe

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | filelogreceiver (pkg/stanza/fileconsumer) |
| Component type | receiver |
| Detection methods | feature-gates, changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#52037 |
| Affected config fields | filelog.protobufCheckpointEncoding, extensions.file_storage.directory, receivers.filelog.storage |
| Has test coverage | true |

Description: Promoted to Stable with WithRegisterToVersion("v0.165.0") by #52037/#43266. Checkpoints are always written as protobuf and the gate can no longer be disabled. Existing JSON checkpoints are read but rewritten as protobuf on next save, so a rollback to a pre-promotion collector build cannot read them and will re-read files from offset 0, duplicating logs. This touches persisted state in the filestorage extension, which on OpenShift is typically a PV-backed log-collection path.

Recommended action: Explicitly test upgrade AND downgrade of filelogreceiver + filestorage with a populated checkpoint directory. Flag the change as downgrade-unsafe in the release notes and document that rollback requires clearing the checkpoint directory if decoding fails.

#### CRIT-10 — Documented top-level topic field was removed upstream for both Kafka receiver and exporter

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | kafkareceiver, kafkaexporter (documentation) |
| Component type | receiver |
| Detection methods | doc-validation |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#44568, #46232, #46917 |
| Affected config fields | topic, traces.topics, metrics.topics, logs.topics, profiles.topics, exclude_topics, traces.topic, topic_from_metadata_key |
| Has test coverage | false |

Description: otel-receivers-kafka-receiver.adoc documents topic: otlp_spans as a top-level key and otel-exporters-kafka-exporter.adoc does the same for the exporter. Upstream removed the deprecated top-level topic/encoding fields (#44568, #46232 for the receiver; #46917 for the exporter). At v0.158.0 the receiver only has per-signal traces.topics / metrics.topics / logs.topics / profiles.topics (plural, a list) with encoding and exclude_topics, and the exporter has per-signal traces.topic / metrics.topic / logs.topic / profiles.topic. With ErrorUnused decoding the documented CRs fail to load.

Recommended action: Rewrite both Kafka doc examples and parameter tables to the per-signal form, document the per-signal defaults (otlp_spans / otlp_metrics / otlp_logs / otlp_profiles) and mention the new exporter keys topic_from_metadata_key and message_key_from_metadata_key.

## High

#### HIGH-1 — receiver.kubeletstats.cpuUsageScrapeBased enabled by default — CPU usage now rate-derived and absent on first scrape

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | kubeletstatsreceiver |
| Component type | receiver |
| Detection methods | changelog, code-diff, feature-gates |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#49477, #50789, #50857 |
| Affected config fields | receiver.kubeletstats.cpuUsageScrapeBased, receivers.kubeletstats.collection_interval, receivers.kubeletstats.metrics |
| Has test coverage | true |

Description: contrib v0.161.0 (#49477/#50789) promoted the gate to beta (on by default). container.cpu.usage, k8s.pod.cpu.usage, k8s.node.cpu.usage and the derived utilization metrics are computed as the rate of the corresponding *.cpu.time counter between scrapes instead of the kubelet's UsageNanoCores, so they are not reported at all on the first scrape and absolute values shift. v0.162.0 (#50857) additionally deprecated k8s.pod.cpu.node.utilization, k8s.pod.memory.node.utilization, k8s.container.cpu.node.utilization and k8s.container.memory.node.utilization.

Recommended action: Compare kubeletstats CPU values before/after on a real OpenShift cluster at short and long collection_interval settings, update alerting that assumes data on the first scrape, check chainsaw tests for hard-coded value assertions, and document the deprecated *.node.utilization metrics plus the opt-out gate.

#### HIGH-2 — PermissiveLabelSanitization promoted to beta (on by default) — underscore-prefixed label names change

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | prometheusreceiver, prometheusexporter, prometheusremotewriteexporter (pkg/translator/prometheus) |
| Component type | receiver |
| Detection methods | changelog, code-diff, feature-gates |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50429, #50584, #50435 |
| Affected config fields | pkg.translator.prometheus.PermissiveLabelSanitization, exporters.prometheus, exporters.prometheusremotewrite, receivers.prometheus |
| Has test coverage | true |

Description: contrib v0.162.0 (#50429/#50584) promoted pkg.translator.prometheus.PermissiveLabelSanitization from alpha to beta. Labels starting with a single underscore are no longer prefixed with key_, affecting the prometheus receiver, prometheus exporter and prometheusremotewrite exporter simultaneously. v0.160.0 (#50435) additionally preserves leading and consecutive underscores in metric and target_info label names when the gate is on. Renamed labels break existing PromQL, recording rules and dashboards.

Recommended action: Diff exposed label names for a representative attribute set before/after and validate series naming end to end against the OpenShift monitoring stack integration. Check multicluster-observability-addon recording rules for dependence on the old sanitization, and document the rename plus the opt-out gate.

#### HIGH-3 — confighttp keepalive reworked: flat fields deprecated, PrioritizeNewKeepalive gate on by default

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | opentelemetry-collector (confighttp keepalive) |
| Component type | core |
| Detection methods | changelog, feature-gates, code-diff |
| Upstream PR | open-telemetry/opentelemetry-collector#14020, #16026 |
| Affected config fields | pkg.confighttp.PrioritizeNewKeepalive, idle_conn_timeout, max_idle_conns, max_idle_conns_per_host, disable_keep_alives, idle_timeout, keep_alives_enabled, keepalive |
| Has test coverage | true |

Description: Core v0.160.0 (#14020) deprecated the flat client fields idle_conn_timeout, max_idle_conns, max_idle_conns_per_host, disable_keep_alives and the server fields idle_timeout, keep_alives_enabled in favour of a keepalive section; setting a deprecated field together with the new section is an error. Core v0.162.0 (#16026) then registered pkg.confighttp.PrioritizeNewKeepalive directly at Beta (on by default), so the nested block takes precedence and configs setting both forms silently honour different values. This affects every confighttp-based component in the downstream build.

Recommended action: Audit downstream default and sample configs for flat keepalive fields and mixed usage (now a hard error), document the migration to the keepalive block, and add a regression test pinning effective idle/keepalive timeouts on otlphttpexporter and the OTLP HTTP receiver after the rebase.

#### HIGH-4 — HTTP server timeouts and keep-alives now enabled by default on five downstream components

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | jaegerreceiver, zipkinreceiver, prometheusremotewritereceiver, jaegerremotesampling, healthcheckextension |
| Component type | receiver |
| Detection methods | code-diff, changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#49316, #51139, #51175 |
| Affected config fields | jaeger.protocols.thrift_http.write_timeout, zipkin.write_timeout, prometheusremotewrite.write_timeout, jaegerremotesampling.http.write_timeout, health_check.write_timeout |
| Has test coverage | false |

Description: All five components previously overrode confighttp.NewDefaultServerConfig() with WriteTimeout=0, ReadHeaderTimeout=0, IdleTimeout=0 and KeepAlivesEnabled=false (TODO referencing #49316). Those overrides were deleted, so they now inherit WriteTimeout=30s, ReadHeaderTimeout=1m, IdleTimeout=1m and KeepAlivesEnabled=true. Clients pushing very large Jaeger-thrift/Zipkin/remote-write payloads, or slow links where a response takes over 30s to write, now have the connection cut; idle connections close after a minute.

Recommended action: Run a soak/load test through the Jaeger, Zipkin and Prometheus remote-write ingest paths on OpenShift with the router in front, verify large-batch ingest still passes in distributed-tracing-qe, and document that the old behaviour requires explicit write_timeout: 0 / idle_timeout: 0 / read_header_timeout: 0.

#### HIGH-5 — Kafka metadata retry settings now actually applied; metadata::retry::max default raised 3 -> 20, metadata::full deprecated

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | kafkareceiver |
| Component type | receiver |
| Detection methods | changelog, code-diff |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50116, #51080 |
| Affected config fields | receivers.kafka.metadata.retry.max, receivers.kafka.metadata.retry.backoff, receivers.kafka.metadata.full, receivers.kafka.partition_processing |
| Has test coverage | false |

Description: contrib v0.162.0 (#50116) raised the metadata::retry::max default from 3 to 20 and — more importantly — the field had been silently unwired since the franz-go migration and is now honored, so a config that explicitly set 3 previously ran with franz-go's 20 and now genuinely retries 3 times. metadata::retry::backoff is now applied in both receiver and exporter, metadata::full is deprecated as a permanent no-op, and a broker outage blocks metadata refresh roughly 7x longer by default. A new partition_processing block (independent, max_buffered_batches, max_in_flight.records/bytes) also lands, requiring autocommit.enable when independent is set.

Recommended action: Check whether any downstream reference config or MCOA template sets metadata::retry::max explicitly — those are the ones whose behavior inverts. Add a QE case for broker-unavailable startup retry timing, confirm reconnection timing has not regressed past test timeouts, and document metadata::full as a no-op plus the new partition_processing block.

#### HIGH-6 — OTTL Base64Decode removed, set() now writes nil by default, non-list slice literals rejected at parse time

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | pkg/ottl (transformprocessor, filterprocessor, routingconnector, tailsamplingprocessor) |
| Component type | processor |
| Detection methods | changelog, code-diff, issues |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50875, #49741, #51833 |
| Affected config fields | ottl.set.allowNil, Base64Decode, Decode, processors.transform.statements, processors.filter |
| Has test coverage | false |

Description: contrib v0.161.0 (#50875) removed the deprecated Base64Decode converter, so statements using it fail to parse and take the collector down at config load (migrate to Decode(..., "base64")). #49741 promoted ottl.set.allowNil to beta then stable and the gate is being removed: set now passes nil through to the target instead of being a no-op, so statements that previously left a field untouched now clear it — silent data mutation. #51833 additionally rejects literal values that are not lists for slice arguments (e.g. keep_keys(attributes, "http.method")) at parse time instead of per execution.

Recommended action: Grep openshift-docs OTTL examples and QE fixtures for Base64Decode( and for single-string arguments to keep_keys/Concat. The set-nil change needs an explicit QE case rather than a config grep, since it is a silent behaviour change on working statements.

#### HIGH-7 — resource_to_telemetry_conversion deprecated in favour of resource_constant_labels — documented downstream

| Field | Value |
|---|---|
| Category | DEPRECATION |
| Component | prometheusexporter, prometheusremotewriteexporter, awsemfexporter |
| Component type | exporter |
| Detection methods | changelog, code-diff, feature-gates, doc-validation |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#48861, #48862, #50009 |
| Affected config fields | exporters.prometheus.resource_to_telemetry_conversion, exporters.prometheusremotewrite.resource_to_telemetry_conversion, exporters.awsemf.resource_to_telemetry_conversion, exporters.prometheus.resource_constant_labels |
| Has test coverage | true |

Description: contrib v0.160.0 (#48861, #48862, #50009) deprecated resource_to_telemetry_conversion in the prometheus and prometheusremotewrite exporters in favour of resource_constant_labels (included/excluded patterns) and deprecated the legacy enabled / exclude_service_attributes subfields in awsemf, each behind a new disable gate. New validation makes setting both blocks an error, and the factories now log a deprecation warning. The option is documented as a supported product feature in otel-exporters-prometheus-exporter.adoc, otel-exporters-aws-emf-exporter.adoc, otel-collector-config-options.adoc and otel-config-send-metrics-monitoring-stack.adoc.

Recommended action: Update the four openshift-docs modules to document resource_constant_labels (and included/excluded for awsemf) as the forward path while noting the deprecated field still works today, verify equivalence for the OpenShift monitoring-stack integration, and track the Alpha->Beta gate flip as the breaking event.

#### HIGH-8 — Exporter queue/batch internal telemetry metrics redefined and queueBatchEnabled gate introduced

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | opentelemetry-collector (exporterhelper) |
| Component type | core |
| Detection methods | changelog, feature-gates |
| Upstream PR | open-telemetry/opentelemetry-collector#14674, #15690 |
| Affected config fields | pkg.exporterhelper.queueBatchEnabled, sending_queue.batch.partition.idle_timeout, sending_queue.batch.partition.cache_size, processors.batch |
| Has test coverage | true |

Description: Core v0.159.0 (#14674) moved otelcol_exporter_queue_batch_send_size and _bytes from enqueue time to the obs-report sender, so they measure the post-batching request and are no longer emitted at all for exporters without sending_queue::batch; the enqueue-time values moved to new otelcol_exporter_enqueue_size/_bytes metrics. The same release added the Alpha gate pkg.exporterhelper.queueBatchEnabled (#15690), which flips batch::enabled true in NewDefaultQueueConfig and is the mechanism by which batchprocessor is eventually superseded. v0.162.0 raised the batch partition idle timeout to 90s and added a cache_size cap of 10000.

Recommended action: Update downstream dashboards, the distributed-tracing-console-plugin and SRE runbooks charting otelcol_exporter_queue_batch_send_size* — for non-batching exporters these series disappear entirely, which reads as an outage. Decide and document whether the product keeps recommending batchprocessor or moves to exporter-side batching, with a throughput/memory comparison before the gate flips.

#### HIGH-9 — Operator requires new RBAC: kube-system get, discovery.k8s.io endpointslices watch, batch jobs/cronjobs

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | opentelemetry-operator (RBAC / ART CSV) |
| Component type | core |
| Detection methods | changelog, code-diff, issues |
| Upstream PR | open-telemetry/opentelemetry-operator#5689, #5551, #5527 |
| Affected config fields | config/rbac/role.yaml, batch/cronjobs, batch/jobs, discovery.k8s.io/endpointslices |
| Has test coverage | false |

Description: Three operator changes expand the ClusterRole and the downstream CSV must follow or features degrade silently. #5689 (0.161.0): OpAMP bridge standalone agent instance IDs need get on the kube-system namespace. #5551 (0.161.0): the operator watches EndpointSlices of default/kubernetes to keep the TA NetworkPolicy current, needing watch on discovery.k8s.io/endpointslices — the rhosdt CSV grants only get and list. #5527 (0.160.0): k8sattributes CronJob/Job label extraction requires get/list/watch on batch/jobs and batch/cronjobs; the downstream CSV lists only jobs while upstream main lists cronjobs and jobs.

Recommended action: Diff config/rbac/role.yaml between the base tag and origin/main and port every addition into the downstream bundle ClusterRole, rather than hand-merging. Missing permissions cause silent feature degradation, not startup failure, so add a post-install RBAC assertion to QE.

#### HIGH-10 — Jaeger Thrift decoder memory-amplification DoS fixed

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | jaegerreceiver |
| Component type | receiver |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#49218 |
| Affected config fields | receivers.jaeger.protocols.thrift_http |
| Has test coverage | true |

Description: contrib v0.162.0 (#49218) bounds the Thrift decoder's max message size to the HTTP request body length. Before the fix a small crafted Thrift HTTP payload could make the decoder allocate far more memory than the request body, letting an unauthenticated client OOM any collector exposing the Jaeger receiver's Thrift HTTP endpoint — commonly exposed via an OpenShift Route downstream.

Recommended action: Treat as a security-relevant fix in the release notes and evaluate a backport to the shipped rhosdt branch rather than waiting for the rebase.

#### HIGH-11 — Unauthenticated empty UDP datagram on port 6831/6832 crashes the entire collector process (OPEN upstream)

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | jaegerreceiver |
| Component type | receiver |
| Detection methods | issues |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#51973 |
| Affected config fields | receivers.jaeger.protocols.thrift_compact, receivers.jaeger.protocols.thrift_binary |
| Has test coverage | false |

Description: contrib #51973, OPEN as of 2026-10-12: a single zero-length UDP datagram to the Jaeger Thrift compact/binary UDP receiver causes a nil-pointer dereference in an unrecovered goroutine, terminating the whole collector. The pooled TBufferedReadTransport has a nil readBuf until Write is called and an empty datagram skips that path. UDP is connectionless and unauthenticated, so anything that can reach the pod port can crash-loop the collector; jaegerreceiver is in the downstream build.

Recommended action: Confirm whether the Jaeger UDP protocols are reachable in supported RHOSDT configurations, track #51973 and consider a downstream patch; advise customers not to expose the UDP ports beyond the pod network and assess whether this warrants a security tracker.

#### HIGH-12 — PRW receiver native histogram bucket spans could drive unbounded memory and CPU

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | prometheusremotewritereceiver |
| Component type | receiver |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50286, #50292 |
| Affected config fields | — |
| Has test coverage | true |

Description: contrib v0.160.0 (#50286) stops native histogram bucket spans from driving unbounded memory and CPU use and #50292 drops the Prometheus overflow bucket instead of translating it; a remote-write client sending crafted bucket spans could previously exhaust collector resources. A pending entry (#52070) additionally refuses an out-of-range symbol reference on a target_info series, which previously returned 204 with the sample counted as written — silent data loss.

Recommended action: Include in the security/robustness section of the release notes, consider backporting #50286 to the shipped branch, and add a QE case for malformed native-histogram remote-write payloads.

#### HIGH-13 — pprofile negative-index panic and exporterhelper queue deadlock fixed in core

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | opentelemetry-collector |
| Component type | core |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-collector#15697, #15700 |
| Affected config fields | sending_queue.block_on_overflow |
| Has test coverage | true |

Description: Core v0.160.0 (#15697) added bounds checks to FromLocationIndices and switchDictionary; a negative index decoded from an OTLP profiles payload previously panicked the collector via Profiles.MergeTo — remotely triggerable if the OTLP receiver accepts profiles. Core v0.163.0 (#15700) fixed sending-queue deadlocks when blocked offers are cancelled with block_on_overflow enabled, which presents as a stalled pipeline with no error. #15936/#16087 also changed oversized-item handling to drop only the oversized item instead of everything queued behind it.

Recommended action: Confirm whether profiles are enabled in the downstream build and, if so, evaluate #15697 for backport. Add a QE soak test with block_on_overflow enabled under memory pressure, which is a common downstream configuration.

#### HIGH-14 — In-cluster Kubernetes API clients no longer honor environment proxy settings

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | k8sclusterreceiver, k8sobjectsreceiver, k8seventsreceiver, kubeletstatsreceiver, k8sattributesprocessor |
| Component type | receiver |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50937 |
| Affected config fields | HTTP_PROXY, HTTPS_PROXY, NO_PROXY |
| Has test coverage | false |

Description: contrib v0.161.0 (#50937) changed internal/k8sconfig so in-cluster Kubernetes API clients ignore HTTP_PROXY/HTTPS_PROXY. This affects every component built on k8sconfig. On OpenShift clusters with a cluster-wide egress proxy the operator injects proxy env vars into collector pods; previously those clients routed API server traffic through the proxy and now they go direct. Correct behaviour, but an observable connectivity change in proxied and disconnected environments where downstream has far more installs than upstream assumes.

Recommended action: Test the k8s* components on a cluster-wide-proxy OpenShift cluster and in the disconnected CI job before GA, and document the change for customers who added NO_PROXY workarounds.

#### HIGH-15 — Redaction processor summary-attribute ownership reworked, changing chained-processor output

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | redactionprocessor |
| Component type | processor |
| Detection methods | changelog, code-diff |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50770 |
| Affected config fields | processors.redaction.summary, processors.redaction.allow_all_keys, processors.redaction.allowed_keys |
| Has test coverage | true |

Description: contrib v0.163.0 (#50770) reworked how the processor treats its own 14 summary attributes. A processor whose summary is not debug or info no longer claims ownership of a summary it finds, so with allow_all_keys: false it now removes the five summary attributes it previously kept unconditionally unless they are in allowed_keys — and summary is unset by default, which counts as silent. A key inside a log body named after a summary attribute is now redacted like any other unknown key. Previously only five of the fourteen attributes survived a second redaction processor.

Recommended action: Re-baseline QE assertions on redaction output attributes, verify the downstream redaction e2e covers a chained configuration, and flag the change in release notes for anyone running two redaction processors in a pipeline.

#### HIGH-16 — Collector ConfigMap YAML rendering rewritten; fixes a startup-failure bug present in the 0.158.0 base

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | opentelemetry-operator (collector ConfigMap rendering) |
| Component type | core |
| Detection methods | issues, code-diff, changelog |
| Upstream PR | open-telemetry/opentelemetry-operator#4314 |
| Affected config fields | spec.config |
| Has test coverage | true |

Description: Operator 0.160.0 (#4314) fixed string values that look like numbers, booleans, timestamps or special floats ("0e12", ".inf") being written unquoted into the generated ConfigMap, which made the collector parse them as a different type and crash-loop — a bug the 0.158.0 base carries. Config.Yaml() was reimplemented in apis/v1beta1/config_yaml.go using go.yaml.in/yaml/v3 with SetIndent(2), integral-float normalization and round-trip verification; the webhook now rejects CRs whose config cannot be rendered faithfully and warns when service.telemetry cannot be parsed. Side effect: every existing ConfigMap is reformatted on upgrade, triggering a one-time collector rollout, and golden-file assertions break. Known limitation: a map key << does not round-trip.

Recommended action: Backport #4314 to rhosdt-3.11 or document quoting as the workaround. Re-baseline chainsaw/e2e assertions comparing ConfigMap content, expect a one-time collector restart across all managed collectors on upgrade, and verify unusual scalar values are not newly rejected at admission.

#### HIGH-17 — Resource detection now retries with exponential backoff by default, and the resource-provider Go API changed

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | resourcedetectionprocessor |
| Component type | processor |
| Detection methods | code-diff |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#47218 |
| Affected config fields | processors.resourcedetection.retry.enabled, processors.resourcedetection.retry.max_elapsed_time, processors.resourcedetection.timeout |
| Has test coverage | false |

Description: config.go adds Retry configretry.BackOffConfig with a Validate() that errors when retry.enabled is true and both timeout and retry.max_elapsed_time are 0; factory.go defaults to Enabled: true, InitialInterval 1s, Multiplier 2, MaxInterval 30s, MaxElapsedTime 0, and getResourceProvider/CreateResourceProvider now take a BackOffConfig instead of a time.Duration. Previously each detector made a single attempt bounded by the 5s client timeout; failing detectors (openshift, ec2, k8snode on a cluster where the metadata endpoint is unreachable) are now retried, which can delay or stall collector startup where it previously failed fast.

Recommended action: Test the downstream-documented detectors on a cluster where detection fails and confirm startup still completes; document the new retry block and update any downstream code calling CreateResourceProvider for the new signature.

#### HIGH-18 — Sending queue / batching switched on by default via configoptional.Some

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | loadbalancingexporter, awscloudwatchlogsexporter |
| Component type | exporter |
| Detection methods | code-diff |
| Upstream PR | — |
| Affected config fields | exporters.loadbalancing.sending_queue, exporters.awscloudwatchlogs.sending_queue.batch |
| Has test coverage | false |

Description: loadbalancingexporter/factory.go changes QueueSettings from configoptional.Default(...) to configoptional.Some(...), making the sending queue active by default rather than only when the user declares the block; awscloudwatchlogsexporter likewise promotes queueSettings.Batch to configoptional.Some. This changes memory footprint, backpressure semantics and data-loss-on-shutdown characteristics for the loadbalancing exporter, which is the documented downstream pattern for tail-sampling fan-out.

Recommended action: Validate the documented loadbalancing + tailsampling topology under load after the rebase (queue-full and data-loss metrics), document the new defaults, and check whether downstream examples need an explicit sending_queue: enabled: false to preserve prior behaviour.

#### HIGH-19 — Top-level HTTP client settings deprecated in favour of a nested http block, behind a gate that rejects them

| Field | Value |
|---|---|
| Category | DEPRECATION |
| Component | prometheusremotewriteexporter |
| Component type | exporter |
| Detection methods | code-diff, feature-gates, doc-validation |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#49755 |
| Affected config fields | exporters.prometheusremotewrite.endpoint, exporters.prometheusremotewrite.tls, exporters.prometheusremotewrite.headers, exporters.prometheusremotewrite.http |
| Has test coverage | true |

Description: #49755 adds a nested HTTP confighttp.ClientConfig field and a custom Unmarshal that copies the squashed top-level ClientConfig into HTTP unless exporter.prometheusremotewritexporter.removeTopLevelHTTPSettings is enabled; with the gate on, any of 19 top-level keys (endpoint, tls, headers, auth, compression, proxy_url, ...) is a hard config error. Compression validation already reads cfg.HTTP.Compression. Every documented downstream PRW config, including openshift-docs, uses the flat form, so the Alpha->Beta flip breaks all of them at validation time.

Recommended action: Migrate openshift-docs PRW examples and QE manifests to the nested http: form now, noting both forms are accepted today, and add a QE config using the nested form with the gate enabled so the migrated shape is proven before the default flips.

#### HIGH-20 — Routing connector now parses and validates all OTTL statements during config validation

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | routingconnector |
| Component type | connector |
| Detection methods | code-diff |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#51748 |
| Affected config fields | connectors.routing.table |
| Has test coverage | false |

Description: config.go Validate() now builds a parser collection and calls parseRoutingStatement for every non-request table entry, joining parse errors (#51748). A routing table whose OTTL previously only failed at runtime, or silently never matched, now blocks collector startup. The factory was also restructured into NewFactoryWithOptions with private OTTL function maps stored on Config, a Go API change for downstream code that constructs the config struct directly.

Recommended action: Run existing routingconnector e2e configs against the new build to confirm they still parse, and note that zero-value Config construction in downstream tests or distro code must now go through the factory.

#### HIGH-21 — v1beta1 language image is now required, and v1alpha1->v1beta1 conversion silently drops imageless language blocks

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | opentelemetry-operator apis (v1beta1 Instrumentation) |
| Component type | auto_instrumentation |
| Detection methods | code-diff |
| Upstream PR | — |
| Affected config fields | Instrumentation.spec.java.image, Instrumentation.spec.nodejs.image, Instrumentation.spec.python.image, Instrumentation.spec.dotnet.image, Instrumentation.spec.go.image, Instrumentation.spec.apacheHttpd.image, Instrumentation.spec.nginx.image |
| Has test coverage | true |

Description: CommonLanguageSpec.Image changes from +optional/omitempty to Required with MinLength=1, and all seven language fields on InstrumentationSpec change from value types to pointers. instrumentation_conversion.go adds toV1beta1Java/NodeJS/... helpers that return nil when in.Image == "", so a v1alpha1 Instrumentation configuring only env or resourceRequirements for a language (relying on the operator's defaulted image) loses that whole block on conversion. The Instrumentation CRD currently serves only v1alpha1, so impact is latent today but becomes data loss the moment v1beta1 is served.

Recommended action: Confirm the downstream bundle still serves only v1alpha1 for Instrumentation, track the conversion-drop as a blocker before v1beta1 is enabled downstream, and raise it upstream if the defaulting webhook does not run before conversion.

#### HIGH-22 — New pkg.stanza.addDefaultScopeName gate registered directly at Beta (on by default)

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | filelogreceiver, journaldreceiver (pkg/stanza) |
| Component type | receiver |
| Detection methods | feature-gates, changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#51160, #51084, #51284, #41672 |
| Affected config fields | pkg.stanza.addDefaultScopeName, operators.container.format, receivers.filelog, receivers.journald |
| Has test coverage | true |

Description: contrib v0.162.0/v0.163.0 (#51160, #51084) registered pkg.stanza.addDefaultScopeName at Beta, so stanza-based receivers now populate a default Scope.name and Scope.version on log entries that previously had an empty scope. Downstream consumers that filter, route or deduplicate on an empty scope name — transform/filter statements, logging-view-plugin queries — see different data. The same window also fixed the container parser rejecting containerd logs with a UTC-offset timestamp (#51284, an outright log-drop bug), rewrote the CRI regexes as hand-written parsers for roughly 70% less CPU on the hot path (#41672), and fixed strptime %Z being matched as Zulu (#50225, #51416).

Recommended action: Check whether the emitted default scope name/version is stable across releases, diff emitted log records in the filelog and journald e2e suites for new scope fields, and document the opt-out. Measure and quote the container-parser CPU reduction, and verify no downstream fixtures encode the old (wrong) %Z behaviour.

#### HIGH-23 — k8sattributes telemetry.disableOldFormatMetrics / enableNewFormatMetrics promoted Alpha -> Beta

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | k8sattributesprocessor |
| Component type | processor |
| Detection methods | feature-gates |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50539 |
| Affected config fields | processor.k8sattributes.telemetry.disableOldFormatMetrics, processor.k8sattributes.telemetry.enableNewFormatMetrics |
| Has test coverage | true |

Description: contrib #50539 promoted both gates to Beta (on by default). The processor's internal telemetry metrics switch to the new naming format and old-format metrics stop being emitted, so any ServiceMonitor, PrometheusRule or dashboard in the product or in multicluster-observability-addon alerting on the old names goes blind. The same PR also removed the deprecated deployment_name_from_replicaset setting.

Recommended action: Grep product dashboards, PrometheusRules and the console plugins for the old k8sattributes internal telemetry metric names and update them before the rebase.

#### HIGH-24 — filelog.allowFileDeletion and filelog.mtimeSortType promoted Alpha -> Beta

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | filelogreceiver (pkg/stanza/fileconsumer) |
| Component type | receiver |
| Detection methods | feature-gates |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50266, #50729 |
| Affected config fields | receivers.filelog.delete_after_read, receivers.filelog.ordering_criteria.mode |
| Has test coverage | true |

Description: #50266 and #50729 promoted both gates to Beta (on by default), so delete_after_read and ordering_criteria.mode: mtime are usable without an explicit gate. The risk is filelog.allowFileDeletion: a config setting delete_after_read: true was previously inert or rejected without the gate and will now actually delete source log files after reading — destructive and irreversible on a customer's node filesystem.

Recommended action: Confirm no shipped sample config, operator-generated config or logging-collection preset sets delete_after_read. Call the behaviour out prominently in release notes since the failure mode is data loss on the host, and add a QE case covering the new default.

#### HIGH-25 — OpenShift/OLM standalone webhook missing env vars for cert-manager autodetection, breaking TargetAllocator mTLS admission

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | opentelemetry-operator (OpenShift standalone webhook) |
| Component type | core |
| Detection methods | issues |
| Upstream PR | open-telemetry/opentelemetry-operator#5660 |
| Affected config fields | spec.targetAllocator.mtls |
| Has test coverage | false |

Description: Operator #5660, fixed in v0.160.0: the standalone OpenShift webhook deployment was not configured with the environment variables required for cert-manager autodetection, so TargetAllocator mTLS admission cannot discover cert-manager when the operator is installed through the OpenShift/OLM path — exactly how RHOSDT is installed. This is a downstream-specific code path with thin upstream CI coverage.

Recommended action: Backport #5660 to rhosdt-3.11 and add a QE case that enables TargetAllocator mTLS on an OLM-installed operator with cert-manager present.

#### HIGH-26 — TargetAllocator endpoint uses a bare service name that does not match NO_PROXY

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | opentelemetry-operator (target allocator) |
| Component type | core |
| Detection methods | issues |
| Upstream PR | open-telemetry/opentelemetry-operator#5586 |
| Affected config fields | spec.targetAllocator.enabled, spec.config.receivers.prometheus.target_allocator.endpoint |
| Has test coverage | false |

Description: Operator #5586, fixed in v0.160.0: the TA endpoint injected into the collector's Prometheus receiver used the bare service name (http://<name>-targetallocator:80), which does not match the standard NO_PROXY entries (.svc, .cluster.local), so Go routes TA discovery requests through the cluster proxy, which typically cannot reach a cluster-internal service. The fix uses the <name>-targetallocator.<namespace>.svc FQDN. OpenShift clusters with a cluster-wide egress proxy are a first-class supported configuration, so 3.11 users hit a silent discovery failure.

Recommended action: Backport #5586 to rhosdt-3.11 and add a proxy-enabled TargetAllocator scenario to the QE matrix.

#### HIGH-27 — Operator crash-loops on clusters with a partial Gateway API CRD bundle

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | opentelemetry-operator (Gateway API detection) |
| Component type | core |
| Detection methods | issues |
| Upstream PR | open-telemetry/opentelemetry-operator#5571 |
| Affected config fields | — |
| Has test coverage | true |

Description: Operator #5571/#5357, fixed in v0.160.0: Gateway API availability was detected by API group presence alone, so a cluster with only part of the bundle (GatewayClass without HTTPRoute) made the operator crash-loop at startup. The fix detects the HTTPRoute kind served in gateway.networking.k8s.io/v1. Partial installs are common on OpenShift where Service Mesh and the Ingress Operator install subsets of the Gateway API CRDs; impact is a total operator outage, not a degraded feature.

Recommended action: Backport #5571 to rhosdt-3.11 and add a QE case installing only GatewayClass to confirm the operator starts.

#### HIGH-28 — NetworkPolicy API server addresses are discovered once at startup and go stale; the fix needs an RBAC verb the CSV lacks

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | opentelemetry-operator (NetworkPolicy API server endpoints) |
| Component type | core |
| Detection methods | issues |
| Upstream PR | open-telemetry/opentelemetry-operator#5551, #5654 |
| Affected config fields | spec.networkPolicy.enabled, spec.targetAllocator.networkPolicy.enabled, discovery.k8s.io/endpointslices |
| Has test coverage | true |

Description: Operator #5551 (fixed 0.161.0) and meta-issue #5654 (OPEN): the IP blocks allowing egress to the Kubernetes API server are resolved exactly once at operator startup from the default/kubernetes EndpointSlices. On managed or shared control planes the IPs change and the policy silently starts blocking API server access; the policy is also not reconciled when networkPolicy.enabled is set back to false. The fix watches EndpointSlices but requires watch on discovery.k8s.io/endpointslices, while the downstream CSV grants only get and list — a backport without the RBAC change leaves the policy permanently stale.

Recommended action: If backporting #5551/#5625, add watch to the discovery.k8s.io/endpointslices rule in both the ART CSV and config/rbac/role.yaml in the same change. Track #5654 before committing to NetworkPolicy support for the OpenTelemetryCollector CR.

#### HIGH-29 — k8s_events receiver silently stalls forever on 0.158.0 — the exact version shipped downstream

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | k8seventsreceiver |
| Component type | receiver |
| Detection methods | issues |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#51982 |
| Affected config fields | receivers.k8s_events |
| Has test coverage | false |

Description: contrib #51982, OPEN as of 2026-10-12: the k8s_events receiver stops delivering events and never recovers. The pod stays Running with no restarts and logs nothing at WARN (the RetryWatcher retry loop logs only at klog V(1)/V(4)/V(5)) and the observer never re-lists. Observed on 8 of 12 clusters, all running 0.158.0, with otelcol_receiver_accepted_log_records flat for days. Only a restart recovers. A short-lived e2e run will not catch a multi-day stall. Related fix v0.162.0 (#49962) keeps the watcher retrying after a transient failure following a 410 Gone in both k8sevents and k8sobjects.

Recommended action: Track #51982, add a long-running/soak assertion on otelcol_receiver_accepted_log_records for the k8s_events receiver, and brief support that a flat event stream with a healthy-looking pod is a known 0.158.0 symptom with restart as the only remedy.

#### HIGH-30 — Collector defaulting silently discards the entire service.telemetry block when the operator cannot parse it

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | opentelemetry-operator (collector defaulting webhook) |
| Component type | core |
| Detection methods | issues |
| Upstream PR | open-telemetry/opentelemetry-operator#5734 |
| Affected config fields | spec.config.service.telemetry, spec.config.service.telemetry.logs, spec.config.service.telemetry.resource |
| Has test coverage | true |

Description: Operator #5734, fixed after 0.158.0: GetTelemetry returns nil both when service.telemetry is absent and when it fails to unmarshal into the operator's Telemetry type (for example otelconf v0.3.0 readers, or resource as map[string]*string), and in both cases ServiceApplyDefaults replaces the whole block with the default Prometheus reader. The object is admitted with no error and no warning and every other telemetry setting (logs, resource, traces) is lost. The reporter's reproducer passes otelcol validate, so the config is valid — the operator just cannot model it.

Recommended action: Backport #5734 to rhosdt-3.11 and add a QE case asserting a declarative service.telemetry.resource.attributes block survives admission unmodified.

#### HIGH-31 — Documented export_created_metric option no longer exists upstream

| Field | Value |
|---|---|
| Category | REMOVED_API |
| Component | prometheusremotewriteexporter (documentation) |
| Component type | exporter |
| Detection methods | doc-validation |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#38662 |
| Affected config fields | export_created_metric |
| Has test coverage | false |

Description: otel-exporters-prometheus-remote-write-exporter.adoc shows export_created_metric: true in the YAML example and documents it. The field was deleted upstream in #38662 and is absent from the exporter config at v0.158.0; with strict unknown-key decoding the documented CR fails to load.

Recommended action: Delete export_created_metric from the example YAML and the parameter list; if _created series are still needed, point users at protobuf_message: io.prometheus.write.v2.Request.

#### HIGH-32 — target_info is documented as a boolean but upstream it is a struct with an enabled field

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | prometheusremotewriteexporter (documentation) |
| Component type | exporter |
| Detection methods | doc-validation |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#12724 |
| Affected config fields | target_info, target_info.enabled |
| Has test coverage | false |

Description: The doc shows target_info: true. Upstream defines TargetInfo as a struct with a single enabled sub-field (default true), introduced in #12724. Decoding the scalar true into a struct is a decode error, so the documented snippet is not loadable.

Recommended action: Change the example to target_info: {enabled: true} and update the parameter description to document target_info.enabled (default true).

#### HIGH-33 — Config options reference lists three components that no longer exist upstream

| Field | Value |
|---|---|
| Category | DOC_STALE |
| Component | collector core (otel-collector-config-options.adoc) |
| Component type | core |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | receivers.opencensus, processors.routing, extensions.memory_ballast |
| Has test coverage | false |

Description: The Values column lists opencensus as an available receiver, routing as an available processor and memory_ballast as an available extension. None exist in contrib at v0.158.0 (routing is now a connector) and none are in redhat-opentelemetry-collector/manifest.yaml. The same table also lists the deprecated aliases otlp/otlphttp, resourcedetection/k8sattributes and spanmetrics.

Recommended action: Regenerate the component value lists from manifest.yaml: drop opencensus, the routing processor and memory_ballast, and switch to the current upstream type names (otlp_grpc, otlp_http, resource_detection, k8s_attributes, span_metrics).

#### HIGH-34 — Kubernetes client libraries 0.36.3 -> 0.37.1 and controller-runtime 0.24.1 -> 0.25.2

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator |
| Component type | operator |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | true |

Description: The whole k8s.io/* set moves 0.36.3 -> 0.37.1 and sigs.k8s.io/controller-runtime 0.24.1 -> 0.25.2, with konnectivity-client 0.34.0 -> 0.36.0, kube-openapi and sigs.k8s.io/json refreshes and gateway-api 1.6.1 -> 1.6.3; the Makefile envtest KUBE_VERSION moves 1.36 -> 1.37. controller-runtime minor bumps historically change manager/webhook/cache option signatures and client semantics, and a client-go minor bump can drop deprecated API group versions.

Recommended action: Rebase the downstream branch onto the new k8s/controller-runtime set in a scratch build first, verify the operator compiles, confirm the OCP version targeted by the next RHOSDT release is compatible with client-go 0.37, and re-run envtest with ENVTEST_K8S_VERSION=1.37.

#### HIGH-35 — buraksezer/consistent major bump v0.10.0 -> v1.1.0 (consistent hashing)

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator (target allocator) |
| Component type | operator |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | TargetAllocator.spec.allocationStrategy |
| Has test coverage | true |

Description: This is the consistent-hashing library behind the target allocator's consistent-hashing allocation strategy. A v0 -> v1 major bump needs no import-path change, so the compiler flags nothing. If hash-ring construction, partition count defaults or member hashing changed, target-to-collector assignments get redistributed on upgrade, causing a one-time scrape reshuffle with duplicate or momentarily dropped scrapes.

Recommended action: Diff v0.10.0..v1.1.0 for changes to Config defaults (PartitionCount, ReplicationFactor, Hasher) and LocateKey/GetPartitionOwner behavior, run the allocation unit tests and an e2e scrape-continuity test across the upgrade, and call out any ring reshuffle in release notes.

#### HIGH-36 — controller-tools v0.21.0 -> v0.23.0 regenerates CRDs

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator |
| Component type | operator |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | false |

Description: CONTROLLER_TOOLS_VERSION moves two minor releases. controller-gen minor bumps routinely change CRD OpenAPI emission — marker handling, x-kubernetes-validations/CEL rule generation, defaulting and description trimming — so the generated CRD YAML in the downstream bundle can differ structurally with no Go type change. kustomize, kind, golangci-lint and govulncheck also bump.

Recommended action: Regenerate CRDs with controller-gen v0.23.0 on the downstream branch and diff against the shipped RHOSDT bundle; check for CRD size growth against OpenShift etcd/annotation limits and for newly emitted CEL rules that would reject previously accepted CRs.

#### HIGH-37 — ordering_criteria.top_n: 0 semantics changed from 1 to "match all files"

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | filelogreceiver |
| Component type | receiver |
| Detection methods | changelog, code-diff, issues |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#47444 |
| Affected config fields | receivers.filelog.ordering_criteria.top_n, receivers.filelog.ordering_criteria.sort_by, filelog.requireExplicitTopN |
| Has test coverage | false |

Description: contrib v0.159.0 (#47444): top_n: 0 now means match all files instead of silently behaving like top_n: 1, so a config that set 0 goes from tailing one file to tailing every matching file — multiplying ingested volume and open file handles on a log-collection DaemonSet. The same PR added the filelog.requireExplicitTopN gate (off by default) that will later make an unset top_n with sort_by configured a startup error. The change lives in pkg/stanza/fileconsumer, so it is not visible in the receiver's config.go diff.

Recommended action: Grep downstream filelog examples, openshift-docs and MCOA/logging-view configs for top_n: 0 and for sort_by without an explicit top_n, set explicit values, and flag the change in the rebase release notes.

## Medium

#### MED-1 — Tail sampling now declares that it mutates data and moves spans out of incoming batches

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | tailsamplingprocessor |
| Component type | processor |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#51920, #49828 |
| Affected config fields | processors.tail_sampling.policies.composite.rate_allocation |
| Has test coverage | true |

Description: contrib v0.163.0 (#51920) moves spans out of incoming batches instead of copying them and declares MutatesData: true. Declaring mutation changes pipeline topology: when a receiver fans out to multiple pipelines the collector must clone data before this processor, shifting memory and CPU cost. Related fixes: #50623 reuses the original decision's threshold when rewriting tracestate for late spans, #49907 drops processor state when TailStorage.Take fails, and #49828 fixes composite sub-policies omitted from rate_allocation getting a zero rate that permanently blocked sampling.

Recommended action: Benchmark tail sampling memory with a multi-pipeline fan-out config before GA, and call out the composite rate_allocation fix — affected users were silently sampling nothing.

#### MED-2 — File exporter race condition caused silent data loss; file storage extension nil-pointer crash

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | fileexporter, file_storage extension |
| Component type | exporter |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#49228, #49735 |
| Affected config fields | exporters.file.group_by.max_open_files, exporters.file.rotation, extensions.file_storage |
| Has test coverage | true |

Description: contrib v0.163.0 (#49228) fixed a race where a file exporter writer could be closed while still in use, silently losing data with no error and no metric; #51515 now rejects group_by.max_open_files <= 0 and negative rotation values at validation. Separately v0.160.0 (#49735) fixed a nil pointer crash in the file_storage extension when bbolt compaction fails during startup after database corruption, which crashes the collector at startup for any config using persistent queues.

Recommended action: Evaluate #49735 for backport since persistent queues are a documented downstream pattern, and add a QE case that starts the collector against a corrupted bbolt file.

#### MED-3 — ECS detector panic, gcp timeout ignored, fail_on_missing_metadata not honored for ec2

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | resourcedetectionprocessor |
| Component type | processor |
| Detection methods | changelog, issues |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50754, #50826, #52074 |
| Affected config fields | processors.resourcedetection.timeout, processors.resourcedetection.ec2.fail_on_missing_metadata, processors.resourcedetection.detectors |
| Has test coverage | true |

Description: Pending #52074: the ECS detector panicked with index-out-of-range on a task ARN with only 5 colon-separated parts (parseTaskARN checked for at least 5 but read the 6th). v0.162.0 (#50754): the gcp detector did not honor the configured timeout when the metadata server is unreachable, so startup could hang far longer than configured on any non-GCP cluster with the detector enabled. v0.163.0 (#50826): fail_on_missing_metadata is now honored for the ec2 detector's instance identity document and hostname lookups.

Recommended action: Verify startup time on a bare-metal/vSphere cluster with the gcp detector configured, since OpenShift clusters often enable multiple detectors defensively. Confirm the ecs detector is not referenced in any supported configuration or doc example.

#### MED-4 — Startup panic on invalid exclude regex, memory leak on custom association identifiers, new duplicate-association validation

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | k8sattributesprocessor |
| Component type | processor |
| Detection methods | changelog, code-diff |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50957, #48588, #49269 |
| Affected config fields | processors.k8sattributes.exclude.pods, processors.k8sattributes.pod_association, processors.k8sattributes.extract.labels.from |
| Has test coverage | true |

Description: v0.162.0 (#50957) now rejects an invalid exclude.pods[].name regex at config load instead of panicking at startup; config.go also adds a duplicate pod_association check (#49269), so two association entries listing the same sources in any order is a new hard error for configs that previously loaded. v0.159.0 (#48588) fixed a memory leak and incorrect deletion for custom association identifiers going through active->stale->active transitions. v0.162.0 (#51188) makes the semconv deprecation warnings actually reachable, so operators will suddenly see warnings they never saw before. New valid extract sources replicaset and cronjob were added.

Recommended action: Verify the downstream default and documented k8sattributes configs contain no duplicate associations, call out the #48588 leak for long-running production collectors, brief support on the new warning noise on upgrade, and document the new replicaset/cronjob sources.

#### MED-5 — TargetAllocatorSpec.FilterStrategy changed from value to pointer; new none enum value

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | opentelemetry-operator apis (TargetAllocator) |
| Component type | core |
| Detection methods | changelog, code-diff, issues |
| Upstream PR | open-telemetry/opentelemetry-operator#5444 |
| Affected config fields | spec.targetAllocator.filterStrategy, TargetAllocator.spec.filterStrategy |
| Has test coverage | true |

Description: Operator 0.159.0 (#5444) changed the Go type to *v1beta1.TargetAllocatorFilterStrategy so typed clients can distinguish unset from configured, and widened the enum from "";relabel-config to "";none;relabel-config. The legacy empty value stays accepted as an alias for disabling filtering, and the TA normalizes "" to none while rejecting any other value at startup. CRD-level this is backward compatible, but downstream Go consumers of the apis module (multicluster-observability-addon, console plugin, QE tooling) will not compile.

Recommended action: Grep multicluster-observability-addon and other repos vendoring opentelemetry-operator/apis for FilterStrategy and update for the pointer type before the rebase; document none as the preferred value and add the change to the API-compatibility release notes.

#### MED-6 — Operator skips GOMEMLIMIT/GOMAXPROCS injection when the cgroup_runtime extension is enabled

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | opentelemetry-operator |
| Component type | core |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-operator#5651 |
| Affected config fields | extensions.cgroup_runtime, GOMEMLIMIT, GOMAXPROCS |
| Has test coverage | false |

Description: Operator 0.161.0 (#5651) stops setting the automatic GOMEMLIMIT and GOMAXPROCS environment variables when the collector config enables the cgroup_runtime extension (the deprecated cgroupruntime type name is also recognized), each skipped only while its gomemlimit.enabled / gomaxprocs.enabled setting is true. Collectors relying on the operator-injected values while also enabling the extension get limits from the extension's cgroup reading instead, which can differ on OpenShift where limits and requests diverge.

Recommended action: Verify the resulting GOMEMLIMIT on an OpenShift collector pod that enables cgroup_runtime, especially where the memory limit is much larger than the request, and confirm memory_limiter thresholds still line up.

#### MED-7 — Kubernetes resolver routed traffic to stale and not-ready endpoints

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | loadbalancingexporter |
| Component type | exporter |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50436, #50741 |
| Affected config fields | exporters.loadbalancing.resolver.k8s |
| Has test coverage | true |

Description: contrib v0.161.0 (#50741) removes stale Kubernetes endpoints when a relist recovers a missed watch deletion, and #50436 skips endpoints whose EndpointSlice conditions.ready is explicitly false. Before these fixes the exporter routed spans to backend pods that were gone or not ready, producing export errors and trace fragmentation in exactly the tail-sampling-behind-loadbalancing topology the product documents. v0.160.0 (#49725) also removed quadratic re-hashing in per-endpoint metric batching.

Recommended action: Add a QE case that scales the backend StatefulSet down during load and asserts no export errors, since pod churn is routine on OpenShift.

#### MED-8 — Histogram reset recovery and exponential bucket diff fixes

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | cumulativetodeltaprocessor |
| Component type | processor |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50828, #51303 |
| Affected config fields | — |
| Has test coverage | true |

Description: contrib v0.162.0 (#50828) fixed histogram and exponential histogram reset recovery by updating prevPoint on reset detection, and v0.163.0 (#51303) fixed ExponentialBuckets.Diff missing a reset when old buckets precede the current histogram offset. Both produced silently wrong delta values after a counter reset rather than an error, so downstream consumers saw corrupted histogram data with no signal.

Recommended action: Call out as a correctness fix in the release notes — customers who saw implausible histogram deltas after pod restarts have an explanation — and confirm the downstream e2e metrics tests exercise a counter reset.

#### MED-9 — shared_cache leaked state across batches; exponential-to-explicit histogram conversion was wrong

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | transformprocessor |
| Component type | processor |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#51087, #50737 |
| Affected config fields | processors.transform.shared_cache |
| Has test coverage | true |

Description: contrib v0.160.0 (#50563) added the shared_cache option to statement lists and v0.162.0 (#51087) immediately fixed it so each batch receives a fresh cache — before the fix cache state leaked across batches, a cross-tenant data-mixing hazard in a shared collector. v0.162.0 (#50737) separately fixed exponential-to-explicit histogram conversion. shared_cache shipped broken in the version immediately before the fix.

Recommended action: Do not document or enable shared_cache if the rebase lands on v0.160.0 or v0.161.0; it is only safe from v0.162.0. Add a QE case asserting cache isolation between batches.

#### MED-10 — OTLP receiver reported client errors as 500 when Content-Type was unsupported or malformed

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | otlpreceiver |
| Component type | receiver |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-collector#15995 |
| Affected config fields | receivers.otlp.protocols.http |
| Has test coverage | true |

Description: Core v0.162.0 (#15995) fixed the error handler so it preserves the HTTP status code when the request Content-Type is not one a Status can be encoded in. Previously an unsupported or malformed Content-Type fell through to 500 with 'failed to marshal error message', reporting genuine client errors — 401 from a server auth extension, 400 from an unsupported Content-Encoding — as server faults. OpenShift customers commonly front the OTLP HTTP receiver with oidc/bearertokenauth, so auth failures were surfacing as collector 500s and misdirecting triage.

Recommended action: Note in the release notes that auth rejections on the OTLP HTTP endpoint now correctly return 4xx; monitoring keyed on collector 5xx rates will see a drop that is a fix, not a regression.

#### MED-11 — Watchers gave up after a transient failure following a 410 Gone

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | k8seventsreceiver, k8sobjectsreceiver |
| Component type | receiver |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#49962 |
| Affected config fields | receivers.k8s_events, receivers.k8sobjects |
| Has test coverage | true |

Description: contrib v0.162.0 (#49962) keeps the watcher retrying in both receivers when retrieving a fresh resource version after a 410 Gone fails transiently. Before the fix the watcher stopped permanently, so the receiver silently produced no further events until restart — data loss with no crash and no obvious error. #51262 also moved k8sevents metric units to singular form.

Recommended action: Consider backporting and add a QE case that forces a 410 Gone and asserts the watcher recovers.

#### MED-12 — Dropped records from healthy partitions and stale offset metrics on revoke

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | kafkareceiver |
| Component type | receiver |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#51852, #50753 |
| Affected config fields | receivers.kafka.message_marking.after, receivers.kafka.autocommit.enable, receivers.kafka.partition_processing.max_in_flight.records |
| Has test coverage | true |

Description: contrib v0.163.0 (#51852) fixed records from healthy partitions being dropped when a poll also contains a fetch error — a real data-loss path during partial broker trouble. v0.162.0 (#50753) stops processing a fetched batch once the partition consumer is cancelled instead of marking and dropping the rest, another data-loss path during rebalance, and #36093 stops reporting stale offset-lag metrics for revoked partitions, which previously produced permanently wrong consumer-lag alerts.

Recommended action: Consider backporting #51852 and #50753 — they affect the at-least-once delivery guarantees customers assume. Note that with max_in_flight.records above 1 the worker always marks after processing, so message_marking.after: false is ignored.

#### MED-13 — Staleness markers and PRW permanent-error / WAL fixes

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | prometheusexporter, prometheusremotewriteexporter |
| Component type | exporter |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#49691, #51289 |
| Affected config fields | exporters.prometheusremotewrite.external_labels, exporters.prometheusremotewrite.wal |
| Has test coverage | true |

Description: contrib v0.162.0 (#51289) fixed the prometheus exporter removing only some series ended by staleness markers when several arrive in the same metric, leaving ghost series. v0.159.0 (#49691) fixed context.DeadlineExceeded being treated as a permanent error in the remote-write exporter, which dropped metrics instead of retrying on timeout — straightforward silent data loss under load — and #49130 flushes buffered WAL entries when idle. v0.160.0 (#50435) preserves UTF-8 characters in external_labels names.

Recommended action: Call out #49691 for backport evaluation and in the release notes: downstream users sending to slow remote-write endpoints were losing metrics silently.

#### MED-14 — Defaulting webhook panics when spec.config.receivers or spec.config.exporters is missing; --tls-min-version ignored

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | opentelemetry-operator (collector defaulting webhook) |
| Component type | core |
| Detection methods | changelog, issues |
| Upstream PR | open-telemetry/opentelemetry-operator#5735, #3565 |
| Affected config fields | spec.config.receivers, spec.config.exporters, --tls-min-version |
| Has test coverage | true |

Description: Operator #5735 (fixed 0.161.0): the mutating webhook runs before the CRD required-field check, so receivers/exporters can be absent, AnyConfig.Object is nil and component defaulting produces 'panic: assignment to entry in nil map', surfaced as an admission denial. A panicking admission webhook can block all collector CR admissions cluster-wide, and the bug is reachable with a plain kubectl create --dry-run=server. Operator #3565 (also 0.161.0) separately fixed the --tls-min-version CLI flag being ignored because it was matched against the wrong flag name.

Recommended action: Backport #5735 to rhosdt-3.11 so the request is cleanly rejected by CRD validation. The --tls-min-version bug is compliance-relevant: if the downstream CSV passes that flag it has not been taking effect, so verify the shipped CSV and re-run any TLS posture scan against the rebased build.

#### MED-15 — Sidecar injection turns an invalid container-less pod into a valid one and then instruments the collector container

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | opentelemetry-operator (sidecar + instrumentation mutators) |
| Component type | core |
| Detection methods | changelog, issues |
| Upstream PR | open-telemetry/opentelemetry-operator#5737 |
| Affected config fields | sidecar.opentelemetry.io/inject, instrumentation.opentelemetry.io/container-names |
| Has test coverage | true |

Description: Operator #5737, fixed in v0.161.0: with native sidecars off (Kubernetes < 1.29, still supported) the sidecar mutator appends the collector to spec.containers, so a pod with containers: [] — invalid and normally rejected — now passes validation. The instrumentation mutator then runs and, with no container-names annotation, ensureContainer picks Containers[0], which is now otc-container, injecting auto-instrumentation into the collector itself. The operator converts a rejection into a silently wrong workload.

Recommended action: Backport #5737 to rhosdt-3.11 if the release supports OpenShift versions on Kubernetes < 1.29; otherwise record it as not applicable in the rebase notes.

#### MED-16 — queuebatch processor renamed to queue_batch with no alias noted

| Field | Value |
|---|---|
| Category | BREAKING_CHANGE |
| Component | opentelemetry-collector (queue_batch processor) |
| Component type | processor |
| Detection methods | code-diff |
| Upstream PR | open-telemetry/opentelemetry-collector#14396 |
| Affected config fields | processors.queuebatch, processors.queue_batch |
| Has test coverage | false |

Description: Core v1.68.0/v0.162.0 (#14396) renamed the queuebatch processor to queue_batch. Core also removed several deprecated APIs in v0.161.0 (pprofile AggregationTemporality/Duration/SetDuration, scraperhelper controller.AddScraper, service.ZapOptions, xconfmap.WithForceUnmarshaler) and changed generated processor lifecycle tests to assert unchanged context propagation.

Recommended action: Check whether queuebatch appears in any downstream manifest or doc, and update the redhat-opentelemetry-collector builder manifest plus any custom components using the removed core APIs.

#### MED-17 — PHP auto-instrumentation added: new API type, new CLI flags, new image to productize

| Field | Value |
|---|---|
| Category | NEW_FEATURE |
| Component | opentelemetry-operator (PHP auto-instrumentation) |
| Component type | auto_instrumentation |
| Detection methods | code-diff, dependencies, changelog, issues |
| Upstream PR | open-telemetry/opentelemetry-operator#932 |
| Affected config fields | Instrumentation.spec.php, ENABLE_PHP_AUTO_INSTRUMENTATION, RELATED_IMAGE_AUTO_INSTRUMENTATION_PHP |
| Has test coverage | true |

Description: v1alpha1 Instrumentation gains a Php field (Image/VolumeClaimTemplate/Env/Resources); the webhook defaults the PHP image and CPU/memory limits and adds PHP to checkUnupgradableVersions; internal/config adds --enable-php-instrumentation (default false), --auto-instrumentation-php-image, ENABLE_PHP_AUTO_INSTRUMENTATION and RELATED_IMAGE_AUTO_INSTRUMENTATION_PHP defaulting to ghcr.io/opentelemetry-php/autoinstrumentation-php:1.4.1, and versions.txt adds autoinstrumentation-php=1.4.1 wired through the Makefile. Note 0.160.0 (#932) removed the in-repo PHP image definition (packaging SIG now hosts it), so the net end state across the rebase window is ambiguous. rhosdt-3.11 versions.txt has no PHP entry today.

Recommended action: Decide whether RHOSDT productizes a PHP image. If yes: ART image build, a relatedImages entry in the CSV (required for disconnected mirroring), docs and e2e coverage. If no: confirm ENABLE_PHP_AUTO_INSTRUMENTATION stays false and the downstream branch overrides autoInstrumentationPhp so the operator never points users at the ghcr.io image, and confirm no dangling PHP reference lands in ocp-build-data or the CSV.

#### MED-18 — New hostmetrics system-convention gates that mutate a process-global gate at runtime

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | hostmetricsreceiver |
| Component type | receiver |
| Detection methods | feature-gates, code-diff |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50325 |
| Affected config fields | receivers.hostmetrics.scrapers, receivers.hostmetrics.metadata_collection_interval |
| Has test coverage | true |

Description: #50325 adds receiver.hostmetrics.DontEmitV0SystemConventions and EmitV1SystemConventions at Alpha plus the matching scraper.process gates, beginning the system.* semconv migration. createMetricsReceiver calls featuregate.GlobalRegistry().Set(...) on the corresponding process scraper gate when these are set, logging that this affects all process scrapers in the process, not just this receiver instance — so enabling the gate on one hostmetrics instance silently changes conventions for every instance. config.go also now rejects a negative metadata_collection_interval. Given how the identically shaped k8sattributes gates went Alpha->Beta in one cycle, this will flip quickly.

Recommended action: Keep these gates off in the downstream default and document the cross-instance side effect. Inventory which system.* metric names the product documents, prepare a v0->v1 mapping table, and watch for the Alpha->Beta promotion on the next rebase.

#### MED-19 — pkg.ottl.functions.enableDynamicSliceArguments registered at Beta, plus enableExperimental at Alpha

| Field | Value |
|---|---|
| Category | NEW_FEATURE |
| Component | pkg/ottl (transformprocessor, filterprocessor, routingconnector) |
| Component type | processor |
| Detection methods | feature-gates |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#51565 |
| Affected config fields | processors.transform.statements, connectors.routing.table.condition |
| Has test coverage | true |

Description: #51565 registers pkg.ottl.functions.enableDynamicSliceArguments at Beta (on by default, from v0.163.0), allowing slice arguments of stable OTTL functions such as Concat to be paths or converters resolving to a slice at runtime rather than only list literals; #50927/#51564 add pkg.ottl.functions.enableExperimental at Alpha. The Beta gate is a default-on grammar relaxation, so statements that previously failed to parse now succeed and misconfigurations once caught at startup may be silently accepted.

Recommended action: Low immediate risk but note it for the OTTL-based processors. Decide the downstream policy for enableExperimental — if it stays off, document that experimental OTTL functions are unsupported in the Red Hat build.

#### MED-20 — New Alpha gate processor.k8sattributes.EnableKubeletPodSource adds a kubelet /pods metadata source

| Field | Value |
|---|---|
| Category | NEW_FEATURE |
| Component | k8sattributesprocessor |
| Component type | processor |
| Detection methods | feature-gates, code-diff |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#49427 |
| Affected config fields | processors.k8sattributes.kubelet |
| Has test coverage | true |

Description: #49427 registers the gate at Alpha (from v0.164.0), allowing the processor to use kubelet /pods polling as the pod metadata source instead of the Kubernetes API watch, together with a new experimental kubelet config block. Off by default so no behaviour change, but it introduces a new RBAC/permission surface (kubelet read access) and a new failure mode that downstream RBAC manifests and the operator-generated ServiceAccount do not account for.

Recommended action: No action beyond awareness this release. If the product later wants it (it reduces API-server watch load on large clusters), review the operator's generated RBAC and the SCC/kubelet access path first, and keep it out of supported-feature docs while Alpha.

#### MED-21 — Pod webhook strips pod spec fields unknown to the operator's k8s.io/api version, cluster-wide (OPEN upstream)

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | opentelemetry-operator (pod mutating webhook) |
| Component type | core |
| Detection methods | issues |
| Upstream PR | open-telemetry/opentelemetry-operator#5733 |
| Affected config fields | — |
| Has test coverage | false |

Description: Operator #5733, OPEN as of 2026-10-08: the pod webhook decodes the pod into corev1.Pod, re-marshals it and diffs against req.Object.Raw, so any field the vendored corev1.Pod does not know becomes a remove operation in the returned patch. The patch is returned even when no mutator changed anything and the webhook has no namespace or object selector, so it applies to every pod created in the cluster. Any operator running on a Kubernetes newer than its k8s.io/api version is affected (demonstrated: spec.hostnameOverride silently dropped). For RHOSDT this is an OpenShift version-skew hazard when an older operator is left installed across an OpenShift upgrade.

Recommended action: Track #5733 (suggested fix: register the pod webhook with admission.WithDefaulter[*corev1.Pod]). Until fixed, document the supported OpenShift version skew per RHOSDT release and factor it into upgrade-ordering guidance.

#### MED-22 — Two open retry defects cause a retry storm and total metric loss during a backend outage

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | prometheusremotewriteexporter |
| Component type | exporter |
| Detection methods | issues |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#52125, #51983 |
| Affected config fields | exporters.prometheusremotewrite.retry_on_failure.max_interval, exporters.prometheusremotewrite.retry_on_failure.multiplier, exporters.prometheusremotewrite.timeout |
| Has test coverage | false |

Description: contrib #52125 (OPEN): retry_on_failure.max_interval is never passed to the backoff — execute() builds backoff.ExponentialBackOff as a struct literal without MaxInterval, so with MaxInterval 0 each step resets the interval to InitialInterval, waits never grow and multiplier has no effect; the reporter observed a retry storm against an already-struggling backend. contrib #51983 (OPEN): the default 5s timeout caps the total retry window, so all metrics are dropped during an outage. Together a transient backend problem becomes amplified load plus complete data loss.

Recommended action: Track #52125 and #51983. Until fixed, document that retry_on_failure.max_interval has no effect and that timeout must be raised for retries to be useful, and consider a backoff assertion in the PRW QE case.

#### MED-23 — Invalid include/exclude regexp passes startup validation and panics at runtime

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | cumulativetodeltaprocessor |
| Component type | processor |
| Detection methods | issues |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#51963 |
| Affected config fields | processors.cumulativetodelta.include.metrics, processors.cumulativetodelta.exclude.metrics |
| Has test coverage | false |

Description: contrib #51963, OPEN as of 2026-10-11: processor.go discards the errors from filterset.CreateFilterSet and Config.Validate() never compiles the regexps, so an invalid pattern passes startup validation. regexp.NewFilterSet then returns a typed nil that, assigned to the FilterSet interface field, is a non-nil interface holding a nil pointer, so the nil guard is false and Matches panics on the first metric. A config typo produces a collector that starts cleanly and crashes under traffic. Related open #51965: missing NaN sum handling for exponential histograms.

Recommended action: Track #51963 and #51965, and add a negative QE case with an invalid include.metrics regexp asserting the collector fails at startup rather than at first data point.

#### MED-24 — Collector panics on first broker connection when oauthbearer_token_source names an extension without Token(context.Context)

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | internal/kafka (kafkaexporter, kafkareceiver) |
| Component type | exporter |
| Detection methods | issues |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#51958 |
| Affected config fields | auth.sasl.mechanism, auth.sasl.oauthbearer_token_source |
| Has test coverage | false |

Description: contrib #51958, OPEN as of 2026-10-11: with mechanism OAUTHBEARER the referenced extension must implement Token(context.Context) (*oauth2.Token, error), but the type assertion in internal/kafka/franz_client.go is unchecked and runs inside the SASL callback, so the collector starts normally and panics on the first broker connection instead of failing at startup with a config error. The README's loose wording makes this easy to hit, and kafkaexporter, kafkareceiver and oauth2clientauthextension are all in the downstream build.

Recommended action: Track #51958, verify which shipped authenticator extensions actually satisfy the interface, and document the supported pairing so support can recognise the panic signature.

#### MED-25 — gzip log files read while still being written fail permanently with 'gzip: invalid header'

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | filelogreceiver |
| Component type | receiver |
| Detection methods | issues |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#51923 |
| Affected config fields | receivers.filelog.compression |
| Has test coverage | false |

Description: contrib #51923, OPEN as of 2026-10-09: with compression gzip or auto, if the receiver polls a gzip file whose stream is still being written, only the data present at the first poll is read. ReadToEnd sets r.Offset to the current compressed file size, which for an incomplete stream points into the middle of the deflate stream rather than a member boundary, so every later poll fails and the offset is never updated — the rest of the file is never read even after it is complete and gzip -t passes. Rotated/compressed log collection is a mainstream OpenShift pattern.

Recommended action: Track #51923, document that compression gzip/auto should only target fully written files, and add a QE case that writes a gzip file incrementally while the receiver polls it.

#### MED-26 — Three target allocator defects fixed in 0.160.0 that the downstream base still carries

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | opentelemetry-operator (target allocator) |
| Component type | core |
| Detection methods | issues |
| Upstream PR | open-telemetry/opentelemetry-operator#5576, #5622, #5657 |
| Affected config fields | spec.targetAllocator.networkPolicy.enabled, spec.targetAllocator.observability.metrics.enableMetrics, spec.targetAllocator.mtls, collector_not_ready_grace_period |
| Has test coverage | true |

Description: #5576: the TA keeps assigning targets to terminating collector pods — a pod on an unreachable node keeps reporting PodReady=True until the kubelet confirms deletion, which never happens, so collectorNotReadyGracePeriod never applies and targets are permanently lost after a node failure, even across a TA restart. #5622: promhttp_metric_handler_requests_total and _in_flight disappeared from the TA /metrics endpoint when a custom gatherer is configured, because #5294 switched to promhttp.HandlerFor without the InstrumentMetricHandler wrapper. #5657: the TargetAllocator CR controller never deletes optional resources it created, so a NetworkPolicy survives networkPolicy.enabled: false, a ServiceMonitor survives enableMetrics: false, and cert-manager resources survive disabling mTLS.

Recommended action: Backport #5576, #5622 and #5657 to rhosdt-3.11. #5657 is the highest priority because a stale NetworkPolicy is the documented escape hatch for the NetworkPolicy problems in this report and it currently does not work.

#### MED-27 — OpenShift docs state network policies are enabled by default, a default upstream reversed in 0.160.0

| Field | Value |
|---|---|
| Category | DOC_STALE |
| Component | openshift-docs (standalone-otel-docs-main) |
| Component type | core |
| Detection methods | issues |
| Upstream PR | open-telemetry/opentelemetry-operator#5654 |
| Affected config fields | spec.networkPolicy.enabled, FEATURE_GATES |
| Has test coverage | false |

Description: otel-troubleshoot-network-policies.adoc states the network policies are enabled by default and need no additional configuration, and otel-configuring-operator.adoc documents FEATURE_GATES with a default of operator.networkpolicy,operand.networkpolicy while describing the gates as enabling experimental features. Upstream reversed this default precisely because the generated policies can block API server access. The docs are also internally inconsistent: safe-by-default alongside a 'Disabling network policies' troubleshooting module, and the same gates described as both default-on and experimental.

Recommended action: Reconcile the docs with the decision made on CRIT-6. At minimum add a known-limitations note covering stale API-server IPs on changing control planes, UDP ports rendered as TCP, and that networkPolicy.enabled: false does not currently delete an already-created TargetAllocator NetworkPolicy.

#### MED-28 — No downstream e2e coverage for the NetworkPolicy feature despite it being default-on and GA-documented

| Field | Value |
|---|---|
| Category | TEST_COVERAGE |
| Component | distributed-tracing-qe (tests/e2e-otel) |
| Component type | core |
| Detection methods | issues |
| Upstream PR | — |
| Affected config fields | spec.networkPolicy.enabled, spec.targetAllocator.networkPolicy.enabled |
| Has test coverage | false |

Description: tests/e2e-otel/ contains around 45 per-component suites but none covering NetworkPolicy generation; grep -ril networkpolicy matches only Tempo multitenancy artifacts under tests/e2e-disconnected. The feature is enabled by default in the shipped CSV, documented as GA with no additional configuration needed, and is the single largest cluster of upstream bug reports against the 0.158.0 base (#5493, #5551, #5611, #5654, #5657, #5275). There is also no dedicated k8sattributesprocessor suite, which matters given the semconv rename.

Recommended action: Add an e2e-otel NetworkPolicy suite asserting the generated policy for both collector and target allocator: egress to the API server works, TCP and UDP container ports render with the correct protocol, and networkPolicy.enabled: false actually deletes the policy. Add a k8sattributesprocessor suite pinning the expected k8s.pod.label* names.

#### MED-29 — Docs use deprecated snake_case-renamed component type aliases throughout

| Field | Value |
|---|---|
| Category | DEPRECATION |
| Component | multiple (14 component type aliases across receivers, exporters, processors, connectors) |
| Component type | core |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | otlp, otlphttp, hostmetrics, filelog, kubeletstats, k8sobjects, prometheusremotewrite, loadbalancing, k8sattributes, resourcedetection, cumulativetodelta, metricstarttime, spanmetrics |
| Has test coverage | false |

Description: Upstream renamed many component types to snake_case and kept the old names as DeprecatedType; the service builders call logDeprecatedTypeAlias, so each use warns today and will break when the alias is dropped. Old -> new, all still using the old name in openshift-docs: otlp -> otlp_grpc, otlphttp -> otlp_http, hostmetrics -> host_metrics, filelog -> file_log, kubeletstats -> kubelet_stats, k8sobjects -> k8s_objects, otlpjsonfile -> otlp_json_file, prometheusremotewrite -> prometheus_remote_write, loadbalancing -> load_balancing, k8sattributes -> k8s_attributes (9 files), resourcedetection -> resource_detection (8 files), cumulativetodelta -> cumulative_to_delta, metricstarttime -> metric_start_time, spanmetrics -> span_metrics. The docs already migrated the OTLP exporter reference modules, so they are internally inconsistent.

Recommended action: Do a coordinated rename pass across openshift-docs/otel-collector/modules/*.adoc and add a release note listing the old->new aliases so customers can update their CRs before the aliases are removed.

#### MED-30 — Seven components shipped in the Red Hat distribution manifest have no documentation module

| Field | Value |
|---|---|
| Category | COMPONENT_DRIFT |
| Component | chronyreceiver, webhookeventreceiver, syslogexporter, memorylimiterextension, headerssetterextension, redactionprocessor, logdedupprocessor |
| Component type | core |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | chrony, webhookevent, syslog, memory_limiter (extension), headers_setter, redaction, logdedup |
| Has test coverage | false |

Description: redhat-opentelemetry-collector/manifest.yaml (0.158.0) builds all seven into the product binary but openshift-docs/otel-collector/modules/ has no reference module for any of them (redaction is mentioned only once, in the 3.11.0 release note). Per the product's own rule, a feature in the source but missing from docs is not supported — so these are shipped-but-unsupported surfaces that users can still enable.

Recommended action: Decide per component: add a reference module with a GA/TP marker, or remove it from manifest.yaml. At minimum state in the release notes that these components are present but unsupported.

#### MED-31 — OBI Receiver doc is not orphaned — the component is in the manifest and the discovery heuristic missed it

| Field | Value |
|---|---|
| Category | COMPONENT_DRIFT |
| Component | obireceiver / component-discovery tooling |
| Component type | receiver |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | false |

Description: The reported docs-without-build-component is a false positive: manifest.yaml declares gomod go.opentelemetry.io/obi v0.10.0 with import go.opentelemetry.io/obi/collector plus a replaces entry. The discovery heuristic matches only */receiver/<name>receiver gomod paths, so an out-of-tree receiver from a non-contrib module is invisible. The real, smaller drift is that the OBI receiver doc carries no config reference at all (it only links to upstream pages) and the OBI module is pinned to v0.10.0, independent of the 0.158.0 collector release cadence.

Recommended action: Fix the discovery heuristic to read the import: key of manifest entries, not just the gomod path. Separately, add at least a minimal config reference for the OBI receiver and track its independent version in release notes.

#### MED-32 — Prometheus 0.312.0 -> 0.315.0 and prometheus-operator 0.92.0 -> 0.94.1 pull in new service-discovery backends

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator (target allocator) |
| Component type | operator |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | TargetAllocator.spec.prometheusCR, OpenTelemetryCollector.spec.targetAllocator.prometheusCR |
| Has test coverage | true |

Description: prometheus/prometheus goes 0.312.0 -> 0.315.0 and the three prometheus-operator modules 0.92.0 -> 0.94.1. Transitive fallout is large and mostly service-discovery related: Azure armcompute v5 -> v8 and armnetwork v4 -> v8, hashicorp/golang-lru v0.6.0 -> v1.0.2, consul/api, serf, hetznercloud, godo, gophercloud, ionos, scaleway, vultr, stackit and outscale all advance, plus brand-new modules oracle/oci-go-sdk/v65, sony/gobreaker/v2, youmark/pkcs8, gofrs/flock and hashicorp/go-metrics. The pkg/apis/monitoring bump changes the ServiceMonitor/PodMonitor/ScrapeConfig Go types the target allocator consumes.

Recommended action: Review the prometheus-operator 0.93/0.94 monitoring API changelog for ServiceMonitor/PodMonitor/ScrapeConfig field additions the TA must handle and run the TA Prometheus-CR e2e suite. Flag the new transitive vendors (oracle/oci-go-sdk/v65 in particular) to productization and CVE triage, since they expand the scanned dependency surface of the operator image.

#### MED-33 — Default auto-instrumentation image tags now carry a -<revision> suffix

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | opentelemetry-operator |
| Component type | auto_instrumentation |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | Instrumentation.spec.java.image, Instrumentation.spec.nodejs.image, Instrumentation.spec.python.image, Instrumentation.spec.dotnet.image, Instrumentation.spec.apacheHttpd.image |
| Has test coverage | false |

Description: The Makefile changes every instrumentation image reference from ${..._VERSION} to ${..._VERSION}-${..._REVISION}, with the revision read from new per-language autoinstrumentation/<lang>/revision.txt files (java, nodejs, python, dotnet, apache-httpd), described as the canonical <sdk-version>-<revision> reference and enforced by ensure-update-is-noop. The default image tag format for injected instrumentation containers therefore changes, and components.md generation follows.

Recommended action: Determine whether downstream productization overrides these references wholesale via CSV relatedImages or inherits the Makefile tag construction; if inherited, update any mirroring, ImageContentSourcePolicy or docs pinning the bare :<version> tag. Confirm ensure-update-is-noop does not fail on the downstream branch where revision.txt may be absent.

#### MED-34 — Default auto-instrumentation SDK versions bumped (Java 2.30.0 -> 2.32.0, Python 0.64b0 -> 0.66b1, .NET 1.16.0 -> 1.17.0)

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator |
| Component type | auto_instrumentation |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | Instrumentation.spec.java, Instrumentation.spec.python, Instrumentation.spec.dotnet |
| Has test coverage | true |

Description: versions.txt moves Java 2.30.0 -> 2.32.0, Python 0.64b0 -> 0.66b1 (two beta minors) and .NET 1.16.0 -> 1.17.0; NodeJS, Go and Apache HTTPD are unchanged. Python beta-minor bumps in particular have a history of changing instrumentation library defaults and dropping support for older runtime versions.

Recommended action: Check the opentelemetry-python-contrib 0.65b0/0.66b0 and opentelemetry-java-instrumentation 2.31/2.32 release notes for removed instrumentations, changed default semantic conventions or minimum-runtime drops, and update the downstream image builds plus the supported-runtime matrix in openshift-docs.

#### MED-35 — Bundled collector moves 0.158.0 -> 0.161.0 and collector/featuregate 1.64.0 -> 1.68.0

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator |
| Component type | operator |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | false |

Description: versions.txt bumps opentelemetry-collector, operator, targetallocator and operator-opamp-bridge from 0.158.0 to 0.161.0, and go.mod moves go.opentelemetry.io/collector/featuregate 1.64.0 -> 1.68.0 — the module the operator uses to parse and validate collector feature gates, so gates added, stabilized or removed in collector 0.159-0.161 become visible to the operator's validation. opamp-go also bumps 0.23.0 -> 0.25.0.

Recommended action: Cross-check the collector 0.159/0.160/0.161 changelogs for gates that changed stability (especially any referenced in the downstream default config or in openshift-docs) and for OpAMP protocol changes affecting the bridge. Note the operator's featuregate is at 1.68.0 while collector main is at 1.69.0 — confirm the version the downstream release pins.

#### MED-36 — Collector core modules v0.158.0/v1.64.0 -> v0.163.0/v1.69.0 with OTel SDK 1.44 -> 1.47 and gRPC 1.82.1 -> 1.84.0

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-collector |
| Component type | core |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | false |

Description: The intra-repo module set moves five minor releases ahead of the downstream base. External bumps alongside it: go.opentelemetry.io/otel and the exporter/trace/metric/sdk family 1.44.0 -> 1.47.0, otel log/sdk-log/otlplog 0.20.0 -> 0.21.0, grpc 1.82.1 -> 1.84.0, protobuf 1.36.11 -> 1.36.12, testify 1.11.1 -> 1.12.1, and knadh/koanf/v2 2.3.5 -> 2.3.8 with providers/confmap 1.0.0 -> 1.0.1 — koanf is the confmap engine, so its behaviour changes affect configuration resolution.

Recommended action: When rebasing redhat-opentelemetry-collector, read the 0.159-0.163 CHANGELOGs for confmap/koanf resolution changes and gRPC default changes (keepalive, max message size) that could alter OTLP behaviour, and validate the downstream default configs still load unchanged.

#### MED-37 — Test fixture install-minio.yaml deleted from the LokiStack export e2e test

| Field | Value |
|---|---|
| Category | TEST_COVERAGE |
| Component | opentelemetry-operator tests/e2e-openshift/export-to-cluster-logging-lokistack |
| Component type | core |
| Detection methods | test-coverage |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | true |

Description: Between the downstream base 7fb5138 and origin/main, tests/e2e-openshift/export-to-cluster-logging-lokistack/install-minio.yaml was deleted — the only file deleted under tests/ in that range. It appears replaced by install-seaweedfs.yaml and namespace.yaml in the same directory, i.e. the object-storage backend was swapped from MinIO to SeaweedFS rather than the test being dropped.

Recommended action: Confirm the LokiStack log-export e2e still runs and asserts the same behaviour with the SeaweedFS backend, and update any downstream or QE copies and references to install-minio.yaml.

## Low

#### LOW-1 — journald receiver gained convert_to_semantic_conventions option

| Field | Value |
|---|---|
| Category | NEW_FEATURE |
| Component | journaldreceiver |
| Component type | receiver |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#7298 |
| Affected config fields | receivers.journald.convert_to_semantic_conventions |
| Has test coverage | true |

Description: contrib v0.162.0 (#7298) added a convert_to_semantic_conventions option that maps well-known journald fields to OpenTelemetry semantic convention attributes. Opt-in, so no regression risk, but it is a user-visible feature on a component the product ships and currently documents without it.

Recommended action: Decide whether to document and support this option in openshift-docs for the release; if not documented it is unsupported by the project's own convention, so state that explicitly.

#### LOW-2 — bearertokenauth gained retry_on_failure and wait_for_token_file startup options

| Field | Value |
|---|---|
| Category | NEW_FEATURE |
| Component | bearertokenauthextension, oidcauthextension |
| Component type | extension |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50122 |
| Affected config fields | extensions.bearertokenauth.retry_on_failure, extensions.bearertokenauth.wait_for_token_file, extensions.oidc.public_keys_file |
| Has test coverage | true |

Description: contrib v0.160.0 (#50122) added retry_on_failure and wait_for_token_file to retry reading the token file during startup when it is not yet available — directly addressing the OpenShift pattern where a projected service account token volume is not yet populated when the container starts, which previously caused CrashLoopBackOff. The same release fixed the oidc extension to reload public_keys_file on any change in its parent directory, so projected-secret key rotations take effect without a restart.

Recommended action: Both changes are directly relevant to the OpenShift projected-token and cert-rotation patterns the product documents. Consider documenting wait_for_token_file and adding a QE case for key rotation without restart.

#### LOW-3 — New additive CRD fields: resizePolicy, revisionHistoryLimit, imagePullSecrets, enableServiceLinks, targetAllocator.telemetry, opampBridge.proxy

| Field | Value |
|---|---|
| Category | NEW_FEATURE |
| Component | opentelemetry-operator apis (v1beta1 common fields) |
| Component type | core |
| Detection methods | changelog, code-diff |
| Upstream PR | open-telemetry/opentelemetry-operator#5501, #4376, #5569, #5047, #5351 |
| Affected config fields | spec.resizePolicy, spec.revisionHistoryLimit, spec.imagePullSecrets, spec.enableServiceLinks, spec.targetAllocator.telemetry, OpAMPBridge.spec.proxy |
| Has test coverage | true |

Description: apis/v1beta1/common.go adds ResizePolicy, RevisionHistoryLimit (default 10), ImagePullSecrets and EnableServiceLinks (default true); opentelemetrycollector_types.go adds TargetAllocatorEmbedded.RevisionHistoryLimit and a new Telemetry/MetricReader/MetricExporter type tree for target allocator OTLP self-telemetry; v1alpha1 OpAMPBridge adds Proxy (url + headers, http/https/socks5/socks5h). All additive and defaulted to prior behaviour, but they enlarge the CRD schema, which matters for OLM bundle size and CRD size limits on some OpenShift versions, and the downstream bundle CRDs must be regenerated or the new fields are silently stripped.

Recommended action: Regenerate the downstream bundle CRDs from the rebased source rather than hand-merging, verify with a CR that sets each new field, confirm the regenerated CRDs still fit bundle/etcd object-size limits, and add the fields to the API reference. imagePullSecrets is particularly relevant for disconnected installs.

#### LOW-4 — Builder gained dist.resource.detection.detectors to trim resourcedetection detectors at build time

| Field | Value |
|---|---|
| Category | NEW_FEATURE |
| Component | opentelemetry-collector (builder) / resourcedetectionprocessor |
| Component type | core |
| Detection methods | changelog |
| Upstream PR | open-telemetry/opentelemetry-collector#16075 |
| Affected config fields | dist.resource.detection.detectors |
| Has test coverage | false |

Description: Core v0.163.0 (#16075) added dist.resource.detection.detectors to the builder config, letting distributions opt into a smaller set of detectors via generated Go build tags; contrib v0.163.0 (#47218) added the corresponding omit_detector_* tags. The Red Hat distribution only needs a handful (openshift, k8s_api, kubeadm, env, system, and the cloud detectors for hosted OpenShift), so this can cut binary size, dependency surface and the CVE surface otel-cve-resolver triages.

Recommended action: Evaluate adding dist.resource.detection.detectors to redhat-opentelemetry-collector/manifest.yaml during the rebase, restricted to the detectors openshift-docs actually documents, and measure the binary-size and dependency-tree delta to justify it.

#### LOW-5 — New num_shards option for parallel tail-sampling event loops

| Field | Value |
|---|---|
| Category | NEW_FEATURE |
| Component | tailsamplingprocessor |
| Component type | processor |
| Detection methods | code-diff, changelog |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#48699 |
| Affected config fields | processors.tail_sampling.num_shards |
| Has test coverage | false |

Description: config.go adds NumShards (default 1, max 256) which splits the processor into independent sharded event loops; num_traces, expected_new_traces_per_sec, decision cache sizes and per-second rate limits are divided across shards. Validation rejects num_shards > 256 and num_shards > 1 together with tail_storage. Default 1 preserves existing behaviour, but the divide-by-shard semantics of existing rate-limit policies is a documentation trap.

Recommended action: Document that policy rate limits are divided across shards when num_shards > 1, and run a scale test before recommending it downstream.

#### LOW-6 — apis module swaps github.com/goccy/go-yaml for go.yaml.in/yaml/v3

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator apis module |
| Component type | core |
| Detection methods | code-diff, dependencies |
| Upstream PR | — |
| Affected config fields | OpenTelemetryCollector.spec.config |
| Has test coverage | true |

Description: apis/go.mod drops goccy/go-yaml v1.19.2 and adds go.yaml.in/yaml/v3 v3.0.5 (bumping go.yaml.in/yaml/v2 to 2.4.4) to back the rewritten Config.Yaml(), and raises k8s.io/api and apimachinery to 0.37.1. The root module promotes go.yaml.in/yaml/v3 to direct while keeping goccy/go-yaml. Downstream consumers that vendor the apis module get a changed transitive dependency set, and YAML library swaps can subtly change marshalling of CR spec fields.

Recommended action: Verify the rendered collector ConfigMap YAML is byte-comparable before and after the switch for the downstream default configurations, especially multi-line strings and empty maps. Refresh SBOM expectations and re-point any CVE tracker referencing goccy/go-yaml in the operator images.

#### LOW-7 — New upstream e2e suites cover the changed behaviour but are not mirrored downstream

| Field | Value |
|---|---|
| Category | TEST_COVERAGE |
| Component | opentelemetry-operator tests/ vs distributed-tracing-qe |
| Component type | core |
| Detection methods | code-diff, test-coverage |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | false |

Description: The operator diff adds 166 changed files under tests/ with new suites that exercise exactly the risky changes in this report: tests/e2e/collector-config-scalars (ConfigMap scalar quoting), tests/e2e/golang-flags-cgroup-runtime, tests/e2e-targetallocator/targetallocator-otlp-selftelemetry, tests/e2e-targetallocator-cr/targetallocator-missing, targetallocator-networkpolicy and targetallocator-networkpolicy-apiserver-endpoints, tests/e2e-ta-collector-mtls/ta-mtls-disable, a new k8sattributes automatic-RBAC step, PHP instrumentation suites, and new test apps (otlp-sink, php, ruby). distributed-tracing-qe/tests/e2e-otel has no equivalents.

Recommended action: Port collector-config-scalars and the target-allocator NetworkPolicy/RBAC chainsaw tests into distributed-tracing-qe, or confirm the upstream suites run in the downstream CI job, before the rebase lands. Confirm the new test-app images are buildable and mirrorable in the disconnected test environment.

#### LOW-8 — New Alpha gate filelog.requireExplicitTopN changes ordering_criteria.top_n fallback when enabled

| Field | Value |
|---|---|
| Category | NEW_FEATURE |
| Component | filelogreceiver |
| Component type | receiver |
| Detection methods | feature-gates |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#47445 |
| Affected config fields | receivers.filelog.ordering_criteria.sort_by, receivers.filelog.ordering_criteria.top_n |
| Has test coverage | true |

Description: #47445 registers the gate at Alpha from v0.159.0. When enabled, ordering_criteria.top_n must be set explicitly whenever sort_by is configured; when disabled (the current default) an unset top_n falls back to the legacy default of 1. Off by default, but promotion turns configs using sort_by without top_n into validation errors.

Recommended action: Ensure any downstream filelog sample or doc using ordering_criteria.sort_by also sets top_n explicitly so the config is forward-compatible when the gate is promoted.

#### LOW-9 — New Alpha gates: consul.prefixMetaAttributes and elasticbeanstalk semconv migration

| Field | Value |
|---|---|
| Category | NEW_FEATURE |
| Component | resourcedetectionprocessor |
| Component type | processor |
| Detection methods | feature-gates |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50012 |
| Affected config fields | processors.resourcedetection.consul, processors.resourcedetection.elasticbeanstalk |
| Has test coverage | true |

Description: Three new Alpha gates absent at v0.158.0: processor.resourcedetection.consul.prefixMetaAttributes (#50012) and processor.resourcedetection.elasticbeanstalk.DontEmitV0DeploymentConventions / EmitV1DeploymentConventions. All off by default. The consul and elasticbeanstalk detectors are rarely used on OpenShift, but the elasticbeanstalk pair follows the same DontEmitV0/EmitV1 pattern being promoted rapidly elsewhere in contrib.

Recommended action: No action this release. Record the elasticbeanstalk conventions pair on the semconv-migration watchlist alongside the hostmetrics and k8sattributes gates so a future promotion is not missed.

#### LOW-10 — filelog.windows.caseInsensitive promoted Alpha -> Beta (Windows-only, no downstream impact)

| Field | Value |
|---|---|
| Category | FEATURE_GATE |
| Component | filelogreceiver |
| Component type | receiver |
| Detection methods | feature-gates |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#50266 |
| Affected config fields | receivers.filelog.include, receivers.filelog.exclude |
| Has test coverage | true |

Description: Promoted by #50266 in the same commit as filelog.allowFileDeletion; on Windows, include/exclude glob matching becomes case-insensitive. The Red Hat build ships Linux container images only, so there is no runtime effect downstream. Listed for completeness because it is a default-changing promotion in a shipped component.

Recommended action: No action. Do not include in customer-facing release notes for the OpenShift distribution.

#### LOW-11 — db_sanitizer ignores attributes for the opensearch and es database systems

| Field | Value |
|---|---|
| Category | BUG_FIX |
| Component | redactionprocessor |
| Component type | processor |
| Detection methods | issues |
| Upstream PR | open-telemetry/opentelemetry-collector-contrib#52050 |
| Affected config fields | processors.redaction.db_sanitizer |
| Has test coverage | true |

Description: contrib #52050, OPEN as of 2026-10-14: the redaction processor's db_sanitizer ignores attributes when the database system is opensearch or es, so query text that should be sanitized passes through unredacted. A data-privacy gap rather than a crash, limited to those two systems. The component is in the downstream build and has a QE suite.

Recommended action: Track #52050. If RHOSDT documents db_sanitizer as a privacy control, note the opensearch/es gap in the docs until it is fixed upstream.

#### LOW-12 — Tail Sampling Processor doc is missing nine top-level options and two policy types

| Field | Value |
|---|---|
| Category | DOC_MISSING |
| Component | tailsamplingprocessor |
| Component type | processor |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | decision_wait_after_root_received, block_on_overflow, decision_cache, tail_storage, maximum_trace_size_bytes, num_shards, policies[].not, policies[].bytes_limiting, invert_match |
| Has test coverage | false |

Description: The module documents only decision_wait, num_traces, expected_new_traces_per_sec and policies (all still valid). Undocumented: decision_wait_after_root_received, block_on_overflow, decision_cache (sampled/non_sampled sizes), tail_storage, sample_on_first_match, sampling_strategy, drop_pending_traces_on_shutdown, maximum_trace_size_bytes, num_shards, plus the not and bytes_limiting policy types, rate_limiting.burst_capacity and the invert_match flag on the attribute policies.

Recommended action: Add the scaling/memory options (num_shards, block_on_overflow, maximum_trace_size_bytes, decision_cache) and the not and bytes_limiting policy types — the ones most relevant to OpenShift gateway deployments.

#### LOW-13 — Host Metrics Receiver doc omits the nfs and system scrapers and metadata_collection_interval

| Field | Value |
|---|---|
| Category | DOC_MISSING |
| Component | hostmetricsreceiver |
| Component type | receiver |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | scrapers.nfs, scrapers.system, metadata_collection_interval |
| Has test coverage | false |

Description: The module lists cpu, disk, load, filesystem, memory, network, paging, processes and process as the available scrapers, but the upstream tree also contains nfsscraper and systemscraper, and the receiver's top-level metadata_collection_interval option is undocumented. All documented keys remain valid.

Recommended action: Add nfs and system to the available-scraper list (or state explicitly that they are unsupported in the Red Hat build) and document metadata_collection_interval.

#### LOW-14 — OTLP Receiver doc covers only endpoint and TLS; per-signal URL paths and common server options are undocumented

| Field | Value |
|---|---|
| Category | DOC_MISSING |
| Component | otlpreceiver |
| Component type | receiver |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | protocols.http.traces_url_path, protocols.http.metrics_url_path, protocols.http.logs_url_path, protocols.grpc.max_recv_msg_size_mib, include_metadata, cors, tls.cipher_suites, tls.tpm |
| Has test coverage | false |

Description: Undocumented HTTP options: traces_url_path, metrics_url_path, logs_url_path. Also undocumented are shared confighttp/configgrpc server options reachable through protocols.grpc/protocols.http (include_metadata, auth, cors, compression_algorithms, max_recv_msg_size_mib, keepalive, middlewares) and the newer configtls fields ca_pem/cert_pem/key_pem, cipher_suites, curve_preferences, include_system_ca_certs_pool, include_insecure_cipher_suites and tpm.

Recommended action: Add the three per-signal URL path options, and add a shared common server/TLS settings module that receiver and exporter modules can cross-reference instead of repeating the same TLS rows in every file.

#### LOW-15 — Prometheus Receiver doc omits trim_metric_suffixes, target_allocator, scrape_on_shutdown, discovery_reload_on_startup and initial_scrape_offset

| Field | Value |
|---|---|
| Category | DOC_MISSING |
| Component | prometheusreceiver |
| Component type | receiver |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | trim_metric_suffixes, target_allocator, scrape_on_shutdown, discovery_reload_on_startup, initial_scrape_offset |
| Has test coverage | false |

Description: The module documents only config.scrape_configs and api_server, while v0.158.0 also exposes trim_metric_suffixes, target_allocator, scrape_on_shutdown, discovery_reload_on_startup and initial_scrape_offset. target_allocator is directly relevant on OpenShift because the operator ships a TargetAllocator.

Recommended action: Document at least target_allocator and trim_metric_suffixes, cross-referencing the operator's TargetAllocator configuration.

#### LOW-16 — Kafka Receiver doc omits consumer, partition-processing, header-extraction and backoff options

| Field | Value |
|---|---|
| Category | DOC_MISSING |
| Component | kafkareceiver |
| Component type | receiver |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | group_id, initial_offset, autocommit, min_fetch_size, max_fetch_size, message_marking.on_permanent_error, partition_processing.independent, header_extraction.extract_headers, error_backoff |
| Has test coverage | false |

Description: Beyond the stale topic/plain_text issues, the module documents none of the consumer-side tuning surface: group_id, initial_offset, session_timeout, heartbeat_interval, autocommit, min/max_fetch_size, max_fetch_wait, max_partition_fetch_size, group_rebalance_strategies, group_instance_id, plus receiver-level message_marking (after, on_error, on_permanent_error), partition_processing, header_extraction, error_backoff and telemetry.metrics.kafka_receiver_records_delay.

Recommended action: Expand the module with a consumer-settings table and the message_marking / partition_processing blocks, which customers need for at-least-once delivery and throughput tuning.

#### LOW-17 — Span Metrics Connector doc documents a single option out of roughly 20 available upstream

| Field | Value |
|---|---|
| Category | DOC_MISSING |
| Component | spanmetricsconnector |
| Component type | connector |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | dimensions, exclude_dimensions, histogram.explicit.buckets, namespace, aggregation_temporality, aggregation_cardinality_limit |
| Has test coverage | false |

Description: The module documents only metrics_flush_interval. Upstream also exposes dimensions, calls_dimensions, exclude_dimensions, dimensions_cache_size, resource_metrics_cache_size, resource_metrics_key_attributes, aggregation_temporality, histogram (disable/unit/exponential/explicit/dimensions), metrics_expiration, series_expiration, metric_timestamp_cache_size, namespace, exemplars, events, include_instrumentation_scope and aggregation_cardinality_limit. dimensions and histogram.explicit.buckets in particular drive the metric labels the doc's own label table describes.

Recommended action: Add at minimum dimensions, histogram (explicit buckets / exponential / disable), namespace, aggregation_temporality and aggregation_cardinality_limit, since the existing label table is only meaningful alongside dimensions.

#### LOW-18 — Kubernetes Attributes Processor doc documents only filter

| Field | Value |
|---|---|
| Category | DOC_MISSING |
| Component | k8sattributesprocessor |
| Component type | processor |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | extract.metadata, extract.labels, extract.annotations, pod_association.sources, exclude.pods, wait_for_metadata, passthrough |
| Has test coverage | false |

Description: The module shows only filter.namespace and filter.node_from_env_var. Upstream also exposes auth_type, passthrough, extract (metadata, annotations, labels, otel_annotations), pod_association.sources, exclude.pods, wait_for_metadata, wait_for_metadata_timeout, watch_sync_period, pod_delete_grace_period and a kubelet block. extract and pod_association are the options most users actually need, and wait_for_metadata affects startup behaviour.

Recommended action: Add extract and pod_association sections (the two options that determine which attributes get attached) plus wait_for_metadata and wait_for_metadata_timeout.

#### LOW-19 — Batch and Memory Limiter processor parameter tables omit a few upstream options

| Field | Value |
|---|---|
| Category | DOC_MISSING |
| Component | batchprocessor, memorylimiterprocessor |
| Component type | processor |
| Detection methods | doc-validation |
| Upstream PR | — |
| Affected config fields | metadata_keys, metadata_cardinality_limit, min_gc_interval_when_soft_limited, max_gc_interval_when_hard_limited |
| Has test coverage | false |

Description: The batch processor table covers timeout, send_batch_size and send_batch_max_size but omits metadata_keys and metadata_cardinality_limit. The memory limiter table covers check_interval, limit_mib, spike_limit_mib, limit_percentage and spike_limit_percentage but omits min_gc_interval_when_soft_limited, min_gc_interval_when_hard_limited, max_gc_interval_when_soft_limited and max_gc_interval_when_hard_limited. All documented fields remain valid.

Recommended action: Append the missing rows to both tables; the memory-limiter GC interval options matter for tuning collectors under memory pressure on OpenShift.

#### LOW-20 — cert-manager 1.21.1 -> 1.21.2 (patch)

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator |
| Component type | operator |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | true |

Description: A patch bump of github.com/cert-manager/cert-manager. The operator uses cert-manager types for the Issuer/Certificate resources it creates when cert-manager-based TLS is selected, so no API change is expected.

Recommended action: No action beyond the normal rebase; confirm the cert-manager version installed in QE clusters still satisfies the API version the operator generates.

#### LOW-21 — OpenShift dependency pseudo-versions advance about two months

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator |
| Component type | operator |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | false |

Description: openshift/api 20260813212709 -> 20261012173350, openshift/library-go 20260814203017 -> 20261012140303 and openshift/controller-runtime-common 20260813135806 -> 20261008111711. These are untagged pseudo-versions tracking master, so they pull in whatever landed in that window for Route/SecurityContextConstraints types and library-go helpers used by the OpenShift-specific paths.

Recommended action: Confirm the openshift/api commit the downstream branch pins corresponds to the OCP release RHOSDT targets; pseudo-versions tracking master can introduce API fields not present on older supported OCP versions.

#### LOW-22 — Root go.mod emptied of dependencies, go.sum deleted, new internal/statusutil module added

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-collector |
| Component type | core |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | false |

Description: The root go.mod at HEAD contains only the module line, go directive and retract block — all require blocks were removed and go.sum deleted. A new internal/statusutil/go.mod brings the repo to 100 go.mod files. Dependency tracking for the collector now requires diffing per-component go.mod files rather than the root.

Recommended action: Update any downstream tooling or vendoring script that assumes the collector root module has dependencies or a go.sum, and diff submodule go.mod files for future dependency reviews of this repo.

#### LOW-23 — Platform support tiers reshuffled: windows/amd64 to Tier 1, windows/arm64 to Tier 2

| Field | Value |
|---|---|
| Category | BEHAVIOR_CHANGE |
| Component | opentelemetry-collector |
| Component type | core |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | false |

Description: docs/platform-support.md promotes windows/amd64 from Tier 2 to Tier 1 and windows/arm64 from Tier 3 to Tier 2. Not a dependency change, but it shifts upstream's stated support guarantees. The Red Hat build ships linux/amd64, arm64, ppc64le and s390x, and linux/ppc64le and linux/s390x remain Tier 3 (community-supported) upstream.

Recommended action: No immediate action. Keep in mind for the IBM P/Z test story that regressions on ppc64le and s390x will not block an upstream release and must be caught by downstream CI.

#### LOW-24 — go-openapi family crosses to v1.0.0 and assorted indirect bumps

| Field | Value |
|---|---|
| Category | DEPENDENCY |
| Component | opentelemetry-operator |
| Component type | operator |
| Detection methods | dependencies |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | false |

Description: go-openapi analysis, spec and validate all go from v0.2x to v1.0.0 (same module path), with errors, loads, runtime, strfmt and the swag/* set advancing. Other notable indirect moves: golang.org/x/crypto 0.54.0 -> 0.58.0, x/net 0.57.0 -> 0.61.0, x/sys 0.47.0 -> 0.49.0, x/mod 0.38.0 -> 0.42.0, grpc 1.83.0 -> 1.84.0, google.golang.org/api 0.286.0 -> 0.297.0, klauspost/compress, cel-go 0.29.2 -> 0.30.0, gopsutil/v4, purego, and michel-laterman/proxy-connect-dialer-go replaced by elastic/proxy-connect-dialer-go.

Recommended action: Treat as a routine refresh. Worth a note to CVE triage that x/crypto and x/net advanced four minors, which usually clears outstanding golang.org/x advisories against the current operator image.

#### LOW-25 — chronyreceiver has zero test coverage in both upstream operator and QE test repos

| Field | Value |
|---|---|
| Category | TEST_COVERAGE |
| Component | chronyreceiver |
| Component type | receiver |
| Detection methods | test-coverage |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | false |

Description: chronyreceiver (type key chrony) is shipped in the downstream collector build but no reference exists in opentelemetry-operator/tests/ or distributed-tracing-qe/tests/ under any name candidate. It is the only one of the 58 build components with no coverage at all, and it is also undocumented, so it is not a supported feature.

Recommended action: Either confirm chronyreceiver is intentionally unsupported and leave it untested, or add a minimal QE smoke test under distributed-tracing-qe/tests/e2e-otel/chronyreceiver/ if it is intended to ship as supported.

#### LOW-26 — Kafka receiver/exporter are covered only upstream; QE has no Kafka test at all

| Field | Value |
|---|---|
| Category | TEST_COVERAGE |
| Component | kafkareceiver, kafkaexporter |
| Component type | receiver |
| Detection methods | test-coverage |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | false |

Description: Both components are documented (supported) and have a dedicated upstream suite at opentelemetry-operator/tests/e2e-openshift/kafka/, but a case-insensitive search for kafka across distributed-tracing-qe/tests/ returns zero hits. Downstream-specific Kafka behaviour (AMQ Streams integration, FIPS/TLS variants) is only validated by the upstream suite — and the Kafka config surface has multiple breaking changes in this rebase window.

Recommended action: No action strictly required if the upstream e2e-openshift/kafka suite runs as part of the product test run; add a QE test if the downstream Kafka story diverges (AMQ Streams-specific auth), and extend coverage to the new config shape required by CRIT-1 and CRIT-10.

#### LOW-27 — zipkinreceiver is documented but has no QE test and only incidental upstream coverage

| Field | Value |
|---|---|
| Category | TEST_COVERAGE |
| Component | zipkinreceiver |
| Component type | receiver |
| Detection methods | test-coverage |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | false |

Description: Upstream coverage is incidental: zipkin appears as a pipeline receiver in tests/e2e-openshift-tls-profile/tls-profile/01-install.yaml, a test whose subject is the TLS security profile. In distributed-tracing-qe the only hit is a Tempo/Jaeger compatibility assertion in e2e-disconnected/compatibility. The documented Zipkin ingest path is therefore never exercised end to end — notable given this rebase enables HTTP server timeouts by default on the zipkin receiver.

Recommended action: Add a small QE test that pushes a Zipkin-format span through the collector and asserts it arrives, covering the default-timeout change in HIGH-4.

#### LOW-28 — Several documented components have only incidental (implicit) coverage on both sides

| Field | Value |
|---|---|
| Category | TEST_COVERAGE |
| Component | awsemfexporter, fileexporter, oauth2clientauthextension, googleclientauthextension, metricstarttimeprocessor, attributesprocessor |
| Component type | core |
| Detection methods | test-coverage |
| Upstream PR | — |
| Affected config fields | — |
| Has test coverage | false |

Description: These components are documented but have no dedicated test directory in either repo — they appear only as extra entries inside pipelines whose test subject is a different component (awsemf inside the awscloudwatchlogsexporter config, metricstarttime and googleclientauth inside the googlemanagedprometheus config, file inside the otlpjsonfilereceiver test).

Recommended action: Informational. If regressions in these components would not be caught by the host test's assertions, promote them to dedicated QE cases; otherwise keep as is.


## Confirmed Coverage Gaps

Components and operator features with no test at all — neither upstream nor QE. Anything with at least one of the two is considered covered, since the product build runs both suites.

- receiver/chronyreceiver (receiver) — undocumented, no upstream or QE test


## Documentation Drift

Docs that exist but no longer match any component in the manifest.

- otel-receivers-obi-receiver.adoc (receiver) — doc exists but no matching component found in the manifest

## Skill Improvement Recommendations

*(Deviations from skill steps as written — `None.` if everything worked as described.)*

- [discover] manifest.yaml has a receiver entry 'go.opentelemetry.io/obi v0.10.0' (with 'import: go.opentelemetry.io/obi/collector') that belongs to neither opentelemetry-collector nor opentelemetry-collector-contrib, so it fits neither the collector_core nor collector_contrib repo enum. It was excluded from components; its doc otel-receivers-obi-receiver.adoc is therefore reported under documented_but_missing even though the component IS in the build.
- [discover] manifest.yaml also contains a 'providers' section (5 confmap provider modules at v1.64.0) and a 'replaces' section, which the STEP 3 section list does not mention. Providers were not emitted as components since 'provider' is not in the type enum.
- [discover] Core-module source_dir derivation: the instruction says to strip 'collector/' — for go.opentelemetry.io/collector/... the prefix stripped is the full 'go.opentelemetry.io/collector/' module prefix, which gives the correct in-repo path.
- [discover] ocp-build-data had only one rhosdt-* remote branch (rhosdt-0.158), so the sort -V | tail -1 selection was trivial.
- [discover] Version strings are reported verbatim from the manifest including the leading 'v' (e.g. v0.158.0), while collector_version/operator_base_version are bare (0.158.0) as they appear in dist.version and versions.txt.
- [setup] openshift-docs is a single-branch clone of 'standalone-otel-docs-main' (the branch the workspace README points at for OTEL docs), so it has no 'main' branch and no origin/main remote-tracking ref. 'git fetch origin main' still succeeded (FETCH_HEAD = bd3cffc19ea7c85408fbdd0c536d1cc77ad3de97), but 'git rev-parse origin/main' failed with 'ambiguous argument'. Used the checked-out branch head instead. Step 4 should use each repo's default/configured branch rather than hardcoding origin/main.
- [setup] Step 5's tag listing worked as written for the operator repo; no workaround needed (origin/main = a41238d9bbe2375bfe0fcce0b78b7425aac28b3f, latest reachable tag v0.161.0).
- [changelog] Instruction step 4 lists component source directories in Go package form (e.g. `filelogreceiver`, `k8sattributesprocessor`), but both upstream CHANGELOG.md entries and `.chloggen` files key components in snake_case (`receiver/file_log`, `processor/k8s_attributes`). A direct substring match against the provided list returns almost nothing; I had to build a name-translation regex to filter. The instruction list should carry the chloggen component keys, or both forms.
- [changelog] The provided component list does not match the actual downstream build. redhat-opentelemetry-collector/manifest.yaml additionally contains `syslogexporter`, `logdedupprocessor` and `webhookeventreceiver`, which the list omits, and spells `filestorage` without its real path `extension/storage/filestorage`. I used manifest.yaml as the authoritative source and noted the extras.
- [changelog] Instruction step 3 says to check `.chloggen/*.yaml` for pending entries; in contrib that glob also matches `.chloggen/config.yaml` (the chloggen tool's own component registry, ~400 lines), which is not a changelog entry and has to be excluded explicitly or it swamps the output.
- [changelog] The three repos are not at comparable points. Collector-core and contrib have released through v0.163.0, but the operator's CHANGELOG.md only reaches 0.161.0, with its unreleased work existing solely as 4 `.chloggen` files. So for the operator the `.chloggen` check was not an 'early warning' supplement as the instructions frame it — it was the only source for the newest changes.
- [changelog] Core collector had exactly one pending `.chloggen` entry (redact-literal-env-provider-defaults.yaml, pkg/otelcol / OpAMP raw config redaction), not relevant to any downstream component, so step 3 produced nothing actionable for that repo.
- [changelog] Several of the highest-impact changes live in shared `pkg/*` and `internal/*` modules (pkg/ottl, pkg/stanza, pkg/kafka/configkafka, pkg/prometheus, internal/k8sconfig) rather than in any component directory named in step 4. A strict reading of the filter would have dropped them, so I included them and attributed each to the downstream component it actually affects.
- [changelog] The operator base was given as commit SHA 7fb513848c6d4ea79b277352fc13ce11eb734b1a rather than a tag; it resolves to 'Prepare release 0.158.0 (#5463)', consistent with the v0.158.0 tags used for the other two repos. No workaround needed, just noting the asymmetry.
- [changelog] The task scoped the work to changelog parsing, but I additionally grepped openshift-docs for configuration fields removed or deprecated upstream. This was not in the instructions and produced two concrete high-value findings (documented `auth.plain_text` for the Kafka receiver/exporter, which is now a hard startup failure, and `resource_to_telemetry_conversion` across four modules). Worth adding as an explicit step.
- [changelog] I did not perform code-diff, feature-gate-registry, GitHub-issue, or test-coverage analysis, as the task text scoped this run to changelogs. The `has_test_coverage` field was therefore inferred from whether the changelog entry describes a fix with an accompanying upstream test, not verified against test files.
- [code-diff] Step 2's `git diff v0.158.0..origin/main -- <dir>/config.go <dir>/factory.go` pattern was too narrow for several real breaking changes. The kafkaexporter `auth.tls`/`auth.plain_text` removal lives in `pkg/kafka/configkafka`, the filelog `ordering_criteria.top_n` semantic change lives in `pkg/stanza/fileconsumer`, and the OTTL `Base64Decode` removal lives in `pkg/ottl` - none appear in the listed component config.go/factory.go files. I supplemented with `git diff v0.158.0..origin/main -- CHANGELOG.md` on both collector repos, which is where most user-facing breaking changes are actually recorded.
- [code-diff] 13 of the 48 listed component directories had zero changes to config.go/factory.go: receiver/chronyreceiver, receiver/filelogreceiver, receiver/k8sclusterreceiver, receiver/k8sobjectsreceiver, receiver/otlpjsonfilereceiver, exporter/googlecloudexporter, extension/pprofextension, extension/oauth2clientauthextension, extension/oidcauthextension, extension/storage/filestorage, extension/headerssetterextension, extension/k8sleaderelector, connector/spanmetricsconnector.
- [code-diff] Six of the listed directories have no `config.go` at all (prometheusremotewritereceiver, zipkinreceiver, jaegerremotesampling, healthcheckextension, k8seventsreceiver, kubeletstatsreceiver put their defaults in factory.go), so a per-file diff returns empty and the `--stat` line I used for triage was ambiguous about which of the two files changed. I had to re-diff file-by-file to find the confighttp default-override removals.
- [code-diff] To characterise the impact of the removed confighttp overrides I looked for `config/confighttp/confighttp.go` in the collector repo; that file no longer exists (it was split into client.go/server.go). I read `config/confighttp/server.go` instead.
- [code-diff] Step 1 and 3 ran exactly as written. No deviation on the operator diffs, though I also read apis/go.mod, versions.txt, pkg/featuregate/featuregate.go, internal/config, and CHANGELOG.md because several breaking changes (removed CLI flag, demoted feature gates, Go/YAML dependency swap, PHP images) are not visible in `apis/` or `internal/webhook/` alone.
- [code-diff] The `os-observability-opentelemetry-operator` directory is untracked in the workspace git status; I did not need it, and the downstream fork `open-telemetry-opentelemetry-operator` already contained the 0.161.0 CHANGELOG, so its checkout is not a clean pre-rebase baseline for grep-based downstream impact checks.
- [feature-gates] The instructed command `git diff <base>..origin/main -- "*.go" | grep -A5 -B5 "featuregate|MustRegister"` was unusable as written: in contrib it produced ~14.6k lines dominated by `_test.go` files calling `featuregate.GlobalRegistry().Set(...)`, and it cannot distinguish a real stage change from an mdatagen file relocation. Replaced with `git diff -G'featuregate|MustRegister|GlobalRegistry'` to find candidate files, plus a Python script that enumerates every non-test `MustRegister("id", featuregate.Stage*)` site at both revisions and diffs the resulting gate->stage maps.
- [feature-gates] Feature gates are now almost entirely generated by mdatagen into `<component>/internal/metadata/generated_feature_gates.go`. Several gates appeared as ADDED/REMOVED pairs purely because the registration moved files or the gate was renamed (e.g. `ottl.contexts.*` -> `pkg.ottl.functions.*`); each add/remove had to be cross-checked with `git log` on the generated file to classify it correctly.
- [feature-gates] The operator base was given only as a bare SHA with no tag; verified via commit message that 7fb513848c6d4ea79b277352fc13ce11eb734b1a is `Prepare release 0.158.0 (#5463)`.
- [feature-gates] The stability progression in the instructions (Alpha->Beta->Stable->Removed) does not cover demotions. The only operator gate changes found were Beta->Alpha demotions, which were classified as BEHAVIOR_CHANGE/HIGH rather than fitting the given ladder.
- [feature-gates] The severity rubric only covers promotions/removals and gives nothing for newly registered gates. Newly registered Beta gates (on by default) were scored HIGH/MEDIUM and newly registered Alpha gates (off by default) MEDIUM/LOW.
- [feature-gates] Deviated from the 'Alpha->Beta: HIGH' rule for `filelog.windows.caseInsensitive`, scored LOW because the downstream build is Linux/OpenShift-only and the gate is Windows-path-matching only.
- [feature-gates] The component filter list uses component names (e.g. `filelogreceiver`, `transformprocessor`), but several gates live in shared packages (`pkg/ottl`, `pkg/stanza`, `pkg/stanza/fileconsumer`, `pkg/translator/prometheus`, `config/confighttp`). These were mapped by hand to the consuming components in the list rather than filtered out.
- [feature-gates] No `reports/` baseline or prior run output was consulted; findings are derived purely from the two git ranges.
- [issues] Step 3 as written does not work: `gh pr list --repo open-telemetry/opentelemetry-operator --state merged --label "breaking" --limit 20` returns `[]` because no `breaking` label exists in that repo. Verified with `gh label list --repo open-telemetry/opentelemetry-operator --limit 200` — the closest labels are `release-blocker` and the `area:*` set. Substituted a scan of the `### 🛑 Breaking changes 🛑` sections of `CHANGELOG.md` on `origin/main`, which is where this repo actually records breaking changes; this is what produced the 0.159.0 FilterStrategy, 0.160.0 NetworkPolicy-default-revert, and 0.161.0 `--create-rbac-permissions`/OpAMP findings.
- [issues] The instructions say 'since the downstream base version' but give no way to determine it. Derived it as v0.158.0 from `open-telemetry-opentelemetry-operator@origin/rhosdt-3.11:versions.txt` and `redhat-opentelemetry-collector/manifest.yaml`, then dated the window with `gh release list` (operator v0.158.0 = 2026-08-17, contrib v0.158.0 = 2026-08-04). Worth making this an explicit first step in the instructions.
- [issues] The `--limit 30` cap on the contrib bug-issue query is far too small for the window. contrib files bugs fast enough that 30 issues only reaches back to 2026-10-07, about 10 days, versus the ~2.5-month gap since the contrib 0.158.0 base. The contrib bug scan is therefore a recent-activity sample, not an exhaustive sweep of the window. A date-bounded search (`--search "label:bug created:>=2026-08-04"`) with a higher limit, or pagination, would be needed for completeness. The operator query at limit 30 did reach back past its base (to 2026-06-23), so only contrib is affected.
- [issues] No breaking-change query was specified for opentelemetry-collector-contrib at all (step 3 only covers the operator). Added an equivalent changelog-based scan of contrib 0.159.0-0.163.0, which produced the two highest-value contrib findings (k8sattributes semconv rename, Kafka config removals) — neither would have been found by the three listed commands.
- [issues] 'Filter to components in the downstream build' required a source of truth that was not named. Used the `gomod:` entries in `redhat-opentelemetry-collector/manifest.yaml` (~70 components) plus `open-telemetry-opentelemetry-operator@origin/rhosdt-3.11` for operator-side scope.
- [issues] Went beyond the three listed commands to verify downstream exposure rather than report upstream issues at face value: read the rhosdt-3.11 `pkg/featuregate/featuregate.go` and OpenShift CSV (confirming the NetworkPolicy gates are StageBeta and force-enabled via the `FEATURE_GATES` env), diffed CSV RBAC against upstream main (finding the missing `endpointslices` `watch` verb and missing `batch/cronjobs`), checked `openshift-docs` for the documented-vs-upstream default mismatch, and listed `distributed-tracing-qe/tests/e2e-otel` for coverage gaps. Several findings' severity depends on this verification and would have been misranked without it.
- [issues] The `redhat-build-of-opentelemetry-workspace` AGENTS.md auto-push spec-PR workflow was not applicable — this task is read-only analysis and wrote no spec files, so nothing was committed or pushed.
- [doc-validation] Instruction 3 was factually wrong: otel-receivers-obi-receiver.adoc is NOT orphaned. redhat-opentelemetry-collector/manifest.yaml lines 25-26 declare `- gomod: go.opentelemetry.io/obi v0.10.0` with `import: go.opentelemetry.io/obi/collector`, plus a `replaces` entry on line 84. The discovery heuristic appears to match only `*/receiver/<name>receiver` gomod paths and so misses out-of-tree components declared via an `import:` key. I reported it as COMPONENT_DRIFT/MEDIUM as instructed, but with a corrected description rather than asserting a removed component.
- [doc-validation] Instruction 2's name-drift direction was inverted. It asked me to grep docs for 'deprecated names (filelog vs file_log, kubeletstats vs kubelet_stats, loadbalancing vs load_balancing)' as if snake_case were the deprecated form. Upstream is the reverse: generated_status.go has `Type = file_log` / `DeprecatedType = filelog`, so snake_case is current and the docs' camel-run-together names are the deprecated ones. A literal grep for `file_log`/`kubelet_stats`/`load_balancing` in the docs returned nothing and would have produced a clean bill of health; I had to enumerate Type/DeprecatedType from every component's internal/metadata/generated_status.go and grep for the old names instead. That enumeration also turned up 11 renames beyond the three listed.
- [doc-validation] Instruction 1 said to pick 'GA components with the most config surface', but GA/TP status is not in the mapping and is not centralized. The overview modules (otel-receivers-overview.adoc etc.) only say 'General Availability and Technology Preview ... are available' without a per-component table; status lives in each module as `include::snippets/technology-preview.adoc[]`. I grepped for that include to build the TP list (32 files) and treated the remainder as GA. This excluded k8sclusterreceiver, which by doc line count (156) would otherwise have been a top-6 pick.
- [doc-validation] The mapping's 'corresponding config.go' is not self-contained for most components; the documented fields live in embedded/squashed structs in other packages. I had to follow `mapstructure:",squash"` into opentelemetry-collector/config/configtls, configgrpc, confighttp; opentelemetry-collector-contrib/pkg/kafka/configkafka; pkg/stanza/fileconsumer (matcher, attrs) and adapter; internal/kubelet and internal/k8sconfig. A grep limited to the mapped config.go would have missed every finding about TLS, Kafka auth, and filelog include/exclude.
- [doc-validation] configtls has no mapstructure tags in configtls.go at this revision; they are in generated_config.go (and mirrored in a config.schema.yaml). An initial `grep mapstructure configtls.go` returned nothing. Several packages now ship config.schema.yaml, which is a cleaner extraction source than the Go structs for future runs of this workflow.
- [doc-validation] The two components whose docs are most broken (kafkaexporter, prometheusremotewriteexporter) each needed `git log -S` archaeology to attribute the removal to a specific upstream PR; the config.go diff alone only shows absence. Worth building into the workflow as an explicit step.
- [doc-validation] Three findings fall outside the per-component mapping entirely and would be missed by a strictly mapping-driven pass: the stale component lists in otel-collector-config-options.adoc (opencensus / routing processor / memory_ballast), the seven manifest components with no doc module, and the cross-file deprecated-alias usage in non-reference modules (otel-forwarding-*.adoc, otel-send-traces-*.adoc, otel-receiving-telemetry-from-multiple-clusters.adoc). Suggest adding a reverse manifest->docs sweep and a repo-wide alias grep.
- [doc-validation] Extracting YAML blocks with `sed -n '/source,yaml/,/^----$/p'` produced empty output because AsciiDoc opens the listing block with `----` on the line immediately after `[source,yaml]`, so the range closes instantly. I read the full files with `tail -n +6` instead.
- [dependencies] Instruction 1 asked to focus on 'Go version' in the operator go.mod diff, but the operator's go directive is unchanged at go 1.26.3 on both sides, so the go.mod diff yielded no Go-version signal. I instead found the Go-version story in the collector repo, and found operator toolchain changes (KUBE_VERSION 1.36->1.37, controller-tools v0.21.0->v0.23.0, kustomize, kind, golangci-lint, govulncheck) only by additionally diffing the Makefile, which the instructions did not list.
- [dependencies] Instruction 3 (collector-core 'git diff v0.158.0..origin/main -- go.mod') is nearly useless as written: upstream emptied the root module's require blocks and deleted go.sum, so the root diff shows only 'go 1.25.0 -> go 1.26.0' plus the deletion of four direct and seven indirect deps. All real collector dependency data required diffing submodule go.mod files (I used otelcol/go.mod and config/configgrpc/go.mod and an aggregate grep over '**/go.mod'), which the instructions do not mention.
- [dependencies] The instructions only cover the operator's root go.mod; the operator also has a second module at apis/go.mod with its own dependency set (and a different go directive, 1.26.0 vs the root's 1.26.3). I diffed it separately and it contained a real change (goccy/go-yaml swapped for go.yaml.in/yaml/v3).
- [dependencies] The severity rubric ('HIGH = major bumps, Go version; MEDIUM = minor in critical deps; LOW = patch') does not map cleanly onto Go module reality: the k8s.io/* 0.36->0.37 and controller-runtime 0.24->0.25 moves are semver-minor but track a full Kubernetes release and routinely carry breaking API changes, so I rated them HIGH rather than MEDIUM. Conversely buraksezer/consistent v0.10.0 -> v1.1.0 is a major bump with no import-path change, so the compiler cannot catch it.
- [dependencies] Ran 'git fetch --tags' defensively on the collector repo; it was unnecessary since the v0.158.0 tag was already present locally.
- [test-coverage] Step 1b's grep pattern produced a large number of false positives and had to be replaced. It matched: (a) opentelemetry-operator/tests/e2e-openshift/README.md, which lists most component names and made ~20 components look 'implicit' upstream; (b) shell-script variables ($count in e2e-openshift/monitoring/check_metrics.sh matched the 'count' connector); (c) chainsaw step keys ('file: 00-install.yaml' matched the 'file' exporter); (d) unrelated k8s fields ('resource:' inside an HPA metrics block matched the 'resource' processor); (e) sub-config keys inside another component ('attributes:' under the obi receiver matched the 'attributes' processor). I excluded *.md and then replaced the grep entirely with a small indentation-aware Python scanner that only counts a token when it is a key directly under a receivers/processors/exporters/connectors/extensions block or a member of a pipeline list (bracket or dash form).
- [test-coverage] The bracket-list half of the suggested regex, `\[.*\b<type_key>\b.*\]`, and my first tightened variant `\[[^]]*(^|[,[ ])<tok>` are both unreliable: the `^` alternative can never match mid-line, so the first element of a list like `processors: [memory_limiter, transform]` is silently dropped. Only the YAML-structure parser gave consistent results.
- [test-coverage] Step 1d's QE dedicated-directory check as written only looks under distributed-tracing-qe/tests/e2e-otel/. I widened it to tests/e2e*/<candidate>/ for symmetry with the upstream check; in practice no extra dedicated dirs were found outside e2e-otel.
- [test-coverage] Two QE dedicated test directories are named with an 'ext' suffix that matches neither the directory name nor the type key: e2e-otel/filestorageext (filestorage / file_storage) and e2e-otel/k8sleaderelectorext (k8sleaderelector / k8s_leader_elector). The candidate-name loop classified both as merely 'implicit'; I upgraded them to 'dedicated' after manually listing the directories. The candidate list should include a '<name>ext' variant for extensions.
- [test-coverage] Upstream dedicated coverage also lives in per-case subdirectories one level deeper than the suite (e.g. tests/e2e-automatic-rbac/receiver-k8scluster/, tests/e2e/extension/), which `ls -d tests/e2e*/<candidate>/` does not find because the dir is named 'receiver-k8scluster' not 'k8sclusterreceiver'. I promoted k8sevents/kubeletstats/k8scluster/k8sobjects receivers, k8sattributes and resourcedetection processors, k8sleaderelector and healthcheck extensions from 'implicit' to 'dedicated' by inspecting the matched paths manually. The glob should be tests/e2e*/*<candidate-fragment>*/ to catch this automatically.
- [test-coverage] otlpexporter's canonical type is now `otlp_grpc` with `deprecated_type: otlp`, which collides with otlpreceiver's type `otlp`. A text search cannot distinguish the OTLP receiver from the OTLP exporter by type key alone; I relied on the receivers:/exporters: block the key sits under (the Python parser does not record which block, so both entries point at a config that contains both).
- [test-coverage] The component list in the task did not include the `repo` field referenced in step 1, so I probed opentelemetry-collector-contrib first and fell back to opentelemetry-collector for each metadata.yaml. All 58 resolved.
- [test-coverage] Step 2's suite-level check surfaced nothing: `git ls-tree tests/` at 7fb5138 and at origin/main list exactly the same 24 entries, so no e2e-* suite directory was added or deleted. Exactly one file was deleted under tests/ (install-minio.yaml), and it was replaced in-place by install-seaweedfs.yaml.
- [test-coverage] For step 3c, several of the suggested search terms produce matches that are not coverage and had to be rejected by inspection: 'autoscaling'/'horizontalpodautoscalers' only matched RBAC rule lists inside k8sclusterreceiver/k8seventsreceiver test manifests; 'ClusterRole' only matched rapidast security-scan setup in e2e-rh-sdl; 'cluster-observability' only matched the unrelated multicluster-observability-addon (MCOA) suite; 'mtls' only matched Tempo gateway secret names. Content inspection, not just the filename hit, was required for every feature.
