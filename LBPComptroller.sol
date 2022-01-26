pragma abicoder v2;
pragma solidity ^0.7.0;


import "https://github.com/beethovenxfi/balancer-v2-monorepo/blob/master/pkg/vault/contracts/interfaces/IVault.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/318c4b44eaba2d745ed4a6381c43e03edc53634d/contracts/access/Ownable.sol";


interface ILBP{
    function setSwapEnabled(bool swapEnabled) external;
    function updateWeightsGradually(uint256 startTime, uint256 endTime, uint256[] memory endWeights) external;
}

contract LBPComptroller is Ownable{
    IVault public vault;
    ILBP pool;

    constructor(address _vault, ILBP _pool) {
        vault = IVault(_vault);
        pool = _pool;
    }

    function initJoin(IAsset[] calldata tokens, uint256[] calldata amounts, bytes32 pid) onlyOwner external {
        IVault.JoinPoolRequest memory join;
        bytes memory data;
        data = abi.encode(0, amounts);
        join = IVault.JoinPoolRequest(tokens , amounts , data, false);
        vault.joinPool(pid, address(this), msg.sender, join);
    }

    function setSwapEnabled(bool _swapEnabled) external onlyOwner {
        pool.setSwapEnabled(_swapEnabled);
    }

    function updateWeightsGradually(uint256 _startTime, uint256 _endTime, uint256[] memory _endWeights) onlyOwner external {
        pool.updateWeightsGradually(_startTime, _endTime, _endWeights);
    }

}