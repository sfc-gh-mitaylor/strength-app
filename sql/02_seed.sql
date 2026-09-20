-- ============================================================
-- Seed reference data: CONFIG, EXERCISE catalog, PROGRAM_SLOT
-- Reference data only. No fabricated sessions or sets.
-- Idempotent via MERGE.
-- ============================================================

USE SCHEMA TRAINING_APP.CORE;

-- ------------------------------------------------------------
-- CONFIG
-- ------------------------------------------------------------
MERGE INTO CONFIG t
USING (
    SELECT * FROM VALUES
      ('tm_discount','0.90','TM = reliable e1RM x this discount'),
      ('breakpoint_high_risk','0.85','Quality() breakpoint for high_risk_load lifts (I = weight/TM)'),
      ('breakpoint_low_risk','0.93','Quality() breakpoint for low_risk_load lifts'),
      ('k_high_risk','2.0','Penalty slope above breakpoint, high_risk_load'),
      ('k_low_risk','0.5','Penalty slope above breakpoint, low_risk_load'),
      ('weekly_growth_target_pct','0.03','Target WoW stimulus growth per active exercise'),
      ('plateau_threshold_pct','0.01','Smoothed growth below this counts as not progressing'),
      ('plateau_consecutive_weeks','2','Consecutive sub-threshold weeks before forcing a swap'),
      ('growth_trend_window_weeks','3','Rolling window for smoothed growth rate'),
      ('fresh_pick_probability','0.08','Per-week chance of an unprompted variety swap in a healthy slot'),
      ('family_cooldown_rotations','3','Rotations a used variation stays ineligible'),
      ('de_wave_pct','50,55,60','DE day %TM wave across the 3-week wave'),
      ('de_wave_length_weeks','3','Length of the DE wave'),
      ('weekly_high_risk_cap_sets_above_i090','6','Hard weekly cap on sets at I > 0.90 across all high_risk_load lifts'),
      ('high_risk_i_cap_threshold','0.90','The I value the weekly high-risk set cap counts against'),
      ('me_top_set_rep_low','3','ME day top-set minimum reps'),
      ('me_top_set_rep_high','6','ME day top-set maximum reps'),
      ('week_start_day','MONDAY','Day weeks roll over on for weekly rollups')
    AS v(KEY, VALUE, DESCRIPTION)
) s
ON t.KEY = s.KEY
WHEN NOT MATCHED THEN INSERT (KEY, VALUE, DESCRIPTION) VALUES (s.KEY, s.VALUE, s.DESCRIPTION);

