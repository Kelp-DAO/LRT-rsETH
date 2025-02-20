## Verification Checklist for Native Restaking on L2s Before Usage

## 1. OFT Contract
### From `https://github.com/Kelp-DAO/kelp-dao-lz` Repo
- [ ] Check that an OFT contract is deployed on the L2. (OFT is from LayerZero (LZ) v2.) [LayerZero V2](https://docs.layerzero.network/v2)
- [ ] Check that all the configuration in `layerzero.config.js` is properly set up. Use `npx hardhat lz:oapp:wire --oapp-config layerzero.config.js` to wire it up if not.
- [ ] Check that ownership of the OFT contract is set to the L2 multisig, `0x7AAd74b7f0d60D5867B59dbD377a71783425af47` or to `0x3924a9a1706285f5e92486dc19945e43fb2f98cf`.
- [ ] Check that all contracts are verified on the L2 explorer.
- [ ] Check if DVN is set up on the OFT contract.

## 2. Deployed Native Restaking on L2
### From `https://github.com/Kelp-DAO/KelpDAO-contracts/` Repo
- [ ] Check that `RSETHPoolV3` has been deployed.
- [ ] Check if `RSETHPoolV3` is an upgradeable contract.
- [ ] Check that `RSETHPoolV3`'s deposit function require native toke swap. If not set `isEthDepositEnabled` to `false`.
- [ ] Check that `RsETHTokenWrapper` is deployed.
- [ ] Check if `RsETHTokenWrapper` is an upgradeable contract.
- [ ] Check MINTER_ROLE for `RSETHPoolV3` is properly set up on `RsETHTokenWrapper` contract.
- [ ] Check if LZ_OFT address is a supported asset on `RsEthTokenWrapper` contract.
- [ ] Check implementations of both contracts have the right bytecode.
- [ ] Check the right proxy admin is set for both contracts.
- [ ] Check that the owner of the proxy admin is L2 multisig or `0x7AAd74b7f0d60D5867B59dbD377a71783425af47`
- [ ] Check that BRIDGER_ROLE is set for `RSETHPoolV3`. It should be `0x3924a9a1706285f5e92486dc19945e43fb2f98cf`.
- [ ] Check that DEFAULT_ADMIN_ROLE is set to the L2 Kelp Multisig, `0x7AAd74b7f0d60D5867B59dbD377a71783425af47` or to `0x3924a9a1706285f5e92486dc19945e43fb2f98cf`.
- [] Check that the contracts are verified.

## 3. Rate Receiver
### From `https://github.com/Kelp-DAO/KelpDAO-contracts/` Repo
- [ ] Check that there is an `RSETHRateReceiver` for this L2. (We use LayerZero (LZ) v1 for it.)
- [ ] Check that ownership of the OFT contract is set to the L2 multisig, `0x7AAd74b7f0d60D5867B59dbD377a71783425af47` or to `0x3924a9a1706285f5e92486dc19945e43fb2f98cf`.
- [ ] Check that `RSETHRateReceiver` is properly set up with endpoint chain ID and endpoint address. See [LayerZero Mainnet Addresses](https://docs.layerzero.network/v1/developers/technical-reference/mainnet/mainnet-addresses).
- [ ] Check that `RSETHMultiChainRateProvider` on the ETH mainnet is wired up to send rates to the `RSETHRateReceiver` address on L2.
- [ ] Check that the contract is verified.

## Deployed Proxy Admin on L2
### From `https://github.com/Kelp-DAO/KelpDAO-contracts/` Repo
- [ ] Check that there is a `ProxyAdmin` contract deployed on the L2.
- [ ] Check that the `ProxyAdmin` contract is verified.
- [ ] Check that the `ProxyAdmin` contract is owned by the L2 multisig, `0x7AAd74b7f0d60D5867B59dbD377a71783425af47` or to `0x3924a9a1706285f5e92486dc19945e43fb2f98cf`.