-- CC Switch SQLite 导出
-- 生成时间: 2026-05-25 08:02:19
-- user_version: 10
PRAGMA foreign_keys=OFF;
PRAGMA user_version=10;
BEGIN TRANSACTION;
CREATE TABLE mcp_servers (
            id TEXT PRIMARY KEY, name TEXT NOT NULL, server_config TEXT NOT NULL,
            description TEXT, homepage TEXT, docs TEXT, tags TEXT NOT NULL DEFAULT '[]',
            enabled_claude BOOLEAN NOT NULL DEFAULT 0, enabled_codex BOOLEAN NOT NULL DEFAULT 0,
            enabled_gemini BOOLEAN NOT NULL DEFAULT 0, enabled_opencode BOOLEAN NOT NULL DEFAULT 0
        , "enabled_hermes" BOOLEAN NOT NULL DEFAULT 0);
CREATE TABLE model_pricing (
            model_id TEXT PRIMARY KEY, display_name TEXT NOT NULL,
            input_cost_per_million TEXT NOT NULL, output_cost_per_million TEXT NOT NULL,
            cache_read_cost_per_million TEXT NOT NULL DEFAULT '0',
            cache_creation_cost_per_million TEXT NOT NULL DEFAULT '0'
        );
CREATE TABLE prompts (
            id TEXT NOT NULL, app_type TEXT NOT NULL, name TEXT NOT NULL, content TEXT NOT NULL,
            description TEXT, enabled BOOLEAN NOT NULL DEFAULT 1, created_at INTEGER, updated_at INTEGER,
            PRIMARY KEY (id, app_type)
        );
CREATE TABLE provider_endpoints (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                provider_id TEXT NOT NULL,
                app_type TEXT NOT NULL,
                url TEXT NOT NULL,
                added_at INTEGER,
                FOREIGN KEY (provider_id, app_type) REFERENCES providers(id, app_type) ON DELETE CASCADE
            );
CREATE TABLE provider_health (
            provider_id TEXT NOT NULL, app_type TEXT NOT NULL, is_healthy INTEGER NOT NULL DEFAULT 1,
            consecutive_failures INTEGER NOT NULL DEFAULT 0, last_success_at TEXT, last_failure_at TEXT,
            last_error TEXT, updated_at TEXT NOT NULL,
            PRIMARY KEY (provider_id, app_type),
            FOREIGN KEY (provider_id, app_type) REFERENCES providers(id, app_type) ON DELETE CASCADE
        );
CREATE TABLE providers (
                id TEXT NOT NULL,
                app_type TEXT NOT NULL,
                name TEXT NOT NULL,
                settings_config TEXT NOT NULL,
                website_url TEXT,
                category TEXT,
                created_at INTEGER,
                sort_index INTEGER,
                notes TEXT,
                icon TEXT,
                icon_color TEXT,
                meta TEXT NOT NULL DEFAULT '{}',
                is_current BOOLEAN NOT NULL DEFAULT 0,
                in_failover_queue BOOLEAN NOT NULL DEFAULT 0, "cost_multiplier" TEXT NOT NULL DEFAULT '1.0', "limit_daily_usd" TEXT, "limit_monthly_usd" TEXT, "provider_type" TEXT,
                PRIMARY KEY (id, app_type)
            );
CREATE TABLE proxy_config (
            app_type TEXT PRIMARY KEY CHECK (app_type IN ('claude','codex','gemini')),
            proxy_enabled INTEGER NOT NULL DEFAULT 0, listen_address TEXT NOT NULL DEFAULT '127.0.0.1',
            listen_port INTEGER NOT NULL DEFAULT 15721, enable_logging INTEGER NOT NULL DEFAULT 1,
            enabled INTEGER NOT NULL DEFAULT 0, auto_failover_enabled INTEGER NOT NULL DEFAULT 0,
            max_retries INTEGER NOT NULL DEFAULT 3, streaming_first_byte_timeout INTEGER NOT NULL DEFAULT 60,
            streaming_idle_timeout INTEGER NOT NULL DEFAULT 120, non_streaming_timeout INTEGER NOT NULL DEFAULT 600,
            circuit_failure_threshold INTEGER NOT NULL DEFAULT 4, circuit_success_threshold INTEGER NOT NULL DEFAULT 2,
            circuit_timeout_seconds INTEGER NOT NULL DEFAULT 60, circuit_error_rate_threshold REAL NOT NULL DEFAULT 0.6,
            circuit_min_requests INTEGER NOT NULL DEFAULT 10,
            default_cost_multiplier TEXT NOT NULL DEFAULT '1',
            pricing_model_source TEXT NOT NULL DEFAULT 'response',
            created_at TEXT NOT NULL DEFAULT (datetime('now')), updated_at TEXT NOT NULL DEFAULT (datetime('now'))
        , live_takeover_active INTEGER NOT NULL DEFAULT 0);
CREATE TABLE proxy_live_backup (
            app_type TEXT PRIMARY KEY, original_config TEXT NOT NULL, backed_up_at TEXT NOT NULL
        );
