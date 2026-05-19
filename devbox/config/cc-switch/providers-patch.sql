-- codewiz-proxy providers patch
-- 仅 INSERT OR IGNORE，不 DELETE，避免重置用户当前选中的 provider (is_current)

-- ==============================================================================
-- Claude Code — Codewiz 落点
-- ==============================================================================

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-codewiz-standard','claude','Codewiz 标准',
    '{"env": {"ANTHROPIC_AUTH_TOKEN": "dummy", "ANTHROPIC_BASE_URL": "http://127.0.0.1:8089",
      "OTEL_EXPORTER_OTLP_ENDPOINT": "http://49.234.245.115:8089",
      "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf",
      "OTEL_METRICS_EXPORTER": "otlp",
      "OTEL_RESOURCE_ATTRIBUTES": "user.name=%E5%AD%90%E7%89%99",
      "ANTHROPIC_DEFAULT_HAIKU_MODEL": "codewiz:haiku",
      "ANTHROPIC_DEFAULT_SONNET_MODEL": "codewiz:sonnet",
      "ANTHROPIC_DEFAULT_OPUS_MODEL": "codewiz:opus"}}',
    NULL,'custom',1779098000000,10,
    'Haiku 4.5 / Sonnet 4.6 / Opus 4.6，codewiz 落点',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false,"apiFormat":"anthropic"}',
    1,0,'1.0',NULL,NULL,NULL
);

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-codewiz-opus47','claude','Codewiz Opus 4.7',
    '{"env": {"ANTHROPIC_AUTH_TOKEN": "dummy", "ANTHROPIC_BASE_URL": "http://127.0.0.1:8089",
      "OTEL_EXPORTER_OTLP_ENDPOINT": "http://49.234.245.115:8089",
      "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf",
      "OTEL_METRICS_EXPORTER": "otlp",
      "OTEL_RESOURCE_ATTRIBUTES": "user.name=%E5%AD%90%E7%89%99",
      "ANTHROPIC_DEFAULT_HAIKU_MODEL": "codewiz:haiku",
      "ANTHROPIC_DEFAULT_SONNET_MODEL": "codewiz:sonnet",
      "ANTHROPIC_DEFAULT_OPUS_MODEL": "codewiz:opus47"}}',
    NULL,'custom',1779098000000,20,
    'Haiku 4.5 / Sonnet 4.6 / Opus 4.7，codewiz 落点',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false,"apiFormat":"anthropic"}',
    0,0,'1.0',NULL,NULL,NULL
);

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-codewiz-thinking','claude','Codewiz Thinking',
    '{"env": {"ANTHROPIC_AUTH_TOKEN": "dummy", "ANTHROPIC_BASE_URL": "http://127.0.0.1:8089",
      "OTEL_EXPORTER_OTLP_ENDPOINT": "http://49.234.245.115:8089",
      "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf",
      "OTEL_METRICS_EXPORTER": "otlp",
      "OTEL_RESOURCE_ATTRIBUTES": "user.name=%E5%AD%90%E7%89%99",
      "ANTHROPIC_DEFAULT_HAIKU_MODEL": "codewiz:haiku",
      "ANTHROPIC_DEFAULT_SONNET_MODEL": "codewiz:sonnet-thinking",
      "ANTHROPIC_DEFAULT_OPUS_MODEL": "codewiz:opus-thinking"}}',
    NULL,'custom',1779098000000,30,
    'Haiku 4.5 / Sonnet 4.6 thinking / Opus 4.6 thinking，codewiz 落点',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false,"apiFormat":"anthropic"}',
    0,0,'1.0',NULL,NULL,NULL
);

-- ==============================================================================
-- Claude Code — Kimi 个人（直连 Kimi API，不经过 codewiz proxy）
-- ==============================================================================

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-kimi-personal','claude','Kimi 个人',
    '{"env": {"ANTHROPIC_AUTH_TOKEN": "sk-kimi-lPAgVR7dhCuluj1xAtjvTE9MDd08waRIdQQg3Rm7cUuU3FkYoeAe7eMoCr8B7G4R", "ANTHROPIC_BASE_URL": "https://api.kimi.com/coding/",
      "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
      "OTEL_EXPORTER_OTLP_ENDPOINT": "http://49.234.245.115:8089",
      "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf",
      "OTEL_METRICS_EXPORTER": "otlp",
      "OTEL_RESOURCE_ATTRIBUTES": "user.name=%E5%AD%90%E7%89%99"},
      "effortLevel": "high", "skipDangerousModePermissionPrompt": true}',
    NULL,'custom',1779098000000,35,
    'Kimi 个人 API 直连（不走 codewiz proxy），需在 .env 中配置 KIMI_PERSONAL_AUTH_TOKEN',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false,"apiFormat":"anthropic"}',
    0,0,'1.0',NULL,NULL,NULL
);

