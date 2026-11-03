# External ABI provenance

The application addresses are the ones in the approved brief, preserved exactly in the deployment table. The Core read shape is from the official Squeekchain Core developer documentation:

https://docs.squeekchain.com/developers/core/

`state()` returns a static tuple with these ABI words:

1. uint64 settledThroughRound
2. uint64 cumulativeWork
3. uint96 cumulativeBlockUnits
4. uint64 blockHeight
5. uint96 blockProgress
6. uint32 workPerThousandBlocks
7. uint256 authorizationNonce
8. bool paused

The production reader checks length and type-width constraints and consumes only cumulativeWork. The NFT dependency is the standard `balanceOf(address) -> uint256` read. No metadata, enumeration, transfer, claim, or other upstream function is called.

The public documentation names a different current deployment address. No such address was substituted for the request's endpoints, and live compatibility of the approved addresses was not independently established. See the README's After launch section for the required read check and the already-authorized timelocked repoint path.

The test dependency is Foundry forge-std v1.9.7, sourced from https://github.com/foundry-rs/forge-std/tree/v1.9.7 and vendored under `lib/forge-std/`. Its two upstream license files accompany its source. No git submodule or downloaded compiler binary is used.
