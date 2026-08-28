ERL := erl
ERLC := erlc
REBAR3 := rebar3
PHASE1_DIR := src/phase-01
PHASE1_BUILD := build/phase-01/bootstrap
TOOLCHAIN_CONFIG := $(PHASE1_DIR)/toolchain.config
COMPILER_MODULE := $(PHASE1_BUILD)/alang_phase1_compiler.beam
COMPILER_TEST_MODULE := $(PHASE1_BUILD)/alang_phase1_compiler_tests.beam
FIXTURE_MODULE := $(PHASE1_BUILD)/alang_phase1_fixture.beam
PACKAGE_MODULE := $(PHASE1_BUILD)/alang_phase1_package.beam
ARTIFACT_TEST_MODULE := $(PHASE1_BUILD)/alang_phase1_artifact_tests.beam
RUNTIME_MODULE := $(PHASE1_BUILD)/alang_phase1_runtime.beam
INTEGRATION_TEST_MODULE := $(PHASE1_BUILD)/alang_phase1_integration_tests.beam
PHASE1_ARTIFACT := build/phase-01/artifact
SEMANTIC_FIXTURE := $(PHASE1_DIR)/semantic-fixture.config
PHASE2_DIR := src/phase-02
PHASE2_BUILD := build/phase-02/compiler
PHASE2_FRONTEND := build/phase-02/frontend
PHASE2_ARTIFACT := build/phase-02/artifact
PHASE2_SOURCE := $(PHASE2_DIR)/fixtures/counter.alang
PHASE2_FIXTURE := $(PHASE2_FRONTEND)/phase1-semantic-fixture.config
PHASE2_RUNTIME_MODULE := $(PHASE1_BUILD)/alang_phase2_runtime.beam
PHASE2_INTEGRATION_MODULE := $(PHASE1_BUILD)/alang_phase2_integration_tests.beam
PHASE2_COMPILER_SOURCES := \
	$(PHASE2_DIR)/alang_phase2_lexer.erl \
	$(PHASE2_DIR)/alang_phase2_parser.erl \
	$(PHASE2_DIR)/alang_phase2_semantics.erl \
	$(PHASE2_DIR)/alang_phase2_ir.erl \
	$(PHASE2_DIR)/alang_phase2_canonical.erl \
	$(PHASE2_DIR)/alang_phase2_reference.erl \
	$(PHASE2_DIR)/alang_phase2_views.erl \
	$(PHASE2_DIR)/alang_phase2_bridge.erl \
	$(PHASE2_DIR)/alang_phase2_compiler.erl \
	$(PHASE2_DIR)/alang_phase2_compiler_tests.erl
PHASE2_COMPILER_STAMP := $(PHASE2_BUILD)/.compiled
PHASE3_DIR := src/phase-03
PHASE3_BUILD := build/phase-03/compiler
PHASE3_EVIDENCE := build/phase-03/evidence/residency.config
PHASE3_SOURCES := \
	$(PHASE3_DIR)/alang_phase3_contract.erl \
	$(PHASE3_DIR)/alang_phase3_contract_tests.erl \
	$(PHASE3_DIR)/alang_phase3_lowering.erl \
	$(PHASE3_DIR)/alang_phase3_forms.erl \
	$(PHASE3_DIR)/alang_phase3_backend.erl \
	$(PHASE3_DIR)/alang_phase3_backend_tests.erl \
	$(PHASE3_DIR)/alang_phase3_abi.erl \
	$(PHASE3_DIR)/alang_phase3_trace.erl \
	$(PHASE3_DIR)/alang_phase3_effect_gateway.erl \
	$(PHASE3_DIR)/alang_phase3_task_worker.erl \
	$(PHASE3_DIR)/alang_phase3_session_sup.erl \
	$(PHASE3_DIR)/alang_phase3_launcher.erl \
	$(PHASE3_DIR)/alang_phase3_runtime_fixture.erl \
	$(PHASE3_DIR)/alang_phase3_runtime_tests.erl \
	$(PHASE3_DIR)/alang_phase3_artifact.erl \
	$(PHASE3_DIR)/alang_phase3_artifact_tests.erl \
	$(PHASE3_DIR)/alang_phase3_reference.erl \
	$(PHASE3_DIR)/alang_phase3_test_fixtures.erl \
	$(PHASE3_DIR)/alang_phase3_residency.erl \
	$(PHASE3_DIR)/alang_phase3_integration_tests.erl
PHASE3_COMPILER_STAMP := $(PHASE3_BUILD)/.compiled
PHASE4_DIR := src/phase-04
PHASE4_BUILD := build/phase-04/runtime
PHASE4_SOURCES := \
	$(PHASE4_DIR)/alang_phase4_effect_registry.erl \
	$(PHASE4_DIR)/alang_phase4_effect_registry_tests.erl \
	$(PHASE4_DIR)/alang_phase4_grants.erl \
	$(PHASE4_DIR)/alang_phase4_grants_tests.erl \
	$(PHASE4_DIR)/alang_phase4_broker.erl \
	$(PHASE4_DIR)/alang_phase4_broker_sup.erl \
	$(PHASE4_DIR)/alang_phase4_broker_tests.erl \
	$(PHASE4_DIR)/alang_phase4_workspace_sidecar.erl \
	$(PHASE4_DIR)/alang_phase4_workspace_adapter.erl \
	$(PHASE4_DIR)/alang_phase4_workspace_adapter_tests.erl \
	$(PHASE4_DIR)/alang_phase4_integration_fixture.erl \
	$(PHASE4_DIR)/alang_phase4_integration_tests.erl
PHASE4_COMPILER_STAMP := $(PHASE4_BUILD)/.compiled
PHASE5_DIR := src/phase-05
PHASE5_BUILD := build/phase-05/runtime
PHASE5_SOURCES := \
	$(PHASE5_DIR)/alang_phase5_state.erl \
	$(PHASE5_DIR)/alang_phase5_state_tests.erl \
	$(PHASE5_DIR)/alang_phase5_journal.erl \
	$(PHASE5_DIR)/alang_phase5_journal_tests.erl \
	$(PHASE5_DIR)/alang_phase5_store.erl \
	$(PHASE5_DIR)/alang_phase5_store_tests.erl \
	$(PHASE5_DIR)/alang_phase5_recovery.erl \
	$(PHASE5_DIR)/alang_phase5_runtime_process.erl \
	$(PHASE5_DIR)/alang_phase5_session_sup.erl \
	$(PHASE5_DIR)/alang_phase5_resume.erl \
	$(PHASE5_DIR)/alang_phase5_recovery_tests.erl \
	$(PHASE5_DIR)/alang_phase5_authority.erl \
	$(PHASE5_DIR)/alang_phase5_authority_tests.erl \
	$(PHASE5_DIR)/alang_phase5_effect_recovery.erl \
	$(PHASE5_DIR)/alang_phase5_effect_recovery_tests.erl \
	$(PHASE5_DIR)/alang_phase5_workflow.erl \
	$(PHASE5_DIR)/alang_phase5_failure_matrix.erl \
	$(PHASE5_DIR)/alang_phase5_node_fixture.erl \
	$(PHASE5_DIR)/alang_phase5_integration_tests.erl
PHASE5_COMPILER_STAMP := $(PHASE5_BUILD)/.compiled
PHASE6_DIR := src/phase-06
PHASE6_BUILD := build/phase-06/runtime
PHASE6_SOURCES := \
	$(PHASE6_DIR)/alang_phase6_model_protocol.erl \
	$(PHASE6_DIR)/alang_phase6_mock_model.erl \
	$(PHASE6_DIR)/alang_phase6_model_protocol_tests.erl \
	$(PHASE6_DIR)/alang_phase6_context.erl \
	$(PHASE6_DIR)/alang_phase6_task.erl \
	$(PHASE6_DIR)/alang_phase6_task_tests.erl \
	$(PHASE6_DIR)/alang_phase6_repair.erl \
	$(PHASE6_DIR)/alang_phase6_verifier.erl \
	$(PHASE6_DIR)/alang_phase6_repair_verifier_tests.erl \
	$(PHASE6_DIR)/alang_phase6_child.erl \
	$(PHASE6_DIR)/alang_phase6_child_worker.erl \
	$(PHASE6_DIR)/alang_phase6_child_sup.erl \
	$(PHASE6_DIR)/alang_phase6_child_tests.erl \
	$(PHASE6_DIR)/alang_phase6_integration_fixture.erl \
	$(PHASE6_DIR)/alang_phase6_orchestrator.erl \
	$(PHASE6_DIR)/alang_phase6_integration_tests.erl
PHASE6_COMPILER_STAMP := $(PHASE6_BUILD)/.compiled
PHASE7_DIR := src/phase-07
PHASE7_BUILD := build/phase-07/validation
PROPER_EBIN := _build/default/lib/proper/ebin
PHASE7_SOURCES := \
	$(PHASE7_DIR)/alang_phase7_generators.erl \
	$(PHASE7_DIR)/alang_phase7_observation.erl \
	$(PHASE7_DIR)/alang_phase7_law_tests.erl \
	$(PHASE7_DIR)/alang_phase7_authority_model.erl \
	$(PHASE7_DIR)/alang_phase7_history_model.erl \
	$(PHASE7_DIR)/alang_phase7_state_property_tests.erl \
	$(PHASE7_DIR)/alang_phase7_adversarial.erl \
	$(PHASE7_DIR)/alang_phase7_adversarial_tests.erl \
	$(PHASE7_DIR)/alang_phase7_fault_campaign.erl \
	$(PHASE7_DIR)/alang_phase7_bench.erl \
	$(PHASE7_DIR)/alang_phase7_fault_performance_tests.erl \
	$(PHASE7_DIR)/alang_phase7_mutation.erl \
	$(PHASE7_DIR)/alang_phase7_mutation_tests.erl \
	$(PHASE7_DIR)/alang_phase7_campaign.erl \
	$(PHASE7_DIR)/alang_phase7_campaign_tests.erl
PHASE7_COMPILER_STAMP := $(PHASE7_BUILD)/.compiled
PHASE8_DIR := src/phase-08
PHASE8_BUILD := build/phase-08/release
PHASE8_SOURCES := \
	$(PHASE8_DIR)/alang_phase8_demo.erl \
	$(PHASE8_DIR)/alang_phase8_inspect.erl \
	$(PHASE8_DIR)/alang_phase8_demo_tests.erl \
	$(PHASE8_DIR)/alang_phase8_comparison.erl \
	$(PHASE8_DIR)/alang_phase8_comparison_tests.erl \
	$(PHASE8_DIR)/alang_phase8_decision.erl \
	$(PHASE8_DIR)/alang_phase8_decision_tests.erl \
	$(PHASE8_DIR)/alang_phase8_release.erl \
	$(PHASE8_DIR)/alang_phase8_release_tests.erl