UPDATE "providers" SET "sort_index" = 35 WHERE "id" = 'cw-kimi-personal';

-- ==============================================================================
-- Claude Code — Lobi 落点
-- ==============================================================================

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-lobi-standard','claude','Lobi 标准',
    '{"env": {"ANTHROPIC_AUTH_TOKEN": "dummy", "ANTHROPIC_BASE_URL": "http://127.0.0.1:8089",
      "OTEL_EXPORTER_OTLP_ENDPOINT": "http://49.234.245.115:8089",
      "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf",
      "OTEL_METRICS_EXPORTER": "otlp",
      "OTEL_RESOURCE_ATTRIBUTES": "user.name=%E5%AD%90%E7%89%99",
      "ANTHROPIC_DEFAULT_HAIKU_MODEL": "lobi:sonnet",
      "ANTHROPIC_DEFAULT_SONNET_MODEL": "lobi:sonnet",
      "ANTHROPIC_DEFAULT_OPUS_MODEL": "lobi:sonnet"}}',
    NULL,'custom',1779098000000,40,
    '全模型映射到 Sonnet 4.6，lobi 落点（lobi 不支持 Haiku/Opus）',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false,"apiFormat":"anthropic"}',
    0,0,'1.0',NULL,NULL,NULL
);

-- ==============================================================================
-- Claude Code — Cowork (Bedrock) 落点
-- ==============================================================================

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-cowork','claude','Cowork (Bedrock)',
    '{"env": {"ANTHROPIC_AUTH_TOKEN": "dummy", "ANTHROPIC_BASE_URL": "http://127.0.0.1:8089",
      "OTEL_EXPORTER_OTLP_ENDPOINT": "http://49.234.245.115:8089",
      "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf",
      "OTEL_METRICS_EXPORTER": "otlp",
      "OTEL_RESOURCE_ATTRIBUTES": "user.name=%E5%AD%90%E7%89%99",
      "ANTHROPIC_DEFAULT_HAIKU_MODEL": "cowork:default",
      "ANTHROPIC_DEFAULT_SONNET_MODEL": "cowork:default",
      "ANTHROPIC_DEFAULT_OPUS_MODEL": "cowork:default"}}',
    NULL,'custom',1779098000000,70,
    'Bedrock 落点，模型由 COWORK_MODEL 环境变量决定（默认 Opus 4.7）',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false,"apiFormat":"anthropic"}',
    0,0,'1.0',NULL,NULL,NULL
);

-- ==============================================================================
-- Codex — OpenAI 模型
-- ==============================================================================

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-codex-gpt53','codex','Codewiz GPT-5.3',
    '{"auth": {"OPENAI_API_KEY": "dummy"}, "config": "model_provider = \"custom\"\nmodel = \"codewiz:gpt53\"\nmodel_reasoning_effort = \"high\"\ndisable_response_storage = true\n\nmodel_context_window = 400000\nmodel_auto_compact_token_limit = 360000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n\n[otel]\nenvironment = \"子牙\"\nexporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/logs\", protocol = \"binary\" } }\nmetrics_exporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/metrics\", protocol = \"binary\" } }\n"}',
    NULL,'custom',1779098000000,80,
    'GPT-5.3 Codex，400K 上下文，代码优化专用',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false}',
    0,0,'1.0',NULL,NULL,NULL
);

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-codex-gpt54','codex','Codewiz GPT-5.4',
    '{"auth": {"OPENAI_API_KEY": "dummy"}, "config": "model_provider = \"custom\"\nmodel = \"codewiz:gpt54\"\nmodel_reasoning_effort = \"high\"\ndisable_response_storage = true\n\nmodel_context_window = 272000\nmodel_auto_compact_token_limit = 244800\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n\n[otel]\nenvironment = \"子牙\"\nexporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/logs\", protocol = \"binary\" } }\nmetrics_exporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/metrics\", protocol = \"binary\" } }\n"}',
    NULL,'custom',1779098000000,90,
    'GPT-5.4，272K 上下文',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false}',
    0,0,'1.0',NULL,NULL,NULL
);

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-codex-gpt55','codex','Codewiz GPT-5.5',
    '{"auth": {"OPENAI_API_KEY": "dummy"}, "config": "model_provider = \"custom\"\nmodel = \"codewiz:gpt55\"\nmodel_reasoning_effort = \"high\"\ndisable_response_storage = true\n\nmodel_context_window = 1000000\nmodel_auto_compact_token_limit = 900000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n\n[otel]\nenvironment = \"子牙\"\nexporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/logs\", protocol = \"binary\" } }\nmetrics_exporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/metrics\", protocol = \"binary\" } }\n"}',
    NULL,'custom',1779098000000,100,
    'GPT-5.5，1M 上下文，最强推理',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false}',
    0,0,'1.0',NULL,NULL,NULL
);

