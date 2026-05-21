-- codewiz-proxy providers patch
-- 仅 INSERT OR IGNORE，不 DELETE，避免重置用户当前选中的 provider (is_current)

-- ==============================================================================
-- Claude Code Providers
-- ==============================================================================
INSERT OR IGNORE INTO "providers" (
    "id", "app_type", "name", "settings_config", "website_url",
    "category", "created_at", "sort_index", "notes", "icon",
    "icon_color", "meta", "is_current", "in_failover_queue",
    "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type"
) VALUES
    -- cw-codewiz-standard       Codewiz 标准           sort= 10
    (
        'cw-codewiz-standard',  -- id
        'claude',     -- app_type
        'Codewiz 标准', -- name
        '{' ||  -- settings_config
        '  "env": {' ||
        '    "ANTHROPIC_AUTH_TOKEN": "dummy",' ||
        '    "ANTHROPIC_BASE_URL": "http://127.0.0.1:8089",' ||
        '    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "codewiz:haiku",' ||
        '    "ANTHROPIC_DEFAULT_SONNET_MODEL": "codewiz:sonnet",' ||
        '    "ANTHROPIC_DEFAULT_OPUS_MODEL": "codewiz:opus"' ||
        '  }' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        10,               -- sort_index
        'Haiku 4.5 / Sonnet 4.6 / Opus 4.6，codewiz 落点', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false,' ||
        '  "apiFormat": "anthropic"' ||
        '}',
        1,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-codewiz-opus47         Codewiz Opus 4.7     sort= 20
    (
        'cw-codewiz-opus47',  -- id
        'claude',     -- app_type
        'Codewiz Opus 4.7', -- name
        '{' ||  -- settings_config
        '  "env": {' ||
        '    "ANTHROPIC_AUTH_TOKEN": "dummy",' ||
        '    "ANTHROPIC_BASE_URL": "http://127.0.0.1:8089",' ||
        '    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "codewiz:haiku",' ||
        '    "ANTHROPIC_DEFAULT_SONNET_MODEL": "codewiz:sonnet",' ||
        '    "ANTHROPIC_DEFAULT_OPUS_MODEL": "codewiz:opus47"' ||
        '  }' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        20,               -- sort_index
        'Haiku 4.5 / Sonnet 4.6 / Opus 4.7，codewiz 落点', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false,' ||
        '  "apiFormat": "anthropic"' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-codewiz-thinking       Codewiz Thinking     sort= 30
    (
        'cw-codewiz-thinking',  -- id
        'claude',     -- app_type
        'Codewiz Thinking', -- name
        '{' ||  -- settings_config
        '  "env": {' ||
        '    "ANTHROPIC_AUTH_TOKEN": "dummy",' ||
        '    "ANTHROPIC_BASE_URL": "http://127.0.0.1:8089",' ||
        '    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "codewiz:haiku",' ||
        '    "ANTHROPIC_DEFAULT_SONNET_MODEL": "codewiz:sonnet-thinking",' ||
        '    "ANTHROPIC_DEFAULT_OPUS_MODEL": "codewiz:opus-thinking"' ||
        '  }' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        30,               -- sort_index
        'Haiku 4.5 / Sonnet 4.6 thinking / Opus 4.6 thinking，codewiz 落点', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false,' ||
        '  "apiFormat": "anthropic"' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-kimi-personal          Kimi 个人              sort= 35
    (
        'cw-kimi-personal',  -- id
        'claude',     -- app_type
        'Kimi 个人', -- name
        '{' ||  -- settings_config
        '  "env": {' ||
        '    "ANTHROPIC_AUTH_TOKEN": "sk-kimi-lPAgVR7dhCuluj1xAtjvTE9MDd08waRIdQQg3Rm7cUuU3FkYoeAe7eMoCr8B7G4R",' ||
        '    "ANTHROPIC_BASE_URL": "https://api.kimi.com/coding/",' ||
        '    "CLAUDE_CODE_ENABLE_TELEMETRY": "1"' ||
        '  },' ||
        '  "effortLevel": "high",' ||
        '  "skipDangerousModePermissionPrompt": true' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        35,               -- sort_index
        'Kimi 个人 API 直连（不走 codewiz proxy），需在 .env 中配置 KIMI_PERSONAL_AUTH_TOKEN', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false,' ||
        '  "apiFormat": "anthropic"' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-lobi-standard          Lobi 标准              sort= 40
    (
        'cw-lobi-standard',  -- id
        'claude',     -- app_type
        'Lobi 标准', -- name
        '{' ||  -- settings_config
        '  "env": {' ||
        '    "ANTHROPIC_AUTH_TOKEN": "dummy",' ||
        '    "ANTHROPIC_BASE_URL": "http://127.0.0.1:8089",' ||
        '    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "lobi:sonnet",' ||
        '    "ANTHROPIC_DEFAULT_SONNET_MODEL": "lobi:sonnet",' ||
        '    "ANTHROPIC_DEFAULT_OPUS_MODEL": "lobi:sonnet"' ||
        '  }' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        40,               -- sort_index
        '全模型映射到 Sonnet 4.6，lobi 落点（lobi 不支持 Haiku/Opus）', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false,' ||
        '  "apiFormat": "anthropic"' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-cowork                 Cowork (Bedrock)     sort= 70
    (
        'cw-cowork',  -- id
        'claude',     -- app_type
        'Cowork (Bedrock)', -- name
        '{' ||  -- settings_config
        '  "env": {' ||
        '    "ANTHROPIC_AUTH_TOKEN": "dummy",' ||
        '    "ANTHROPIC_BASE_URL": "http://127.0.0.1:8089",' ||
        '    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "cowork:default",' ||
        '    "ANTHROPIC_DEFAULT_SONNET_MODEL": "cowork:default",' ||
        '    "ANTHROPIC_DEFAULT_OPUS_MODEL": "cowork:default"' ||
        '  }' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        70,               -- sort_index
        'Bedrock 落点，模型由 COWORK_MODEL 环境变量决定（默认 Opus 4.7）', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false,' ||
        '  "apiFormat": "anthropic"' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    );

-- cw-kimi-personal 的 sort_index 修正（如果之前已插入）
UPDATE "providers" SET "sort_index" = 35 WHERE "id" = 'cw-kimi-personal';

-- ==============================================================================
-- Codex Providers
-- ==============================================================================
INSERT OR IGNORE INTO "providers" (
    "id", "app_type", "name", "settings_config", "website_url",
    "category", "created_at", "sort_index", "notes", "icon",
    "icon_color", "meta", "is_current", "in_failover_queue",
    "cost_multiplier", "limit_daily_usd", "limit_monthly_usd", "provider_type"
) VALUES
    -- cw-codex-gpt53            Codewiz GPT-5.3      sort= 80
    (
        'cw-codex-gpt53',  -- id
        'codex',     -- app_type
        'Codewiz GPT-5.3', -- name
        '{' ||  -- settings_config
        '  "auth": {"OPENAI_API_KEY": "dummy"},' ||
        '  "config": "model_provider = \"custom\"\n' ||
        'model = \"codewiz:gpt53\"\n' ||
        'model_reasoning_effort = \"high\"\n' ||
        '\n' ||
        'model_context_window = 400000\n' ||
        'model_auto_compact_token_limit = 360000\n' ||
        '[model_providers.custom]\n' ||
        'name = \"custom\"\n' ||
        'wire_api = \"responses\"\n' ||
        'requires_openai_auth = false\n' ||
        'base_url = \"http://127.0.0.1:8089\""' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        80,               -- sort_index
        'GPT-5.3 Codex，400K 上下文，代码优化专用', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-codex-gpt54            Codewiz GPT-5.4      sort= 90
    (
        'cw-codex-gpt54',  -- id
        'codex',     -- app_type
        'Codewiz GPT-5.4', -- name
        '{' ||  -- settings_config
        '  "auth": {"OPENAI_API_KEY": "dummy"},' ||
        '  "config": "model_provider = \"custom\"\n' ||
        'model = \"codewiz:gpt54\"\n' ||
        'model_reasoning_effort = \"high\"\n' ||
        '\n' ||
        'model_context_window = 272000\n' ||
        'model_auto_compact_token_limit = 244800\n' ||
        '[model_providers.custom]\n' ||
        'name = \"custom\"\n' ||
        'wire_api = \"responses\"\n' ||
        'requires_openai_auth = false\n' ||
        'base_url = \"http://127.0.0.1:8089\""' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        90,               -- sort_index
        'GPT-5.4，272K 上下文', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-codex-gpt55            Codewiz GPT-5.5      sort=100
    (
        'cw-codex-gpt55',  -- id
        'codex',     -- app_type
        'Codewiz GPT-5.5', -- name
        '{' ||  -- settings_config
        '  "auth": {"OPENAI_API_KEY": "dummy"},' ||
        '  "config": "model_provider = \"custom\"\n' ||
        'model = \"codewiz:gpt55\"\n' ||
        'model_reasoning_effort = \"high\"\n' ||
        '\n' ||
        'model_context_window = 1000000\n' ||
        'model_auto_compact_token_limit = 900000\n' ||
        '[model_providers.custom]\n' ||
        'name = \"custom\"\n' ||
        'wire_api = \"responses\"\n' ||
        'requires_openai_auth = false\n' ||
        'base_url = \"http://127.0.0.1:8089\""' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        100,               -- sort_index
        'GPT-5.5，1M 上下文，最强推理', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-codex-deepseek-pro     Codewiz DeepSeek Pro sort=110
    (
        'cw-codex-deepseek-pro',  -- id
        'codex',     -- app_type
        'Codewiz DeepSeek Pro', -- name
        '{' ||  -- settings_config
        '  "auth": {"OPENAI_API_KEY": "dummy"},' ||
        '  "config": "model_provider = \"custom\"\n' ||
        'model = \"codewiz:deepseek-pro\"\n' ||
        '\n' ||
        'model_context_window = 1000000\n' ||
        'model_auto_compact_token_limit = 900000\n' ||
        '[model_providers.custom]\n' ||
        'name = \"custom\"\n' ||
        'wire_api = \"responses\"\n' ||
        'requires_openai_auth = false\n' ||
        'base_url = \"http://127.0.0.1:8089\""' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        110,               -- sort_index
        'DeepSeek V4 Pro，免费，1M 上下文', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-codex-deepseek-flash   Codewiz DeepSeek Flash sort=120
    (
        'cw-codex-deepseek-flash',  -- id
        'codex',     -- app_type
        'Codewiz DeepSeek Flash', -- name
        '{' ||  -- settings_config
        '  "auth": {"OPENAI_API_KEY": "dummy"},' ||
        '  "config": "model_provider = \"custom\"\n' ||
        'model = \"codewiz:deepseek-flash\"\n' ||
        '\n' ||
        'model_context_window = 1000000\n' ||
        'model_auto_compact_token_limit = 900000\n' ||
        '[model_providers.custom]\n' ||
        'name = \"custom\"\n' ||
        'wire_api = \"responses\"\n' ||
        'requires_openai_auth = false\n' ||
        'base_url = \"http://127.0.0.1:8089\""' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        120,               -- sort_index
        'DeepSeek V4 Flash，免费，速度快', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-codex-kimi26           Codewiz Kimi K2.6    sort=130
    (
        'cw-codex-kimi26',  -- id
        'codex',     -- app_type
        'Codewiz Kimi K2.6', -- name
        '{' ||  -- settings_config
        '  "auth": {"OPENAI_API_KEY": "dummy"},' ||
        '  "config": "model_provider = \"custom\"\n' ||
        'model = \"codewiz:kimi26\"\n' ||
        '\n' ||
        'model_context_window = 256000\n' ||
        'model_auto_compact_token_limit = 230400\n' ||
        '[model_providers.custom]\n' ||
        'name = \"custom\"\n' ||
        'wire_api = \"responses\"\n' ||
        'requires_openai_auth = false\n' ||
        'base_url = \"http://127.0.0.1:8089\""' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        130,               -- sort_index
        'Kimi K2.6，免费，256K 上下文', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-codex-kimi25           Codewiz Kimi K2.5    sort=140
    (
        'cw-codex-kimi25',  -- id
        'codex',     -- app_type
        'Codewiz Kimi K2.5', -- name
        '{' ||  -- settings_config
        '  "auth": {"OPENAI_API_KEY": "dummy"},' ||
        '  "config": "model_provider = \"custom\"\n' ||
        'model = \"codewiz:kimi25\"\n' ||
        '\n' ||
        'model_context_window = 256000\n' ||
        'model_auto_compact_token_limit = 230400\n' ||
        '[model_providers.custom]\n' ||
        'name = \"custom\"\n' ||
        'wire_api = \"responses\"\n' ||
        'requires_openai_auth = false\n' ||
        'base_url = \"http://127.0.0.1:8089\""' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        140,               -- sort_index
        'Kimi K2.5，免费，动态上下文', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-codex-glm              Codewiz GLM-5.1      sort=150
    (
        'cw-codex-glm',  -- id
        'codex',     -- app_type
        'Codewiz GLM-5.1', -- name
        '{' ||  -- settings_config
        '  "auth": {"OPENAI_API_KEY": "dummy"},' ||
        '  "config": "model_provider = \"custom\"\n' ||
        'model = \"codewiz:glm\"\n' ||
        '\n' ||
        'model_context_window = 202000\n' ||
        'model_auto_compact_token_limit = 181800\n' ||
        '[model_providers.custom]\n' ||
        'name = \"custom\"\n' ||
        'wire_api = \"responses\"\n' ||
        'requires_openai_auth = false\n' ||
        'base_url = \"http://127.0.0.1:8089\""' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        150,               -- sort_index
        'GLM-5.1，免费，中文优化，202K 上下文', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-codex-dots             Codewiz dots.llm2    sort=160
    (
        'cw-codex-dots',  -- id
        'codex',     -- app_type
        'Codewiz dots.llm2', -- name
        '{' ||  -- settings_config
        '  "auth": {"OPENAI_API_KEY": "dummy"},' ||
        '  "config": "model_provider = \"custom\"\n' ||
        'model = \"codewiz:dots\"\n' ||
        '\n' ||
        'model_context_window = 256000\n' ||
        'model_auto_compact_token_limit = 230400\n' ||
        '[model_providers.custom]\n' ||
        'name = \"custom\"\n' ||
        'wire_api = \"responses\"\n' ||
        'requires_openai_auth = false\n' ||
        'base_url = \"http://127.0.0.1:8089\""' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        160,               -- sort_index
        '小红书自研 dots.llm2.inst，免费，支持 Computer Use', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-lobi-deepseek-pro      Lobi DeepSeek Pro    sort=170
    (
        'cw-lobi-deepseek-pro',  -- id
        'codex',     -- app_type
        'Lobi DeepSeek Pro', -- name
        '{' ||  -- settings_config
        '  "auth": {"OPENAI_API_KEY": "dummy"},' ||
        '  "config": "model_provider = \"custom\"\n' ||
        'model = \"lobi:deepseek-pro\"\n' ||
        '\n' ||
        'model_context_window = 1000000\n' ||
        'model_auto_compact_token_limit = 900000\n' ||
        '[model_providers.custom]\n' ||
        'name = \"custom\"\n' ||
        'wire_api = \"responses\"\n' ||
        'requires_openai_auth = false\n' ||
        'base_url = \"http://127.0.0.1:8089\""' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        170,               -- sort_index
        'DeepSeek V4 Pro，lobi 落点，1M 上下文', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-lobi-deepseek-flash    Lobi DeepSeek Flash  sort=180
    (
        'cw-lobi-deepseek-flash',  -- id
        'codex',     -- app_type
        'Lobi DeepSeek Flash', -- name
        '{' ||  -- settings_config
        '  "auth": {"OPENAI_API_KEY": "dummy"},' ||
        '  "config": "model_provider = \"custom\"\n' ||
        'model = \"lobi:deepseek-flash\"\n' ||
        '\n' ||
        'model_context_window = 1000000\n' ||
        'model_auto_compact_token_limit = 900000\n' ||
        '[model_providers.custom]\n' ||
        'name = \"custom\"\n' ||
        'wire_api = \"responses\"\n' ||
        'requires_openai_auth = false\n' ||
        'base_url = \"http://127.0.0.1:8089\""' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        180,               -- sort_index
        'DeepSeek V4 Flash，lobi 落点，速度快', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-lobi-kimi26            Lobi Kimi K2.6       sort=190
    (
        'cw-lobi-kimi26',  -- id
        'codex',     -- app_type
        'Lobi Kimi K2.6', -- name
        '{' ||  -- settings_config
        '  "auth": {"OPENAI_API_KEY": "dummy"},' ||
        '  "config": "model_provider = \"custom\"\n' ||
        'model = \"lobi:kimi26\"\n' ||
        '\n' ||
        'model_context_window = 256000\n' ||
        'model_auto_compact_token_limit = 230400\n' ||
        '[model_providers.custom]\n' ||
        'name = \"custom\"\n' ||
        'wire_api = \"responses\"\n' ||
        'requires_openai_auth = false\n' ||
        'base_url = \"http://127.0.0.1:8089\""' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        190,               -- sort_index
        'Kimi K2.6，lobi 落点，256K 上下文', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-lobi-kimi25            Lobi Kimi K2.5       sort=200
    (
        'cw-lobi-kimi25',  -- id
        'codex',     -- app_type
        'Lobi Kimi K2.5', -- name
        '{' ||  -- settings_config
        '  "auth": {"OPENAI_API_KEY": "dummy"},' ||
        '  "config": "model_provider = \"custom\"\n' ||
        'model = \"lobi:kimi25\"\n' ||
        '\n' ||
        'model_context_window = 200000\n' ||
        'model_auto_compact_token_limit = 180000\n' ||
        '[model_providers.custom]\n' ||
        'name = \"custom\"\n' ||
        'wire_api = \"responses\"\n' ||
        'requires_openai_auth = false\n' ||
        'base_url = \"http://127.0.0.1:8089\""' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        200,               -- sort_index
        'Kimi K2.5，lobi 落点，200K 上下文', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-lobi-kimi25-qs         Lobi Kimi K2.5-qs    sort=210
    (
        'cw-lobi-kimi25-qs',  -- id
        'codex',     -- app_type
        'Lobi Kimi K2.5-qs', -- name
        '{' ||  -- settings_config
        '  "auth": {"OPENAI_API_KEY": "dummy"},' ||
        '  "config": "model_provider = \"custom\"\n' ||
        'model = \"lobi:kimi25qs\"\n' ||
        '\n' ||
        'model_context_window = 200000\n' ||
        'model_auto_compact_token_limit = 180000\n' ||
        '[model_providers.custom]\n' ||
        'name = \"custom\"\n' ||
        'wire_api = \"responses\"\n' ||
        'requires_openai_auth = false\n' ||
        'base_url = \"http://127.0.0.1:8089\""' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        210,               -- sort_index
        'Kimi K2.5-qs，lobi 落点，200K 上下文', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    ),
    -- cw-lobi-glm5v             Lobi GLM-5v-turbo    sort=220
    (
        'cw-lobi-glm5v',  -- id
        'codex',     -- app_type
        'Lobi GLM-5v-turbo', -- name
        '{' ||  -- settings_config
        '  "auth": {"OPENAI_API_KEY": "dummy"},' ||
        '  "config": "model_provider = \"custom\"\n' ||
        'model = \"lobi:glm5v\"\n' ||
        '\n' ||
        'model_context_window = 203000\n' ||
        'model_auto_compact_token_limit = 182700\n' ||
        '[model_providers.custom]\n' ||
        'name = \"custom\"\n' ||
        'wire_api = \"responses\"\n' ||
        'requires_openai_auth = false\n' ||
        'base_url = \"http://127.0.0.1:8089\""' ||
        '}',
        NULL,              -- website_url
        'custom',          -- category
        1779098000000,     -- created_at
        220,               -- sort_index
        'GLM-5v-turbo，lobi 落点，中文优化，203K 上下文', -- notes
        NULL,              -- icon
        NULL,              -- icon_color
        '{' ||  -- meta
        '  "commonConfigEnabled": true,' ||
        '  "endpointAutoSelect": false' ||
        '}',
        0,                -- is_current
        0,                 -- in_failover_queue
        '1.0',             -- cost_multiplier
        NULL,              -- limit_daily_usd
        NULL,              -- limit_monthly_usd
        NULL               -- provider_type
    );

-- ==============================================================================
-- 同步已有记录的 sort_index（排序逻辑变更时生效）
-- ==============================================================================
UPDATE "providers" SET "sort_index" = 10 WHERE "id" = 'cw-codewiz-standard';
UPDATE "providers" SET "sort_index" = 20 WHERE "id" = 'cw-codewiz-opus47';
UPDATE "providers" SET "sort_index" = 30 WHERE "id" = 'cw-codewiz-thinking';
UPDATE "providers" SET "sort_index" = 35 WHERE "id" = 'cw-kimi-personal';
UPDATE "providers" SET "sort_index" = 40 WHERE "id" = 'cw-lobi-standard';
UPDATE "providers" SET "sort_index" = 70 WHERE "id" = 'cw-cowork';
UPDATE "providers" SET "sort_index" = 80 WHERE "id" = 'cw-codex-gpt53';
UPDATE "providers" SET "sort_index" = 90 WHERE "id" = 'cw-codex-gpt54';
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
UPDATE "providers" SET "is_current" = 1
WHERE "id" = 'cw-codewiz-standard'
  AND (SELECT COUNT(*) FROM "providers" WHERE "is_current" = 1) = 0;

-- ==============================================================================
-- 通用配置片段 (Common Config Snippets) — 跨 provider 共享，切换时不丢失
-- ==============================================================================

-- Claude Code：插件、Marketplace、telemetry、危险模式免确认
INSERT OR IGNORE INTO "settings" ("key", "value") VALUES (
    'common_config_claude',
    '{
  "enabledPlugins": {
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
  "skipDangerousModePermissionPrompt": true
}'
);

-- Codex：响应存储关闭、telemetry
INSERT OR IGNORE INTO "settings" ("key", "value") VALUES (
    'common_config_codex',
    'disable_response_storage = true

[otel]
environment = "子牙"

[otel.exporter.otlp-http]
endpoint = "http://49.234.245.115:8089/v1/logs"
protocol = "binary"

[otel.metrics_exporter.otlp-http]
endpoint = "http://49.234.245.115:8089/v1/metrics"
protocol = "binary"
'
);