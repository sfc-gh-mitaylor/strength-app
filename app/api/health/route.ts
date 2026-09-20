import { getTableCounts, getConfig, getCatalogSummary, CORE } from "@/lib/training-db"

export const dynamic = "force-dynamic"

/**
 * Health check: proves the SPCS service can reach Snowflake under owner's
 * rights and that the TRAINING_APP.CORE schema is present and seeded.
 */
export async function GET() {
  try {
    const [tables, config, catalog] = await Promise.all([
      getTableCounts(),
      getConfig(),
      getCatalogSummary(),
    ])

    const missing = tables.filter((t) => t.rows < 0).map((t) => t.table)

    return Response.json({
      ok: missing.length === 0,
      schema: CORE,
      missingTables: missing,
      tables,
      configKeys: config.length,
      catalog,
      checkedAt: new Date().toISOString(),
    })
  } catch (e) {
    console.error(new Date().toISOString(), "[api/health] failed", e)
    return Response.json(
      { ok: false, error: e instanceof Error ? e.message : "Health check failed" },
      { status: 500 },
    )
  }
}
