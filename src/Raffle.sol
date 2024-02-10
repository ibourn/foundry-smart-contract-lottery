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
 * @title A sample Raffle contract
 * @author ibourn
 * @notice This is a simple Raffle contract
 * @dev implements Chainlink VRFv2
 */
contract Raffle {
    /** Errors */
    error Raffle__NotEnoughEthSent();

    /** State variables */
    uint256 private immutable i_entranceFee;

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH sent");
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
    }

    function pickWinner() public {}

    /****************************************************************************
     * Getter functions
     ****************************************************************************/

    /** Getter funcitons */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