-- ==============================================================================
-- Codex — 第三方 OpenAI 兼容模型
-- ==============================================================================

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-codex-deepseek-pro','codex','Codewiz DeepSeek Pro',
    '{"auth": {"OPENAI_API_KEY": "dummy"}, "config": "model_provider = \"custom\"\nmodel = \"codewiz:deepseek-pro\"\ndisable_response_storage = true\n\nmodel_context_window = 1000000\nmodel_auto_compact_token_limit = 900000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n\n[otel]\nenvironment = \"子牙\"\nexporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/logs\", protocol = \"binary\" } }\nmetrics_exporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/metrics\", protocol = \"binary\" } }\n"}',
    NULL,'custom',1779098000000,110,
    'DeepSeek V4 Pro，免费，1M 上下文',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false}',
    0,0,'1.0',NULL,NULL,NULL
);

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-codex-deepseek-flash','codex','Codewiz DeepSeek Flash',
    '{"auth": {"OPENAI_API_KEY": "dummy"}, "config": "model_provider = \"custom\"\nmodel = \"codewiz:deepseek-flash\"\ndisable_response_storage = true\n\nmodel_context_window = 1000000\nmodel_auto_compact_token_limit = 900000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n\n[otel]\nenvironment = \"子牙\"\nexporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/logs\", protocol = \"binary\" } }\nmetrics_exporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/metrics\", protocol = \"binary\" } }\n"}',
    NULL,'custom',1779098000000,120,
    'DeepSeek V4 Flash，免费，速度快',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false}',
    0,0,'1.0',NULL,NULL,NULL
);

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-codex-kimi26','codex','Codewiz Kimi K2.6',
    '{"auth": {"OPENAI_API_KEY": "dummy"}, "config": "model_provider = \"custom\"\nmodel = \"codewiz:kimi26\"\ndisable_response_storage = true\n\nmodel_context_window = 256000\nmodel_auto_compact_token_limit = 230400\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n\n[otel]\nenvironment = \"子牙\"\nexporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/logs\", protocol = \"binary\" } }\nmetrics_exporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/metrics\", protocol = \"binary\" } }\n"}',
    NULL,'custom',1779098000000,130,
    'Kimi K2.6，免费，256K 上下文',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false}',
    0,0,'1.0',NULL,NULL,NULL
);

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-codex-kimi25','codex','Codewiz Kimi K2.5',
    '{"auth": {"OPENAI_API_KEY": "dummy"}, "config": "model_provider = \"custom\"\nmodel = \"codewiz:kimi25\"\ndisable_response_storage = true\n\nmodel_context_window = 256000\nmodel_auto_compact_token_limit = 230400\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n\n[otel]\nenvironment = \"子牙\"\nexporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/logs\", protocol = \"binary\" } }\nmetrics_exporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/metrics\", protocol = \"binary\" } }\n"}',
    NULL,'custom',1779098000000,140,
    'Kimi K2.5，免费，动态上下文',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false}',
    0,0,'1.0',NULL,NULL,NULL
);

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-codex-glm','codex','Codewiz GLM-5.1',
    '{"auth": {"OPENAI_API_KEY": "dummy"}, "config": "model_provider = \"custom\"\nmodel = \"codewiz:glm\"\ndisable_response_storage = true\n\nmodel_context_window = 202000\nmodel_auto_compact_token_limit = 181800\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n\n[otel]\nenvironment = \"子牙\"\nexporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/logs\", protocol = \"binary\" } }\nmetrics_exporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/metrics\", protocol = \"binary\" } }\n"}',
    NULL,'custom',1779098000000,150,
    'GLM-5.1，免费，中文优化，202K 上下文',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false}',
    0,0,'1.0',NULL,NULL,NULL
);

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-codex-dots','codex','Codewiz dots.llm2',
    '{"auth": {"OPENAI_API_KEY": "dummy"}, "config": "model_provider = \"custom\"\nmodel = \"codewiz:dots\"\ndisable_response_storage = true\n\nmodel_context_window = 256000\nmodel_auto_compact_token_limit = 230400\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n\n[otel]\nenvironment = \"子牙\"\nexporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/logs\", protocol = \"binary\" } }\nmetrics_exporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/metrics\", protocol = \"binary\" } }\n"}',
    NULL,'custom',1779098000000,160,
    '小红书自研 dots.llm2.inst，免费，支持 Computer Use',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false}',
    0,0,'1.0',NULL,NULL,NULL
);

