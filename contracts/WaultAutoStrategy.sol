// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
/**
 * @dev Strategy to farm single tokens through AutoFarm contract.
 */

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface IUniswapRouter {
    function factory() external pure returns (address);
    function WBNB() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityBNB(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountBNBMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountBNB, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityBNB(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountBNBMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountBNB);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityBNBWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountBNBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountBNB);
    function removeLiquidityBNBSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountBNBMin,
        address to,
        uint deadline
    ) external returns (uint amountBNB);
    function removeLiquidityBNBWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountBNBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountBNB);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactBNBForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForBNBSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactBNBForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactBNB(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForBNB(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapBNBForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IAutoFarmV2 {
    function poolInfo(uint256 _pid) external view returns (address, uint256, uint256, uint256, address);
    function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256);
    function pendingAUTO(uint256 _pid, address _user) external view returns (uint256);
    function stakedWantTokens(uint256 _pid, address _user) external view returns (uint256);
    function deposit(uint256 _pid, uint256 _wantAmt) external;
    function withdraw(uint256 _pid, uint256 _wantAmt) external;
    function withdrawAll(uint256 _pid) external;
    function emergencyWithdraw(uint256 _pid) external;
}

interface IStratVLEV {
    function updateBalance() external;
}

interface IMasterChef {
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function enterStaking(uint256 _amount) external;
    function leaveStaking(uint256 _amount) external;
    function pendingCake(uint256 _pid, address _user) external view returns (uint256);
    function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256);
    function emergencyWithdraw(uint256 _pid) external;
}

contract StrategyAutoVenus is Ownable, Pausable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /**
     * @dev Tokens Used:
     * {wbnb} - Required for liquidity routing when doing swaps.
     * {Auto} - Token generated by staking our funds. In this case it's the AUTO token.
     * {want} - Token that the strategy maximizes.
     * {bifi} - BeefyFinance token, used to send funds to the treasury.
     */
