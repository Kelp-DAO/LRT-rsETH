# Deployer Kit

The deployer kit script is a tool to streamline the deployment of contracts between scripts and unit tests. Sharing a single script during testing and production deployment reduces the risk of errors and allows to test the deployment process in advance.

## Requirements

The script utilizes Node.js to run. We recommend the node version defined in the `.nvmrc` file.

## Installation

```bash
forge install 0xPolygon/deployer-kit
```

## Usage Example

The following command will create a deployer contract for the `MyExample` contract from the `src/Example.sol` file in the `test/deployers/MyExampleDeployer.s.sol` file.

```bash
node lib/deployer-kit src/Example.sol -o test/deployers -n MyExample
```

## Flags

| --flag    | -flag | Description                                               |
| --------- | ----- | --------------------------------------------------------- |
| --output  | -o    | Output directory (default: script/deployers)              |
| --name    | -n    | Name of the contract (default: name of the contract file) |
| Options   |       |                                                           |
| --help    | -h    | Print help                                                |
| --version | -v    | Print the version number                                  |

## License

​
Licensed under either of
​

- Apache License, Version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
  ​

at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.

---

© 2023 PT Services DMCC
