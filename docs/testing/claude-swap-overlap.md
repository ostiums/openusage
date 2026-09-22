# Claude Swap Overlap Verification

Issue: #1227. PR: #1226.

## Review Fixes Verified on 2026-09-13

Merged current upstream `main` (`bb055e2`) and resolved the scanner conflict by keeping both Swap
history folders and upstream's session ownership, cancellation, and nested workflow handling.

`ClaudeSwapReviewRegressionTests` adds four cases:

- A default login with an account UUID but no organization remains available beside Swap, including
  when both logins have the same account UUID. Repeated discovery keeps the IDs stable, and both
  providers retain their own credentials.
- A matching full-scope Swap session supplies Session and Weekly limits when the default login
  lacks `user:profile`.
- That session is still rejected if its profile names another organization; limited-scope fallback
  keeps the existing re-login warning without displaying the other organization's limits.
- A UUID-only default card does not claim local history when multiple identities are known.

All four new tests failed against the merged code before these fixes, then passed after them.
`swift test --filter 'Claude|ProviderAccountAssemblyTests'` passed 156 tests, with two opt-in tests
skipped and zero failures. Full `swift test` passed 1,342 tests, with three skipped and zero failures
(1,345 total, including XCTest and Swift Testing).

`CONFIG=debug ./script/build_and_run.sh build` rebuilt and signed the app successfully. The fresh
app was launched on the host, and all four discovered Claude cards completed live refreshes
successfully. `git diff --check` passed.

The Tart VM was recovered later the same day by unlocking its macOS login screen. The exact updated
app and host-compiled test bundles were copied through a read-only shared folder. Inside the VM
(macOS 15.7.7, build 24G720), all four new regression tests passed. The full suite also passed:
1,342 passed, three skipped, zero failures (1,345 total, including the CLI and Swift Testing suites).
Compilation used the host Xcode toolchain; test execution used the VM's staged XCTest runtime.

The first full VM run found a missing fixture: the provisioning-profile test sources a repository
shell script using its compiled absolute path. After copying that exact script to the expected
guest path, the full suite was rerun and passed. No production code change was needed.

### Repeated Live Check on 2026-09-13

The updated app was launched through the guest's `cua-driver` CLI from
`/Users/admin/openusage-qa/20260913/OpenUsage.app`. Its executable SHA-256 matches the host build:
`059369d3aeeb95c37cefadde69e5cf779ad3e549d591df354f148b19dae77793`.

Claude Desktop remained signed into the work account. Two `cswap run --require-session` instances
reached normal Claude Code prompts in separate personal and work session directories and remained
running during the checks. The personal instance used Claude Code 2.1.263; Code's automatic update
had installed 2.1.270 by the time the work instance started. Swap was 0.26.0.

The default was switched from work to personal and back to work. The updated app's bundled CLI
forced live refreshes through GUI Terminal after each switch. Both runs returned exactly two cards,
with identical IDs and organization-first names, no errors, and neither card marked stale:

| Identity | Card ID | Session usage in both states | Weekly usage in both states |
| --- | --- | --- | --- |
| Work | `claude` | 4% | 0% |
| Personal | `claude@32ae3dfb` | 1% | 52% |

After those refreshes, Claude Code's auth-status command confirmed the expected account and
organization for the default and both session directories. Separate profile and usage requests
using each session's own credential file also succeeded, verified both account and organization
UUIDs, and returned the corresponding limits above. These requests were read-only; no model
prompts were submitted and no real credentials were deliberately expired or revoked.

The opt-in live XCTest also passed, but its default auth store can select the global Keychain
login even with a session directory override. The per-session isolation evidence therefore comes
from the explicit profile-and-usage probes, rather than treating that account-agnostic test as
proof of both identities. The original work default was restored.

The fresh GUI app independently completed a scheduled refresh at 05:23 UTC with both Claude
cards successful. Its log retained Desktop, default/session, and read-only vault sources on the
work card, and session/vault sources on the personal card. The work card's previously expired
CLI/session sources were live again after normal Swap and Claude Code startup. The dashboard
also showed the expected work organization label and per-account session limits.

## Automated Coverage

The focused Claude suite runs the production discovery, credential selection, refresh, layout,
and history code with controlled credentials and HTTP responses. It does not require live tokens.

| Requirement | Regression coverage |
| --- | --- |
| Merge overlapping identities and preserve matching sources | `testSwapDesktopOverlapKeepsTwoNamedIdentitiesAcrossDefaultSwitches` and `testOverlapFallsBackBothDirectionsWithoutUsingOtherOrganization` |
| Stable IDs, layout order, and pins after default switching | `testSwapDesktopOverlapKeepsTwoNamedIdentitiesAcrossDefaultSwitches` |
| Desktop-to-Swap and CLI/Swap-to-Desktop fallback | `testOverlapFallsBackBothDirectionsWithoutUsingOtherOrganization`, for both identities, revoked tokens and wrong-organization profiles |
| Discard stale usage when default and session credentials change in flight | `testOverlapDiscardsStaleUsageDuringDefaultAndSessionChanges` |
| Save renewed credentials only to their supplying session file or Keychain service; reject concurrent replacement | `testOverlapRotationWritesOnlySupplyingSessionAndRejectsConcurrentReplacement` |
| Never renew or write vault credentials | The rotation test above and `testVaultUsesExplicitSlotAndNeverRotatesBackupTokens` |
| Deduplicate copied history for both identities and exclude unattributed entries | `testAdditionalSessionHistoryIsFilteredAndSharedHistoryIsDeduplicated` |
| Same email with different organizations produces distinguishable cards | `testSwapDesktopOverlapKeepsTwoNamedIdentitiesAcrossDefaultSwitches` |