PHASE8_COMPILER_STAMP := $(PHASE8_BUILD)/.compiled
FIDELITY_DIR := src/effectful-source-fidelity
FIDELITY_ASSETS := assets/effectful-source-fidelity
FIDELITY_BUILD := build/effectful-source-fidelity/phase-01
FIDELITY_PHASE1_SOURCES := \
	$(FIDELITY_DIR)/alang_fidelity_json.erl \
	$(FIDELITY_DIR)/alang_fidelity_contract.erl \
	$(FIDELITY_DIR)/alang_fidelity_corpus.erl \
	$(FIDELITY_DIR)/alang_fidelity_decision.erl \
	$(FIDELITY_DIR)/alang_fidelity_preregister.erl \
	$(FIDELITY_DIR)/alang_fidelity_representation.erl \
	$(FIDELITY_DIR)/alang_fidelity_contract_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_corpus_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_decision_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_integration_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_representation_tests.erl
FIDELITY_PHASE1_CONTRACTS := \
	$(FIDELITY_ASSETS)/contracts/alang-task-comprehension-v1.schema.json \
	$(FIDELITY_ASSETS)/contracts/alang-answer-key-v1.schema.json \
	$(FIDELITY_ASSETS)/contracts/metrics-and-decision-v1.json \
	$(FIDELITY_ASSETS)/contracts/alang-source-v2-contract.json \
	$(FIDELITY_ASSETS)/contracts/alang-task-json-v1.schema.json \
	$(FIDELITY_ASSETS)/contracts/semantic-pair-v1.schema.json \
	$(FIDELITY_ASSETS)/contracts/pairing-and-materialization-v1.json \
	$(FIDELITY_ASSETS)/contracts/corpus-manifest-v1.schema.json \
	$(FIDELITY_ASSETS)/contracts/provider-profiles-v1.schema.json \
	$(FIDELITY_ASSETS)/contracts/campaign-policy-v1.schema.json
FIDELITY_PHASE1_REGISTRATION := \
	$(FIDELITY_ASSETS)/corpus/corpus-manifest-v1.json \
	$(wildcard $(FIDELITY_ASSETS)/corpus/*/*.alang) \
	$(wildcard $(FIDELITY_ASSETS)/corpus/*/*.json) \
	$(FIDELITY_ASSETS)/campaign/provider-profiles-v1.json \
	$(FIDELITY_ASSETS)/campaign/campaign-policy-v1.json \
	$(FIDELITY_ASSETS)/campaign/prompt-template-v1.txt
FIDELITY_PHASE1_STAMP := $(FIDELITY_BUILD)/.compiled
FIDELITY_PHASE1_EVIDENCE := $(FIDELITY_BUILD)/evidence/pre-registration-evidence.json
FIDELITY_PHASE2_BUILD := build/effectful-source-fidelity/phase-02
FIDELITY_PHASE2_SOURCES := \
	$(FIDELITY_DIR)/alang_fidelity_lexer.erl \
	$(FIDELITY_DIR)/alang_fidelity_parser.erl \
	$(FIDELITY_DIR)/alang_fidelity_ast.erl \
	$(FIDELITY_DIR)/alang_fidelity_canonical.erl \
	$(FIDELITY_DIR)/alang_fidelity_frontend_evidence.erl \
	$(FIDELITY_DIR)/alang_fidelity_frontend_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_body_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_ast_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_phase2_integration_tests.erl
FIDELITY_PHASE2_STAMP := $(FIDELITY_PHASE2_BUILD)/.compiled
FIDELITY_PHASE2_EVIDENCE := $(FIDELITY_PHASE2_BUILD)/evidence/frontend-evidence.etf
FIDELITY_PHASE3_BUILD := build/effectful-source-fidelity/phase-03
FIDELITY_PHASE3_SOURCES := \
	$(FIDELITY_DIR)/alang_fidelity_json_pointer.erl \
	$(FIDELITY_DIR)/alang_fidelity_control.erl \
	$(FIDELITY_DIR)/alang_fidelity_control_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_source.erl \
	$(FIDELITY_DIR)/alang_fidelity_semantics.erl \
	$(FIDELITY_DIR)/alang_fidelity_semantics_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_authority.erl \
	$(FIDELITY_DIR)/alang_fidelity_ir.erl \
	$(FIDELITY_DIR)/alang_fidelity_compiler.erl \
	$(FIDELITY_DIR)/alang_fidelity_lowering_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_phase3_mutation.erl \
	$(FIDELITY_DIR)/alang_fidelity_phase3_evidence.erl \
	$(FIDELITY_DIR)/alang_fidelity_phase3_integration_tests.erl
FIDELITY_PHASE3_STAMP := $(FIDELITY_PHASE3_BUILD)/.compiled
FIDELITY_PHASE3_EVIDENCE := $(FIDELITY_PHASE3_BUILD)/evidence/lowering-evidence.etf
FIDELITY_PHASE4_BUILD := build/effectful-source-fidelity/phase-04
FIDELITY_PHASE4_SOURCES := \
	$(FIDELITY_DIR)/alang_fidelity_forms_v2.erl \
	$(FIDELITY_DIR)/alang_fidelity_artifact_v2.erl \
	$(FIDELITY_DIR)/alang_fidelity_backend_v2.erl \
	$(FIDELITY_DIR)/alang_fidelity_backend_v2_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_runtime_abi.erl \
	$(FIDELITY_DIR)/alang_fidelity_completion.erl \
	$(FIDELITY_DIR)/alang_fidelity_runtime.erl \
	$(FIDELITY_DIR)/alang_fidelity_runtime_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_offline.erl \
	$(FIDELITY_DIR)/alang_fidelity_phase4_mutation.erl \
	$(FIDELITY_DIR)/alang_fidelity_offline_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_phase4_worker.erl \
	$(FIDELITY_DIR)/alang_fidelity_phase4_evidence.erl \
	$(FIDELITY_DIR)/alang_fidelity_phase4_integration_tests.erl