-- ==============================================================================
-- Codex — Lobi 落点（OpenAI 兼容模型）
-- ==============================================================================

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-lobi-deepseek-pro','codex','Lobi DeepSeek Pro',
    '{"auth": {"OPENAI_API_KEY": "dummy"}, "config": "model_provider = \"custom\"\nmodel = \"lobi:deepseek-pro\"\ndisable_response_storage = true\n\nmodel_context_window = 1000000\nmodel_auto_compact_token_limit = 900000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n\n[otel]\nenvironment = \"子牙\"\nexporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/logs\", protocol = \"binary\" } }\nmetrics_exporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/metrics\", protocol = \"binary\" } }\n"}',
    NULL,'custom',1779098000000,170,
    'DeepSeek V4 Pro，lobi 落点，1M 上下文',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false}',
    0,0,'1.0',NULL,NULL,NULL
);

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-lobi-deepseek-flash','codex','Lobi DeepSeek Flash',
    '{"auth": {"OPENAI_API_KEY": "dummy"}, "config": "model_provider = \"custom\"\nmodel = \"lobi:deepseek-flash\"\ndisable_response_storage = true\n\nmodel_context_window = 1000000\nmodel_auto_compact_token_limit = 900000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n\n[otel]\nenvironment = \"子牙\"\nexporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/logs\", protocol = \"binary\" } }\nmetrics_exporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/metrics\", protocol = \"binary\" } }\n"}',
    NULL,'custom',1779098000000,180,
    'DeepSeek V4 Flash，lobi 落点，速度快',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false}',
    0,0,'1.0',NULL,NULL,NULL
);

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-lobi-kimi26','codex','Lobi Kimi K2.6',
    '{"auth": {"OPENAI_API_KEY": "dummy"}, "config": "model_provider = \"custom\"\nmodel = \"lobi:kimi26\"\ndisable_response_storage = true\n\nmodel_context_window = 256000\nmodel_auto_compact_token_limit = 230400\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n\n[otel]\nenvironment = \"子牙\"\nexporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/logs\", protocol = \"binary\" } }\nmetrics_exporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/metrics\", protocol = \"binary\" } }\n"}',
    NULL,'custom',1779098000000,190,
    'Kimi K2.6，lobi 落点，256K 上下文',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false}',
    0,0,'1.0',NULL,NULL,NULL
);

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-lobi-kimi25','codex','Lobi Kimi K2.5',
    '{"auth": {"OPENAI_API_KEY": "dummy"}, "config": "model_provider = \"custom\"\nmodel = \"lobi:kimi25\"\ndisable_response_storage = true\n\nmodel_context_window = 200000\nmodel_auto_compact_token_limit = 180000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n\n[otel]\nenvironment = \"子牙\"\nexporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/logs\", protocol = \"binary\" } }\nmetrics_exporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/metrics\", protocol = \"binary\" } }\n"}',
    NULL,'custom',1779098000000,200,
    'Kimi K2.5，lobi 落点，200K 上下文',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false}',
    0,0,'1.0',NULL,NULL,NULL
);

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-lobi-kimi25-qs','codex','Lobi Kimi K2.5-qs',
    '{"auth": {"OPENAI_API_KEY": "dummy"}, "config": "model_provider = \"custom\"\nmodel = \"lobi:kimi25qs\"\ndisable_response_storage = true\n\nmodel_context_window = 200000\nmodel_auto_compact_token_limit = 180000\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n\n[otel]\nenvironment = \"子牙\"\nexporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/logs\", protocol = \"binary\" } }\nmetrics_exporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/metrics\", protocol = \"binary\" } }\n"}',
    NULL,'custom',1779098000000,210,
    'Kimi K2.5-qs，lobi 落点，200K 上下文',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false}',
    0,0,'1.0',NULL,NULL,NULL
);

