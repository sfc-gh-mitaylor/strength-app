-- ============================================================
-- Strength training app — core schema
-- Milestone 1: schema only. No computation, no fabricated history.
-- Idempotent: safe to re-run.
-- ============================================================

CREATE DATABASE IF NOT EXISTS TRAINING_APP;
CREATE SCHEMA IF NOT EXISTS TRAINING_APP.CORE;

USE SCHEMA TRAINING_APP.CORE;

-- ------------------------------------------------------------
-- CONFIG: every tunable lives here, nothing hardcoded in app code
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CONFIG (
    KEY           VARCHAR         NOT NULL PRIMARY KEY,
    VALUE         VARCHAR         NOT NULL,
    DESCRIPTION   VARCHAR,
    UPDATED_AT    TIMESTAMP_LTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP()
);

-- ------------------------------------------------------------
-- EXERCISE: catalog. FAMILY drives rotation pools.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS EXERCISE (
    EXERCISE_ID       VARCHAR       NOT NULL PRIMARY KEY,
    NAME              VARCHAR       NOT NULL,
    MOVEMENT_PATTERN  VARCHAR       NOT NULL,
    RISK_CLASS        VARCHAR       NOT NULL, -- high_risk_load | low_risk_load
    FAMILY            VARCHAR       NOT NULL, -- rotation pool key, e.g. 'bicep_flexion'
    IS_MAIN_LIFT      BOOLEAN       NOT NULL DEFAULT FALSE,
    IN_ROTATION_POOL  BOOLEAN       NOT NULL DEFAULT TRUE,  -- eligible for program slots
    IN_BORED_POOL     BOOLEAN       NOT NULL DEFAULT TRUE,  -- eligible for freestyle sessions
    NOTES             VARCHAR,
    CREATED_AT        TIMESTAMP_LTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT CHK_EXERCISE_RISK CHECK (RISK_CLASS IN ('high_risk_load','low_risk_load'))
);

-- ------------------------------------------------------------
-- PROGRAM_SLOT: DeFranco 4-day conjugate split slots
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PROGRAM_SLOT (
    SLOT_ID      VARCHAR       NOT NULL PRIMARY KEY,
    SLOT_CODE    VARCHAR       NOT NULL, -- ME_UPPER, DE_LOWER, ACCESSORY_1, ...
    SESSION_DAY  VARCHAR       NOT NULL, -- ME_UPPER | ME_LOWER | DE_UPPER | DE_LOWER
    SLOT_KIND    VARCHAR       NOT NULL, -- me | de | accessory
    SLOT_ORDER   NUMBER(4,0)   NOT NULL,
    FAMILY_HINT  VARCHAR,                -- family this slot draws from when rotating
    CREATED_AT   TIMESTAMP_LTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT CHK_SLOT_KIND CHECK (SLOT_KIND IN ('me','de','accessory'))
);

-- ------------------------------------------------------------
-- SLOT_ASSIGNMENT: which exercise a slot points at, with history.
-- Active row = RETIRED_AT IS NULL.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SLOT_ASSIGNMENT (
    ASSIGNMENT_ID     VARCHAR       NOT NULL PRIMARY KEY,
    USER_NAME         VARCHAR       NOT NULL,
    SLOT_ID           VARCHAR       NOT NULL,
    EXERCISE_ID       VARCHAR       NOT NULL,
    ASSIGN_REASON     VARCHAR       NOT NULL, -- initial | plateau_swap | fresh_pick | manual
    ASSIGNED_AT       TIMESTAMP_LTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    RETIRED_AT        TIMESTAMP_LTZ,
    BASELINE_RESET_AT TIMESTAMP_LTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT CHK_ASSIGN_REASON CHECK (ASSIGN_REASON IN ('initial','plateau_swap','fresh_pick','manual'))
);

-- ------------------------------------------------------------
-- TRAINING_MAX: TM per main lift, append-only history.
-- Current TM = latest EFFECTIVE_FROM per (USER_NAME, EXERCISE_ID).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS TRAINING_MAX (
    TM_ID          VARCHAR       NOT NULL PRIMARY KEY,
    USER_NAME      VARCHAR       NOT NULL,
    EXERCISE_ID    VARCHAR       NOT NULL,
    TM_VALUE       NUMBER(10,2)  NOT NULL,
    SOURCE_E1RM    NUMBER(10,2),
    SOURCE_SET_ID  VARCHAR,
    TM_DISCOUNT    NUMBER(5,4),            -- discount actually applied, for auditability
    EFFECTIVE_FROM TIMESTAMP_LTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    NOTE           VARCHAR
);

