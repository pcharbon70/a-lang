ERL := erl
ERLC := erlc
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
	$(PHASE5_DIR)/alang_phase5_store_tests.erl
PHASE5_COMPILER_STAMP := $(PHASE5_BUILD)/.compiled

.PHONY: build-phase-1-artifact build-phase-2-artifact build-phase-3-evidence check-toolchain compile-phase-1-bootstrap compile-phase-1-runtime compile-phase-2-toolchain compile-phase-2-source compile-phase-2-runtime compile-phase-3-toolchain compile-phase-4-runtime compile-phase-5-runtime run-phase-1 run-phase-2 test test-phase-1 test-phase-2 test-phase-3 test-phase-4 test-phase-5 test-section-1-2 test-section-1-3 test-section-1-4 test-section-2-1 test-section-2-2 test-section-2-3 test-section-2-4 test-section-2-5 test-section-3-1 test-section-3-2 test-section-3-3 test-section-3-4 test-section-3-5 test-section-4-1 test-section-4-2 test-section-4-3 test-section-4-4 test-section-4-5 test-section-5-1 test-section-5-2

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

test-phase-5: test-section-5-2

test: test-phase-1 test-phase-2 test-phase-3 test-phase-4 test-phase-5

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