-- ------------------------------------------------------------
-- EXERCISE catalog
--   risk_class high_risk_load: spinal/shoulder-loaded compounds where
--     loading near max is the joint/CNS risk. Load capped at I<=0.85 band.
--   risk_class low_risk_load: machines, isolation, supported work — safe
--     to push to RPE 9-10 at higher %TM.
-- ------------------------------------------------------------
MERGE INTO EXERCISE t
USING (
    SELECT * FROM VALUES
      -- ---------- MAIN LIFTS / ME rotation pools ----------
      -- horizontal press (ME_UPPER)
      ('ex_bench_bb',        'Barbell Bench Press',        'horizontal_press', 'high_risk_load', 'horizontal_press', TRUE,  TRUE, TRUE,  'ME upper anchor'),
      ('ex_bench_close',     'Close-Grip Bench Press',     'horizontal_press', 'high_risk_load', 'horizontal_press', TRUE,  TRUE, TRUE,  NULL),
      ('ex_floor_press',     'Floor Press',                'horizontal_press', 'high_risk_load', 'horizontal_press', TRUE,  TRUE, TRUE,  'Shoulder-friendly ROM'),
      ('ex_bench_incline',   'Incline Barbell Press',      'horizontal_press', 'high_risk_load', 'horizontal_press', TRUE,  TRUE, TRUE,  NULL),
      ('ex_bench_db_flat',   'Flat DB Press',              'horizontal_press', 'low_risk_load',  'horizontal_press', FALSE, TRUE, TRUE,  NULL),
      ('ex_bench_board',     'Board Press',                'horizontal_press', 'high_risk_load', 'horizontal_press', TRUE,  TRUE, TRUE,  NULL),
      -- squat / hip hinge (ME_LOWER)
      ('ex_squat_box',       'Box Squat',                  'squat',            'high_risk_load', 'squat',            TRUE,  TRUE, TRUE,  'Westside staple, joint-friendly'),
      ('ex_squat_front',     'Front Squat',                'squat',            'high_risk_load', 'squat',            TRUE,  TRUE, TRUE,  NULL),
      ('ex_squat_ssb',       'Safety Bar Squat',           'squat',            'high_risk_load', 'squat',            TRUE,  TRUE, TRUE,  'Shoulder-sparing'),
      ('ex_dl_trapbar',      'Trap Bar Deadlift',          'hinge',            'high_risk_load', 'hinge',            TRUE,  TRUE, TRUE,  'Lower spinal shear than straight bar'),
      ('ex_dl_rdl',          'Romanian Deadlift',          'hinge',            'high_risk_load', 'hinge',            TRUE,  TRUE, TRUE,  NULL),
      ('ex_dl_rack',         'Rack Pull',                  'hinge',            'high_risk_load', 'hinge',            TRUE,  TRUE, TRUE,  NULL),
      ('ex_goodmorning',     'Good Morning',               'hinge',            'high_risk_load', 'hinge',            FALSE, TRUE, TRUE,  NULL),
      -- vertical press
      ('ex_ohp_bb',          'Standing Barbell Press',     'vertical_press',   'high_risk_load', 'vertical_press',   TRUE,  TRUE, TRUE,  NULL),
      ('ex_ohp_db',          'Seated DB Shoulder Press',   'vertical_press',   'low_risk_load',  'vertical_press',   FALSE, TRUE, TRUE,  NULL),
      ('ex_ohp_landmine',    'Landmine Press',             'vertical_press',   'low_risk_load',  'vertical_press',   FALSE, TRUE, TRUE,  'Shoulder-friendly'),

      -- ---------- ACCESSORY pools ----------
      -- horizontal pull / upper back
      ('ex_row_bb',          'Barbell Row',                'horizontal_pull',  'high_risk_load', 'horizontal_pull',  FALSE, TRUE, TRUE,  NULL),
      ('ex_row_db',          'One-Arm DB Row',             'horizontal_pull',  'low_risk_load',  'horizontal_pull',  FALSE, TRUE, TRUE,  NULL),
      ('ex_row_chest_sup',   'Chest-Supported Row',        'horizontal_pull',  'low_risk_load',  'horizontal_pull',  FALSE, TRUE, TRUE,  NULL),
      ('ex_row_seated_cable','Seated Cable Row',           'horizontal_pull',  'low_risk_load',  'horizontal_pull',  FALSE, TRUE, TRUE,  NULL),
      ('ex_row_meadows',     'Meadows Row',                'horizontal_pull',  'low_risk_load',  'horizontal_pull',  FALSE, TRUE, TRUE,  NULL),
      -- vertical pull
      ('ex_pullup',          'Pull-Up',                    'vertical_pull',    'low_risk_load',  'vertical_pull',    FALSE, TRUE, TRUE,  NULL),
      ('ex_chinup',          'Chin-Up',                    'vertical_pull',    'low_risk_load',  'vertical_pull',    FALSE, TRUE, TRUE,  NULL),
      ('ex_lat_pulldown',    'Lat Pulldown',               'vertical_pull',    'low_risk_load',  'vertical_pull',    FALSE, TRUE, TRUE,  NULL),
      ('ex_pulldown_neutral','Neutral-Grip Pulldown',      'vertical_pull',    'low_risk_load',  'vertical_pull',    FALSE, TRUE, TRUE,  NULL),
      -- posterior chain
      ('ex_ghr',             'Glute Ham Raise',            'posterior_chain',  'low_risk_load',  'posterior_chain',  FALSE, TRUE, TRUE,  NULL),
      ('ex_back_ext',        'Back Extension',             'posterior_chain',  'low_risk_load',  'posterior_chain',  FALSE, TRUE, TRUE,  NULL),
      ('ex_rev_hyper',       'Reverse Hyper',              'posterior_chain',  'low_risk_load',  'posterior_chain',  FALSE, TRUE, TRUE,  'DeFranco/Westside favourite'),
      ('ex_hip_thrust',      'Barbell Hip Thrust',         'posterior_chain',  'low_risk_load',  'posterior_chain',  FALSE, TRUE, TRUE,  NULL),
      ('ex_sled_drag',       'Sled Drag',                  'posterior_chain',  'low_risk_load',  'posterior_chain',  FALSE, TRUE, TRUE,  'GPP, near-zero joint cost'),
      -- single leg
      ('ex_split_squat',     'Bulgarian Split Squat',      'single_leg',       'low_risk_load',  'single_leg',       FALSE, TRUE, TRUE,  NULL),
      ('ex_lunge_walking',   'Walking Lunge',              'single_leg',       'low_risk_load',  'single_leg',       FALSE, TRUE, TRUE,  NULL),
      ('ex_step_up',         'Step-Up',                    'single_leg',       'low_risk_load',  'single_leg',       FALSE, TRUE, TRUE,  NULL),
      ('ex_leg_press',       'Leg Press',                  'single_leg',       'low_risk_load',  'single_leg',       FALSE, TRUE, TRUE,  NULL),
      -- bicep flexion
      ('ex_curl_db',         'DB Curl',                    'elbow_flexion',    'low_risk_load',  'bicep_flexion',    FALSE, TRUE, TRUE,  NULL),
      ('ex_curl_preacher',   'Preacher Curl',              'elbow_flexion',    'low_risk_load',  'bicep_flexion',    FALSE, TRUE, TRUE,  NULL),
      ('ex_curl_hammer',     'Hammer Curl',                'elbow_flexion',    'low_risk_load',  'bicep_flexion',    FALSE, TRUE, TRUE,  NULL),
      ('ex_curl_incline',    'Incline DB Curl',            'elbow_flexion',    'low_risk_load',  'bicep_flexion',    FALSE, TRUE, TRUE,  NULL),
      ('ex_curl_cable',      'Cable Curl',                 'elbow_flexion',    'low_risk_load',  'bicep_flexion',    FALSE, TRUE, TRUE,  NULL),
      -- tricep extension
      ('ex_tri_pushdown',    'Cable Pushdown',             'elbow_extension',  'low_risk_load',  'tricep_extension', FALSE, TRUE, TRUE,  NULL),
      ('ex_tri_skull',       'Skull Crusher',              'elbow_extension',  'low_risk_load',  'tricep_extension', FALSE, TRUE, TRUE,  NULL),
      ('ex_tri_overhead',    'Overhead Cable Extension',   'elbow_extension',  'low_risk_load',  'tricep_extension', FALSE, TRUE, TRUE,  NULL),
      ('ex_tri_dip',         'Dip',                        'elbow_extension',  'low_risk_load',  'tricep_extension', FALSE, TRUE, TRUE,  NULL),
      ('ex_tri_jm',          'JM Press',                   'elbow_extension',  'low_risk_load',  'tricep_extension', FALSE, TRUE, TRUE,  NULL),
      -- rear delt / scap
      ('ex_facepull',        'Face Pull',                  'scap_retraction',  'low_risk_load',  'rear_delt',        FALSE, TRUE, TRUE,  NULL),
      ('ex_rear_delt_fly',   'Rear Delt Fly',              'scap_retraction',  'low_risk_load',  'rear_delt',        FALSE, TRUE, TRUE,  NULL),
      ('ex_band_pullapart',  'Band Pull-Apart',            'scap_retraction',  'low_risk_load',  'rear_delt',        FALSE, TRUE, TRUE,  NULL),
      ('ex_shrug',           'DB Shrug',                   'scap_elevation',   'low_risk_load',  'rear_delt',        FALSE, TRUE, TRUE,  NULL),
      -- lateral delt
      ('ex_lat_raise_db',    'DB Lateral Raise',           'shoulder_abduction','low_risk_load', 'lateral_delt',     FALSE, TRUE, TRUE,  NULL),
      ('ex_lat_raise_cable', 'Cable Lateral Raise',        'shoulder_abduction','low_risk_load', 'lateral_delt',     FALSE, TRUE, TRUE,  NULL),
      -- grip
      ('ex_farmer_carry',    'Farmer Carry',               'grip',             'low_risk_load',  'grip',             FALSE, TRUE, TRUE,  NULL),
      ('ex_deadhang',        'Dead Hang',                  'grip',             'low_risk_load',  'grip',             FALSE, TRUE, TRUE,  NULL),
      ('ex_plate_pinch',     'Plate Pinch',                'grip',             'low_risk_load',  'grip',             FALSE, TRUE, TRUE,  NULL),
      -- core
      ('ex_ab_wheel',        'Ab Wheel Rollout',           'core',             'low_risk_load',  'core',             FALSE, TRUE, TRUE,  NULL),
      ('ex_hanging_leg',     'Hanging Leg Raise',          'core',             'low_risk_load',  'core',             FALSE, TRUE, TRUE,  NULL),
      ('ex_pallof',          'Pallof Press',               'core',             'low_risk_load',  'core',             FALSE, TRUE, TRUE,  NULL),
      ('ex_suitcase_carry',  'Suitcase Carry',             'core',             'low_risk_load',  'core',             FALSE, TRUE, TRUE,  NULL),

      -- ---------- "I'm bored" pool only (never in normal rotation) ----------
      ('ex_zercher',         'Zercher Squat',              'squat',            'high_risk_load', 'squat',            FALSE, FALSE, TRUE, 'Freestyle only'),
      ('ex_jefferson',       'Jefferson Curl',             'hinge',            'low_risk_load',  'hinge',            FALSE, FALSE, TRUE, 'Freestyle only, light'),
      ('ex_kb_swing',        'Kettlebell Swing',           'hinge',            'low_risk_load',  'posterior_chain',  FALSE, FALSE, TRUE, 'Freestyle only'),
      ('ex_turkish_getup',   'Turkish Get-Up',             'full_body',        'low_risk_load',  'core',             FALSE, FALSE, TRUE, 'Freestyle only'),
      ('ex_sandbag_carry',   'Sandbag Carry',              'grip',             'low_risk_load',  'grip',             FALSE, FALSE, TRUE, 'Freestyle only'),
      ('ex_battle_rope',     'Battle Ropes',               'conditioning',     'low_risk_load',  'conditioning',     FALSE, FALSE, TRUE, 'Freestyle only'),
      ('ex_prowler_push',    'Prowler Push',               'conditioning',     'low_risk_load',  'conditioning',     FALSE, FALSE, TRUE, 'Freestyle only'),
      ('ex_med_ball_slam',   'Medicine Ball Slam',         'conditioning',     'low_risk_load',  'conditioning',     FALSE, FALSE, TRUE, 'Freestyle only'),
      ('ex_nordic_curl',     'Nordic Hamstring Curl',      'posterior_chain',  'low_risk_load',  'posterior_chain',  FALSE, FALSE, TRUE, 'Freestyle only'),
      ('ex_pushup_weighted', 'Weighted Push-Up',           'horizontal_press', 'low_risk_load',  'horizontal_press', FALSE, FALSE, TRUE, 'Freestyle only')
    AS v(EXERCISE_ID, NAME, MOVEMENT_PATTERN, RISK_CLASS, FAMILY, IS_MAIN_LIFT, IN_ROTATION_POOL, IN_BORED_POOL, NOTES)
) s
ON t.EXERCISE_ID = s.EXERCISE_ID
WHEN NOT MATCHED THEN INSERT
  (EXERCISE_ID, NAME, MOVEMENT_PATTERN, RISK_CLASS, FAMILY, IS_MAIN_LIFT, IN_ROTATION_POOL, IN_BORED_POOL, NOTES)
  VALUES (s.EXERCISE_ID, s.NAME, s.MOVEMENT_PATTERN, s.RISK_CLASS, s.FAMILY, s.IS_MAIN_LIFT, s.IN_ROTATION_POOL, s.IN_BORED_POOL, s.NOTES);

