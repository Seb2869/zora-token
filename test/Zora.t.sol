// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Zora} from "../src/zora/Zora.sol";
import {IZora} from "../src/zora/IZora.sol";
import {Test} from "forge-std/Test.sol";

contract ZoraTest is Test {
    address deployer = makeAddr("deployer");

    function testCanMintInitialDistribution() public {
        address[] memory tos = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        tos[0] = makeAddr("to1");
        tos[1] = makeAddr("to2");

        amounts[0] = 10 * 10 ** 18;
        amounts[1] = 50 * 10 ** 18;

        vm.startPrank(deployer);
        Zora zora = new Zora();
        zora.mintSupply(tos, amounts);

        assertEq(zora.balanceOf(tos[0]), amounts[0]);
        assertEq(zora.balanceOf(tos[1]), amounts[1]);
    }

    function testCannotMintAfterAllSupplyIsMinted() public {
        address[] memory tos = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        tos[0] = makeAddr("to1");

        amounts[0] = 10 * 10 ** 18;

        vm.startPrank(deployer);
        Zora zora = new Zora();
        zora.mintSupply(tos, amounts);

        vm.expectRevert(IZora.AlreadyMinted.selector);
        zora.mintSupply(new address[](0), new uint256[](0));
    }

    function testCannotMintIfNotDeployer() public {
        address[] memory tos = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        tos[0] = makeAddr("to1");
        amounts[0] = 10 * 10 ** 18;

        vm.prank(deployer);
        Zora zora = new Zora();

        vm.prank(makeAddr("not-deployer"));
        vm.expectRevert(IZora.OnlyDeployer.selector);
        zora.mintSupply(tos, amounts);
    }
}
