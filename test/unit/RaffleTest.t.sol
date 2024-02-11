// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";

contract RaffleTest is Test {
    /** State variables */
    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("PLAYER");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    /** Events */
    event EnteredRaffle(address indexed player);

    function setUp() public {
        // create an instance of the deployer script
        DeployRaffle deployRaffle = new DeployRaffle();

        // run the deployer script
        (raffle, helperConfig) = deployRaffle.run();

        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link
        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function test_RaffleInitializesWithOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /** EnterRaffle */
    function test_EnterRaffleRverts_WhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function test_RaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function test_EmitsEventOnEntrance() public {
        // Arrange
        vm.prank(PLAYER);
        // Act - Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function test_CantEnter_WhenRaffleStateIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1); // optionnal but it marks time passing
        raffle.performUpkeep("");

        // Act - Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /** checkUpkeep */
    function test_CheckUpkeepReturnsFalse_WhenItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function test_CheckUpkeepReturnsFalse_WhenRaffleStateIsNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // here the state is set to calculating
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function test_CheckUpkeepReturnsFalse_WhenTimeHasNotPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    // // with this implementation same as when no balance
    // function test_CheckUpkeepReturnsFalse_WhenNoPlayers() public {
    //     // Arrange
    //     vm.warp(block.timestamp + interval + 1);
    //     vm.roll(block.number + 1);
    //     // Act
    //     (bool upkeepNeeded, ) = raffle.checkUpkeep("");
    //     // Assert
    //     assert(!upkeepNeeded);
    // }

    function test_CheckUpkeepReturnsTrue_WhenAllConditionsAreMet() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded);
    }

    /** performUpkeep */
    function test_PerformUpkeepCanOnlyRun_WhenCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act - Assert
        raffle.performUpkeep("");
    }

    function test_PerformUpkeepReverts_WhenCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 playersLength = 0;
        uint256 raffleState = uint256(Raffle.RaffleState.OPEN); //0

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act - Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpKeepNotNeeded.selector,
                currentBalance,
                playersLength,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }
}