-- ------------------------------------------------------------
-- PROGRAM_SLOT: DeFranco "Westside for Skinny Bastards" 4-day split
--   ME Upper / ME Lower / DE Upper / DE Lower, each + accessories
-- ------------------------------------------------------------
MERGE INTO PROGRAM_SLOT t
USING (
    SELECT * FROM VALUES
      -- ME UPPER
      ('slot_me_upper',       'ME_UPPER',      'ME_UPPER', 'me',        1, 'horizontal_press'),
      ('slot_meu_acc_1',      'ACCESSORY_1',   'ME_UPPER', 'accessory', 2, 'horizontal_pull'),
      ('slot_meu_acc_2',      'ACCESSORY_2',   'ME_UPPER', 'accessory', 3, 'vertical_pull'),
      ('slot_meu_acc_3',      'ACCESSORY_3',   'ME_UPPER', 'accessory', 4, 'tricep_extension'),
      ('slot_meu_acc_4',      'ACCESSORY_4',   'ME_UPPER', 'accessory', 5, 'rear_delt'),
      -- ME LOWER
      ('slot_me_lower',       'ME_LOWER',      'ME_LOWER', 'me',        1, 'squat'),
      ('slot_mel_acc_1',      'ACCESSORY_1',   'ME_LOWER', 'accessory', 2, 'posterior_chain'),
      ('slot_mel_acc_2',      'ACCESSORY_2',   'ME_LOWER', 'accessory', 3, 'single_leg'),
      ('slot_mel_acc_3',      'ACCESSORY_3',   'ME_LOWER', 'accessory', 4, 'core'),
      ('slot_mel_acc_4',      'ACCESSORY_4',   'ME_LOWER', 'accessory', 5, 'grip'),
      -- DE UPPER
      ('slot_de_upper',       'DE_UPPER',      'DE_UPPER', 'de',        1, 'horizontal_press'),
      ('slot_deu_acc_1',      'ACCESSORY_1',   'DE_UPPER', 'accessory', 2, 'vertical_press'),
      ('slot_deu_acc_2',      'ACCESSORY_2',   'DE_UPPER', 'accessory', 3, 'horizontal_pull'),
      ('slot_deu_acc_3',      'ACCESSORY_3',   'DE_UPPER', 'accessory', 4, 'bicep_flexion'),
      ('slot_deu_acc_4',      'ACCESSORY_4',   'DE_UPPER', 'accessory', 5, 'lateral_delt'),
      -- DE LOWER
      ('slot_de_lower',       'DE_LOWER',      'DE_LOWER', 'de',        1, 'squat'),
      ('slot_del_acc_1',      'ACCESSORY_1',   'DE_LOWER', 'accessory', 2, 'hinge'),
      ('slot_del_acc_2',      'ACCESSORY_2',   'DE_LOWER', 'accessory', 3, 'posterior_chain'),
      ('slot_del_acc_3',      'ACCESSORY_3',   'DE_LOWER', 'accessory', 4, 'single_leg'),
      ('slot_del_acc_4',      'ACCESSORY_4',   'DE_LOWER', 'accessory', 5, 'core')
    AS v(SLOT_ID, SLOT_CODE, SESSION_DAY, SLOT_KIND, SLOT_ORDER, FAMILY_HINT)
) s
ON t.SLOT_ID = s.SLOT_ID
WHEN NOT MATCHED THEN INSERT
  (SLOT_ID, SLOT_CODE, SESSION_DAY, SLOT_KIND, SLOT_ORDER, FAMILY_HINT)
  VALUES (s.SLOT_ID, s.SLOT_CODE, s.SESSION_DAY, s.SLOT_KIND, s.SLOT_ORDER, s.FAMILY_HINT);