Command on the build machine:

```sh
swift test --filter 'ClaudeSwap|ClaudeAccountIsolationTests|ClaudeDesktopAuthStoreTests|ProviderAccountAssemblyTests|ClaudeLogUsageScannerTests|ClaudeProviderTests'
```

On 2026-09-07, the focused host run passed 94 tests and skipped two opt-in tests, with zero failures.
The full host `swift test` run also passed: 1,328 tests total, with three skipped and zero failures.
The compiled test bundle and its XCTest runtime were transferred to the existing Tart VM
(`macos-sandbox`, arm64, macOS 15.7.7, build 24G720), where the same selection also passed
94 tests and skipped two, with zero failures. This is execution inside the VM; compilation used
the host Xcode toolchain because the VM only has older Command Line Tools.

The skipped tests are the opt-in live usage request and the local-history parity harness.
The live usage test was separately enabled inside the VM and passed against the default login.
It returned actual session and weekly limits. The local-history parity harness was not enabled.

## Live Overlap Check

**Passed after both sessions completed interactive startup.**

The updated debug app was built, copied to `/Users/admin/openusage-qa/OpenUsage.app`, and launched
through the VM's `cua-driver` 0.23.2 CLI. Its executable SHA-256 matches the host build:
`96ee030dade69c52fd2323f3f1d63a5cd7c9338e01d14fd004186cde4fd75577`.

The VM has Claude Code 2.1.263, Claude Swap 0.26.0, and Claude Desktop 1.46388.4.
Two saved Swap accounts were present. Desktop's window shows the work account signed in.
Two separate `cswap run` processes were launched through GUI Terminal, with separate personal
and work session directories. Their auth status identifies the correct account and organization.

The default was switched from work to personal, then back to work. OpenUsage's bundled CLI
performed forced live refreshes in both states. Both returned exactly two cards, zero errors,
unchanged card IDs and unchanged organization-first names:

| Identity | Card ID | Weekly usage with personal default | Weekly usage with work default |
| --- | --- | --- | --- |
| Work | `claude` | 0% | 0% |
| Personal | `claude@32ae3dfb` | 52% | 52% |

The GUI app's 11:18 UTC refresh log also showed the retained overlap: the personal card had
default/session and read-only vault sources; the work card had Desktop, session, and read-only
vault sources. Both cards refreshed successfully. After the return switch and forced refresh,
separate real usage requests using each session directory passed again (one test per account).
No forced expiration or revocation of real user credentials was performed; those scenarios are
covered by controlled regression fixtures.

The live UI showed that email-first names truncated before their organization. Names were changed
to organization-first, then the app was rebuilt and restarted before repeating validation.

### Final Interactive Check

The user resolved the work session's folder-trust prompt. Both original session processes then
reached their normal Claude Code prompts and remained running throughout the repeat check.
With Desktop also running, the default was switched from work to personal and back to work again.
The bundled OpenUsage CLI was launched from GUI Terminal through cua-driver and forced a refresh
after each switch. Both runs returned exactly the same two card IDs and names, zero errors, and
the same 0% work / 52% personal weekly usage. The original work default was restored.

Separate real usage requests from both session directories passed after those refreshes. The work
refresh retained Desktop as its preferred credential, with default/session and read-only vault
fallbacks; there was no Desktop authentication failure. The GUI dashboard's accessibility state
also showed the expected organization-first labels and per-account limits.

The GUI app independently logged successful scheduled refreshes with both identities. Direct
cua-driver clicks on its Refresh button returned unverified delivery, so the forced-refresh
evidence above comes from the bundled CLI, not an assumed button click. No model prompts were
submitted as part of the authentication checks.

Earlier background keyboard input was rejected because two Terminal windows shared a process.
Foreground/desktop key attempts also failed to advance the trust prompt. Restarting the driver in
the graphical session kept its standard permission settings unchanged. The user's manual click
resolved this setup obstacle; it is no longer an outstanding test requirement.

Initial SSH-only vault reads were unavailable through Keychain; launching Swap from GUI Terminal
resolved session creation. OpenUsage also initially waited in a Desktop Safe Storage Keychain read,
then completed startup. The original work default has been restored. No host account credentials
were copied into the VM.

Unattributed SDK/Conductor history remains excluded when multiple accounts are known. Broader
history attribution is outside this PR's scope.