-- ------------------------------------------------------------
-- SESSION: one training session.
-- SESSION_TYPE freestyle => excluded from growth-trend calcs.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SESSION (
    SESSION_ID    VARCHAR       NOT NULL PRIMARY KEY,
    USER_NAME     VARCHAR       NOT NULL,
    SESSION_DATE  DATE          NOT NULL,
    SESSION_TYPE  VARCHAR       NOT NULL, -- program | freestyle
    SLOT_KIND     VARCHAR,                -- me | de | accessory | NULL for freestyle
    SESSION_DAY   VARCHAR,                -- ME_UPPER etc, NULL for freestyle
    DE_WAVE_WEEK  NUMBER(2,0),            -- 1..3 for DE days
    NOTES         VARCHAR,
    CREATED_AT    TIMESTAMP_LTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT CHK_SESSION_TYPE CHECK (SESSION_TYPE IN ('program','freestyle'))
);

-- ------------------------------------------------------------
-- SET_LOG: every logged set. Source of truth for all derived metrics.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SET_LOG (
    SET_ID       VARCHAR       NOT NULL PRIMARY KEY,
    USER_NAME    VARCHAR       NOT NULL,
    SESSION_ID   VARCHAR       NOT NULL,
    EXERCISE_ID  VARCHAR       NOT NULL,
    SET_INDEX    NUMBER(4,0)   NOT NULL,
    WEIGHT       NUMBER(10,2)  NOT NULL,
    REPS         NUMBER(4,0)   NOT NULL,
    RPE          NUMBER(3,1),            -- logged and displayed; NOT an input to risk penalty
    IS_WARMUP    BOOLEAN       NOT NULL DEFAULT FALSE,
    LOGGED_AT    TIMESTAMP_LTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT CHK_SET_REPS CHECK (REPS > 0),
    CONSTRAINT CHK_SET_WEIGHT CHECK (WEIGHT >= 0)
);

-- ------------------------------------------------------------
-- WEEKLY_EXERCISE_STIMULUS: materialized weekly rollup, program sets only.
-- Populated by the stimulus module in a later milestone.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS WEEKLY_EXERCISE_STIMULUS (
    USER_NAME       VARCHAR       NOT NULL,
    EXERCISE_ID     VARCHAR       NOT NULL,
    WEEK_START      DATE          NOT NULL,
    STIMULUS        NUMBER(18,4)  NOT NULL,
    TONNAGE         NUMBER(18,2)  NOT NULL,
    SET_COUNT       NUMBER(6,0)   NOT NULL,
    GROWTH_RATE_3W  NUMBER(10,6),          -- smoothed WoW stimulus growth
    COMPUTED_AT     TIMESTAMP_LTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (USER_NAME, EXERCISE_ID, WEEK_START)
);

-- ------------------------------------------------------------
-- ROTATION_EVENT: audit trail distinguishing stalled vs variety swaps
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ROTATION_EVENT (
    EVENT_ID          VARCHAR       NOT NULL PRIMARY KEY,
    USER_NAME         VARCHAR       NOT NULL,
    SLOT_ID           VARCHAR       NOT NULL,
    FROM_EXERCISE_ID  VARCHAR,
    TO_EXERCISE_ID    VARCHAR       NOT NULL,
    REASON            VARCHAR       NOT NULL, -- plateau_swap | fresh_pick | manual
    GROWTH_RATE_AT_SWAP NUMBER(10,6),
    OCCURRED_AT       TIMESTAMP_LTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT CHK_ROTATION_REASON CHECK (REASON IN ('plateau_swap','fresh_pick','manual'))
);

-- ------------------------------------------------------------
-- FAMILY_COOLDOWN: stops a variation reappearing too soon
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS FAMILY_COOLDOWN (
    USER_NAME                VARCHAR       NOT NULL,
    FAMILY                   VARCHAR       NOT NULL,
    EXERCISE_ID              VARCHAR       NOT NULL,
    LAST_USED_ROTATION_NO    NUMBER(6,0)   NOT NULL,
    COOLDOWN_UNTIL_ROTATION  NUMBER(6,0)   NOT NULL,
    UPDATED_AT               TIMESTAMP_LTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (USER_NAME, FAMILY, EXERCISE_ID)
);