CREATE TABLE proxy_request_logs (
            request_id TEXT PRIMARY KEY, provider_id TEXT NOT NULL, app_type TEXT NOT NULL, model TEXT NOT NULL,
            request_model TEXT,
            input_tokens INTEGER NOT NULL DEFAULT 0, output_tokens INTEGER NOT NULL DEFAULT 0,
            cache_read_tokens INTEGER NOT NULL DEFAULT 0, cache_creation_tokens INTEGER NOT NULL DEFAULT 0,
            input_cost_usd TEXT NOT NULL DEFAULT '0', output_cost_usd TEXT NOT NULL DEFAULT '0',
            cache_read_cost_usd TEXT NOT NULL DEFAULT '0', cache_creation_cost_usd TEXT NOT NULL DEFAULT '0',
            total_cost_usd TEXT NOT NULL DEFAULT '0', latency_ms INTEGER NOT NULL, first_token_ms INTEGER,
            duration_ms INTEGER, status_code INTEGER NOT NULL, error_message TEXT, session_id TEXT,
            provider_type TEXT, is_streaming INTEGER NOT NULL DEFAULT 0,
            cost_multiplier TEXT NOT NULL DEFAULT '1.0', created_at INTEGER NOT NULL
        , "data_source" TEXT NOT NULL DEFAULT 'proxy');
CREATE TABLE session_log_sync (
                file_path TEXT PRIMARY KEY,
                last_modified INTEGER NOT NULL,
                last_line_offset INTEGER NOT NULL DEFAULT 0,
                last_synced_at INTEGER NOT NULL
            );
CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE skill_repos (
            owner TEXT NOT NULL, name TEXT NOT NULL, branch TEXT NOT NULL DEFAULT 'main',
            enabled BOOLEAN NOT NULL DEFAULT 1, PRIMARY KEY (owner, name)
        );
CREATE TABLE skills (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            directory TEXT NOT NULL,
            repo_owner TEXT,
            repo_name TEXT,
            repo_branch TEXT DEFAULT 'main',
            readme_url TEXT,
            enabled_claude BOOLEAN NOT NULL DEFAULT 0,
            enabled_codex BOOLEAN NOT NULL DEFAULT 0,
            enabled_gemini BOOLEAN NOT NULL DEFAULT 0,
            enabled_opencode BOOLEAN NOT NULL DEFAULT 0,
            installed_at INTEGER NOT NULL DEFAULT 0
        , "content_hash" TEXT, "updated_at" INTEGER NOT NULL DEFAULT 0, "enabled_hermes" BOOLEAN NOT NULL DEFAULT 0);
CREATE TABLE stream_check_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT, provider_id TEXT NOT NULL, provider_name TEXT NOT NULL,
            app_type TEXT NOT NULL, status TEXT NOT NULL, success INTEGER NOT NULL, message TEXT NOT NULL,
            response_time_ms INTEGER, http_status INTEGER, model_used TEXT,
            retry_count INTEGER DEFAULT 0, tested_at INTEGER NOT NULL
        );
CREATE TABLE usage_daily_rollups (
                date TEXT NOT NULL,
                app_type TEXT NOT NULL,
                provider_id TEXT NOT NULL,
                model TEXT NOT NULL,
                request_count INTEGER NOT NULL DEFAULT 0,
                success_count INTEGER NOT NULL DEFAULT 0,
                input_tokens INTEGER NOT NULL DEFAULT 0,
                output_tokens INTEGER NOT NULL DEFAULT 0,
                cache_read_tokens INTEGER NOT NULL DEFAULT 0,
                cache_creation_tokens INTEGER NOT NULL DEFAULT 0,
                total_cost_usd TEXT NOT NULL DEFAULT '0',
                avg_latency_ms INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (date, app_type, provider_id, model)
            );
CREATE INDEX idx_providers_failover
             ON providers(app_type, in_failover_queue, sort_index);
