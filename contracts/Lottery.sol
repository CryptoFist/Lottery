// SPDX-License-Identifier: MIT
pragma solidity = 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ILottery.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/ITicketNFT.sol";
import "./interfaces/IRewardNFT.sol";

contract Lottery is Ownable, ILottery {
    using SafeERC20 for IERC20;

    struct lottery {
        uint256 index;
        address[] holders;
    }

    uint256 public thresholdTicketCnt = 10;
    uint256 public maxBuyTicketCnt = 3;
    uint256 public ticketPrice;
    uint256 public lotteryId;
    uint256 public saleId;
    uint256 public totalSoldTickets;
    address public priceToken;
    address public ticketNFT;

    address private swapToken;
    address private rewardNFT;
    address private lotteryVault;
    IUniswapV2Router02 private router;
    uint256 private swapPercent;
    mapping(uint256 => lottery) private lottories;

    constructor (
        uint256 ticketPrice_,
        uint256 swapPercent_,
        address ticketNFT_,
        address priceToken_,
        address swapToken_,
        address rewardNFT_,
        address lotteryVault_,
        address router_
    ) {
        ticketPrice = ticketPrice_;
        swapPercent = swapPercent_;
        ticketNFT = ticketNFT_;
        priceToken = priceToken_;
        swapToken = swapToken_;
        rewardNFT = rewardNFT_;
        lotteryVault = lotteryVault_;
        router = IUniswapV2Router02(router_);
    }

    /// @notice Get ticket price.
    /// @return Ticket price as priceToken.
    function getTicketPrice() external view returns (uint256) {
        return ticketPrice;
    }

    /// @notice Buy tickets with priceToken.
    /// @dev Users can buy multiple tickets but should be less than max amount.
    /// @param amount_ The amount of tickets.
    function buyTicket(uint256 amount_) external {
        address buyer = msg.sender;
        require (buyer != address(0), "invalid address");
        require (
            amount_ <= maxBuyTicketCnt &&
            lottories[lotteryId].index + amount_ < thresholdTicketCnt, 
            "exceeds max amount"
        );

        uint256 price = amount_ * ticketPrice;
        IERC20(priceToken).safeTransferFrom(buyer, address(this), price);

        lottery storage curLottery = lottories[lotteryId];
        curLottery.index += amount_;
        totalSoldTickets += amount_;
        for (uint256 i = 0; i < amount_; i ++) {
            curLottery.holders.push(buyer);
        }
        saleId ++;
        ITicketNFT(ticketNFT).mintNFT(buyer, amount_);
        emit BuyTicket(saleId, price, totalSoldTickets, 0);

        _swapAndTransferToVault(amount_);
        if (curLottery.index == thresholdTicketCnt - 1) {
            _chooseWinnerAndGiveReward();
            lotteryId ++;
            emit CreatedLottery(lotteryId);
        }
    }

    /// @notice Swap price token to specific token and transfer it to vault address.
    /// @param amount_ Amount of price token.
    function _swapAndTransferToVault(uint256 amount_) internal {
        uint256 amountToSwap = amount_ * swapPercent / 100;
        address[] memory path = new address[](2);
        path[0] = priceToken;
        path[1] = swapToken;
        IERC20(priceToken).safeApprove(address(router), amountToSwap);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountToSwap, 
            0, 
            path, 
            lotteryVault, 
            block.timestamp
        );

        emit SwappedPriceTokens(saleId, amountToSwap);   
    }

    /// @notice Choose winner and mint NFT to winner.
    function _chooseWinnerAndGiveReward() internal {
        uint256 winnerIdx = _random() % thresholdTicketCnt;
        address winner = lottories[lotteryId].holders[winnerIdx];
        IRewardNFT(rewardNFT).mintNFT(winner);
        emit WinnerForLottery(winner, lotteryId);
    }

    /// @notice generate radom number based on block's difficulty, timestamp, lotteryId, thresholdTicketCnt
    function _random() internal view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, lotteryId, thresholdTicketCnt)));
    }
}