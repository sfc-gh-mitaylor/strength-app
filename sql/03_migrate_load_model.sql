-- ============================================================
-- Migration: load model (bodyweight handling) + TM eligibility config
-- Idempotent: safe to re-run.
-- ============================================================

USE SCHEMA TRAINING_APP.CORE;

-- ------------------------------------------------------------
-- EXERCISE: how the movement is loaded
--   external   - load is whatever is on the bar/machine
--   bodyweight - load is BW_FRACTION x bodyweight_flat_kg, plus any added load
-- ------------------------------------------------------------
ALTER TABLE EXERCISE ADD COLUMN IF NOT EXISTS LOAD_MODE   VARCHAR      DEFAULT 'external';
ALTER TABLE EXERCISE ADD COLUMN IF NOT EXISTS BW_FRACTION NUMBER(4,3);

-- ------------------------------------------------------------
-- SET_LOG: persist the resolved load at log time so historical stimulus stays
-- reproducible even if bodyweight_flat_kg is changed later.
-- ------------------------------------------------------------
ALTER TABLE SET_LOG ADD COLUMN IF NOT EXISTS EFFECTIVE_WEIGHT NUMBER(10,2);

-- ------------------------------------------------------------
-- Classify bodyweight movements.
-- BW_FRACTION = share of bodyweight the movement actually loads.
-- ------------------------------------------------------------
UPDATE EXERCISE SET LOAD_MODE = 'bodyweight', BW_FRACTION = 1.000
  WHERE EXERCISE_ID IN ('ex_pullup','ex_chinup','ex_tri_dip','ex_deadhang');

UPDATE EXERCISE SET LOAD_MODE = 'bodyweight', BW_FRACTION = 0.650
  WHERE EXERCISE_ID IN ('ex_pushup_weighted');

UPDATE EXERCISE SET LOAD_MODE = 'bodyweight', BW_FRACTION = 0.600
  WHERE EXERCISE_ID IN ('ex_nordic_curl','ex_ghr');

UPDATE EXERCISE SET LOAD_MODE = 'bodyweight', BW_FRACTION = 0.400
  WHERE EXERCISE_ID IN ('ex_hanging_leg');

UPDATE EXERCISE SET LOAD_MODE = 'bodyweight', BW_FRACTION = 0.350
  WHERE EXERCISE_ID IN ('ex_ab_wheel','ex_back_ext');

UPDATE EXERCISE SET LOAD_MODE = 'bodyweight', BW_FRACTION = 0.300
  WHERE EXERCISE_ID IN ('ex_split_squat','ex_lunge_walking','ex_step_up','ex_turkish_getup');

-- Everything else is externally loaded.
UPDATE EXERCISE SET LOAD_MODE = 'external', BW_FRACTION = NULL
  WHERE LOAD_MODE IS NULL OR (LOAD_MODE <> 'bodyweight');

-- ------------------------------------------------------------
-- New CONFIG keys
-- ------------------------------------------------------------
MERGE INTO CONFIG t
USING (
    SELECT * FROM VALUES
      ('bodyweight_flat_kg','100','Flat bodyweight figure used to resolve bodyweight-exercise load (kg)'),
      ('units','kg','Weight units used throughout the app'),
      ('tm_eligible_max_rpe','8','A set only updates TM if RPE is at or below this (clean, submaximal)'),
      ('tm_eligible_min_reps','3','Minimum reps for a TM-eligible set'),
      ('tm_eligible_max_reps','10','Maximum reps for a TM-eligible set'),
      ('tm_min_sets_for_pseudo','2','Logged eligible sets needed before an accessory gets a derived TM'),
      ('quality_floor','0','Lower clamp on Quality(). Without it the penalty branch goes negative at high I and heavy sets would subtract stimulus'),
      ('tm_lookback_days','120','How far back to look for the best e1RM when deriving a TM')
    AS v(KEY, VALUE, DESCRIPTION)
) s
ON t.KEY = s.KEY
WHEN NOT MATCHED THEN INSERT (KEY, VALUE, DESCRIPTION) VALUES (s.KEY, s.VALUE, s.DESCRIPTION);
