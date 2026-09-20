/**
 * Domain-level Snowflake access for the strength app.
 *
 * Milestone 1 scope: read-only introspection used by the status page to prove
 * the SPCS -> Snowflake path works. No writes yet.
 *
 * IMPORTANT for later milestones: `querySnowflake` in lib/snowflake.ts takes a
 * raw SQL string with no parameter binding. Do NOT interpolate user input into
 * SQL. Before set-logging lands (milestone 2) add a bind-capable helper.
 */

import { headers } from "next/headers"
import { querySnowflake, getServiceToken } from "@/lib/snowflake"

export const DB = "TRAINING_APP"
export const CORE = `${DB}.CORE`

/** Tables we expect to exist, in a sensible display order. */
export const CORE_TABLES = [
  "CONFIG",
  "EXERCISE",
  "PROGRAM_SLOT",
  "SLOT_ASSIGNMENT",
  "TRAINING_MAX",
  "SESSION",
  "SET_LOG",
  "WEEKLY_EXERCISE_STIMULUS",
  "ROTATION_EVENT",
  "FAMILY_COOLDOWN",
] as const

export interface TableCount {
  table: string
  rows: number
}

export interface ConfigEntry {
  key: string
  value: string
  description: string | null
}

/**
 * Row counts for every core table.
 *
 * Uses INFORMATION_SCHEMA.TABLES rather than a UNION of COUNT(*) queries: one
 * round trip, and it also surfaces tables that exist but were not expected.
 * ROW_COUNT there is maintained by Snowflake metadata and is exact for
 * standard tables.
 */
export async function getTableCounts(): Promise<TableCount[]> {
  const rows = await querySnowflake(`
    SELECT TABLE_NAME, ROW_COUNT
    FROM ${DB}.INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'CORE' AND TABLE_TYPE = 'BASE TABLE'
  `)

  const found = new Map<string, number>(
    rows.map((r) => [String(r.TABLE_NAME), Number(r.ROW_COUNT ?? 0)]),
  )

  const ordered: TableCount[] = CORE_TABLES.map((t) => ({
    table: t,
    rows: found.get(t) ?? -1, // -1 => expected table is missing
  }))

  // Surface anything present in the schema that we did not expect.
  for (const [name, count] of found) {
    if (!CORE_TABLES.includes(name as (typeof CORE_TABLES)[number])) {
      ordered.push({ table: name, rows: count })
    }
  }

  return ordered
}

/** All tunables from CONFIG. */
export async function getConfig(): Promise<ConfigEntry[]> {
  const rows = await querySnowflake(`
    SELECT KEY, VALUE, DESCRIPTION
    FROM ${CORE}.CONFIG
    ORDER BY KEY
  `)
  return rows.map((r) => ({
    key: String(r.KEY),
    value: String(r.VALUE),
    description: r.DESCRIPTION == null ? null : String(r.DESCRIPTION),
  }))
}

export interface CatalogSummary {
  totalExercises: number
  rotationPool: number
  boredOnlyPool: number
  mainLifts: number
  highRiskLifts: number
  families: number
  slots: number
}

/** Headline numbers for the seeded exercise catalog and program slots. */
export async function getCatalogSummary(): Promise<CatalogSummary> {
  const rows = await querySnowflake(`
    SELECT
      (SELECT COUNT(*) FROM ${CORE}.EXERCISE)                                      AS TOTAL_EXERCISES,
      (SELECT COUNT(*) FROM ${CORE}.EXERCISE WHERE IN_ROTATION_POOL)               AS ROTATION_POOL,
      (SELECT COUNT(*) FROM ${CORE}.EXERCISE WHERE NOT IN_ROTATION_POOL
                                               AND IN_BORED_POOL)                  AS BORED_ONLY_POOL,
      (SELECT COUNT(*) FROM ${CORE}.EXERCISE WHERE IS_MAIN_LIFT)                   AS MAIN_LIFTS,
      (SELECT COUNT(*) FROM ${CORE}.EXERCISE WHERE RISK_CLASS = 'high_risk_load')  AS HIGH_RISK_LIFTS,
      (SELECT COUNT(DISTINCT FAMILY) FROM ${CORE}.EXERCISE)                        AS FAMILIES,
      (SELECT COUNT(*) FROM ${CORE}.PROGRAM_SLOT)                                  AS SLOTS
  `)
  const r = rows[0] ?? {}
  return {
    totalExercises: Number(r.TOTAL_EXERCISES ?? 0),
    rotationPool: Number(r.ROTATION_POOL ?? 0),
    boredOnlyPool: Number(r.BORED_ONLY_POOL ?? 0),
    mainLifts: Number(r.MAIN_LIFTS ?? 0),
    highRiskLifts: Number(r.HIGH_RISK_LIFTS ?? 0),
    families: Number(r.FAMILIES ?? 0),
    slots: Number(r.SLOTS ?? 0),
  }
}

export interface Identity {
  /** Identity Snowflake attributes the query to. Under caller's rights this is the logged-in user. */
  user: string
  role: string
  /** True only when a real SPCS caller token was used — i.e. genuine end-user identity. */
  callersRights: boolean
  /** True when running inside SPCS (service token file present). */
  inSpcs: boolean
  /** True when the ingress proxy injected sf-context-current-user-token. */
  callerTokenPresent: boolean
}

/**
 * Who is Snowflake running our queries as?
 *
 * Caller's rights is only claimed when it is genuinely in effect: inside SPCS
 * *and* with a caller token injected by the ingress proxy. Outside SPCS,
 * `querySnowflake` silently ignores `{ callersRights: true }` and falls back to
 * local dev credentials — so trusting a successful call would report a caller's
 * rights path that does not exist, making the auth gate unfalsifiable.
 */
export async function getIdentity(): Promise<Identity> {
  const sql = `SELECT CURRENT_USER() AS USER_NAME, CURRENT_ROLE() AS ROLE_NAME`

  const inSpcs = Boolean(getServiceToken())
  const callerTokenPresent = inSpcs
    ? Boolean((await headers()).get("sf-context-current-user-token"))
    : false
  const useCallersRights = inSpcs && callerTokenPresent

  const rows = await querySnowflake(sql, useCallersRights ? { callersRights: true } : {})
  const r = rows[0] ?? {}

  return {
    user: String(r.USER_NAME ?? "unknown"),
    role: String(r.ROLE_NAME ?? "unknown"),
    callersRights: useCallersRights,
    inSpcs,
    callerTokenPresent,
  }
}
