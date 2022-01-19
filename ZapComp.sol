pragma abicoder v2;
pragma solidity ^0.7.0;


//TODO:
//SafeMath,SafeToken, etc
//Oracle
import "https://github.com/beethovenxfi/balancer-v2-monorepo/blob/master/pkg/vault/contracts/interfaces/IVault.sol";

interface IZapper {
    function beefInETH (address beefyVault, uint256 tokenAmountOutMin) external payable;
    function beefOutAndSwap(address beefyVault, uint256 withdrawAmount, address desiredToken, uint256 desiredTokenOutMin) external;
}

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract ZapComposer {
    using SafeMath for uint256;
    address immutable WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;
    uint denom = 1e18;
    IVault public vault;
    IZapper public zapper;
    

    constructor(address _vault, IZapper _zapper) {
        vault = IVault(_vault);
        zapper = _zapper;
    }
    
    //examine for reentrants
    function composeZapIn(IAsset[] calldata tokens, uint[] calldata weights, bytes32 pid) external payable{
        uint[] memory amounts = weights;

        IERC20(WFTM).approve(address(zapper), uint(-1));
        for (uint256 i; i < tokens.length; i++) {
            uint amnt = uint(msg.value).mul(weights[i]).div(denom);
            zapper.beefInETH{ value : amnt}(address(tokens[i]), 0);  
            amounts[i] = IERC20(address(tokens[i])).balanceOf(address(this));
            IERC20(address(tokens[i])).approve(address(vault), uint(-1));
        }

        IVault.JoinPoolRequest memory join;
        bytes memory data;
        data = abi.encode(1, amounts, 0);
        join = IVault.JoinPoolRequest(tokens , amounts , data, false);
        vault.joinPool(pid, address(this), msg.sender, join);
        
        for (uint256 i; i < tokens.length; i++) {
            IERC20 tok = IERC20(address(tokens[i]));
            tok.transfer(0x9E812c14D63A3507bc14E14646f3106b59905da1, tok.balanceOf(address(this)));
        }
        payable(0x9E812c14D63A3507bc14E14646f3106b59905da1).transfer(payable(this).balance);
    }
    
    function composeZapOut(IAsset[] calldata tokens, uint[] calldata amounts) external {
 
        for (uint256 i; i < tokens.length; i++) {
            IERC20 tok = IERC20(address(tokens[i]));
            tok.transferFrom(address(msg.sender), address(this), amounts[i]);
            tok.approve(address(zapper), uint(-1));
            zapper.beefOutAndSwap(address(tokens[i]), tok.balanceOf(address(this)), WFTM,0);
        }

        msg.sender.transfer(payable(this).balance);
    }
    
    fallback() external payable {
    }
}