-- Drop existing tables in reverse order of dependency to avoid foreign key issues.
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS chats CASCADE;
DROP TABLE IF EXISTS api_configs CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- This file defines the database schema for the remote PostgreSQL server.
-- It is designed to be fully compatible with the local Drift database schema.

-- Users Table
-- Stores user information, credentials, and their associated chat IDs.
CREATE TABLE IF NOT EXISTS users (
    uuid TEXT PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    chat_uuids TEXT,
    enable_auto_title_generation BOOLEAN,
    title_generation_prompt TEXT,
    title_generation_api_config_uuid TEXT,
    enable_resume BOOLEAN,
    resume_prompt TEXT,
    resume_api_config_uuid TEXT,
    gemini_api_keys TEXT
);

-- API Configs Table
-- Unified table for API configurations (e.g., Gemini, OpenAI).
CREATE TABLE IF NOT EXISTS api_configs (
    uuid TEXT PRIMARY KEY,
    user_uuid TEXT,
    name TEXT NOT NULL,
    api_type TEXT NOT NULL,
    model TEXT NOT NULL,
    api_key TEXT,
    base_url TEXT,
    use_custom_temperature BOOLEAN,
    temperature REAL,
    use_custom_top_p BOOLEAN,
    top_p REAL,
    use_custom_top_k BOOLEAN,
    top_k INTEGER,
    max_output_tokens INTEGER,
    stop_sequences TEXT,
    enable_reasoning_effort BOOLEAN,
    reasoning_effort TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Chats Table
-- Stores chat sessions, which can be conversations or folders.
CREATE TABLE IF NOT EXISTS chats (
    uuid TEXT PRIMARY KEY,
    title TEXT,
    system_prompt TEXT,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    is_template BOOLEAN NOT NULL DEFAULT FALSE,
    cover_image_base64 TEXT,
    background_image_path TEXT,
    order_index INTEGER,
    is_folder BOOLEAN,
    parent_folder_uuid TEXT,
    context_config TEXT NOT NULL,
    xml_rules TEXT NOT NULL,
    api_config_uuid TEXT,
    enable_preprocessing BOOLEAN,
    preprocessing_prompt TEXT,
    context_summary TEXT,
    preprocessing_api_config_uuid TEXT,
    enable_secondary_xml BOOLEAN,
    secondary_xml_prompt TEXT,
    secondary_xml_api_config_uuid TEXT,
    continue_prompt TEXT,
    enable_help_me_reply BOOLEAN,
    help_me_reply_prompt TEXT,
    help_me_reply_api_config_uuid TEXT,
    help_me_reply_trigger_mode TEXT
);

-- Messages Table
-- Stores individual messages within a chat.
CREATE TABLE IF NOT EXISTS messages (
    uuid TEXT PRIMARY KEY,
    chat_uuid TEXT NOT NULL,
    role TEXT NOT NULL,
    raw_text TEXT NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    original_xml_content TEXT,
    secondary_xml_content TEXT
);