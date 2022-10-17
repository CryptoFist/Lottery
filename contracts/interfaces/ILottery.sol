// SPDX-License-Identifier: MIT
pragma solidity = 0.8.17;

interface ILottery {
    event BuyTicket(uint256 saleId, uint256 ticketPrice, uint256 totalTickets, uint256 fee);

    event SwappedPriceTokens(uint256 saleId, uint256 swappedAmount);

    event CreatedLottery(uint256 lotteryId);

    event WinnerForLottery(address indexed winner, uint256 lotteryId);
}