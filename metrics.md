
[<img width="200" alt="get in touch with Consensys Diligence" src="https://user-images.githubusercontent.com/2865694/56826101-91dcf380-685b-11e9-937c-af49c2510aa0.png">](https://diligence.consensys.net)<br/>
<sup>
[[  🌐  ](https://diligence.consensys.net)  [  📩  ](mailto:diligence@consensys.net)  [  🔥  ](https://consensys.github.io/diligence/)]
</sup><br/><br/>



# Solidity Metrics for 'CLI'

## Table of contents

- [Scope](#t-scope)
    - [Source Units in Scope](#t-source-Units-in-Scope)
    - [Out of Scope](#t-out-of-scope)
        - [Excluded Source Units](#t-out-of-scope-excluded-source-units)
        - [Duplicate Source Units](#t-out-of-scope-duplicate-source-units)
        - [Doppelganger Contracts](#t-out-of-scope-doppelganger-contracts)
- [Report Overview](#t-report)
    - [Risk Summary](#t-risk)
    - [Source Lines](#t-source-lines)
    - [Inline Documentation](#t-inline-documentation)
    - [Components](#t-components)
    - [Exposed Functions](#t-exposed-functions)
    - [StateVariables](#t-statevariables)
    - [Capabilities](#t-capabilities)
    - [Dependencies](#t-package-imports)
    - [Totals](#t-totals)

## <span id=t-scope>Scope</span>

This section lists files that are in scope for the metrics report. 

- **Project:** `'CLI'`
- **Included Files:** 
    - ``
- **Excluded Paths:** 
    - ``
- **File Limit:** `undefined`
    - **Exclude File list Limit:** `undefined`

- **Workspace Repository:** `unknown` (`undefined`@`undefined`)

### <span id=t-source-Units-in-Scope>Source Units in Scope</span>

Source Units Analyzed: **`17`**<br>
Source Units in Scope: **`17`** (**100%**)

| Type | File   | Logic Contracts | Interfaces | Lines | nLines | nSLOC | Comment Lines | Complex. Score | Capabilities |
| ---- | ------ | --------------- | ---------- | ----- | ------ | ----- | ------------- | -------------- | ------------ | 
| 📝 | contracts/LRTConfig.sol | 1 | **** | 180 | 157 | 98 | 36 | 78 | **** |
| 📝 | contracts/LRTDepositPool.sol | 1 | **** | 233 | 201 | 109 | 60 | 112 | **<abbr title='Initiates ETH Value Transfer'>📤</abbr><abbr title='Unchecked Blocks'>Σ</abbr>** |
| 📝 | contracts/LRTOracle.sol | 1 | **** | 100 | 93 | 53 | 21 | 43 | **<abbr title='Unchecked Blocks'>Σ</abbr>** |
| 📝 | contracts/NodeDelegator.sol | 1 | **** | 135 | 109 | 65 | 24 | 105 | **<abbr title='Initiates ETH Value Transfer'>📤</abbr><abbr title='Unchecked Blocks'>Σ</abbr>** |
| 📝 | contracts/RSETH.sol | 1 | **** | 66 | 66 | 35 | 21 | 43 | **** |
| 🔍 | contracts/interfaces/IEigenStrategyManager.sol | **** | 1 | 29 | 22 | 4 | 20 | 5 | **** |
| 🔍 | contracts/interfaces/ILRTConfig.sol | **** | 1 | 35 | 22 | 14 | 4 | 15 | **** |
| 🔍 | contracts/interfaces/ILRTDepositPool.sol | **** | 1 | 39 | 19 | 13 | 3 | 19 | **** |
| 🔍 | contracts/interfaces/ILRTOracle.sol | **** | 1 | 12 | 9 | 4 | 3 | 7 | **** |
| 🔍 | contracts/interfaces/INodeDelegator.sol | **** | 1 | 21 | 14 | 6 | 4 | 9 | **** |
| 🔍 | contracts/interfaces/IPriceFetcher.sol | **** | 1 | 10 | 8 | 4 | 2 | 5 | **** |
| 🔍 | contracts/interfaces/IRSETH.sol | **** | 1 | 10 | 7 | 4 | 1 | 7 | **** |
| 🔍 | contracts/interfaces/IStrategy.sol | **** | 1 | 92 | 22 | 4 | 65 | 23 | **** |
| 📝🔍 | contracts/oracles/ChainlinkPriceOracle.sol | 1 | 1 | 65 | 55 | 31 | 14 | 35 | **** |
| 🎨 | contracts/utils/LRTConfigRoleChecker.sol | 1 | **** | 59 | 59 | 39 | 9 | 28 | **** |
| 📚 | contracts/utils/LRTConstants.sol | 1 | **** | 23 | 23 | 13 | 7 | 29 | **<abbr title='Uses Hash-Functions'>🧮</abbr>** |
| 📚 | contracts/utils/UtilLib.sol | 1 | **** | 14 | 14 | 7 | 5 | 4 | **** |
| 📝📚🔍🎨 | **Totals** | **9** | **9** | **1123**  | **900** | **503** | **299** | **567** | **<abbr title='Initiates ETH Value Transfer'>📤</abbr><abbr title='Uses Hash-Functions'>🧮</abbr><abbr title='Unchecked Blocks'>Σ</abbr>** |

<sub>
Legend: <a onclick="toggleVisibility('table-legend', this)">[➕]</a>
<div id="table-legend" style="display:none">

<ul>
<li> <b>Lines</b>: total lines of the source unit </li>
<li> <b>nLines</b>: normalized lines of the source unit (e.g. normalizes functions spanning multiple lines) </li>
<li> <b>nSLOC</b>: normalized source lines of code (only source-code lines; no comments, no blank lines) </li>
<li> <b>Comment Lines</b>: lines containing single or block comments </li>
<li> <b>Complexity Score</b>: a custom complexity score derived from code statements that are known to introduce code complexity (branches, loops, calls, external interfaces, ...) </li>
</ul>

</div>
</sub>


#### <span id=t-out-of-scope>Out of Scope</span>

##### <span id=t-out-of-scope-excluded-source-units>Excluded Source Units</span>

Source Units Excluded: **`0`**

<a onclick="toggleVisibility('excluded-files', this)">[➕]</a>
<div id="excluded-files" style="display:none">
| File   |
| ------ |
| None |

</div>


##### <span id=t-out-of-scope-duplicate-source-units>Duplicate Source Units</span>

Duplicate Source Units Excluded: **`0`** 

<a onclick="toggleVisibility('duplicate-files', this)">[➕]</a>
<div id="duplicate-files" style="display:none">
| File   |
| ------ |
| None |

</div>

##### <span id=t-out-of-scope-doppelganger-contracts>Doppelganger Contracts</span>

Doppelganger Contracts: **`0`** 

<a onclick="toggleVisibility('doppelganger-contracts', this)">[➕]</a>
<div id="doppelganger-contracts" style="display:none">
| File   | Contract | Doppelganger | 
| ------ | -------- | ------------ |


</div>


## <span id=t-report>Report</span>

### Overview

The analysis finished with **`0`** errors and **`0`** duplicate files.





#### <span id=t-risk>Risk</span>

<div class="wrapper" style="max-width: 512px; margin: auto">
			<canvas id="chart-risk-summary"></canvas>
</div>

#### <span id=t-source-lines>Source Lines (sloc vs. nsloc)</span>

<div class="wrapper" style="max-width: 512px; margin: auto">
    <canvas id="chart-nsloc-total"></canvas>
</div>

#### <span id=t-inline-documentation>Inline Documentation</span>

- **Comment-to-Source Ratio:** On average there are`2.14` code lines per comment (lower=better).
- **ToDo's:** `0` 

#### <span id=t-components>Components</span>

| 📝Contracts   | 📚Libraries | 🔍Interfaces | 🎨Abstract |
| ------------- | ----------- | ------------ | ---------- |
| 6 | 2  | 9  | 1 |

#### <span id=t-exposed-functions>Exposed Functions</span>

This section lists functions that are explicitly declared public or payable. Please note that getter methods for public stateVars are not included.  

| 🌐Public   | 💰Payable |
| ---------- | --------- |
| 87 | 0  | 

| External   | Internal | Private | Pure | View |
| ---------- | -------- | ------- | ---- | ---- |
| 82 | 58  | 4 | 1 | 40 |

#### <span id=t-statevariables>StateVariables</span>

| Total      | 🌐Public  |
| ---------- | --------- |
| 24  | 24 |

#### <span id=t-capabilities>Capabilities</span>

| Solidity Versions observed | 🧪 Experimental Features | 💰 Can Receive Funds | 🖥 Uses Assembly | 💣 Has Destroyable Contracts | 
| -------------------------- | ------------------------ | -------------------- | ---------------- | ---------------------------- |
| `0.8.21`<br/>`>=0.5.0` |  | **** | **** | **** | 

| 📤 Transfers ETH | ⚡ Low-Level Calls | 👥 DelegateCall | 🧮 Uses Hash Functions | 🔖 ECRecover | 🌀 New/Create/Create2 |
| ---------------- | ----------------- | --------------- | ---------------------- | ------------ | --------------------- |
| `yes` | **** | **** | `yes` | **** | **** | 

| ♻️ TryCatch | Σ Unchecked |
| ---------- | ----------- |
| **** | `yes` |

#### <span id=t-package-imports>Dependencies / External Imports</span>

| Dependency / Import Path | Count  | 
| ------------------------ | ------ |
| @openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol | 1 |
| @openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol | 2 |
| @openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol | 3 |
| @openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol | 2 |
| @openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol | 1 |
| @openzeppelin/contracts/access/IAccessControl.sol | 1 |
| @openzeppelin/contracts/interfaces/IERC20.sol | 3 |
| @openzeppelin/contracts/token/ERC20/IERC20.sol | 2 |

#### <span id=t-totals>Totals</span>

##### Summary

<div class="wrapper" style="max-width: 90%; margin: auto">
    <canvas id="chart-num-bar"></canvas>
</div>

##### AST Node Statistics

###### Function Calls

<div class="wrapper" style="max-width: 90%; margin: auto">
    <canvas id="chart-num-bar-ast-funccalls"></canvas>
</div>

###### Assembly Calls

<div class="wrapper" style="max-width: 90%; margin: auto">
    <canvas id="chart-num-bar-ast-asmcalls"></canvas>
</div>

###### AST Total

<div class="wrapper" style="max-width: 90%; margin: auto">
    <canvas id="chart-num-bar-ast"></canvas>
</div>

##### Inheritance Graph

<a onclick="toggleVisibility('surya-inherit', this)">[➕]</a>
<div id="surya-inherit" style="display:none">
<div class="wrapper" style="max-width: 512px; margin: auto">
    <div id="surya-inheritance" style="text-align: center;"></div> 
</div>
</div>

##### CallGraph

<a onclick="toggleVisibility('surya-call', this)">[➕]</a>
<div id="surya-call" style="display:none">
<div class="wrapper" style="max-width: 512px; margin: auto">
    <div id="surya-callgraph" style="text-align: center;"></div>
</div>
</div>

###### Contract Summary

<a onclick="toggleVisibility('surya-mdreport', this)">[➕]</a>
<div id="surya-mdreport" style="display:none">
 Sūrya's Description Report

 Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| contracts/LRTConfig.sol | [object Promise] |
| contracts/LRTDepositPool.sol | [object Promise] |
| contracts/LRTOracle.sol | [object Promise] |
| contracts/NodeDelegator.sol | [object Promise] |
| contracts/RSETH.sol | [object Promise] |
| contracts/interfaces/IEigenStrategyManager.sol | [object Promise] |
| contracts/interfaces/ILRTConfig.sol | [object Promise] |
| contracts/interfaces/ILRTDepositPool.sol | [object Promise] |
| contracts/interfaces/ILRTOracle.sol | [object Promise] |
| contracts/interfaces/INodeDelegator.sol | [object Promise] |
| contracts/interfaces/IPriceFetcher.sol | [object Promise] |
| contracts/interfaces/IRSETH.sol | [object Promise] |
| contracts/interfaces/IStrategy.sol | [object Promise] |
| contracts/oracles/ChainlinkPriceOracle.sol | [object Promise] |
| contracts/utils/LRTConfigRoleChecker.sol | [object Promise] |
| contracts/utils/LRTConstants.sol | [object Promise] |
| contracts/utils/UtilLib.sol | [object Promise] |


 Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **LRTConfig** | Implementation | ILRTConfig, AccessControlUpgradeable |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | initialize | External ❗️ | 🛑  | initializer |
| └ | addNewSupportedAsset | External ❗️ | 🛑  | onlyRole |
| └ | _addNewSupportedAsset | Private 🔐 | 🛑  | |
| └ | updateAssetDepositLimit | External ❗️ | 🛑  | onlyRole onlySupportedAsset |
| └ | updateAssetStrategy | External ❗️ | 🛑  | onlyRole onlySupportedAsset |
| └ | getLSTToken | External ❗️ |   |NO❗️ |
| └ | getContract | External ❗️ |   |NO❗️ |
| └ | getSupportedAssetList | External ❗️ |   |NO❗️ |
| └ | setRSETH | External ❗️ | 🛑  | onlyRole |
| └ | setToken | External ❗️ | 🛑  | onlyRole |
| └ | _setToken | Private 🔐 | 🛑  | |
| └ | setContract | External ❗️ | 🛑  | onlyRole |
| └ | _setContract | Private 🔐 | 🛑  | |
||||||
| **LRTDepositPool** | Implementation | ILRTDepositPool, LRTConfigRoleChecker, PausableUpgradeable, ReentrancyGuardUpgradeable |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | initialize | External ❗️ | 🛑  | initializer |
| └ | getTotalAssetDeposits | Public ❗️ |   |NO❗️ |
| └ | getAssetCurrentLimit | Public ❗️ |   |NO❗️ |
| └ | getNodeDelegatorQueue | External ❗️ |   |NO❗️ |
| └ | getAssetDistributionData | Public ❗️ |   | onlySupportedAsset |
| └ | getRsETHAmountToMint | Public ❗️ |   |NO❗️ |
| └ | depositAsset | External ❗️ | 🛑  | whenNotPaused nonReentrant onlySupportedAsset |
| └ | _mintRsETH | Private 🔐 | 🛑  | |
| └ | addNodeDelegatorContractToQueue | External ❗️ | 🛑  | onlyLRTAdmin |
| └ | transferAssetToNodeDelegator | External ❗️ | 🛑  | nonReentrant onlyLRTManager onlySupportedAsset |
| └ | updateMaxNodeDelegatorCount | External ❗️ | 🛑  | onlyLRTAdmin |
| └ | setMinAmountToDeposit | External ❗️ | 🛑  | onlyLRTAdmin |
| └ | pause | External ❗️ | 🛑  | onlyLRTManager |
| └ | unpause | External ❗️ | 🛑  | onlyLRTAdmin |
||||||
| **LRTOracle** | Implementation | ILRTOracle, LRTConfigRoleChecker, Initializable |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | initialize | External ❗️ | 🛑  | initializer |
| └ | getAssetPrice | Public ❗️ |   | onlySupportedAsset |
| └ | updateRSETHPrice | External ❗️ | 🛑  |NO❗️ |
| └ | updatePriceOracleFor | External ❗️ | 🛑  | onlyLRTManager onlySupportedAsset |
||||||
| **NodeDelegator** | Implementation | INodeDelegator, LRTConfigRoleChecker, PausableUpgradeable, ReentrancyGuardUpgradeable |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | initialize | External ❗️ | 🛑  | initializer |
| └ | maxApproveToEigenStrategyManager | External ❗️ | 🛑  | onlySupportedAsset onlyLRTManager |
| └ | depositAssetIntoStrategy | External ❗️ | 🛑  | whenNotPaused nonReentrant onlySupportedAsset onlyLRTManager |
| └ | transferBackToLRTDepositPool | External ❗️ | 🛑  | whenNotPaused nonReentrant onlySupportedAsset onlyLRTManager |
| └ | getAssetBalances | External ❗️ |   |NO❗️ |
| └ | getAssetBalance | External ❗️ |   |NO❗️ |
| └ | pause | External ❗️ | 🛑  | onlyLRTManager |
| └ | unpause | External ❗️ | 🛑  | onlyLRTAdmin |
||||||
| **RSETH** | Implementation | Initializable, LRTConfigRoleChecker, ERC20Upgradeable, PausableUpgradeable |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | initialize | External ❗️ | 🛑  | initializer |
| └ | mint | External ❗️ | 🛑  | onlyRole whenNotPaused |
| └ | burnFrom | External ❗️ | 🛑  | onlyRole whenNotPaused |
| └ | pause | External ❗️ | 🛑  | onlyLRTManager |
| └ | unpause | External ❗️ | 🛑  | onlyLRTAdmin |
| └ | updateLRTConfig | External ❗️ | 🛑  | onlyLRTAdmin |
||||||
| **IEigenStrategyManager** | Interface |  |||
| └ | depositIntoStrategy | External ❗️ | 🛑  |NO❗️ |
| └ | getDeposits | External ❗️ |   |NO❗️ |
||||||
| **ILRTConfig** | Interface |  |||
| └ | rsETH | External ❗️ |   |NO❗️ |
| └ | assetStrategy | External ❗️ |   |NO❗️ |
| └ | isSupportedAsset | External ❗️ |   |NO❗️ |
| └ | getLSTToken | External ❗️ |   |NO❗️ |
| └ | getContract | External ❗️ |   |NO❗️ |
| └ | getSupportedAssetList | External ❗️ |   |NO❗️ |
| └ | depositLimitByAsset | External ❗️ |   |NO❗️ |
||||||
| **ILRTDepositPool** | Interface |  |||
| └ | depositAsset | External ❗️ | 🛑  |NO❗️ |
| └ | getTotalAssetDeposits | External ❗️ |   |NO❗️ |
| └ | getAssetCurrentLimit | External ❗️ |   |NO❗️ |
| └ | getRsETHAmountToMint | External ❗️ |   |NO❗️ |
| └ | addNodeDelegatorContractToQueue | External ❗️ | 🛑  |NO❗️ |
| └ | transferAssetToNodeDelegator | External ❗️ | 🛑  |NO❗️ |
| └ | updateMaxNodeDelegatorCount | External ❗️ | 🛑  |NO❗️ |
| └ | getNodeDelegatorQueue | External ❗️ |   |NO❗️ |
| └ | getAssetDistributionData | External ❗️ |   |NO❗️ |
||||||
| **ILRTOracle** | Interface |  |||
| └ | getAssetPrice | External ❗️ |   |NO❗️ |
| └ | assetPriceOracle | External ❗️ |   |NO❗️ |
| └ | rsETHPrice | External ❗️ |   |NO❗️ |
||||||
| **INodeDelegator** | Interface |  |||
| └ | depositAssetIntoStrategy | External ❗️ | 🛑  |NO❗️ |
| └ | maxApproveToEigenStrategyManager | External ❗️ | 🛑  |NO❗️ |
| └ | getAssetBalances | External ❗️ |   |NO❗️ |
| └ | getAssetBalance | External ❗️ |   |NO❗️ |
||||||
| **IPriceFetcher** | Interface |  |||
| └ | getAssetPrice | External ❗️ |   |NO❗️ |
| └ | assetPriceFeed | External ❗️ |   |NO❗️ |
||||||
| **IRSETH** | Interface | IERC20 |||
| └ | mint | External ❗️ | 🛑  |NO❗️ |
| └ | burn | External ❗️ | 🛑  |NO❗️ |
||||||
| **IStrategy** | Interface |  |||
| └ | deposit | External ❗️ | 🛑  |NO❗️ |
| └ | withdraw | External ❗️ | 🛑  |NO❗️ |
| └ | sharesToUnderlying | External ❗️ | 🛑  |NO❗️ |
| └ | underlyingToShares | External ❗️ | 🛑  |NO❗️ |
| └ | userUnderlying | External ❗️ | 🛑  |NO❗️ |
| └ | sharesToUnderlyingView | External ❗️ |   |NO❗️ |
| └ | underlyingToSharesView | External ❗️ |   |NO❗️ |
| └ | userUnderlyingView | External ❗️ |   |NO❗️ |
| └ | underlyingToken | External ❗️ |   |NO❗️ |
| └ | totalShares | External ❗️ |   |NO❗️ |
| └ | explanation | External ❗️ |   |NO❗️ |
||||||
| **AggregatorV3Interface** | Interface |  |||
| └ | decimals | External ❗️ |   |NO❗️ |
| └ | latestRoundData | External ❗️ |   |NO❗️ |
||||||
| **ChainlinkPriceOracle** | Implementation | IPriceFetcher, LRTConfigRoleChecker, Initializable |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | initialize | External ❗️ | 🛑  | initializer |
| └ | getAssetPrice | External ❗️ |   | onlySupportedAsset |
| └ | updatePriceFeedFor | External ❗️ | 🛑  | onlyLRTManager onlySupportedAsset |
||||||
| **LRTConfigRoleChecker** | Implementation |  |||
| └ | updateLRTConfig | External ❗️ | 🛑  | onlyLRTAdmin |
||||||
| **LRTConstants** | Library |  |||
||||||
| **UtilLib** | Library |  |||
| └ | checkNonZeroAddress | Internal 🔒 |   | |


 Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
 

</div>
____
<sub>
Thinking about smart contract security? We can provide training, ongoing advice, and smart contract auditing. [Contact us](https://diligence.consensys.net/contact/).
</sub>


