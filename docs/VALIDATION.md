# Validation

The project builds with pinned Solidity 0.8.26 and the checked-in Foundry settings. No network, environment variables, broadcast keys, or uncommitted dependencies are required by tests. forge-std v1.9.7 is vendored as ordinary files, with its upstream MIT and Apache licenses.

Required commands:

```sh
forge build
forge test
forge fmt --check
python3 tools/export_abi.py --check
```

Additional checks used during implementation are `forge build --sizes`, focused regression runs, and the deployed-bytecode opcode scan in `Deployment.t.sol`. The configured fuzz seed is the assignment's exact seed; 256 inputs are used per fuzz test. Stateful testing uses 128 sequences at depth 64, totaling 8,192 handler calls in a complete campaign.

| Test source | Coverage |
| --- | --- |
| `SeedLedger.t.sol` | Initial baseline, daily boundary/replay, zero work, batch claims, new-village eligibility, counter decreases and same-Core repoint recovery, uint64 maximum work, namespace isolation, live NFT XP, historical output integral, missing/malformed/reentrant readers, timelock cancellation/replacement/renunciation |
| `Rules.t.sol` | Numeric quote checks, all maximum levels/units, invalid inputs, exhaustive 10,000-tile permutation, camp separation, distance, capacity monotonicity fuzz, 30% NFT reduction bound fuzz |
| `Villages.t.sol` | Founding/name rules, map allocation, two build slots, plot reservations, cancel refunds, queue replay, research prerequisites/counters, production and fractional-settlement fuzz, storage, Market burn/cap rollback, treasury duration/cooldown and no-charge refusal under a longer shield, NFT order snapshots, reader failure rollback, callback access control, ETH rejection |
| `Army.t.sol` | Training reservations/upkeep, unlock/room limits, return replay, troop/champion locking, shield changes in flight, raid limits, current NFT stats, point caps, recoverable settlement failure, loot/Vault conservation, low-TH treatment, scouts, camp regrowth/caps, Catapult damage/repair, maximum canonical army |
| `CombatMath.t.sol` | Independent integer casualty reference fuzz to one million troops per side, mixed-army whole-army rounding fuzz and the lone-stack regression, zero-attack handling, callback reentrancy, NFT transfer during travel, empty-camp deadline regression, 04:00 UTC camp day |
| `Clans.t.sol` | Found/invite/join/leave prerequisites, uninvited join refused and cannot cancel a raid, founder-only and revocable invitations, capacity, founder controls, no friendly raids, troop-only support/recall, former-clan return, join during incoming attack, support losses/origin room, season/week score formula and namespace isolation |
| `Deployment.t.sol` | Constructors with absent dependency code, explicit ownership, zero-argument rejection, all runtime sizes and reachable forbidden-opcode scan |
| `Invariants.t.sol` | Stateful public-API actions with checkpoint/time changes, claims, builds/cancellations, research, Market, treasury, training, camps, returns, and settlement |

The stateful properties checked after randomized actions are:

1. Canonical SEED balances sum to minted minus net burned; non-loot actions cannot change another village's current resources or SEED.
2. Every resource stays at or below its village's storage limit.
3. Committed room equals the sum of home troops, training queue, and all live movements/support, and never exceeds capacity.
4. Each wallet retains exactly its own village and distinct tile.
5. Checkpoint days strictly increase, and the applications accept no normal ETH custody.

Ordinary integration tests and the invariant setup use player actions. Late-game fixtures explicitly impersonate the immutable Army callback only to supply resources for expensive endgame setup; the fixture is test-only, and separate tests reject all unprivileged calls to that callback. `ArmyWorld` is an isolated test namespace with generous room/resources for independent arithmetic fuzzing; it is never a launch application and cannot affect the canonical game.

These checks are implementation evidence, not a formal proof or an independent security audit. All test/helpers remain in `test/` and are delivered; no submitted source depends on `test/scratch/`.

## Recorded final result

The final local run passed **87 reported checks, zero failed, zero skipped**, across nine suites. Foundry reports the five stateful properties as one invariant group: all five passed for 128 runs and 8,192 calls. The six parameterized fuzz tests each passed 256 inputs with the pinned seed. `forge build`, `forge test`, `forge fmt --check`, and `python3 tools/export_abi.py --check` all exited successfully.

All five application ABIs were regenerated from the final build. Runtime/initcode sizes from those artifacts are:

| Contract | Runtime bytes | Initcode bytes (before arguments) |
| --- | ---: | ---: |
| GameRules | 5,717 | 5,743 |
| SeedLedger | 6,078 | 6,372 |
| Clans | 5,660 | 5,706 |
| Army | 23,644 | 24,132 |
| Villages | 20,583 | 21,231 |

Every application is under EIP-170's 24,576-byte runtime limit and EIP-3860's 49,152-byte initcode limit, including its static constructor arguments. No application bytecode contains an external library link reference. The deployment tests also scan the instantiated runtimes for the protected floor's forbidden reachable opcodes.
