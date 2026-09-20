import { getIdentity } from "@/lib/training-db"

export const dynamic = "force-dynamic"

/**
 * Identity check: the milestone-1 gate.
 *
 * Proves the SPCS ingress proxy authenticated a real Snowflake user and
 * injected `sf-context-current-user-token`, so the app can scope data per user
 * rather than trusting everyone who can reach the public endpoint.
 *
 * In SPCS `authPath` must be "caller". "owner" means executeAsCaller is not in
 * effect and every visitor would share one identity.
 */
export async function GET() {
  try {
    const identity = await getIdentity()

    return Response.json({
      ...identity,
      authPath: identity.callersRights ? "caller" : "owner",
      checkedAt: new Date().toISOString(),
    })
  } catch (e) {
    console.error(new Date().toISOString(), "[api/whoami] failed", e)
    return Response.json(
      { error: e instanceof Error ? e.message : "Identity check failed" },
      { status: 500 },
    )
  }
}
