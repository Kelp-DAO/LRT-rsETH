// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { Test } from "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract BaseTest is Test {
    MockToken public stETH;
    MockToken public ethX;

    MockToken public rETH;
    MockToken public cbETH;

    address public admin = makeAddr("admin");

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");

    uint256 public oneThousand = 1000 ** 18;

    function setUp() public virtual {
        stETH = new MockToken("staked ETH", "stETH");
        ethX = new MockToken("ETHX", "ethX");
        rETH = new MockToken("rETH", "rETH");
        cbETH = new MockToken("cbETH", "cbETH");

        // mint LST tokens to alice, bob and carol
        mintLSTTokensForUsers(stETH);
        mintLSTTokensForUsers(ethX);
        mintLSTTokensForUsers(rETH);
        mintLSTTokensForUsers(cbETH);

        // give ETH to alice, bob and carol
        vm.deal(alice, oneThousand);
        vm.deal(bob, oneThousand);
        vm.deal(carol, oneThousand);
    }

    function mintLSTTokensForUsers(MockToken asset) internal {
        asset.mint(alice, oneThousand);
        asset.mint(bob, oneThousand);
        asset.mint(carol, oneThousand);
    }

    /// @dev Expects an event to be emitted by checking all three topics and the data. As mentioned
    /// in the Foundry
    /// Book, the extra `true` arguments don't hurt.
    function expectEmit() internal {
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true });
    }
}