//    address constant public wbnb = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c); // Main
    address constant public wbnb = address(0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd); // Test
    address constant public Auto = address(0xa184088a740c695E156F91f5cC086a06bb78b827);
    address constant public bifi = address(0xCa3F508B8e4Dd382eE878A314789373D80A5190A);
    address public want;

    /**
     * @dev Third Party Contracts:
     * {unirouter} - PancakeSwap unirouter
     * {autofarm} - AutoFarm contract
     * {autostrat} - AutoFarm underlying strategy contract
     * {poolId} - AutoFarm pool id
     */
    address constant public unirouter  = address(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);
    address constant public autofarm = address(0x0895196562C7868C5Be92459FaE7f877ED450452);
    address public autostrat;
    uint8 public poolId;

    /**
     * @dev Beefy Contracts:
     * {rewards} - Reward pool where the strategy fee earnings will go.
     * {treasury} - Address of the BeefyFinance treasury
     * {vault} - Address of the vault that controls the strategy's funds.
     * {strategist} - Address of the strategy author/deployer where strategist fee will go.
     */
    address constant public rewards  = address(0x453D4Ba9a2D594314DF88564248497F7D74d6b2C);
    address constant public treasury = address(0x4A32De8c248533C28904b24B4cFCFE18E9F2ad01);
    address public vault;
    address public strategist;

    /**
     * @dev Distribution of fees earned. This allocations relative to the % implemented on doSplit().
     * Current implementation separates 4.5% for fees.
     *
     * {REWARDS_FEE} - 3% goes to BIFI holders through the {rewards} pool.
     * {CALL_FEE} - 0.5% goes to whoever executes the harvest function as gas subsidy.
     * {TREASURY_FEE} - 0.5% goes to the treasury.
     * {STRATEGIST_FEE} - 0.5% goes to the strategist.
     * {MAX_FEE} - Aux const used to safely calc the correct amounts.
     */
    uint constant public REWARDS_FEE    = 665;
    uint constant public CALL_FEE       = 111;
    uint constant public TREASURY_FEE   = 112;
    uint constant public STRATEGIST_FEE = 112;
    uint constant public MAX_FEE        = 1000;

    /**
     * @dev Routes we take to swap tokens using PancakeSwap.
     * {autoToWbnbRoute} - Route we take to go from {auto} into {wbnb}.
     * {wbnbToBifiRoute} - Route we take to go from {wbnb} into {bifi}.
     * {autoToWantRoute} - Route we take to go from {auto} into {want}.
     */
    address[] public autoToWbnbRoute = [Auto, wbnb];
    address[] public wbnbToBifiRoute = [wbnb, bifi];
    address[] public autoToWantRoute;

    /**
     * @dev Event that is fired each time someone harvests the strat.
     */
    event StratHarvest(address indexed harvester);

    /**
     * @dev Initializes the strategy with the token to maximize.
     */
    constructor(address _want, uint8 _poolId, address _vault, address _strategist) public {
        want = _want;
        poolId = _poolId;
        vault = _vault;
        strategist = _strategist;

        (, , , , address _autostrat) = IAutoFarmV2(autofarm).poolInfo(poolId);
        autostrat = _autostrat;

        if (want == wbnb) {
            autoToWantRoute = [Auto, wbnb];
        } else {
            autoToWantRoute = [Auto, wbnb, want];
        }

        IERC20(want).safeApprove(autofarm, uint(-1));
        IERC20(Auto).safeApprove(unirouter, uint(-1));
        IERC20(wbnb).safeApprove(unirouter, uint(-1));
    }

    /**
     * @dev Function that puts the funds to work.
     * It gets called whenever someone deposits in the strategy's vault contract.
     * It deposits {want} in the AutoFarm to earn rewards in {auto}.
     */
    function deposit() public whenNotPaused {
        uint256 wantBal = IERC20(want).balanceOf(address(this));

        if (wantBal > 0) {
            IAutoFarmV2(autofarm).deposit(poolId, wantBal);
        }
    }

    /**
     * @dev Withdraws funds and sents them back to the vault.
     * It redeposits harvested and pending cakes in AutoFarm strategy via farm()
     * It withdraws {want} from the AutoFarm.
     * The available {want} is returned to the vault.
     */
    function withdraw(uint256 _amount) external {
        require(msg.sender == vault, "!vault");

        uint256 wantBal = IERC20(want).balanceOf(address(this));

        if (wantBal < _amount) {
            IAutoFarmV2(autofarm).withdraw(poolId, _amount.sub(wantBal));
            wantBal = IERC20(want).balanceOf(address(this));
        }

        if (wantBal > _amount) {
            wantBal = _amount;
        }

        IERC20(want).safeTransfer(vault, wantBal);
    }

    /**
     * @dev Core function of the strat, in charge of collecting and re-investing rewards.
     * 1. It claims rewards from the AutoFarm
     * 3. It charges the system fee and sends it to BIFI stakers.
     * 4. It re-invests the remaining profits.
     */
    function harvest() external whenNotPaused {
        require(!Address.isContract(msg.sender), "!contract");
        IAutoFarmV2(autofarm).deposit(poolId, 0);
        chargeFees();
        swapRewards();
        deposit();

        emit StratHarvest(msg.sender);
    }

    /**
     * @dev Takes out 4.5% as system fees from the rewards.
     * 0.5% -> Call Fee
     * 0.5% -> Treasury fee
     * 0.5% -> Strategist fee
     * 3.0% -> BIFI Holders
     */
    function chargeFees() internal {
        uint256 toWbnb = IERC20(Auto).balanceOf(address(this)).mul(45).div(1000);
        IUniswapRouter(unirouter).swapExactTokensForTokens(toWbnb, 0, autoToWbnbRoute, address(this), now.add(600));

        uint256 wbnbBal = IERC20(wbnb).balanceOf(address(this));

        uint256 callFee = wbnbBal.mul(CALL_FEE).div(MAX_FEE);
        IERC20(wbnb).safeTransfer(msg.sender, callFee);

        uint256 treasuryHalf = wbnbBal.mul(TREASURY_FEE).div(MAX_FEE).div(2);
        IERC20(wbnb).safeTransfer(treasury, treasuryHalf);
        IUniswapRouter(unirouter).swapExactTokensForTokens(treasuryHalf, 0, wbnbToBifiRoute, treasury, now.add(600));

        uint256 rewardsFee = wbnbBal.mul(REWARDS_FEE).div(MAX_FEE);
        IERC20(wbnb).safeTransfer(rewards, rewardsFee);

        uint256 strategistFee = wbnbBal.mul(STRATEGIST_FEE).div(MAX_FEE);
        IERC20(wbnb).safeTransfer(strategist, strategistFee);
    }

    /**
     * @dev Swaps {auto} rewards earned for more {want}.
     */
    function swapRewards() internal {
        uint256 autoBal = IERC20(Auto).balanceOf(address(this));
        IUniswapRouter(unirouter).swapExactTokensForTokens(autoBal, 0, autoToWantRoute, address(this), now.add(600));
    }

    /**
     * @dev Function to synchronize AutoFarm balance of {want}.
     * It should be called by the vault before minting shares.
     */
    function updateBalance() public {
        IStratVLEV(autostrat).updateBalance();
    }

    /**
     * @dev Function to calculate the total underlaying {want} held by the strat.
     * It takes into account both the funds in hand, as the funds allocated in AutoFarm.
     */
    function balanceOf() public view returns (uint256) {
        return balanceOfWant().add(balanceOfPool());
    }

    /**
     * @dev It calculates how much {want} the contract holds.
     */
    function balanceOfWant() public view returns (uint) {
        return IERC20(want).balanceOf(address(this));
    }

    /**
     * @dev It calculates how much {want} the strategy has allocated in the AutoFarm
     */
    function balanceOfPool() public view returns (uint256) {
        return IAutoFarmV2(autofarm).stakedWantTokens(poolId, address(this));
    }

    /**
     * @dev Function that has to be called as part of strat migration. It sends all the available funds back to the
     * vault, ready to be migrated to the new strat.
     */
    function retireStrat() external {
        require(msg.sender == vault, "!vault");

        IAutoFarmV2(autofarm).emergencyWithdraw(poolId);

        uint256 wantBal = IERC20(want).balanceOf(address(this));
        IERC20(want).transfer(vault, wantBal);
    }

    /**
     * @dev Pauses deposits. Withdraws all funds from the MasterChef, leaving rewards behind
     */
    function panic() public onlyOwner {
        pause();
        IAutoFarmV2(autofarm).emergencyWithdraw(poolId);
    }

    /**
     * @dev Pauses the strat.
     */
    function pause() public onlyOwner {
        _pause();

        IERC20(want).safeApprove(autofarm, 0);
        IERC20(Auto).safeApprove(unirouter, 0);
        IERC20(wbnb).safeApprove(unirouter, 0);
    }

    /**
     * @dev Unpauses the strat.
     */
    function unpause() external onlyOwner {
        _unpause();

        IERC20(want).safeApprove(autofarm, uint(-1));
        IERC20(Auto).safeApprove(unirouter, uint(-1));
        IERC20(wbnb).safeApprove(unirouter, uint(-1));
    }

    /**
     * @dev Updates address where strategist fee earnings will go.
     * @param _strategist new strategist address.
     */
    function setStrategist(address _strategist) external {
        require(msg.sender == strategist, "!strategist");
        strategist = _strategist;
    }
}