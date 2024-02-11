// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

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
    uint256 deployerKey;

    address public PLAYER = makeAddr("PLAYER");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    /** Events */
    event EnteredRaffle(address indexed player);

    function setUp() public {
        // create an instance of the deployer script
        console.log("RaffleTest / setUp : creating deployer instance");
        DeployRaffle deployRaffle = new DeployRaffle();

        console.log("RaffleTest / setUp : running the deployer");
        // run the deployer script
        (raffle, helperConfig) = deployRaffle.run();
        console.log("RaffleTest / setUp : getting network config");
        // ! stack to deep issue ! => remove the deployerKey
        // if needed, we can use the helperConfig to get the deployerKey in a sceond time
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig();

        // (, , , , , , , deployerKey) = helperConfig.activeNetworkConfig();
        console.log("RaffleTest / setUp : dealing to player");
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

    modifier raffeleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }
    // Testing using the output of an event. (EVM can't read events, but tests can)
    // Important to test events cause Chainlink nodes listen to them
    function test_PerformUpkeepUpdatesRaffleState_AndEmitRequestId()
        public
        raffeleEnteredAndTimePassed
    {
        // Arrange -> modifier
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Assert
        // Method to get the desired log :
        // We know first event emitted : by VRFCoordiantorV2Mock
        // and second event emitted : by Raffle
        bytes32 requestId = entries[1].topics[1];
        // topics[0] refers to the entire event
        // topics[1] refers to the first indexed parameter

        Raffle.RaffleState raffleState = raffle.getRaffleState();

        assert(uint256(raffleState) == 1); // 1 is calculating
        assert(uint256(requestId) > 0);
    }

    /** fulfillRandomWords */

    // should compute params of the functions of the real VRFCoordinatorV2
    // to test the fulfillRandomWords on forked chain
    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    // params in test allows fuzzing
    // skipFork : test not running on forked chain to avoid revert
    function test_FulfillRandomWordsCanOnlyBeCalled_AfterPerformUpkeep(
        uint256 randomRequestId
    ) public skipFork {
        // Arrange
        // revert msg from Mock:fulfillRandomWordsWithOverride : "nonexistent request"
        // real contract:fulfillRandomWords : different params => do skipFork
        vm.expectRevert("nonexistent request");
        // only on local test
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function test_FulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffeleEnteredAndTimePassed
        skipFork
    {
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 previousTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1); // +1 for the first player

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // pretend to be the chainlink vrf to get random number to pick a winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        // Not good practice to have many asserts in a single test
        assert(uint256(raffle.getRaffleState()) == 0); // 0 is open
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(raffle.getPlayersLength() == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLastTimeStamp() > previousTimeStamp);
        console.log("Winner: %s", raffle.getRecentWinner());
        console.log("Winner balance: %s", raffle.getRecentWinner().balance);
        console.log(
            "Prize + STARTING_USER_BALANCE - entranceFee: %s",
            prize + STARTING_USER_BALANCE - entranceFee
        );
        assert(
            raffle.getRecentWinner().balance ==
                (STARTING_USER_BALANCE + prize - entranceFee)
        );
    }
}