FIDELITY_PHASE4_STAMP := $(FIDELITY_PHASE4_BUILD)/.compiled
FIDELITY_PHASE4_EVIDENCE_DIR := $(FIDELITY_PHASE4_BUILD)/evidence
FIDELITY_PHASE4_REPRODUCTION_A := $(FIDELITY_PHASE4_EVIDENCE_DIR)/reproduction-a.etf
FIDELITY_PHASE4_REPRODUCTION_B := $(FIDELITY_PHASE4_EVIDENCE_DIR)/reproduction-b.etf
FIDELITY_PHASE4_EVIDENCE := $(FIDELITY_PHASE4_EVIDENCE_DIR)/source-to-beam-evidence.etf
FIDELITY_PHASE4_ERL_PATHS := -pa $(FIDELITY_PHASE4_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -pa $(PHASE6_BUILD) -pa $(PHASE7_BUILD) -pa $(PHASE8_BUILD)
FIDELITY_PHASE5_BUILD := build/effectful-source-fidelity/phase-05
FIDELITY_PHASE5_SOURCES := \
	$(FIDELITY_DIR)/alang_fidelity_adapter_fault_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_bootstrap.erl \
	$(FIDELITY_DIR)/alang_fidelity_campaign.erl \
	$(FIDELITY_DIR)/alang_fidelity_campaign_journal.erl \
	$(FIDELITY_DIR)/alang_fidelity_campaign_runner.erl \
	$(FIDELITY_DIR)/alang_fidelity_campaign_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_evidence.erl \
	$(FIDELITY_DIR)/alang_fidelity_observation.erl \
	$(FIDELITY_DIR)/alang_fidelity_provider_protocol.erl \
	$(FIDELITY_DIR)/alang_fidelity_https.erl \
	$(FIDELITY_DIR)/alang_fidelity_https_fixture.erl \
	$(FIDELITY_DIR)/alang_fidelity_openai_adapter.erl \
	$(FIDELITY_DIR)/alang_fidelity_anthropic_adapter.erl \
	$(FIDELITY_DIR)/alang_fidelity_live_gate.erl \
	$(FIDELITY_DIR)/alang_fidelity_offline_campaign.erl \
	$(FIDELITY_DIR)/alang_fidelity_phase5_integration_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_phase5_mutation.erl \
	$(FIDELITY_DIR)/alang_fidelity_phase5_worker.erl \
	$(FIDELITY_DIR)/alang_fidelity_provider_tests.erl \
	$(FIDELITY_DIR)/alang_fidelity_score.erl \
	$(FIDELITY_DIR)/alang_fidelity_scoring_tests.erl
FIDELITY_PHASE5_STAMP := $(FIDELITY_PHASE5_BUILD)/.compiled
FIDELITY_PHASE5_EVIDENCE_DIR := $(FIDELITY_PHASE5_BUILD)/evidence
FIDELITY_PHASE5_REPRODUCTION_A := $(FIDELITY_PHASE5_EVIDENCE_DIR)/reproduction-a.etf
FIDELITY_PHASE5_REPRODUCTION_B := $(FIDELITY_PHASE5_EVIDENCE_DIR)/reproduction-b.etf
FIDELITY_PHASE5_ERL_PATHS := -pa $(FIDELITY_PHASE5_BUILD) -pa $(FIDELITY_PHASE4_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD)
COMPACT_DIR := src/compact-projection-fidelity
COMPACT_ASSETS := assets/compact-projection-fidelity
COMPACT_BUILD := build/compact-projection-fidelity/phase-01
COMPACT_SECTION11_SOURCES := \
	$(FIDELITY_DIR)/alang_fidelity_json.erl \
	$(COMPACT_DIR)/alang_compact_contract.erl \
	$(COMPACT_DIR)/alang_compact_contract_tests.erl
COMPACT_SECTION11_ASSETS := \
	$(COMPACT_ASSETS)/contracts/campaign-contract-v1.json \
	$(COMPACT_ASSETS)/contracts/campaign-contract-v1.schema.json
COMPACT_SECTION11_STAMP := $(COMPACT_BUILD)/.section-1-1-compiled
COMPACT_SECTION12_SOURCES := \
	$(COMPACT_DIR)/alang_compact_power.erl \
	$(COMPACT_DIR)/alang_compact_schedule.erl \
	$(COMPACT_DIR)/alang_compact_design_tests.erl
COMPACT_SECTION12_ASSETS := \
	$(COMPACT_ASSETS)/campaign/power-design-v1.json \
	$(COMPACT_ASSETS)/campaign/case-design-v1.json \
	$(COMPACT_ASSETS)/campaign/schedule-policy-v1.json \
	$(COMPACT_ASSETS)/contracts/power-design-v1.schema.json \
	$(COMPACT_ASSETS)/contracts/case-design-v1.schema.json \
	$(COMPACT_ASSETS)/contracts/schedule-policy-v1.schema.json
COMPACT_SECTION12_STAMP := $(COMPACT_BUILD)/.section-1-2-compiled
COMPACT_SECTION13_SOURCES := \
	$(FIDELITY_DIR)/alang_fidelity_contract.erl \
	$(COMPACT_DIR)/alang_compact_corpus.erl \
	$(COMPACT_DIR)/alang_compact_registration.erl \
	$(COMPACT_DIR)/alang_compact_registration_tests.erl
COMPACT_SECTION13_ASSETS := \
	$(COMPACT_ASSETS)/corpus/confirmatory-corpus-v1.json \
	$(COMPACT_ASSETS)/campaign/provider-profiles-v1.json \
	$(COMPACT_ASSETS)/campaign/tokenizer-profiles-v1.json \
	$(COMPACT_ASSETS)/campaign/campaign-policy-v1.json \
	$(COMPACT_ASSETS)/contracts/confirmatory-corpus-v1.schema.json \
	$(COMPACT_ASSETS)/contracts/provider-profiles-v1.schema.json \
	$(COMPACT_ASSETS)/contracts/tokenizer-profiles-v1.schema.json \
	$(COMPACT_ASSETS)/contracts/campaign-policy-v1.schema.json
COMPACT_SECTION13_STAMP := $(COMPACT_BUILD)/.section-1-3-compiled
COMPACT_SECTION14_SOURCES := \
	$(COMPACT_DIR)/alang_compact_preregister.erl \
	$(COMPACT_DIR)/alang_compact_integration_tests.erl
COMPACT_SECTION14_ASSETS := \
	$(COMPACT_ASSETS)/campaign/projection-vocabulary-v1.json \
	$(COMPACT_ASSETS)/campaign/protocol-registry-v1.json \
	$(COMPACT_ASSETS)/campaign/traceability-v1.json \
	$(COMPACT_ASSETS)/contracts/projection-vocabulary-v1.schema.json \
	$(COMPACT_ASSETS)/contracts/protocol-registry-v1.schema.json \
	$(COMPACT_ASSETS)/contracts/traceability-v1.schema.json \
	$(COMPACT_ASSETS)/contracts/preregistration-evidence-v1.schema.json
COMPACT_SECTION14_STAMP := $(COMPACT_BUILD)/.section-1-4-compiled
COMPACT_PHASE1_EVIDENCE := $(COMPACT_BUILD)/evidence/pre-registration-evidence.json
COMPACT_PHASE2_BUILD := build/compact-projection-fidelity/phase-02
COMPACT_SECTION21_SOURCES := \
	$(FIDELITY_DIR)/alang_fidelity_json.erl \
	$(FIDELITY_DIR)/alang_fidelity_contract.erl \
	$(FIDELITY_DIR)/alang_fidelity_representation.erl \
	$(FIDELITY_DIR)/alang_fidelity_lexer.erl \
	$(FIDELITY_DIR)/alang_fidelity_parser.erl \
	$(FIDELITY_DIR)/alang_fidelity_ast.erl \
	$(FIDELITY_DIR)/alang_fidelity_source.erl \
	$(COMPACT_DIR)/alang_compact_tokenizer.erl \
	$(COMPACT_DIR)/alang_compact_tokenizer_tests.erl \
	$(COMPACT_DIR)/alang_compact_source_normalizer.erl \
	$(COMPACT_DIR)/alang_compact_surface.erl \
	$(COMPACT_DIR)/alang_compact_surface_tests.erl \
	$(COMPACT_DIR)/alang_compact_token_audit.erl \
	$(COMPACT_DIR)/alang_compact_token_audit_tests.erl
COMPACT_SECTION21_ASSETS := \
	$(COMPACT_ASSETS)/phase-02/contracts/surface-registry-v1.json \
	$(COMPACT_ASSETS)/phase-02/contracts/surface-registry-v1.schema.json \
	$(COMPACT_ASSETS)/phase-02/contracts/token-audit-contract-v1.json \
	$(COMPACT_ASSETS)/phase-02/contracts/token-audit-contract-v1.schema.json \
	$(COMPACT_ASSETS)/phase-02/tokenizers/cl100k_base.tiktoken \
	$(COMPACT_ASSETS)/phase-02/tokenizers/o200k_base.tiktoken \
	$(COMPACT_ASSETS)/phase-02/tokenizers/tokenizer-runtime-v1.json \
	$(COMPACT_ASSETS)/phase-02/tokenizers/tokenizer-runtime-v1.schema.json \
	$(COMPACT_ASSETS)/phase-02/tokenizers/tokenizer-conformance-v1.json
COMPACT_SECTION21_STAMP := $(COMPACT_PHASE2_BUILD)/.section-2-1-compiled
COMPACT_SECTION22_SOURCES := \
	$(COMPACT_DIR)/alang_compact_model.erl \
	$(COMPACT_DIR)/alang_compact_model_tests.erl \
	$(COMPACT_DIR)/alang_compact_source_map.erl \
	$(COMPACT_DIR)/alang_compact_surface.erl \
	$(COMPACT_DIR)/alang_compact_surface_tests.erl
COMPACT_SECTION22_ASSETS := \
	$(COMPACT_ASSETS)/phase-02/contracts/model-format-v1.json \
	$(COMPACT_ASSETS)/phase-02/contracts/model-format-v1.schema.json
COMPACT_SECTION22_STAMP := $(COMPACT_PHASE2_BUILD)/.section-2-2-compiled
COMPACT_SECTION23_SOURCES := \
	$(COMPACT_DIR)/alang_compact_opaque.erl \
	$(COMPACT_DIR)/alang_compact_opaque_tests.erl \
	$(COMPACT_DIR)/alang_compact_source_map.erl \
	$(COMPACT_DIR)/alang_compact_source_map_tests.erl \
	$(COMPACT_DIR)/alang_compact_surface.erl \
	$(COMPACT_DIR)/alang_compact_surface_tests.erl
COMPACT_SECTION23_ASSETS := \
	$(COMPACT_ASSETS)/phase-02/contracts/opaque-control-v1.json \
	$(COMPACT_ASSETS)/phase-02/contracts/opaque-control-v1.schema.json \
	$(COMPACT_ASSETS)/phase-02/contracts/source-map-v1.json \
	$(COMPACT_ASSETS)/phase-02/contracts/source-map-v1.schema.json
COMPACT_SECTION23_STAMP := $(COMPACT_PHASE2_BUILD)/.section-2-3-compiled
COMPACT_SECTION24_SOURCES := \
	$(COMPACT_DIR)/alang_compact_phase2_mutation.erl \
	$(COMPACT_DIR)/alang_compact_phase2_residency.erl \
	$(COMPACT_DIR)/alang_compact_phase2_worker.erl \
	$(COMPACT_DIR)/alang_compact_phase2_integration_tests.erl
COMPACT_SECTION24_STAMP := $(COMPACT_PHASE2_BUILD)/.section-2-4-compiled
COMPACT_PHASE2_EVIDENCE_DIR := $(COMPACT_PHASE2_BUILD)/evidence
COMPACT_PHASE2_REPRODUCTION_A := $(COMPACT_PHASE2_EVIDENCE_DIR)/reproduction-a.json
COMPACT_PHASE2_REPRODUCTION_B := $(COMPACT_PHASE2_EVIDENCE_DIR)/reproduction-b.json
COMPACT_PHASE2_ERL_PATHS := -pa $(PHASE2_BUILD) -pa $(FIDELITY_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(COMPACT_BUILD) -pa $(COMPACT_PHASE2_BUILD)
MNEMONIC_DIR := src/token-positive-mnemonic-promotion
MNEMONIC_ASSETS := assets/token-positive-mnemonic-promotion
MNEMONIC_BUILD := build/token-positive-mnemonic-promotion/phase-01
MNEMONIC_SECTION11_SOURCES := \
	$(FIDELITY_DIR)/alang_fidelity_json.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_contract.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_contract_tests.erl
MNEMONIC_SECTION11_ASSETS := \
	$(MNEMONIC_ASSETS)/contracts/campaign-contract-v1.json \
	$(MNEMONIC_ASSETS)/contracts/campaign-contract-v1.schema.json
MNEMONIC_SECTION11_STAMP := $(MNEMONIC_BUILD)/.section-1-1-compiled
MNEMONIC_SECTION12_SOURCES := \
	$(FIDELITY_DIR)/alang_fidelity_contract.erl \
	$(COMPACT_DIR)/alang_compact_power.erl \
	$(COMPACT_DIR)/alang_compact_corpus.erl \
	$(COMPACT_DIR)/alang_compact_registration.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_power.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_schedule.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_corpus.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_registration.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_design_tests.erl
MNEMONIC_SECTION12_ASSETS := \
	$(MNEMONIC_ASSETS)/campaign/campaign-policy-v1.json \
	$(MNEMONIC_ASSETS)/campaign/case-design-v1.json \
	$(MNEMONIC_ASSETS)/campaign/power-design-v1.json \
	$(MNEMONIC_ASSETS)/campaign/prompt-policy-v1.json \
	$(MNEMONIC_ASSETS)/campaign/provider-profiles-v1.json \
	$(MNEMONIC_ASSETS)/campaign/schedule-policy-v1.json \
	$(MNEMONIC_ASSETS)/campaign/tokenizer-profiles-v1.json \
	$(MNEMONIC_ASSETS)/corpus/confirmatory-corpus-v1.json \
	$(MNEMONIC_ASSETS)/contracts/campaign-policy-v1.schema.json \
	$(MNEMONIC_ASSETS)/contracts/case-design-v1.schema.json \
	$(MNEMONIC_ASSETS)/contracts/confirmatory-corpus-v1.schema.json \
	$(MNEMONIC_ASSETS)/contracts/power-design-v1.schema.json \
	$(MNEMONIC_ASSETS)/contracts/prompt-policy-v1.schema.json \
	$(MNEMONIC_ASSETS)/contracts/provider-profiles-v1.schema.json \
	$(MNEMONIC_ASSETS)/contracts/schedule-policy-v1.schema.json \
	$(MNEMONIC_ASSETS)/contracts/tokenizer-profiles-v1.schema.json
MNEMONIC_SECTION12_STAMP := $(MNEMONIC_BUILD)/.section-1-2-compiled
MNEMONIC_SECTION13_SOURCES := \
	$(MNEMONIC_DIR)/alang_mnemonic_mutation.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_preregister.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_phase1_worker.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_integration_tests.erl
MNEMONIC_SECTION13_ASSETS := \
	$(MNEMONIC_ASSETS)/campaign/traceability-v1.json \
	$(MNEMONIC_ASSETS)/contracts/traceability-v1.schema.json \
	$(MNEMONIC_ASSETS)/contracts/preregistration-evidence-v1.schema.json
MNEMONIC_SECTION13_STAMP := $(MNEMONIC_BUILD)/.section-1-3-compiled
MNEMONIC_PHASE1_EVIDENCE_DIR := $(MNEMONIC_BUILD)/evidence
MNEMONIC_PHASE1_REPRODUCTION_A := $(MNEMONIC_PHASE1_EVIDENCE_DIR)/reproduction-a.json
MNEMONIC_PHASE1_REPRODUCTION_B := $(MNEMONIC_PHASE1_EVIDENCE_DIR)/reproduction-b.json
MNEMONIC_PHASE2_BUILD := build/token-positive-mnemonic-promotion/phase-02
MNEMONIC_SECTION21_SOURCES := \
	$(FIDELITY_DIR)/alang_fidelity_json.erl \
	$(FIDELITY_DIR)/alang_fidelity_contract.erl \
	$(FIDELITY_DIR)/alang_fidelity_representation.erl \
	$(FIDELITY_DIR)/alang_fidelity_lexer.erl \
	$(FIDELITY_DIR)/alang_fidelity_parser.erl \
	$(FIDELITY_DIR)/alang_fidelity_ast.erl \
	$(FIDELITY_DIR)/alang_fidelity_source.erl \
	$(COMPACT_DIR)/alang_compact_source_normalizer.erl \
	$(COMPACT_DIR)/alang_compact_surface.erl \
	$(COMPACT_DIR)/alang_compact_source_map.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_candidate.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_candidate_tests.erl
MNEMONIC_SECTION21_ASSETS := \
	$(MNEMONIC_ASSETS)/phase-02/contracts/candidate-contract-v1.json \
	$(MNEMONIC_ASSETS)/phase-02/contracts/candidate-contract-v1.schema.json \
	$(COMPACT_ASSETS)/campaign/projection-vocabulary-v1.json \
	$(COMPACT_ASSETS)/phase-02/contracts/surface-registry-v1.json \
	$(COMPACT_ASSETS)/phase-02/contracts/source-map-v1.json
MNEMONIC_SECTION21_STAMP := $(MNEMONIC_PHASE2_BUILD)/.section-2-1-compiled
MNEMONIC_SECTION22_SOURCES := \
	$(COMPACT_DIR)/alang_compact_tokenizer.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_protocol.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_qualification.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_authorization.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_phase2_worker.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_protocol_tests.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_qualification_tests.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_authorization_tests.erl
MNEMONIC_SECTION22_ASSETS := \
	$(MNEMONIC_ASSETS)/phase-02/contracts/protocol-contract-v1.json \
	$(MNEMONIC_ASSETS)/phase-02/contracts/protocol-contract-v1.schema.json \
	$(MNEMONIC_ASSETS)/phase-02/contracts/qualification-contract-v1.json \
	$(MNEMONIC_ASSETS)/phase-02/contracts/qualification-contract-v1.schema.json \
	$(MNEMONIC_ASSETS)/phase-02/contracts/qualification-evidence-v1.schema.json \
	$(MNEMONIC_ASSETS)/phase-02/contracts/authorization-v1.json \
	$(MNEMONIC_ASSETS)/phase-02/contracts/authorization-v1.schema.json \
	$(COMPACT_ASSETS)/phase-02/tokenizers/tokenizer-runtime-v1.json \
	$(COMPACT_ASSETS)/phase-02/tokenizers/cl100k_base.tiktoken \
	$(COMPACT_ASSETS)/phase-02/tokenizers/o200k_base.tiktoken
MNEMONIC_SECTION22_STAMP := $(MNEMONIC_PHASE2_BUILD)/.section-2-2-compiled
MNEMONIC_PHASE2_EVIDENCE_DIR := $(MNEMONIC_PHASE2_BUILD)/evidence
MNEMONIC_PHASE2_QUALIFICATION_A := $(MNEMONIC_PHASE2_EVIDENCE_DIR)/qualification-a.json
MNEMONIC_PHASE2_QUALIFICATION_B := $(MNEMONIC_PHASE2_EVIDENCE_DIR)/qualification-b.json
MNEMONIC_SECTION23_SOURCES := \
	$(MNEMONIC_DIR)/alang_mnemonic_phase2_mutation.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_phase2_residency.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_phase2_evidence.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_phase2_integration_worker.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_phase2_integration_tests.erl
MNEMONIC_SECTION23_ASSETS := \
	$(MNEMONIC_ASSETS)/phase-02/contracts/phase-2-evidence-v1.schema.json
MNEMONIC_SECTION23_STAMP := $(MNEMONIC_PHASE2_BUILD)/.section-2-3-compiled
MNEMONIC_PHASE2_EVIDENCE_A := $(MNEMONIC_PHASE2_EVIDENCE_DIR)/phase-2-a.json
MNEMONIC_PHASE2_EVIDENCE_B := $(MNEMONIC_PHASE2_EVIDENCE_DIR)/phase-2-b.json
MNEMONIC_PHASE3_BUILD := build/token-positive-mnemonic-promotion/phase-03
MNEMONIC_SECTION31_SOURCES := \
	$(MNEMONIC_DIR)/alang_mnemonic_live_gate.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_journal.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_runner.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_ollama.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_execution_tests.erl
MNEMONIC_SECTION31_STAMP := $(MNEMONIC_PHASE3_BUILD)/.section-3-1-compiled
MNEMONIC_SECTION32_SOURCES := \
	$(MNEMONIC_DIR)/alang_mnemonic_observation.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_replay.erl \
	$(MNEMONIC_DIR)/alang_mnemonic_observation_tests.erl
MNEMONIC_SECTION32_STAMP := $(MNEMONIC_PHASE3_BUILD)/.section-3-2-compiled

.PHONY: build-phase-1-artifact build-phase-2-artifact build-phase-3-evidence check-toolchain compare compile-phase-1-bootstrap compile-phase-1-runtime compile-phase-2-toolchain compile-phase-2-source compile-phase-2-runtime compile-phase-3-toolchain compile-phase-4-runtime compile-phase-5-runtime compile-phase-6-runtime compile-phase-7-validation compile-phase-8-release decide demo release-candidate run-phase-1 run-phase-2 test test-phase-1 test-phase-2 test-phase-3 test-phase-4 test-phase-5 test-phase-6 test-phase-7 test-phase-8 test-section-1-2 test-section-1-3 test-section-1-4 test-section-2-1 test-section-2-2 test-section-2-3 test-section-2-4 test-section-2-5 test-section-3-1 test-section-3-2 test-section-3-3 test-section-3-4 test-section-3-5 test-section-4-1 test-section-4-2 test-section-4-3 test-section-4-4 test-section-4-5 test-section-5-1 test-section-5-2 test-section-5-3 test-section-5-4 test-section-5-5 test-section-6-1 test-section-6-2 test-section-6-3 test-section-6-4 test-section-6-5 test-section-7-1 test-section-7-2 test-section-7-3 test-section-7-4 test-section-7-5 test-section-8-1 test-section-8-2 test-section-8-3 test-section-8-4
.PHONY: build-fidelity-phase-1-evidence build-fidelity-phase-2-evidence build-fidelity-phase-3-evidence build-fidelity-phase-4-evidence build-fidelity-phase-4-reproduction build-fidelity-phase-5-offline-evidence compile-fidelity-phase-1 compile-fidelity-phase-2 compile-fidelity-phase-3 compile-fidelity-phase-4 compile-fidelity-phase-5 test-fidelity-phase-1 test-fidelity-phase-2 test-fidelity-phase-3 test-fidelity-phase-4 test-fidelity-phase-5 test-fidelity-section-1-1 test-fidelity-section-1-2 test-fidelity-section-1-3 test-fidelity-section-1-4 test-fidelity-section-2-1 test-fidelity-section-2-2 test-fidelity-section-2-3 test-fidelity-section-2-4 test-fidelity-section-3-1 test-fidelity-section-3-2 test-fidelity-section-3-3 test-fidelity-section-3-4 test-fidelity-section-4-1 test-fidelity-section-4-2 test-fidelity-section-4-3 test-fidelity-section-4-4 test-fidelity-section-5-1 test-fidelity-section-5-2 test-fidelity-section-5-3 test-fidelity-section-5-4
.PHONY: build-compact-phase-1-evidence build-compact-phase-2-reproduction compile-compact-section-1-1 compile-compact-section-1-2 compile-compact-section-1-3 compile-compact-section-1-4 compile-compact-section-2-1 compile-compact-section-2-2 compile-compact-section-2-3 compile-compact-section-2-4 test-compact-phase-1 test-compact-phase-2 test-compact-section-1-1 test-compact-section-1-2 test-compact-section-1-3 test-compact-section-1-4 test-compact-section-2-1 test-compact-section-2-2 test-compact-section-2-3 test-compact-section-2-4
.PHONY: build-mnemonic-phase-1-evidence build-mnemonic-phase-2-evidence build-mnemonic-phase-2-qualification compile-mnemonic-section-1-1 compile-mnemonic-section-1-2 compile-mnemonic-section-1-3 compile-mnemonic-section-2-1 compile-mnemonic-section-2-2 compile-mnemonic-section-2-3 compile-mnemonic-section-3-1 compile-mnemonic-section-3-2 test-mnemonic-section-1-1 test-mnemonic-section-1-2 test-mnemonic-section-1-3 test-mnemonic-phase-1 test-mnemonic-phase-2 test-mnemonic-section-2-1 test-mnemonic-section-2-2 test-mnemonic-section-2-3 test-mnemonic-section-3-1 test-mnemonic-section-3-2

compile-mnemonic-section-1-1: $(MNEMONIC_SECTION11_STAMP)

$(MNEMONIC_SECTION11_STAMP): $(MNEMONIC_SECTION11_SOURCES) $(MNEMONIC_SECTION11_ASSETS)
	mkdir -p $(MNEMONIC_BUILD)
	$(ERLC) -Werror +deterministic -o $(MNEMONIC_BUILD) $(MNEMONIC_SECTION11_SOURCES)
	touch $@

test-mnemonic-section-1-1: compile-mnemonic-section-1-1
	$(ERL) -noshell -pa $(MNEMONIC_BUILD) -eval 'case eunit:test(alang_mnemonic_contract_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

compile-mnemonic-section-1-2: $(MNEMONIC_SECTION12_STAMP)

$(MNEMONIC_SECTION12_STAMP): $(MNEMONIC_SECTION11_STAMP) $(MNEMONIC_SECTION12_SOURCES) $(MNEMONIC_SECTION12_ASSETS)
	$(ERLC) -Werror +deterministic -pa $(MNEMONIC_BUILD) -o $(MNEMONIC_BUILD) $(MNEMONIC_SECTION12_SOURCES)
	touch $@

test-mnemonic-section-1-2: test-mnemonic-section-1-1 compile-mnemonic-section-1-2
	$(ERL) -noshell -pa $(MNEMONIC_BUILD) -eval 'case eunit:test(alang_mnemonic_design_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

compile-mnemonic-section-1-3: $(MNEMONIC_SECTION13_STAMP)

$(MNEMONIC_SECTION13_STAMP): $(MNEMONIC_SECTION12_STAMP) $(MNEMONIC_SECTION13_SOURCES) $(MNEMONIC_SECTION13_ASSETS)
	$(ERLC) -Werror +deterministic -pa $(MNEMONIC_BUILD) -o $(MNEMONIC_BUILD) $(MNEMONIC_SECTION13_SOURCES)
	touch $@

build-mnemonic-phase-1-evidence: compile-mnemonic-section-1-3
	mkdir -p $(MNEMONIC_PHASE1_EVIDENCE_DIR)
	$(ERL) -noshell -pa $(MNEMONIC_BUILD) -s alang_mnemonic_phase1_worker main -extra $(MNEMONIC_PHASE1_REPRODUCTION_A)
	$(ERL) -noshell -pa $(MNEMONIC_BUILD) -s alang_mnemonic_phase1_worker main -extra $(MNEMONIC_PHASE1_REPRODUCTION_B)
	cmp $(MNEMONIC_PHASE1_REPRODUCTION_A) $(MNEMONIC_PHASE1_REPRODUCTION_B)

test-mnemonic-section-1-3: test-mnemonic-section-1-2 build-mnemonic-phase-1-evidence
	$(ERL) -noshell -pa $(MNEMONIC_BUILD) -eval 'case eunit:test(alang_mnemonic_integration_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-mnemonic-phase-1: test-mnemonic-section-1-3

compile-mnemonic-section-2-1: $(MNEMONIC_SECTION21_STAMP)

$(MNEMONIC_SECTION21_STAMP): $(MNEMONIC_SECTION13_STAMP) $(MNEMONIC_SECTION21_SOURCES) $(MNEMONIC_SECTION21_ASSETS)
	mkdir -p $(MNEMONIC_PHASE2_BUILD)
	$(ERLC) -Werror +deterministic -pa $(MNEMONIC_BUILD) -o $(MNEMONIC_PHASE2_BUILD) $(MNEMONIC_SECTION21_SOURCES)
	touch $@

test-mnemonic-section-2-1: test-mnemonic-phase-1 compile-mnemonic-section-2-1
	$(ERL) -noshell -pa $(MNEMONIC_PHASE2_BUILD) -pa $(MNEMONIC_BUILD) -eval 'case eunit:test(alang_mnemonic_candidate_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

compile-mnemonic-section-2-2: $(MNEMONIC_SECTION22_STAMP)

$(MNEMONIC_SECTION22_STAMP): $(MNEMONIC_SECTION21_STAMP) $(MNEMONIC_SECTION22_SOURCES) $(MNEMONIC_SECTION22_ASSETS)
	$(ERLC) -Werror +deterministic -pa $(MNEMONIC_PHASE2_BUILD) -pa $(MNEMONIC_BUILD) -o $(MNEMONIC_PHASE2_BUILD) $(MNEMONIC_SECTION22_SOURCES)
	touch $@

build-mnemonic-phase-2-qualification: compile-mnemonic-section-2-2
	mkdir -p $(MNEMONIC_PHASE2_EVIDENCE_DIR)
	$(ERL) -noshell -pa $(MNEMONIC_PHASE2_BUILD) -pa $(MNEMONIC_BUILD) -s alang_mnemonic_phase2_worker main -extra $(MNEMONIC_PHASE2_QUALIFICATION_A)
	$(ERL) -noshell -pa $(MNEMONIC_PHASE2_BUILD) -pa $(MNEMONIC_BUILD) -s alang_mnemonic_phase2_worker main -extra $(MNEMONIC_PHASE2_QUALIFICATION_B)
	cmp $(MNEMONIC_PHASE2_QUALIFICATION_A) $(MNEMONIC_PHASE2_QUALIFICATION_B)

test-mnemonic-section-2-2: test-mnemonic-section-2-1 build-mnemonic-phase-2-qualification
	$(ERL) -noshell -pa $(MNEMONIC_PHASE2_BUILD) -pa $(MNEMONIC_BUILD) -eval 'case eunit:test([alang_mnemonic_protocol_tests, alang_mnemonic_qualification_tests, alang_mnemonic_authorization_tests], [verbose]) of ok -> halt(0); error -> halt(1) end.'

compile-mnemonic-section-2-3: $(MNEMONIC_SECTION23_STAMP)

$(MNEMONIC_SECTION23_STAMP): $(MNEMONIC_SECTION22_STAMP) $(MNEMONIC_SECTION23_SOURCES) $(MNEMONIC_SECTION23_ASSETS)
	$(ERLC) -Werror +deterministic -pa $(MNEMONIC_PHASE2_BUILD) -pa $(MNEMONIC_BUILD) -o $(MNEMONIC_PHASE2_BUILD) $(MNEMONIC_SECTION23_SOURCES)
	touch $@

build-mnemonic-phase-2-evidence: compile-mnemonic-section-2-3
	mkdir -p $(MNEMONIC_PHASE2_EVIDENCE_DIR)
	$(ERL) -noshell -pa $(MNEMONIC_PHASE2_BUILD) -pa $(MNEMONIC_BUILD) -s alang_mnemonic_phase2_integration_worker main -extra $(MNEMONIC_PHASE2_EVIDENCE_A)
	$(ERL) -noshell -pa $(MNEMONIC_PHASE2_BUILD) -pa $(MNEMONIC_BUILD) -s alang_mnemonic_phase2_integration_worker main -extra $(MNEMONIC_PHASE2_EVIDENCE_B)
	cmp $(MNEMONIC_PHASE2_EVIDENCE_A) $(MNEMONIC_PHASE2_EVIDENCE_B)

test-mnemonic-section-2-3: test-mnemonic-section-2-2 build-mnemonic-phase-2-evidence
	$(ERL) -noshell -pa $(MNEMONIC_PHASE2_BUILD) -pa $(MNEMONIC_BUILD) -eval 'case eunit:test(alang_mnemonic_phase2_integration_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-mnemonic-phase-2: test-mnemonic-section-2-3

compile-mnemonic-section-3-1: $(MNEMONIC_SECTION31_STAMP)

$(MNEMONIC_SECTION31_STAMP): $(MNEMONIC_SECTION23_STAMP) $(MNEMONIC_SECTION31_SOURCES)
	mkdir -p $(MNEMONIC_PHASE3_BUILD)
	$(ERLC) -Werror +deterministic -pa $(MNEMONIC_PHASE2_BUILD) -pa $(MNEMONIC_BUILD) -o $(MNEMONIC_PHASE3_BUILD) $(MNEMONIC_SECTION31_SOURCES)
	touch $@

test-mnemonic-section-3-1: test-mnemonic-phase-2 compile-mnemonic-section-3-1
	$(ERL) -noshell -pa $(MNEMONIC_PHASE3_BUILD) -pa $(MNEMONIC_PHASE2_BUILD) -pa $(MNEMONIC_BUILD) -eval 'case eunit:test(alang_mnemonic_execution_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

compile-mnemonic-section-3-2: $(MNEMONIC_SECTION32_STAMP)

$(MNEMONIC_SECTION32_STAMP): $(MNEMONIC_SECTION31_STAMP) $(MNEMONIC_SECTION32_SOURCES)
	$(ERLC) -Werror +deterministic -pa $(MNEMONIC_PHASE3_BUILD) -pa $(MNEMONIC_PHASE2_BUILD) -pa $(MNEMONIC_BUILD) -o $(MNEMONIC_PHASE3_BUILD) $(MNEMONIC_SECTION32_SOURCES)
	touch $@

test-mnemonic-section-3-2: test-mnemonic-section-3-1 compile-mnemonic-section-3-2
	$(ERL) -noshell -pa $(MNEMONIC_PHASE3_BUILD) -pa $(MNEMONIC_PHASE2_BUILD) -pa $(MNEMONIC_BUILD) -eval 'case eunit:test(alang_mnemonic_observation_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

compile-compact-section-1-1: $(COMPACT_SECTION11_STAMP)

$(COMPACT_SECTION11_STAMP): $(COMPACT_SECTION11_SOURCES) $(COMPACT_SECTION11_ASSETS)
	mkdir -p $(COMPACT_BUILD)
	$(ERLC) -Werror +deterministic -o $(COMPACT_BUILD) $(COMPACT_SECTION11_SOURCES)
	touch $@

test-compact-section-1-1: compile-compact-section-1-1
	$(ERL) -noshell -pa $(COMPACT_BUILD) -eval 'case eunit:test(alang_compact_contract_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

compile-compact-section-1-2: $(COMPACT_SECTION12_STAMP)

$(COMPACT_SECTION12_STAMP): $(COMPACT_SECTION11_STAMP) $(COMPACT_SECTION12_SOURCES) $(COMPACT_SECTION12_ASSETS)
	$(ERLC) -Werror +deterministic -pa $(COMPACT_BUILD) -o $(COMPACT_BUILD) $(COMPACT_SECTION12_SOURCES)
	touch $@

test-compact-section-1-2: test-compact-section-1-1 compile-compact-section-1-2
	$(ERL) -noshell -pa $(COMPACT_BUILD) -eval 'case eunit:test(alang_compact_design_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

compile-compact-section-1-3: $(COMPACT_SECTION13_STAMP)

$(COMPACT_SECTION13_STAMP): $(COMPACT_SECTION12_STAMP) $(COMPACT_SECTION13_SOURCES) $(COMPACT_SECTION13_ASSETS)
	$(ERLC) -Werror +deterministic -pa $(COMPACT_BUILD) -o $(COMPACT_BUILD) $(COMPACT_SECTION13_SOURCES)
	touch $@

test-compact-section-1-3: test-compact-section-1-2 compile-compact-section-1-3
	$(ERL) -noshell -pa $(COMPACT_BUILD) -eval 'case eunit:test(alang_compact_registration_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

compile-compact-section-1-4: $(COMPACT_SECTION14_STAMP)

$(COMPACT_SECTION14_STAMP): $(COMPACT_SECTION13_STAMP) $(COMPACT_SECTION14_SOURCES) $(COMPACT_SECTION14_ASSETS)
	$(ERLC) -Werror +deterministic -pa $(COMPACT_BUILD) -o $(COMPACT_BUILD) $(COMPACT_SECTION14_SOURCES)
	touch $@

build-compact-phase-1-evidence: compile-compact-section-1-4
	$(ERL) -noshell -pa $(COMPACT_BUILD) -s alang_compact_preregister main -extra $(COMPACT_PHASE1_EVIDENCE)

test-compact-section-1-4: test-compact-section-1-3 build-compact-phase-1-evidence
	$(ERL) -noshell -pa $(COMPACT_BUILD) -eval 'case eunit:test(alang_compact_integration_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-compact-phase-1: test-compact-section-1-4

compile-compact-section-2-1: $(COMPACT_SECTION21_STAMP)

$(COMPACT_SECTION21_STAMP): $(COMPACT_SECTION14_STAMP) $(FIDELITY_PHASE3_STAMP) $(COMPACT_SECTION21_SOURCES) $(COMPACT_SECTION21_ASSETS)
	mkdir -p $(COMPACT_PHASE2_BUILD)
	$(ERLC) -Werror +deterministic -pa $(PHASE2_BUILD) -pa $(FIDELITY_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(COMPACT_BUILD) -o $(COMPACT_PHASE2_BUILD) $(COMPACT_SECTION21_SOURCES)
	touch $@

test-compact-section-2-1: test-compact-phase-1 compile-compact-section-2-1
	$(ERL) -noshell -pa $(PHASE2_BUILD) -pa $(FIDELITY_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(COMPACT_BUILD) -pa $(COMPACT_PHASE2_BUILD) -eval 'case eunit:test([alang_compact_tokenizer_tests, alang_compact_surface_tests, alang_compact_token_audit_tests], [verbose]) of ok -> halt(0); error -> halt(1) end.'

compile-compact-section-2-2: $(COMPACT_SECTION22_STAMP)

$(COMPACT_SECTION22_STAMP): $(COMPACT_SECTION21_STAMP) $(COMPACT_SECTION22_SOURCES) $(COMPACT_SECTION22_ASSETS)
	$(ERLC) -Werror +deterministic -pa $(PHASE2_BUILD) -pa $(FIDELITY_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(COMPACT_BUILD) -pa $(COMPACT_PHASE2_BUILD) -o $(COMPACT_PHASE2_BUILD) $(COMPACT_SECTION22_SOURCES)
	touch $@

test-compact-section-2-2: test-compact-section-2-1 compile-compact-section-2-2
	$(ERL) -noshell -pa $(PHASE2_BUILD) -pa $(FIDELITY_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(COMPACT_BUILD) -pa $(COMPACT_PHASE2_BUILD) -eval 'case eunit:test(alang_compact_model_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

compile-compact-section-2-3: $(COMPACT_SECTION23_STAMP)

$(COMPACT_SECTION23_STAMP): $(COMPACT_SECTION22_STAMP) $(COMPACT_SECTION23_SOURCES) $(COMPACT_SECTION23_ASSETS)
	$(ERLC) -Werror +deterministic -pa $(PHASE2_BUILD) -pa $(FIDELITY_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(COMPACT_BUILD) -pa $(COMPACT_PHASE2_BUILD) -o $(COMPACT_PHASE2_BUILD) $(COMPACT_SECTION23_SOURCES)
	touch $@

test-compact-section-2-3: test-compact-section-2-2 compile-compact-section-2-3
	$(ERL) -noshell -pa $(PHASE2_BUILD) -pa $(FIDELITY_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(COMPACT_BUILD) -pa $(COMPACT_PHASE2_BUILD) -eval 'case eunit:test([alang_compact_opaque_tests, alang_compact_source_map_tests], [verbose]) of ok -> halt(0); error -> halt(1) end.'

compile-compact-section-2-4: $(COMPACT_SECTION24_STAMP)

$(COMPACT_SECTION24_STAMP): $(COMPACT_SECTION23_STAMP) $(COMPACT_SECTION24_SOURCES)
	$(ERLC) -Werror +deterministic $(COMPACT_PHASE2_ERL_PATHS) -o $(COMPACT_PHASE2_BUILD) $(COMPACT_SECTION24_SOURCES)
	touch $@

build-compact-phase-2-reproduction: compile-compact-section-2-4
	mkdir -p $(COMPACT_PHASE2_EVIDENCE_DIR)
	$(ERL) -noshell $(COMPACT_PHASE2_ERL_PATHS) -s alang_compact_phase2_worker main -extra $(COMPACT_PHASE2_REPRODUCTION_A)
	$(ERL) -noshell $(COMPACT_PHASE2_ERL_PATHS) -s alang_compact_phase2_worker main -extra $(COMPACT_PHASE2_REPRODUCTION_B)
	cmp -s $(COMPACT_PHASE2_REPRODUCTION_A) $(COMPACT_PHASE2_REPRODUCTION_B)

test-compact-section-2-4: test-compact-section-2-3 build-compact-phase-2-reproduction
	$(ERL) -noshell $(COMPACT_PHASE2_ERL_PATHS) -eval 'case eunit:test(alang_compact_phase2_integration_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-compact-phase-2: test-compact-section-2-4

compile-fidelity-phase-1: $(FIDELITY_PHASE1_STAMP)

$(FIDELITY_PHASE1_STAMP): $(FIDELITY_PHASE1_SOURCES) $(FIDELITY_PHASE1_CONTRACTS) $(FIDELITY_PHASE1_REGISTRATION)
	mkdir -p $(FIDELITY_BUILD)
	$(ERLC) -Werror +deterministic -o $(FIDELITY_BUILD) $(FIDELITY_PHASE1_SOURCES)
	touch $@

test-fidelity-section-1-1: compile-fidelity-phase-1
	$(ERL) -noshell -pa $(FIDELITY_BUILD) -eval 'case eunit:test([alang_fidelity_contract_tests, alang_fidelity_decision_tests], [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-fidelity-section-1-2: test-fidelity-section-1-1
	$(ERL) -noshell -pa $(FIDELITY_BUILD) -eval 'case eunit:test(alang_fidelity_representation_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-fidelity-section-1-3: test-fidelity-section-1-2
	$(ERL) -noshell -pa $(FIDELITY_BUILD) -eval 'case eunit:test(alang_fidelity_corpus_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

build-fidelity-phase-1-evidence: compile-fidelity-phase-1
	$(ERL) -noshell -pa $(FIDELITY_BUILD) -s alang_fidelity_preregister main -extra $(FIDELITY_PHASE1_EVIDENCE)

test-fidelity-section-1-4: test-fidelity-section-1-3 build-fidelity-phase-1-evidence
	$(ERL) -noshell -pa $(FIDELITY_BUILD) -eval 'case eunit:test(alang_fidelity_integration_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-fidelity-phase-1: test-fidelity-section-1-4

compile-fidelity-phase-2: $(FIDELITY_PHASE2_STAMP)

$(FIDELITY_PHASE2_STAMP): $(FIDELITY_PHASE2_SOURCES) $(FIDELITY_PHASE1_STAMP) $(PHASE2_COMPILER_STAMP) rebar.config rebar.lock
	$(REBAR3) compile
	mkdir -p $(FIDELITY_PHASE2_BUILD)
	ERL_LIBS=$(CURDIR)/_build/default/lib $(ERLC) -Werror +deterministic -pa $(FIDELITY_BUILD) -pa $(PHASE2_BUILD) -o $(FIDELITY_PHASE2_BUILD) $(FIDELITY_PHASE2_SOURCES)
	touch $@

test-fidelity-section-2-1: test-fidelity-phase-1 compile-fidelity-phase-2
	$(ERL) -noshell -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -pa $(PHASE2_BUILD) -eval 'case eunit:test(alang_fidelity_frontend_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-fidelity-section-2-2: test-fidelity-section-2-1
	$(ERL) -noshell -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -pa $(PHASE2_BUILD) -eval 'case eunit:test(alang_fidelity_body_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-fidelity-section-2-3: test-fidelity-section-2-2
	$(ERL) -noshell -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -pa $(PHASE2_BUILD) -eval 'case eunit:test(alang_fidelity_ast_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

build-fidelity-phase-2-evidence: compile-fidelity-phase-2
	$(ERL) -noshell -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -pa $(PHASE2_BUILD) -s alang_fidelity_frontend_evidence main -extra $(FIDELITY_PHASE2_EVIDENCE)

test-fidelity-section-2-4: test-fidelity-section-2-3 build-fidelity-phase-2-evidence
	$(ERL) -noshell -pa $(PROPER_EBIN) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -pa $(PHASE2_BUILD) -eval 'case eunit:test([alang_phase2_compiler_tests, alang_fidelity_phase2_integration_tests], [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-fidelity-phase-2: test-fidelity-section-2-4

compile-fidelity-phase-3: $(FIDELITY_PHASE3_STAMP)

$(FIDELITY_PHASE3_STAMP): $(FIDELITY_PHASE3_SOURCES) $(FIDELITY_PHASE2_STAMP)
	mkdir -p $(FIDELITY_PHASE3_BUILD)
	$(ERLC) -Werror +deterministic -pa $(PROPER_EBIN) -pa $(FIDELITY_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -o $(FIDELITY_PHASE3_BUILD) $(FIDELITY_PHASE3_SOURCES)
	touch $@

test-fidelity-section-3-1: test-fidelity-phase-2 compile-fidelity-phase-3
	$(ERL) -noshell -pa $(FIDELITY_PHASE3_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -eval 'case eunit:test(alang_fidelity_control_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-fidelity-section-3-2: test-fidelity-section-3-1
	$(ERL) -noshell -pa $(FIDELITY_PHASE3_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -eval 'case eunit:test(alang_fidelity_semantics_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-fidelity-section-3-3: test-fidelity-section-3-2
	$(ERL) -noshell -pa $(FIDELITY_PHASE3_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -eval 'case eunit:test(alang_fidelity_lowering_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

build-fidelity-phase-3-evidence: compile-fidelity-phase-3
	$(ERL) -noshell -pa $(FIDELITY_PHASE3_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -s alang_fidelity_phase3_evidence main -extra $(FIDELITY_PHASE3_EVIDENCE)

test-fidelity-section-3-4: test-fidelity-section-3-3 build-fidelity-phase-3-evidence
	$(ERL) -noshell -pa $(PROPER_EBIN) -pa $(FIDELITY_PHASE3_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -eval 'case eunit:test(alang_fidelity_phase3_integration_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-fidelity-phase-3: test-fidelity-section-3-4

compile-fidelity-phase-4: $(FIDELITY_PHASE4_STAMP)

$(FIDELITY_PHASE4_STAMP): $(FIDELITY_PHASE4_SOURCES) $(FIDELITY_PHASE3_STAMP) $(COMPILER_MODULE) $(PHASE3_COMPILER_STAMP) $(PHASE4_COMPILER_STAMP) $(PHASE5_COMPILER_STAMP) $(PHASE6_COMPILER_STAMP)
	mkdir -p $(FIDELITY_PHASE4_BUILD)
	$(ERLC) -Werror +deterministic -pa $(PROPER_EBIN) -pa $(FIDELITY_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(PHASE1_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -pa $(PHASE6_BUILD) -o $(FIDELITY_PHASE4_BUILD) $(FIDELITY_PHASE4_SOURCES)
	touch $@

test-fidelity-section-4-1: test-fidelity-phase-3 compile-fidelity-phase-4
	$(ERL) -noshell -pa $(FIDELITY_PHASE4_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -pa $(PHASE1_BUILD) -eval 'case eunit:test(alang_fidelity_backend_v2_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-fidelity-section-4-2: test-fidelity-section-4-1
	$(ERL) -noshell -pa $(FIDELITY_PHASE4_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -pa $(PHASE1_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -pa $(PHASE6_BUILD) -eval 'case eunit:test(alang_fidelity_runtime_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-fidelity-section-4-3: test-fidelity-section-4-2 test-phase-8
	$(ERL) -noshell -pa $(FIDELITY_PHASE4_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -pa $(PHASE6_BUILD) -pa $(PHASE7_BUILD) -pa $(PHASE8_BUILD) -eval 'case eunit:test(alang_fidelity_offline_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

build-fidelity-phase-4-reproduction: compile-fidelity-phase-4
	mkdir -p $(FIDELITY_PHASE4_EVIDENCE_DIR)
	$(ERL) -noshell $(FIDELITY_PHASE4_ERL_PATHS) -s alang_fidelity_phase4_worker main -extra $(FIDELITY_PHASE4_REPRODUCTION_A)
	$(ERL) -noshell $(FIDELITY_PHASE4_ERL_PATHS) -s alang_fidelity_phase4_worker main -extra $(FIDELITY_PHASE4_REPRODUCTION_B)
	cmp $(FIDELITY_PHASE4_REPRODUCTION_A) $(FIDELITY_PHASE4_REPRODUCTION_B)

build-fidelity-phase-4-evidence: test-fidelity-section-4-3 build-fidelity-phase-4-reproduction
	$(ERL) -noshell $(FIDELITY_PHASE4_ERL_PATHS) -s alang_fidelity_phase4_evidence main -extra $(FIDELITY_PHASE4_EVIDENCE)

test-fidelity-section-4-4: build-fidelity-phase-4-evidence
	$(ERL) -noshell $(FIDELITY_PHASE4_ERL_PATHS) -eval 'case eunit:test(alang_fidelity_phase4_integration_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-fidelity-phase-4: test-fidelity-section-4-4

compile-fidelity-phase-5: $(FIDELITY_PHASE5_STAMP)

$(FIDELITY_PHASE5_STAMP): $(FIDELITY_PHASE5_SOURCES) $(FIDELITY_PHASE4_STAMP)
	mkdir -p $(FIDELITY_PHASE5_BUILD)
	$(ERLC) -Werror +deterministic -pa $(FIDELITY_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(FIDELITY_PHASE4_BUILD) -o $(FIDELITY_PHASE5_BUILD) $(FIDELITY_PHASE5_SOURCES)
	touch $@

test-fidelity-section-5-1: test-fidelity-phase-4 compile-fidelity-phase-5
	$(ERL) -noshell -pa $(FIDELITY_PHASE5_BUILD) -pa $(FIDELITY_PHASE4_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -eval 'case eunit:test(alang_fidelity_provider_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-fidelity-section-5-2: test-fidelity-section-5-1
	$(ERL) -noshell -pa $(FIDELITY_PHASE5_BUILD) -pa $(FIDELITY_PHASE4_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -eval 'case eunit:test(alang_fidelity_campaign_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-fidelity-section-5-3: test-fidelity-section-5-2
	$(ERL) -noshell -pa $(FIDELITY_PHASE5_BUILD) -pa $(FIDELITY_PHASE4_BUILD) -pa $(FIDELITY_PHASE3_BUILD) -pa $(FIDELITY_PHASE2_BUILD) -pa $(FIDELITY_BUILD) -eval 'case eunit:test(alang_fidelity_scoring_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

build-fidelity-phase-5-offline-evidence: compile-fidelity-phase-5
	mkdir -p $(FIDELITY_PHASE5_EVIDENCE_DIR)
	$(ERL) -noshell $(FIDELITY_PHASE5_ERL_PATHS) -s alang_fidelity_phase5_worker main -extra $(FIDELITY_PHASE5_REPRODUCTION_A)
	$(ERL) -noshell $(FIDELITY_PHASE5_ERL_PATHS) -s alang_fidelity_phase5_worker main -extra $(FIDELITY_PHASE5_REPRODUCTION_B)
	cmp $(FIDELITY_PHASE5_REPRODUCTION_A) $(FIDELITY_PHASE5_REPRODUCTION_B)

test-fidelity-section-5-4: test-fidelity-section-5-3 build-fidelity-phase-5-offline-evidence
	$(ERL) -noshell $(FIDELITY_PHASE5_ERL_PATHS) -eval 'case eunit:test([alang_fidelity_adapter_fault_tests, alang_fidelity_phase5_integration_tests], [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-fidelity-phase-5: test-fidelity-section-5-4

check-toolchain: $(COMPILER_MODULE)
	$(ERL) -noshell -pa $(PHASE1_BUILD) -eval 'case alang_phase1_compiler:check_toolchain("$(TOOLCHAIN_CONFIG)") of {ok, Actual} -> io:format("toolchain_ok ~tp~n", [Actual]), halt(0); {error, Reason} -> io:format(standard_error, "toolchain_error ~tp~n", [Reason]), halt(1) end.'

compile-phase-1-bootstrap: $(COMPILER_MODULE) $(COMPILER_TEST_MODULE) $(FIXTURE_MODULE) $(PACKAGE_MODULE) $(ARTIFACT_TEST_MODULE)

compile-phase-1-runtime: compile-phase-1-bootstrap $(RUNTIME_MODULE) $(INTEGRATION_TEST_MODULE)

test-section-1-2: check-toolchain compile-phase-1-bootstrap
	$(ERL) -noshell -pa $(PHASE1_BUILD) -eval 'case eunit:test(alang_phase1_compiler_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

build-phase-1-artifact: check-toolchain compile-phase-1-bootstrap
	$(ERL) -noshell -pa $(PHASE1_BUILD) -eval 'case alang_phase1_package:build("$(PHASE1_ARTIFACT)", "$(SEMANTIC_FIXTURE)", "$(TOOLCHAIN_CONFIG)") of {ok, Built} -> case alang_phase1_package:verify("$(PHASE1_ARTIFACT)", "$(SEMANTIC_FIXTURE)", "$(TOOLCHAIN_CONFIG)") of {ok, Verified} -> io:format("artifact_ok module=~p beam_sha256=~s manifest_sha256=~s~n", [maps:get(module, Built), maps:get(beam_sha256, Verified), maps:get(manifest_sha256, Verified)]), halt(0); {error, VerifyReason} -> io:format(standard_error, "artifact_verify_error ~tp~n", [VerifyReason]), halt(1) end; {error, BuildReason} -> io:format(standard_error, "artifact_build_error ~tp~n", [BuildReason]), halt(1) end.'

test-section-1-3: test-section-1-2 build-phase-1-artifact
	$(ERL) -noshell -pa $(PHASE1_BUILD) -eval 'case eunit:test(alang_phase1_artifact_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-1-4: test-section-1-3 compile-phase-1-runtime
	$(ERL) -noshell -sname alang_phase1_test_$$$$ -setcookie alang_phase1_local_test -pa $(PHASE1_BUILD) -s alang_phase1_integration_tests main

run-phase-1: build-phase-1-artifact compile-phase-1-runtime
	$(ERL) -noshell -sname alang_phase1_run_$$$$ -setcookie alang_phase1_local_test -pa $(PHASE1_BUILD) -s alang_phase1_runtime main

test-phase-1: test-section-1-4 run-phase-1

test-section-2-1: compile-phase-2-toolchain
	$(ERL) -noshell -pa $(PHASE2_BUILD) -eval 'case eunit:test(alang_phase2_compiler_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-2-2: test-section-2-1

test-section-2-3: test-section-2-2

test-section-2-4: test-section-2-3

compile-phase-2-toolchain: $(PHASE2_COMPILER_STAMP)

$(PHASE2_COMPILER_STAMP): $(PHASE2_COMPILER_SOURCES)
	mkdir -p $(PHASE2_BUILD)
	$(ERLC) -Werror +deterministic -o $(PHASE2_BUILD) $(PHASE2_COMPILER_SOURCES)
	touch $@

compile-phase-2-source: compile-phase-2-toolchain compile-phase-1-bootstrap
	$(ERL) -noshell -pa $(PHASE2_BUILD) -pa $(PHASE1_BUILD) -s alang_phase2_compiler main -extra $(PHASE2_SOURCE) $(PHASE2_FRONTEND)

build-phase-2-artifact: compile-phase-2-source check-toolchain compile-phase-1-bootstrap
	$(ERL) -noshell -pa $(PHASE1_BUILD) -eval 'case alang_phase1_package:build("$(PHASE2_ARTIFACT)", "$(PHASE2_FIXTURE)", "$(TOOLCHAIN_CONFIG)") of {ok, Built} -> case alang_phase1_package:verify("$(PHASE2_ARTIFACT)", "$(PHASE2_FIXTURE)", "$(TOOLCHAIN_CONFIG)") of {ok, Verified} -> io:format("phase_2_artifact_ok module=~p beam_sha256=~s manifest_sha256=~s~n", [maps:get(module, Built), maps:get(beam_sha256, Verified), maps:get(manifest_sha256, Verified)]), halt(0); {error, VerifyReason} -> io:format(standard_error, "phase_2_artifact_verify_error ~tp~n", [VerifyReason]), halt(1) end; {error, BuildReason} -> io:format(standard_error, "phase_2_artifact_build_error ~tp~n", [BuildReason]), halt(1) end.'

compile-phase-2-runtime: compile-phase-1-runtime $(PHASE2_RUNTIME_MODULE) $(PHASE2_INTEGRATION_MODULE)

test-section-2-5: test-section-2-4
	$(MAKE) build-phase-2-artifact compile-phase-2-runtime
	$(ERL) -noshell -sname alang_phase2_test_$$$$ -setcookie alang_phase2_local_test -pa $(PHASE1_BUILD) -s alang_phase2_integration_tests main

run-phase-2: build-phase-2-artifact compile-phase-2-runtime
	$(ERL) -noshell -sname alang_phase2_run_$$$$ -setcookie alang_phase2_local_test -pa $(PHASE1_BUILD) -s alang_phase2_runtime main

test-phase-2: test-section-2-5 run-phase-2

compile-phase-3-toolchain: $(PHASE3_COMPILER_STAMP)

$(PHASE3_COMPILER_STAMP): $(PHASE3_SOURCES)
	mkdir -p $(PHASE3_BUILD)
	$(ERLC) -Werror +deterministic -o $(PHASE3_BUILD) $(PHASE3_SOURCES)
	touch $@

test-section-3-1: compile-phase-2-toolchain compile-phase-3-toolchain
	$(ERL) -noshell -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -eval 'case eunit:test(alang_phase3_contract_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-3-2: test-section-3-1
	$(ERL) -noshell -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -eval 'case eunit:test(alang_phase3_backend_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-3-3: test-section-3-2
	$(ERL) -noshell -pa $(PHASE3_BUILD) -eval 'case eunit:test(alang_phase3_runtime_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-3-4: test-section-3-3
	$(ERL) -noshell -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -eval 'case eunit:test(alang_phase3_artifact_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

build-phase-3-evidence: compile-phase-1-bootstrap compile-phase-2-toolchain compile-phase-3-toolchain
	$(ERL) -noshell -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -eval 'case alang_phase3_residency:write("$(PHASE3_EVIDENCE)") of {ok, Evidence} -> io:format("phase_3_residency_ok modules=~B engine=~p otp=~s~n", [maps:size(maps:get(module_paths, Evidence)), maps:get(engine, Evidence), maps:get(otp_release, Evidence)]), halt(0); {error, Reason} -> io:format(standard_error, "phase_3_residency_error ~tp~n", [Reason]), halt(1) end.'

test-section-3-5: test-section-3-4 build-phase-3-evidence
	$(ERL) -noshell -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -eval 'case eunit:test(alang_phase3_integration_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-phase-3: test-section-3-5

compile-phase-4-runtime: $(PHASE4_COMPILER_STAMP)

$(PHASE4_COMPILER_STAMP): $(PHASE4_SOURCES)
	mkdir -p $(PHASE4_BUILD)
	$(ERLC) -Werror +deterministic -o $(PHASE4_BUILD) $(PHASE4_SOURCES)
	touch $@

test-section-4-1: compile-phase-4-runtime
	$(ERL) -noshell -pa $(PHASE4_BUILD) -eval 'case eunit:test(alang_phase4_effect_registry_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-4-2: test-section-4-1
	$(ERL) -noshell -pa $(PHASE4_BUILD) -eval 'case eunit:test(alang_phase4_grants_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-4-3: test-section-4-2
	$(ERL) -noshell -pa $(PHASE4_BUILD) -eval 'case eunit:test(alang_phase4_broker_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-4-4: test-section-4-3
	$(ERL) -noshell -pa $(PHASE4_BUILD) -eval 'case eunit:test(alang_phase4_workspace_adapter_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-4-5: test-section-4-4 compile-phase-1-bootstrap compile-phase-2-toolchain compile-phase-3-toolchain
	$(ERL) -noshell -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -eval 'case eunit:test(alang_phase4_integration_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-phase-4: test-section-4-5

compile-phase-5-runtime: $(PHASE5_COMPILER_STAMP)

$(PHASE5_COMPILER_STAMP): $(PHASE5_SOURCES)
	mkdir -p $(PHASE5_BUILD)
	$(ERLC) -Werror +deterministic -o $(PHASE5_BUILD) $(PHASE5_SOURCES)
	touch $@

test-section-5-1: compile-phase-5-runtime
	$(ERL) -noshell -pa $(PHASE5_BUILD) -eval 'case eunit:test(alang_phase5_state_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-5-2: test-section-5-1
	$(ERL) -noshell -pa $(PHASE5_BUILD) -eval 'case eunit:test([alang_phase5_journal_tests, alang_phase5_store_tests], [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-5-3: test-section-5-2 compile-phase-1-bootstrap compile-phase-2-toolchain compile-phase-3-toolchain compile-phase-4-runtime
	$(ERL) -noshell -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -eval 'case eunit:test(alang_phase5_recovery_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-5-4: test-section-5-3
	$(ERL) -noshell -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -eval 'case eunit:test([alang_phase5_authority_tests, alang_phase5_effect_recovery_tests], [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-5-5: test-section-5-4 compile-phase-1-bootstrap compile-phase-2-toolchain compile-phase-3-toolchain compile-phase-4-runtime
	$(ERL) -noshell -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -eval 'case eunit:test(alang_phase5_integration_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-phase-5: test-section-5-5

compile-phase-6-runtime: $(PHASE6_COMPILER_STAMP)

$(PHASE6_COMPILER_STAMP): $(PHASE6_SOURCES)
	mkdir -p $(PHASE6_BUILD)
	$(ERLC) -Werror +deterministic -o $(PHASE6_BUILD) $(PHASE6_SOURCES)
	touch $@

test-section-6-1: compile-phase-6-runtime
	$(ERL) -noshell -pa $(PHASE6_BUILD) -eval 'case eunit:test(alang_phase6_model_protocol_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-6-2: test-section-6-1
	$(ERL) -noshell -pa $(PHASE6_BUILD) -eval 'case eunit:test(alang_phase6_task_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-6-3: test-section-6-2
	$(ERL) -noshell -pa $(PHASE6_BUILD) -eval 'case eunit:test(alang_phase6_repair_verifier_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-6-4: test-section-6-3 compile-phase-3-toolchain compile-phase-4-runtime
	$(ERL) -noshell -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE6_BUILD) -eval 'case eunit:test(alang_phase6_child_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-6-5: test-section-6-4 compile-phase-1-bootstrap compile-phase-2-toolchain compile-phase-3-toolchain compile-phase-4-runtime compile-phase-5-runtime
	$(ERL) -noshell -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -pa $(PHASE6_BUILD) -eval 'case eunit:test(alang_phase6_integration_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-phase-6: test-section-6-5

compile-phase-7-validation: $(PHASE7_COMPILER_STAMP)

$(PHASE7_COMPILER_STAMP): $(PHASE7_SOURCES) rebar.config rebar.lock
	$(REBAR3) compile
	mkdir -p $(PHASE7_BUILD)
	ERL_LIBS=$(CURDIR)/_build/default/lib $(ERLC) -Werror +deterministic -o $(PHASE7_BUILD) $(PHASE7_SOURCES)
	touch $@

test-section-7-1: compile-phase-1-bootstrap compile-phase-2-toolchain compile-phase-3-toolchain compile-phase-7-validation
	$(ERL) -noshell -pa $(PROPER_EBIN) -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE7_BUILD) -eval 'case eunit:test(alang_phase7_law_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-7-2: test-section-7-1 compile-phase-4-runtime compile-phase-5-runtime
	$(ERL) -noshell -pa $(PROPER_EBIN) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -pa $(PHASE7_BUILD) -eval 'case eunit:test(alang_phase7_state_property_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-7-3: test-section-7-2 compile-phase-6-runtime
	$(ERL) -noshell -pa $(PROPER_EBIN) -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -pa $(PHASE6_BUILD) -pa $(PHASE7_BUILD) -eval 'case eunit:test(alang_phase7_adversarial_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-7-4: test-section-7-3 test-section-3-3 test-section-4-4 test-section-5-5 test-section-6-5
	$(ERL) -noshell -pa $(PROPER_EBIN) -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -pa $(PHASE6_BUILD) -pa $(PHASE7_BUILD) -eval 'case eunit:test(alang_phase7_fault_performance_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-section-7-5: test-section-7-4
	$(ERL) -noshell -pa $(PROPER_EBIN) -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -pa $(PHASE6_BUILD) -pa $(PHASE7_BUILD) -eval 'case eunit:test([alang_phase7_mutation_tests, alang_phase7_campaign_tests], [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-phase-7: test-section-7-5

compile-phase-8-release: $(PHASE8_COMPILER_STAMP)

$(PHASE8_COMPILER_STAMP): $(PHASE8_SOURCES)
	mkdir -p $(PHASE8_BUILD)
	$(ERLC) -Werror +deterministic -o $(PHASE8_BUILD) $(PHASE8_SOURCES)
	touch $@

demo: compile-phase-1-bootstrap compile-phase-2-toolchain compile-phase-3-toolchain compile-phase-4-runtime compile-phase-5-runtime compile-phase-6-runtime compile-phase-7-validation compile-phase-8-release
	$(ERL) -noshell -pa $(PROPER_EBIN) -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -pa $(PHASE6_BUILD) -pa $(PHASE7_BUILD) -pa $(PHASE8_BUILD) -s alang_phase8_demo main -extra build/phase-08/demo

test-section-8-1: demo
	$(ERL) -noshell -pa $(PROPER_EBIN) -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -pa $(PHASE6_BUILD) -pa $(PHASE7_BUILD) -pa $(PHASE8_BUILD) -eval 'case eunit:test(alang_phase8_demo_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

compare: compile-phase-8-release
	$(ERL) -noshell -pa $(PROPER_EBIN) -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -pa $(PHASE6_BUILD) -pa $(PHASE7_BUILD) -pa $(PHASE8_BUILD) -s alang_phase8_comparison main -extra build/phase-08/comparison

test-section-8-2: test-section-8-1 test-section-7-4 test-section-7-5 compare
	$(ERL) -noshell -pa $(PROPER_EBIN) -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -pa $(PHASE6_BUILD) -pa $(PHASE7_BUILD) -pa $(PHASE8_BUILD) -eval 'case eunit:test(alang_phase8_comparison_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

decide: compile-phase-8-release
	$(ERL) -noshell -pa $(PHASE8_BUILD) -s alang_phase8_decision main -extra build/phase-08/decision/architecture-decision.config

test-section-8-3: test-section-8-2 decide
	$(ERL) -noshell -pa $(PHASE8_BUILD) -eval 'case eunit:test(alang_phase8_decision_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

release-candidate: compile-phase-8-release
	$(ERL) -noshell -pa $(PROPER_EBIN) -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -pa $(PHASE6_BUILD) -pa $(PHASE7_BUILD) -pa $(PHASE8_BUILD) -s alang_phase8_release main -extra build/phase-08/release-candidate

test-section-8-4: test-phase-1 test-phase-2 test-phase-3 test-phase-4 test-phase-5 test-phase-6 test-phase-7 test-section-8-3 release-candidate
	$(ERL) -noshell -pa $(PROPER_EBIN) -pa $(PHASE1_BUILD) -pa $(PHASE2_BUILD) -pa $(PHASE3_BUILD) -pa $(PHASE4_BUILD) -pa $(PHASE5_BUILD) -pa $(PHASE6_BUILD) -pa $(PHASE7_BUILD) -pa $(PHASE8_BUILD) -eval 'case eunit:test(alang_phase8_release_tests, [verbose]) of ok -> halt(0); error -> halt(1) end.'

test-phase-8: test-section-8-4

test: test-phase-1 test-phase-2 test-phase-3 test-phase-4 test-phase-5 test-phase-6 test-phase-7 test-phase-8 test-fidelity-phase-1 test-fidelity-phase-2 test-fidelity-phase-3 test-fidelity-phase-4

$(PHASE1_BUILD):
	mkdir -p $(PHASE1_BUILD)

$(COMPILER_MODULE): $(PHASE1_DIR)/alang_phase1_compiler.erl | $(PHASE1_BUILD)
	$(ERLC) -Werror +deterministic -o $(PHASE1_BUILD) $<

$(COMPILER_TEST_MODULE): $(PHASE1_DIR)/alang_phase1_compiler_tests.erl $(COMPILER_MODULE) | $(PHASE1_BUILD)
	$(ERLC) -Werror +deterministic -o $(PHASE1_BUILD) $<

$(FIXTURE_MODULE): $(PHASE1_DIR)/alang_phase1_fixture.erl | $(PHASE1_BUILD)
	$(ERLC) -Werror +deterministic -o $(PHASE1_BUILD) $<

$(PACKAGE_MODULE): $(PHASE1_DIR)/alang_phase1_package.erl $(COMPILER_MODULE) $(FIXTURE_MODULE) | $(PHASE1_BUILD)
	$(ERLC) -Werror +deterministic -o $(PHASE1_BUILD) $<

$(ARTIFACT_TEST_MODULE): $(PHASE1_DIR)/alang_phase1_artifact_tests.erl $(COMPILER_MODULE) $(FIXTURE_MODULE) $(PACKAGE_MODULE) | $(PHASE1_BUILD)
	$(ERLC) -Werror +deterministic -o $(PHASE1_BUILD) $<

$(RUNTIME_MODULE): $(PHASE1_DIR)/alang_phase1_runtime.erl $(PACKAGE_MODULE) | $(PHASE1_BUILD)
	$(ERLC) -Werror +deterministic -o $(PHASE1_BUILD) $<

$(INTEGRATION_TEST_MODULE): $(PHASE1_DIR)/alang_phase1_integration_tests.erl $(COMPILER_MODULE) $(PACKAGE_MODULE) $(RUNTIME_MODULE) | $(PHASE1_BUILD)
	$(ERLC) -Werror +deterministic -o $(PHASE1_BUILD) $<

$(PHASE2_RUNTIME_MODULE): src/phase-02/alang_phase2_runtime.erl $(RUNTIME_MODULE) | $(PHASE1_BUILD)
	$(ERLC) -Werror +deterministic -o $(PHASE1_BUILD) $<

$(PHASE2_INTEGRATION_MODULE): src/phase-02/alang_phase2_integration_tests.erl $(PHASE2_RUNTIME_MODULE) | $(PHASE1_BUILD)
	$(ERLC) -Werror +deterministic -o $(PHASE1_BUILD) $<