INSERT OR IGNORE INTO "providers" (
    "id","app_type","name","settings_config","website_url","category","created_at",
    "sort_index","notes","icon","icon_color","meta","is_current","in_failover_queue",
    "cost_multiplier","limit_daily_usd","limit_monthly_usd","provider_type"
) VALUES (
    'cw-lobi-glm5v','codex','Lobi GLM-5v-turbo',
    '{"auth": {"OPENAI_API_KEY": "dummy"}, "config": "model_provider = \"custom\"\nmodel = \"lobi:glm5v\"\ndisable_response_storage = true\n\nmodel_context_window = 203000\nmodel_auto_compact_token_limit = 182700\n[model_providers.custom]\nname = \"custom\"\nwire_api = \"responses\"\nrequires_openai_auth = false\nbase_url = \"http://127.0.0.1:8089\"\n\n[otel]\nenvironment = \"子牙\"\nexporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/logs\", protocol = \"binary\" } }\nmetrics_exporter = { otlp-http = { endpoint = \"http://49.234.245.115:8089/v1/metrics\", protocol = \"binary\" } }\n"}',
    NULL,'custom',1779098000000,220,
    'GLM-5v-turbo，lobi 落点，中文优化，203K 上下文',
    NULL,NULL,'{"commonConfigEnabled":true,"endpointAutoSelect":false}',
    0,0,'1.0',NULL,NULL,NULL
);

-- ==============================================================================
-- 同步已有记录的 sort_index（排序逻辑变更时生效）
-- ==============================================================================
UPDATE "providers" SET "sort_index" = 10  WHERE "id" = 'cw-codewiz-standard';
UPDATE "providers" SET "sort_index" = 20  WHERE "id" = 'cw-codewiz-opus47';
UPDATE "providers" SET "sort_index" = 30  WHERE "id" = 'cw-codewiz-thinking';
UPDATE "providers" SET "sort_index" = 35  WHERE "id" = 'cw-kimi-personal';
UPDATE "providers" SET "sort_index" = 40  WHERE "id" = 'cw-lobi-standard';
UPDATE "providers" SET "sort_index" = 70  WHERE "id" = 'cw-cowork';
UPDATE "providers" SET "sort_index" = 80  WHERE "id" = 'cw-codex-gpt53';
UPDATE "providers" SET "sort_index" = 90  WHERE "id" = 'cw-codex-gpt54';
UPDATE "providers" SET "sort_index" = 100 WHERE "id" = 'cw-codex-gpt55';
UPDATE "providers" SET "sort_index" = 110 WHERE "id" = 'cw-codex-deepseek-pro';
UPDATE "providers" SET "sort_index" = 120 WHERE "id" = 'cw-codex-deepseek-flash';
UPDATE "providers" SET "sort_index" = 130 WHERE "id" = 'cw-codex-kimi26';
UPDATE "providers" SET "sort_index" = 140 WHERE "id" = 'cw-codex-kimi25';
UPDATE "providers" SET "sort_index" = 150 WHERE "id" = 'cw-codex-glm';
UPDATE "providers" SET "sort_index" = 160 WHERE "id" = 'cw-codex-dots';
UPDATE "providers" SET "sort_index" = 170 WHERE "id" = 'cw-lobi-deepseek-pro';
UPDATE "providers" SET "sort_index" = 180 WHERE "id" = 'cw-lobi-deepseek-flash';
UPDATE "providers" SET "sort_index" = 190 WHERE "id" = 'cw-lobi-kimi26';
UPDATE "providers" SET "sort_index" = 200 WHERE "id" = 'cw-lobi-kimi25';
UPDATE "providers" SET "sort_index" = 210 WHERE "id" = 'cw-lobi-kimi25-qs';
UPDATE "providers" SET "sort_index" = 220 WHERE "id" = 'cw-lobi-glm5v';

-- ==============================================================================
-- 默认 provider：仅当用户尚未选择任何 provider 时，自动选中 Codewiz 标准
-- ==============================================================================
UPDATE "providers" SET "is_current" = 1 WHERE "id" = 'cw-codewiz-standard' AND (SELECT COUNT(*) FROM "providers" WHERE "is_current" = 1) = 0;
