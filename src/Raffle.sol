// SPDX-license-identifier: MIT

pragma solidity ^0.8.18;

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

/**
 * chainlink infos => https://docs.chain.link/vrf/v2/subscription/supported-networks
 *
 * Mainnet
 *
 *
 *
 *
 *
 * Sepolia
 * LINK Token => 0x779877A7B0D9E8603169DdbD7836e478b4624789
 * VRF Coordinator	=> 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
 * 150 gwei Key Hash => 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c
 *
 */

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A sample Raffle contract
 * @author ibourn
 * @notice This is a simple Raffle contract
 * @dev implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    /** Errors */
    error Raffle__NotEnoughEthSent();
    error Raffle__TransfertFailed();
    error Raffle__NotOpen();
    error Raffle__UpKeepNotNeeded(
        uint256 balance,
        uint256 players,
        uint256 state
    );

    /** Type declarations */
    enum RaffleState {
        OPEN, //0
        CALCULATING //1
    }

    /** State variables */
    // @dev Chainlink VRF request confirmations : nbr of block confirmations
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    // @dev Chainlink VRF request number of words
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev duration of the ottery in seconds
    uint256 private immutable i_interval;
    // @dev Chainlink VRF keyHash renamed to gasLane. Gas lane to use specifying the max gas price to bump to
    bytes32 private immutable i_gasLane;
    // @dev Chainlink VRF address
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    // @dev Chainlink VRF subscriptionId
    uint64 private immutable i_subscriptionId;
    // @dev Chainlink VRF callbackGasLimit
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /** Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

    /// @dev renamed keyHash to gasLane
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH sent");
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }

        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    // When the winner supposed to be picked ?
    /**
     * @dev funciton called by Chainlink Automation Nodes to check if it's time to perform the upkeep
     * To perform an upkeep should be true :
     * - time have passed betwen raffles
     * - the raffle state is OPEN
     * - the contract has ETH (i.e. players)
     * - the subscruptuin is funded with LINK
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "0x0");
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    // 1. Get a randomn number
    // 2. Use the random number to pick a winner
    // 3. Be automatically called
    // function pickWinner() public {
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        // check if enough time has passed
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert(); //Raffle__NotEnoughTimePassed();
        }
        s_raffleState = RaffleState.CALCULATING;
        // (from Chainlink doc) Will revert if subscription is not set and funded.
        // uint256 requestId = i_vrfCoordinator.requestRandomWords(
        i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        //     // pick a winner
        //     uint256 winnerIndex = randomWords[0] % s_players.length;
        //     s_players[winnerIndex].transfer(address(this).balance);
        //     // reset the players array
        //     delete s_players;
        //     s_lastTimeStamp = block.timestamp;

        // CEI => Checks-Effects-Interactions

        // checks first => revert quicker = cheaper

        // effects => we change the state of the contract
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);

        // interactions => we interact with other contracts
        (bool succes, ) = winner.call{value: address(this).balance}("");
        if (!succes) {
            revert Raffle__TransfertFailed();
        }
    }

    /****************************************************************************
     * Getter functions
     ****************************************************************************/

    /** Getter funcitons */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