CREATE INDEX idx_request_logs_created_at ON proxy_request_logs(created_at);
CREATE INDEX idx_request_logs_model ON proxy_request_logs(model);
CREATE INDEX idx_request_logs_provider ON proxy_request_logs(provider_id, app_type);
CREATE INDEX idx_request_logs_session ON proxy_request_logs(session_id);
CREATE INDEX idx_request_logs_status ON proxy_request_logs(status_code);
CREATE INDEX idx_stream_check_logs_provider
             ON stream_check_logs(app_type, provider_id, tested_at DESC);
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('claude-opus-4-7', 'Claude Opus 4.7', '5', '25', '0.50', '6.25');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('claude-opus-4-6-20260206', 'Claude Opus 4.6', '5', '25', '0.50', '6.25');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('claude-sonnet-4-6-20260217', 'Claude Sonnet 4.6', '3', '15', '0.30', '3.75');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('claude-opus-4-5-20251101', 'Claude Opus 4.5', '5', '25', '0.50', '6.25');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('claude-sonnet-4-5-20250929', 'Claude Sonnet 4.5', '3', '15', '0.30', '3.75');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('claude-haiku-4-5-20251001', 'Claude Haiku 4.5', '1', '5', '0.10', '1.25');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('claude-opus-4-20250514', 'Claude Opus 4', '15', '75', '1.50', '18.75');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('claude-opus-4-1-20250805', 'Claude Opus 4.1', '15', '75', '1.50', '18.75');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('claude-sonnet-4-20250514', 'Claude Sonnet 4', '3', '15', '0.30', '3.75');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('claude-3-5-haiku-20241022', 'Claude 3.5 Haiku', '0.80', '4', '0.08', '1');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('claude-3-5-sonnet-20241022', 'Claude 3.5 Sonnet', '3', '15', '0.30', '3.75');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.4', 'GPT-5.4', '2.50', '15', '0.25', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.4-mini', 'GPT-5.4 Mini', '0.75', '4.50', '0.075', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.4-nano', 'GPT-5.4 Nano', '0.20', '1.25', '0.02', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.2', 'GPT-5.2', '1.75', '14', '0.175', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.2-low', 'GPT-5.2', '1.75', '14', '0.175', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.2-medium', 'GPT-5.2', '1.75', '14', '0.175', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.2-high', 'GPT-5.2', '1.75', '14', '0.175', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.2-xhigh', 'GPT-5.2', '1.75', '14', '0.175', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.2-codex', 'GPT-5.2 Codex', '1.75', '14', '0.175', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.2-codex-low', 'GPT-5.2 Codex', '1.75', '14', '0.175', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.2-codex-medium', 'GPT-5.2 Codex', '1.75', '14', '0.175', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.2-codex-high', 'GPT-5.2 Codex', '1.75', '14', '0.175', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.2-codex-xhigh', 'GPT-5.2 Codex', '1.75', '14', '0.175', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.3-codex', 'GPT-5.3 Codex', '1.75', '14', '0.175', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.3-codex-low', 'GPT-5.3 Codex', '1.75', '14', '0.175', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.3-codex-medium', 'GPT-5.3 Codex', '1.75', '14', '0.175', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.3-codex-high', 'GPT-5.3 Codex', '1.75', '14', '0.175', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.3-codex-xhigh', 'GPT-5.3 Codex', '1.75', '14', '0.175', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.1', 'GPT-5.1', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.1-low', 'GPT-5.1', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.1-medium', 'GPT-5.1', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.1-high', 'GPT-5.1', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.1-minimal', 'GPT-5.1', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.1-codex', 'GPT-5.1 Codex', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.1-codex-mini', 'GPT-5.1 Codex', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.1-codex-max', 'GPT-5.1 Codex', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.1-codex-max-high', 'GPT-5.1 Codex', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5.1-codex-max-xhigh', 'GPT-5.1 Codex', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5', 'GPT-5', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5-low', 'GPT-5', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5-medium', 'GPT-5', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5-high', 'GPT-5', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5-minimal', 'GPT-5', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5-codex', 'GPT-5 Codex', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5-codex-low', 'GPT-5 Codex', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5-codex-medium', 'GPT-5 Codex', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5-codex-high', 'GPT-5 Codex', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5-codex-mini', 'GPT-5 Codex', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5-codex-mini-medium', 'GPT-5 Codex', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5-codex-mini-high', 'GPT-5 Codex', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('o3', 'OpenAI o3', '2', '8', '0.50', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('o4-mini', 'OpenAI o4-mini', '1.10', '4.40', '0.275', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-4.1', 'GPT-4.1', '2', '8', '0.50', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-4.1-mini', 'GPT-4.1 Mini', '0.40', '1.60', '0.10', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-4.1-nano', 'GPT-4.1 Nano', '0.10', '0.40', '0.025', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gemini-3.1-pro-preview', 'Gemini 3.1 Pro Preview', '2', '12', '0.20', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gemini-3.1-flash-lite-preview', 'Gemini 3.1 Flash Lite Preview', '0.25', '1.50', '0.025', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gemini-3-pro-preview', 'Gemini 3 Pro Preview', '2', '12', '0.2', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gemini-3-flash-preview', 'Gemini 3 Flash Preview', '0.5', '3', '0.05', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gemini-2.5-pro', 'Gemini 2.5 Pro', '1.25', '10', '0.125', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gemini-2.5-flash', 'Gemini 2.5 Flash', '0.3', '2.5', '0.03', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gemini-2.5-flash-lite', 'Gemini 2.5 Flash Lite', '0.10', '0.40', '0.01', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gemini-2.0-flash', 'Gemini 2.0 Flash', '0.10', '0.40', '0.025', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('step-3.5-flash', 'Step 3.5 Flash', '0.10', '0.30', '0.02', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('doubao-seed-code', 'Doubao Seed Code', '0.17', '1.11', '0.02', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('doubao-seed-2-0-pro', 'Doubao Seed 2.0 Pro', '0.47', '2.37', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('doubao-seed-2-0-code', 'Doubao Seed 2.0 Code', '0.47', '2.37', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('doubao-seed-2-0-lite', 'Doubao Seed 2.0 Lite', '0.25', '2', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('doubao-seed-2-0-mini', 'Doubao Seed 2.0 Mini', '0.03', '0.31', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('deepseek-v3.2', 'DeepSeek V3.2', '0.28', '0.42', '0.028', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('deepseek-v3.1', 'DeepSeek V3.1', '0.55', '1.67', '0.055', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('deepseek-v3', 'DeepSeek V3', '0.28', '1.11', '0.028', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('deepseek-chat', 'DeepSeek Chat', '0.27', '1.10', '0.07', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('deepseek-reasoner', 'DeepSeek Reasoner', '0.55', '2.19', '0.14', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('kimi-k2-thinking', 'Kimi K2 Thinking', '0.55', '2.20', '0.10', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('kimi-k2-0905', 'Kimi K2', '0.55', '2.20', '0.10', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('kimi-k2-turbo', 'Kimi K2 Turbo', '1.11', '8.06', '0.14', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('kimi-k2.5', 'Kimi K2.5', '0.60', '2.50', '0.10', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('kimi-k2.6', 'Kimi K2.6', '0.95', '4.00', '0.16', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('minimax-m2.1', 'MiniMax M2.1', '0.27', '0.95', '0.03', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('minimax-m2.1-lightning', 'MiniMax M2.1 Lightning', '0.27', '2.33', '0.03', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('minimax-m2', 'MiniMax M2', '0.27', '0.95', '0.03', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('minimax-m2.5', 'MiniMax M2.5', '0.12', '0.95', '0.03', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('minimax-m2.5-lightning', 'MiniMax M2.5 Lightning', '0.30', '2.40', '0.03', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('minimax-m2.7', 'MiniMax M2.7', '0.30', '1.20', '0.06', '0.375');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('minimax-m2.7-highspeed', 'MiniMax M2.7 Highspeed', '0.60', '2.40', '0.06', '0.375');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('glm-4.7', 'GLM-4.7', '0.39', '1.75', '0.04', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('glm-4.6', 'GLM-4.6', '0.28', '1.11', '0.03', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('glm-5', 'GLM-5', '0.72', '2.30', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('glm-5.1', 'GLM-5.1', '0.95', '3.15', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('mimo-v2-flash', 'Mimo V2 Flash', '0.09', '0.29', '0.009', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('mimo-v2-pro', 'MiMo V2 Pro', '1', '3', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('qwen3.6-plus', 'Qwen3.6 Plus', '0.325', '1.95', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('qwen3.5-plus', 'Qwen3.5 Plus', '0.26', '1.56', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('qwen3-max', 'Qwen3 Max', '0.78', '3.90', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('qwen3-235b-a22b', 'Qwen3 235B-A22B', '0.70', '8.40', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('qwen3-coder-plus', 'Qwen3 Coder Plus', '0.65', '3.25', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('qwen3-coder-flash', 'Qwen3 Coder Flash', '0.195', '0.975', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('qwen3-coder-next', 'Qwen3 Coder Next', '0.12', '0.75', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('qwq-plus', 'QwQ Plus', '0.80', '2.40', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('qwq-32b', 'QwQ 32B', '0.20', '0.60', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('qwen3-32b', 'Qwen3 32B', '0.16', '0.64', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('grok-4.20-0309-reasoning', 'Grok 4.20 Reasoning', '2', '6', '0.20', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('grok-4.20-0309-non-reasoning', 'Grok 4.20', '2', '6', '0.20', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('grok-4-1-fast-reasoning', 'Grok 4.1 Fast Reasoning', '0.20', '0.50', '0.05', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('grok-4-1-fast-non-reasoning', 'Grok 4.1 Fast', '0.20', '0.50', '0.05', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('grok-4', 'Grok 4', '3', '15', '0.75', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('grok-code-fast-1', 'Grok Code Fast', '0.20', '1.50', '0.02', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('grok-3', 'Grok 3', '3', '15', '0.75', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('grok-3-mini', 'Grok 3 Mini', '0.25', '0.50', '0.075', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('codestral-2508', 'Codestral', '0.30', '0.90', '0.03', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('devstral-small-1.1', 'Devstral Small 1.1', '0.07', '0.28', '0.01', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('devstral-2-2512', 'Devstral 2', '0.40', '0.90', '0.04', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('devstral-medium', 'Devstral Medium', '0.40', '2', '0.04', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('mistral-large-3-2512', 'Mistral Large 3', '0.50', '1.50', '0.05', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('mistral-medium-3.1', 'Mistral Medium 3.1', '0.40', '2', '0.04', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('mistral-small-3.2-24b', 'Mistral Small 3.2', '0.075', '0.20', '0.01', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('magistral-medium', 'Magistral Medium', '2', '5', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('command-a', 'Cohere Command A', '2.50', '10', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('command-r-plus', 'Cohere Command R+', '2.50', '10', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('command-r', 'Cohere Command R', '0.15', '0.60', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('o3-pro', 'OpenAI o3-pro', '20', '80', '0', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('o3-mini', 'OpenAI o3-mini', '0.55', '2.20', '0.55', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('o1', 'OpenAI o1', '15', '60', '7.50', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('o1-mini', 'OpenAI o1-mini', '0.55', '2.20', '0.55', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('codex-mini', 'Codex Mini', '0.75', '3', '0.025', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5-mini', 'GPT-5 Mini', '0.25', '2', '0.025', '0');
INSERT INTO "model_pricing" ("model_id", "display_name", "input_cost_per_million", "output_cost_per_million", "cache_read_cost_per_million", "cache_creation_cost_per_million") VALUES ('gpt-5-nano', 'GPT-5 Nano', '0.05', '0.40', '0.005', '0');
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-codewiz-standard', 'claude', 'Codewiz 标准', '{"env":{"ANTHROPIC_AUTH_TOKEN":"dummy","ANTHROPIC_BASE_URL":"http://127.0.0.1:8089","ANTHROPIC_DEFAULT_HAIKU_MODEL":"codewiz:haiku","ANTHROPIC_DEFAULT_OPUS_MODEL":"codewiz:opus","ANTHROPIC_DEFAULT_SONNET_MODEL":"codewiz:sonnet"},"extraKnownMarketplaces":{"claude-hud":{"autoUpdate":false}}}', NULL, 'custom', 1779098000000, 10, 'Haiku 4.5 / Sonnet 4.6 / Opus 4.6，codewiz 落点', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false,"apiFormat":"anthropic"}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-codewiz-opus47', 'claude', 'Codewiz Opus 4.7', '{"env":{"ANTHROPIC_AUTH_TOKEN":"dummy","ANTHROPIC_BASE_URL":"http://127.0.0.1:8089","ANTHROPIC_DEFAULT_HAIKU_MODEL":"codewiz:haiku","ANTHROPIC_DEFAULT_OPUS_MODEL":"codewiz:opus47","ANTHROPIC_DEFAULT_SONNET_MODEL":"codewiz:sonnet"}}', NULL, 'custom', 1779098000000, 20, 'Haiku 4.5 / Sonnet 4.6 / Opus 4.7，codewiz 落点', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false,"apiFormat":"anthropic"}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-codewiz-thinking', 'claude', 'Codewiz Thinking', '{"env":{"ANTHROPIC_AUTH_TOKEN":"dummy","ANTHROPIC_BASE_URL":"http://127.0.0.1:8089","ANTHROPIC_DEFAULT_HAIKU_MODEL":"codewiz:haiku","ANTHROPIC_DEFAULT_OPUS_MODEL":"codewiz:opus-thinking","ANTHROPIC_DEFAULT_SONNET_MODEL":"codewiz:sonnet-thinking"}}', NULL, 'custom', 1779098000000, 30, 'Haiku 4.5 / Sonnet 4.6 thinking / Opus 4.6 thinking，codewiz 落点', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false,"apiFormat":"anthropic"}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-kimi-personal', 'claude', 'Kimi 个人', '{"env":{"ANTHROPIC_AUTH_TOKEN":"sk-kimi-lPAgVR7dhCuluj1xAtjvTE9MDd08waRIdQQg3Rm7cUuU3FkYoeAe7eMoCr8B7G4R","ANTHROPIC_BASE_URL":"https://api.kimi.com/coding/","ANTHROPIC_DEFAULT_HAIKU_MODEL":"kimi-k2.6","ANTHROPIC_DEFAULT_OPUS_MODEL":"kimi-k2.6","ANTHROPIC_DEFAULT_SONNET_MODEL":"kimi-k2.6","ANTHROPIC_MODEL":"kimi-k2.6"}}', NULL, 'custom', 1779098000000, 35, 'Kimi 个人 API 直连（不走 codewiz proxy），需在 .env 中配置 KIMI_PERSONAL_AUTH_TOKEN', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false}', 1, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-lobi-standard', 'claude', 'Lobi 标准', '{"env":{"ANTHROPIC_AUTH_TOKEN":"dummy","ANTHROPIC_BASE_URL":"http://127.0.0.1:8089","ANTHROPIC_DEFAULT_HAIKU_MODEL":"lobi:sonnet","ANTHROPIC_DEFAULT_OPUS_MODEL":"lobi:sonnet","ANTHROPIC_DEFAULT_SONNET_MODEL":"lobi:sonnet"}}', NULL, 'custom', 1779098000000, 40, '全模型映射到 Sonnet 4.6，lobi 落点（lobi 不支持 Haiku/Opus）', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false,"apiFormat":"anthropic"}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-cowork', 'claude', 'Cowork (Bedrock)', '{"enabledPlugins":{"context7@claude-plugins-official":true},"env":{"ANTHROPIC_AUTH_TOKEN":"dummy","ANTHROPIC_BASE_URL":"http://127.0.0.1:8089","ANTHROPIC_DEFAULT_HAIKU_MODEL":"cowork:default","ANTHROPIC_DEFAULT_OPUS_MODEL":"cowork:default","ANTHROPIC_DEFAULT_SONNET_MODEL":"cowork:default"}}', NULL, 'custom', 1779098000000, 70, 'Bedrock 落点，模型由 COWORK_MODEL 环境变量决定（默认 Opus 4.7）', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false,"apiFormat":"anthropic"}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-codex-gpt53', 'codex', 'Codewiz GPT-5.3', '{"auth":{"OPENAI_API_KEY":"dummy"},"config":"model_provider = \"custom\"\nmodel = \"codewiz:gpt53\"\nmodel_reasoning_effort = \"high\"\n\nmodel_context_window = 400000\nmodel_auto_compact_token_limit = 360000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n"}', NULL, 'custom', 1779098000000, 80, 'GPT-5.3 Codex，400K 上下文，代码优化专用', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-codex-gpt54', 'codex', 'Codewiz GPT-5.4', '{"auth":{"OPENAI_API_KEY":"dummy"},"config":"model_provider = \"custom\"\nmodel = \"codewiz:gpt54\"\nmodel_reasoning_effort = \"high\"\n\nmodel_context_window = 272000\nmodel_auto_compact_token_limit = 244800\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n"}', NULL, 'custom', 1779098000000, 90, 'GPT-5.4，272K 上下文', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-codex-gpt55', 'codex', 'Codewiz GPT-5.5', '{"auth":{"OPENAI_API_KEY":"dummy"},"config":"model_provider = \"custom\"\nmodel = \"codewiz:gpt55\"\nmodel_reasoning_effort = \"high\"\n\nmodel_context_window = 1000000\nmodel_auto_compact_token_limit = 900000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n"}', NULL, 'custom', 1779098000000, 100, 'GPT-5.5，1M 上下文，最强推理', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-codex-deepseek-pro', 'codex', 'Codewiz DeepSeek Pro', '{"auth":{"OPENAI_API_KEY":"dummy"},"config":"model_provider = \"custom\"\nmodel = \"codewiz:deepseek-pro\"\n\nmodel_context_window = 1000000\nmodel_auto_compact_token_limit = 900000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n"}', NULL, 'custom', 1779098000000, 110, 'DeepSeek V4 Pro，免费，1M 上下文', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false}', 1, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-codex-deepseek-flash', 'codex', 'Codewiz DeepSeek Flash', '{"auth":{"OPENAI_API_KEY":"dummy"},"config":"model_provider = \"custom\"\nmodel = \"codewiz:deepseek-flash\"\n\nmodel_context_window = 1000000\nmodel_auto_compact_token_limit = 900000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n"}', NULL, 'custom', 1779098000000, 120, 'DeepSeek V4 Flash，免费，速度快', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-codex-kimi26', 'codex', 'Codewiz Kimi K2.6', '{"auth":{"OPENAI_API_KEY":"dummy"},"config":"model_provider = \"custom\"\nmodel = \"codewiz:gpt53\"\nmodel_reasoning_effort = \"high\"\n\nmodel_context_window = 400000\nmodel_auto_compact_token_limit = 360000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n"}', NULL, 'custom', 1779098000000, 130, 'Kimi K2.6，免费，256K 上下文', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-codex-kimi25', 'codex', 'Codewiz Kimi K2.5', '{"auth":{"OPENAI_API_KEY":"dummy"},"config":"model_provider = \"custom\"\nmodel = \"codewiz:kimi25\"\n\nmodel_context_window = 256000\nmodel_auto_compact_token_limit = 230400\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n"}', NULL, 'custom', 1779098000000, 140, 'Kimi K2.5，免费，动态上下文', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-codex-glm', 'codex', 'Codewiz GLM-5.1', '{"auth":{"OPENAI_API_KEY":"dummy"},"config":"model_provider = \"custom\"\nmodel = \"codewiz:glm\"\n\nmodel_context_window = 202000\nmodel_auto_compact_token_limit = 181800\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n"}', NULL, 'custom', 1779098000000, 150, 'GLM-5.1，免费，中文优化，202K 上下文', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-codex-dots', 'codex', 'Codewiz dots.llm2', '{"auth":{"OPENAI_API_KEY":"dummy"},"config":"model_provider = \"custom\"\nmodel = \"codewiz:dots\"\n\nmodel_context_window = 256000\nmodel_auto_compact_token_limit = 230400\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n"}', NULL, 'custom', 1779098000000, 160, '小红书自研 dots.llm2.inst，免费，支持 Computer Use', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-lobi-deepseek-pro', 'codex', 'Lobi DeepSeek Pro', '{"auth":{"OPENAI_API_KEY":"dummy"},"config":"model_provider = \"custom\"\nmodel = \"lobi:deepseek-pro\"\n\nmodel_context_window = 1000000\nmodel_auto_compact_token_limit = 900000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n"}', NULL, 'custom', 1779098000000, 170, 'DeepSeek V4 Pro，lobi 落点，1M 上下文', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-lobi-deepseek-flash', 'codex', 'Lobi DeepSeek Flash', '{"auth":{"OPENAI_API_KEY":"dummy"},"config":"model_provider = \"custom\"\nmodel = \"lobi:deepseek-flash\"\n\nmodel_context_window = 1000000\nmodel_auto_compact_token_limit = 900000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n"}', NULL, 'custom', 1779098000000, 180, 'DeepSeek V4 Flash，lobi 落点，速度快', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-lobi-kimi26', 'codex', 'Lobi Kimi K2.6', '{"auth":{"OPENAI_API_KEY":"dummy"},"config":"model_provider = \"custom\"\nmodel = \"lobi:kimi26\"\n\nmodel_context_window = 256000\nmodel_auto_compact_token_limit = 230400\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n"}', NULL, 'custom', 1779098000000, 190, 'Kimi K2.6，lobi 落点，256K 上下文', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-lobi-kimi25', 'codex', 'Lobi Kimi K2.5', '{"auth":{"OPENAI_API_KEY":"dummy"},"config":"model_provider = \"custom\"\nmodel = \"lobi:kimi25\"\n\nmodel_context_window = 200000\nmodel_auto_compact_token_limit = 180000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n"}', NULL, 'custom', 1779098000000, 200, 'Kimi K2.5，lobi 落点，200K 上下文', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-lobi-kimi25-qs', 'codex', 'Lobi Kimi K2.5-qs', '{"auth":{"OPENAI_API_KEY":"dummy"},"config":"model_provider = \"custom\"\nmodel = \"lobi:kimi25qs\"\n\nmodel_context_window = 200000\nmodel_auto_compact_token_limit = 180000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n"}', NULL, 'custom', 1779098000000, 210, 'Kimi K2.5-qs，lobi 落点，200K 上下文', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('cw-lobi-glm5v', 'codex', 'Lobi GLM-5v-turbo', '{"auth":{"OPENAI_API_KEY":"dummy"},"config":"model_provider = \"custom\"\nmodel = \"lobi:glm5v\"\n\nmodel_context_window = 203000\nmodel_auto_compact_token_limit = 182700\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n"}', NULL, 'custom', 1779098000000, 220, 'GLM-5v-turbo，lobi 落点，中文优化，203K 上下文', NULL, NULL, '{"commonConfigEnabled":true,"endpointAutoSelect":false}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "providers" ("id", "app_type", "name", "settings_config", "website_url", "category", "created_at", "sort_index", "notes", "icon", "icon_color", "meta", "is_current", "in_failover_queue", "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type") VALUES ('个人-deepseek-v4-pro', 'claude', '个人 deepseek-v4-pro', '{"effortLevel":"high","env":{"ANTHROPIC_AUTH_TOKEN":"sk-dd60045eb19e4d78a7fa3aa7f45c5f44","ANTHROPIC_BASE_URL":"https://api.deepseek.com/anthropic","ANTHROPIC_DEFAULT_HAIKU_MODEL":"deepseek-v4-pro","ANTHROPIC_DEFAULT_OPUS_MODEL":"deepseek-v4-pro","ANTHROPIC_DEFAULT_SONNET_MODEL":"deepseek-v4-pro","ANTHROPIC_MODEL":"deepseek-v4-pro","ANTHROPIC_REASONING_MODEL":"deepseek-v4-pro"},"reasoning_effort":"max"}', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '{"commonConfigEnabled":true}', 0, 0, '1.0', NULL, NULL, NULL);
INSERT INTO "proxy_config" ("app_type", "proxy_enabled", "listen_address", "listen_port", "enable_logging", "enabled", "auto_failover_enabled", "max_retries", "streaming_first_byte_timeout", "streaming_idle_timeout", "non_streaming_timeout", "circuit_failure_threshold", "circuit_success_threshold", "circuit_timeout_seconds", "circuit_error_rate_threshold", "circuit_min_requests", "default_cost_multiplier", "pricing_model_source", "created_at", "updated_at", "live_takeover_active") VALUES ('claude', 0, '127.0.0.1', 15721, 1, 0, 0, 6, 90, 180, 600, 8, 3, 90, 0.7, 15, '1', 'response', '2026-04-07 12:40:36', '2026-04-09 13:40:02', 0);
INSERT INTO "proxy_config" ("app_type", "proxy_enabled", "listen_address", "listen_port", "enable_logging", "enabled", "auto_failover_enabled", "max_retries", "streaming_first_byte_timeout", "streaming_idle_timeout", "non_streaming_timeout", "circuit_failure_threshold", "circuit_success_threshold", "circuit_timeout_seconds", "circuit_error_rate_threshold", "circuit_min_requests", "default_cost_multiplier", "pricing_model_source", "created_at", "updated_at", "live_takeover_active") VALUES ('codex', 0, '127.0.0.1', 15721, 1, 0, 0, 3, 60, 120, 600, 4, 2, 60, 0.6, 10, '1', 'response', '2026-04-07 12:40:36', '2026-04-07 12:40:36', 0);
INSERT INTO "proxy_config" ("app_type", "proxy_enabled", "listen_address", "listen_port", "enable_logging", "enabled", "auto_failover_enabled", "max_retries", "streaming_first_byte_timeout", "streaming_idle_timeout", "non_streaming_timeout", "circuit_failure_threshold", "circuit_success_threshold", "circuit_timeout_seconds", "circuit_error_rate_threshold", "circuit_min_requests", "default_cost_multiplier", "pricing_model_source", "created_at", "updated_at", "live_takeover_active") VALUES ('gemini', 0, '127.0.0.1', 15721, 1, 0, 0, 5, 60, 120, 600, 4, 2, 60, 0.6, 10, '1', 'response', '2026-04-07 12:40:36', '2026-04-07 12:40:36', 0);
INSERT INTO "settings" ("key", "value") VALUES ('common_config_upstream_semantics_migrated_v1', 'true');
INSERT INTO "settings" ("key", "value") VALUES ('common_config_claude', '{
  "enabledPlugins": {
    "claude-hud@claude-hud": true,
    "code-review@claude-plugins-official": true,
    "codex@openai-codex": true,
    "planning-with-files@planning-with-files": true,
    "superpowers@claude-plugins-official": true
  },
  "env": {
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://49.234.245.115:8089",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_RESOURCE_ATTRIBUTES": "user.name=%E5%AD%90%E7%89%99"
  },
  "extraKnownMarketplaces": {
    "claude-hud": {
      "source": {
        "repo": "jarrodwatts/claude-hud",
        "source": "github"
      }
    },
    "openai-codex": {
      "source": {
        "repo": "openai/codex-plugin-cc",
        "source": "github"
      }
    },
    "planning-with-files": {
      "source": {
        "repo": "OthmanAdi/planning-with-files",
        "source": "github"
      }
    }
  },
  "permissions": {
    "defaultMode": "bypassPermissions"
  },
  "skipDangerousModePermissionPrompt": true,
  "statusLine": {
    "command": "bash -c ''cols=$(stty size </dev/tty 2>/dev/null | awk ''\"''\"''{ print $2 }''\"''\"''); export COLUMNS=$(( ${cols:-120} > 4 ? ${cols:-120} - 4 : 1 )); plugin_dir=$(ls -d \"${CLAUDE_CONFIG_DIR:-$HOME/.claude}\"/plugins/cache/*/claude-hud/*/ 2>/dev/null | awk -F/ ''\"''\"''{ print $(NF-1) \"\\t\" $0 }''\"''\"'' | grep -E ''\"''\"''^[0-9]+\\.[0-9]+\\.[0-9]+[[:space:]]''\"''\"'' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1 | cut -f2-); exec \"/usr/bin/node\" \"${plugin_dir}dist/index.js\"''",
    "type": "command"
  }
}');
INSERT INTO "settings" ("key", "value") VALUES ('common_config_codex', 'disable_response_storage = true

[otel]
environment = "子牙"

[otel.exporter.otlp-http]
endpoint = "http://49.234.245.115:8089/v1/logs"
protocol = "binary"

[otel.metrics_exporter.otlp-http]
endpoint = "http://49.234.245.115:8089/v1/metrics"
protocol = "binary"
');
INSERT INTO "skill_repos" ("owner", "name", "branch", "enabled") VALUES ('anthropics', 'skills', 'main', 1);
INSERT INTO "skill_repos" ("owner", "name", "branch", "enabled") VALUES ('ComposioHQ', 'awesome-claude-skills', 'master', 1);
INSERT INTO "skill_repos" ("owner", "name", "branch", "enabled") VALUES ('cexll', 'myclaude', 'master', 1);
INSERT INTO "skill_repos" ("owner", "name", "branch", "enabled") VALUES ('JimLiu', 'baoyu-skills', 'main', 1);
INSERT INTO "stream_check_logs" ("id", "provider_id", "provider_name", "app_type", "status", "success", "message", "response_time_ms", "http_status", "model_used", "retry_count", "tested_at") VALUES (1, 'afa3155d-a262-4480-a4a5-07416941d2d5', 'weclawai', 'codex', 'operational', 1, 'Check succeeded', 1360, 200, 'gpt-5.1-codex', 0, 1775815891);
INSERT INTO "stream_check_logs" ("id", "provider_id", "provider_name", "app_type", "status", "success", "message", "response_time_ms", "http_status", "model_used", "retry_count", "tested_at") VALUES (2, 'afa3155d-a262-4480-a4a5-07416941d2d5', 'weclawai', 'codex', 'operational', 1, 'Check succeeded', 3478, 200, 'gpt-5.1-codex', 0, 1775815898);
COMMIT;
PRAGMA foreign_keys=ON;
