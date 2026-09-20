import { Suspense } from "react"
import {
  getTableCounts,
  getConfig,
  getCatalogSummary,
  getIdentity,
  CORE,
} from "@/lib/training-db"

// Snowflake is not reachable during the docker build.
export const dynamic = "force-dynamic"

function Stat({ label, value, hint }: { label: string; value: string | number; hint?: string }) {
  return (
    <div className="rounded-lg border border-border bg-card px-4 py-3">
      <div className="text-[11px] uppercase tracking-wider text-muted-foreground">{label}</div>
      <div className="mt-1 text-2xl font-semibold tabular-nums">{value}</div>
      {hint && <div className="mt-0.5 text-xs text-muted-foreground">{hint}</div>}
    </div>
  )
}

function Panel({
  title,
  subtitle,
  children,
}: {
  title: string
  subtitle?: string
  children: React.ReactNode
}) {
  return (
    <section className="rounded-lg border border-border bg-card">
      <div className="border-b border-border px-4 py-3">
        <h2 className="text-sm font-semibold tracking-tight">{title}</h2>
        {subtitle && <p className="mt-0.5 text-xs text-muted-foreground">{subtitle}</p>}
      </div>
      <div className="p-4">{children}</div>
    </section>
  )
}

function ErrorPanel({ title, error }: { title: string; error: unknown }) {
  const message = error instanceof Error ? error.message : String(error)
  return (
    <Panel title={title} subtitle="Failed">
      <pre className="whitespace-pre-wrap break-words text-xs text-red-600 dark:text-red-400">
        {message}
      </pre>
    </Panel>
  )
}

/** Identity: the milestone-1 gate. Shows who Snowflake thinks is asking. */
async function IdentityPanel() {
  try {
    const id = await getIdentity()
    return (
      <Panel
        title="Authenticated caller"
        subtitle={
          id.callersRights
            ? "Caller's rights — queries run as the logged-in Snowflake user"
            : id.inSpcs
              ? "Owner's rights — running in SPCS but NO caller token was injected. Check executeAsCaller in app.yml."
              : "Owner's rights — local dev, no SPCS service token (expected off-platform)"
        }
      >
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <Stat label="User" value={id.user} />
          <Stat label="Role" value={id.role} />
          <Stat
            label="Auth path"
            value={id.callersRights ? "caller" : "owner"}
            hint={id.inSpcs ? "running in SPCS" : "local dev"}
          />
        </div>
      </Panel>
    )
  } catch (e) {
    console.error(new Date().toISOString(), "[page] identity panel failed", e)
    return <ErrorPanel title="Authenticated caller" error={e} />
  }
}

/** Schema health: every core table and its row count. */
async function SchemaPanel() {
  try {
    const [tables, catalog] = await Promise.all([getTableCounts(), getCatalogSummary()])
    const missing = tables.filter((t) => t.rows < 0)

    return (
      <>
        <Panel title="Exercise catalog" subtitle="Seeded reference data">
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <Stat label="Exercises" value={catalog.totalExercises} />
            <Stat label="Rotation pool" value={catalog.rotationPool} hint="eligible for slots" />
            <Stat label="Freestyle only" value={catalog.boredOnlyPool} hint="“I’m bored” pool" />
            <Stat label="Families" value={catalog.families} hint="rotation pools" />
            <Stat label="Main lifts" value={catalog.mainLifts} />
            <Stat label="High-risk load" value={catalog.highRiskLifts} hint="capped at I ≤ 0.85" />
            <Stat label="Program slots" value={catalog.slots} hint="4-day conjugate split" />
          </div>
        </Panel>

        <Panel
          title={`Schema — ${CORE}`}
          subtitle={
            missing.length > 0
              ? `${missing.length} expected table(s) missing`
              : `${tables.length} tables present`
          }
        >
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-xs uppercase tracking-wider text-muted-foreground">
                <th className="pb-2 font-medium">Table</th>
                <th className="pb-2 text-right font-medium">Rows</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {tables.map((t) => (
                <tr key={t.table}>
                  <td className="py-1.5 font-mono text-xs">{t.table}</td>
                  <td className="py-1.5 text-right tabular-nums">
                    {t.rows < 0 ? (
                      <span className="text-red-600 dark:text-red-400">missing</span>
                    ) : (
                      t.rows.toLocaleString()
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Panel>
      </>
    )
  } catch (e) {
    console.error(new Date().toISOString(), "[page] schema panel failed", e)
    return <ErrorPanel title={`Schema — ${CORE}`} error={e} />
  }
}

/** Config: every tunable, read live so nothing is hardcoded in the UI. */
async function ConfigPanel() {
  try {
    const config = await getConfig()
    return (
      <Panel title="Configuration" subtitle={`${config.length} tunables, read live from CONFIG`}>
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-xs uppercase tracking-wider text-muted-foreground">
              <th className="pb-2 font-medium">Key</th>
              <th className="pb-2 text-right font-medium">Value</th>
              <th className="hidden pb-2 pl-4 font-medium md:table-cell">Meaning</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {config.map((c) => (
              <tr key={c.key}>
                <td className="py-1.5 font-mono text-xs">{c.key}</td>
                <td className="py-1.5 text-right font-mono text-xs tabular-nums">{c.value}</td>
                <td className="hidden py-1.5 pl-4 text-xs text-muted-foreground md:table-cell">
                  {c.description ?? "—"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Panel>
    )
  } catch (e) {
    console.error(new Date().toISOString(), "[page] config panel failed", e)
    return <ErrorPanel title="Configuration" error={e} />
  }
}

function PanelSkeleton({ label }: { label: string }) {
  return (
    <Panel title={label} subtitle="Loading…">
      <div className="h-16 animate-pulse rounded bg-muted" />
    </Panel>
  )
}

export default function Home() {
  return (
    <main className="mx-auto w-full max-w-5xl px-4 py-10">
      <header className="mb-8">
        <h1 className="text-xl font-semibold tracking-tight">Baseline status</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Milestone 1 — schema and service skeleton. Confirms Snowflake authentication, caller
          identity, and seeded reference data before any training features are built.
        </p>
      </header>

      <div className="flex flex-col gap-6">
        <Suspense fallback={<PanelSkeleton label="Authenticated caller" />}>
          <IdentityPanel />
        </Suspense>
        <Suspense fallback={<PanelSkeleton label="Schema" />}>
          <SchemaPanel />
        </Suspense>
        <Suspense fallback={<PanelSkeleton label="Configuration" />}>
          <ConfigPanel />
        </Suspense>
      </div>
    </main>
  )
}
