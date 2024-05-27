// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IMultiIncentive.sol";
import "../../interfaces/IMintBurnERC20.sol";
import "../../interfaces/IERC20Detailed.sol";
import "../../interfaces/IPriceCalculator.sol";

/// @title PoolBase
/// @author Noah, Park
/// @notice Base contract for depositing collateral and minting usdAsset
abstract contract PoolBase {
    IMintBurnERC20 public usdAsset;
    IERC20 public collateralAsset;

    mapping(address => uint256) public collateralAmount; // collateral deposited by user
    mapping(address => uint256) public borrowedAmount; // usdAsset borrowed by user (including fee)
    mapping(address => uint256) public feeUnpaid;
    mapping(address => uint256) public feeDebt;
    uint256 public feeUpdatedAt;
    uint256 public feePerShare;

    uint256 public poolIssuedUSD; // total usdAsset minted by pool

    IPriceCalculator public priceCalculator;
    address public gov;
    address public feeReceiver; // fee receiver

    // ========= POOL CONFIGURATION ===============//

    uint256 public maxTotalMintAmount; // maximum poolIssuedUSD, default type(uint256 public ).max

    uint256 public minMintAmount; // minimum mint amount, default 1

    uint256 public mintFee; // 10000 = 100%, default 0.1%

    uint256 public mintInterest; // 10000 = 100%, default 0%

    uint256 public normalRedemptionFee; // 10000 = 100%, default 1%

    uint256 public protectionRedemptionFee; // 10000 = 100 %, default 0.5%

    uint256 public safeCollateralRatio; // 10000 = 100% , default 150%

    uint256 public protectionCollateralRatio; // 10000 = 100%, default 150%

    uint256 public liquidationCollateralRatio; // 10000 = 100%, default 120%

    uint256 public liquidationBonus; // 11000 = 10% of collateral plus, default 20%

    uint256 public liquidationProtocolRatio; // 10000 = 100%, default 50%

    address public mintIncentivePool;

    address public collateralIncentivePool;

    // ========= POOL CONFIGURATION END =============== //

    // ========= MODIFIER =============== //

    modifier onlyGov() {
        require(msg.sender == gov, "not gov");
        _;
    }

    // ========= INITIALIZER =============== //

    function _initialize(IMintBurnERC20 _usdAsset, IERC20 _collateral) internal virtual {
        usdAsset = _usdAsset;
        collateralAsset = _collateral;

        gov = msg.sender;
        feeReceiver = msg.sender;

        emit SetGov(address(0), gov, block.timestamp);
        emit SetFeeReceiver(address(0), feeReceiver, block.timestamp);
    }

    // ========= GOV FUNCTIONS =============== //

    function setGov(address _gov) external onlyGov {
        require(_gov != address(0), "zero address");

        emit SetGov(gov, _gov, block.timestamp);

        gov = _gov;
    }

    function setFeeReceiver(address _feeReceiver) external onlyGov {
        require(_feeReceiver != address(0), "zero address");

        emit SetFeeReceiver(feeReceiver, _feeReceiver, block.timestamp);

        feeReceiver = _feeReceiver;
    }

    function setPriceCalculator(IPriceCalculator _priceCalculator) external onlyGov {
        require(address(_priceCalculator) != address(0), "zero address");

        emit SetPriceCalculator(address(priceCalculator), address(_priceCalculator), block.timestamp);

        priceCalculator = _priceCalculator;
    }

    function setPoolConfiguration(
        uint256 _maxTotalMintAmount,
        uint256 _minMintAmount,
        uint256 _mintFee,
        uint256 _mintInterest,
        uint256 _normalRedemptionFee,
        uint256 _protectionRedemptionFee,
        uint256 _safeCollateralRatio,
        uint256 _protectionCollateralRatio,
        uint256 _liquidationCollateralRatio,
        uint256 _liquidationBonus,
        uint256 _liquidationProtocolRatio
    ) external onlyGov {
        _updateFee();
        maxTotalMintAmount = _maxTotalMintAmount;
        minMintAmount = _minMintAmount;
        mintFee = _mintFee;
        normalRedemptionFee = _normalRedemptionFee;
        protectionRedemptionFee = _protectionRedemptionFee;
        safeCollateralRatio = _safeCollateralRatio;
        protectionCollateralRatio = _protectionCollateralRatio;
        liquidationCollateralRatio = _liquidationCollateralRatio;
        liquidationBonus = _liquidationBonus;
        liquidationProtocolRatio = _liquidationProtocolRatio;
        mintInterest = _mintInterest;

        emit SetPoolConfiguration(
            _maxTotalMintAmount,
            _minMintAmount,
            _mintFee,
            _mintInterest,
            _normalRedemptionFee,
            _protectionRedemptionFee,
            _safeCollateralRatio,
            _protectionCollateralRatio,
            _liquidationCollateralRatio,
            _liquidationBonus,
            _liquidationProtocolRatio,
            block.timestamp
        );
    }

    function setMintIncentivePool(address _mintIncentivePool) external onlyGov {
        emit SetMintIncentivePool(mintIncentivePool, _mintIncentivePool, block.timestamp);

        mintIncentivePool = _mintIncentivePool;
    }

    function setCollateralIncentivePool(address _collateralIncentivePool) external onlyGov {
        emit SetCollateralIncentivePool(collateralIncentivePool, _collateralIncentivePool, block.timestamp);

        collateralIncentivePool = _collateralIncentivePool;
    }

    // ========= GETTER =============== //

    // returns price in 18 decimals vitual function
    function getAssetPrice() public view virtual returns (uint256);

    function totalCollateralAmount() public view virtual returns (uint256) {
        return address(collateralAsset) == address(0) ? address(this).balance : collateralAsset.balanceOf(address(this));
    }

    function getAsset() external view returns (address) {
        return address(collateralAsset);
    }

    function collateralRatio(address user) external view virtual returns (uint256) {
        return ((collateralAmount[user] * getAssetPrice() * 10000) / getBorrowedOf(user) / _adjustDecimals());
    }

    function getBorrowedOf(address user) public view virtual returns (uint256) {
        return borrowedAmount[user] + feeUnpaid[user] + getUserFee(user);
    }

    function getUserFee(address user) public view returns (uint256) {
        uint256 _feePerShare = feePerShare + (_newFee() * 1e18) / poolIssuedUSD;

        return (borrowedAmount[user] * _feePerShare) / 1e18 - feeDebt[user];
    }

    // ========= INTERNAL =============== //

    // check after every function that changes user status,  collateral ratio is above safeCollateralRatio
    function _inSafeZone(address user, uint256 price) internal view virtual returns (bool) {
        require(
            ((collateralAmount[user] * price * 10000) / getBorrowedOf(user) / _adjustDecimals()) >= safeCollateralRatio,
            "collateral ratio is Below safeCollateralRatio"
        );

        return true;
    }

    function _adjustDecimals() internal view virtual returns (uint256) {
        uint8 decimals;
        if (address(collateralAsset) == address(0)) {
            decimals = 18;
        } else {
            decimals = IERC20Detailed(address(collateralAsset)).decimals();
        }
        return 10 ** uint256(decimals);
    }

    function _updateFee() internal {
        if (block.timestamp > feeUpdatedAt && poolIssuedUSD > 0) {
            // 1. mint interest
            uint256 generatedFee = _newFee();
            if (generatedFee > 0) {
                usdAsset.mint(feeReceiver, generatedFee);

                emit FeeAccrued(feeReceiver, generatedFee, block.timestamp);
            }

            // 2. update feePerShare
            feePerShare = feePerShare + (_newFee() * 1e18) / poolIssuedUSD;
        }

        feeUpdatedAt = block.timestamp;
    }

    function _newFee() internal view returns (uint256) {
        return (poolIssuedUSD * mintInterest * (block.timestamp - feeUpdatedAt)) / (86400 * 365) / 10000;
    }

    // ========= MUTABLES =============== //

    function mint(uint256 assetAmount, uint256 mintAmount) external payable virtual {
        if (assetAmount > 0) {
            if (collateralIncentivePool != address(0)) {
                try IMultiIncentive(collateralIncentivePool).refreshReward(msg.sender) {} catch {}
            }

            _safeTransferIn(msg.sender, assetAmount);
            collateralAmount[msg.sender] += assetAmount;

            emit Deposit(msg.sender, assetAmount, block.timestamp);
        }

        if (mintAmount > 0) {
            uint256 assetPrice = getAssetPrice();
            _mint(msg.sender, mintAmount, assetPrice);
        }
    }

    function withdraw(uint256 amount) external virtual {
        require(amount > 0, " > 0 ");
        _withdraw(msg.sender, amount);
    }

    function repay(address onBehalfOf, uint256 amount) external virtual {
        require(onBehalfOf != address(0), " != address(0)");
        require(amount > 0, " > 0 ");
        _repay(msg.sender, onBehalfOf, amount);
    }

    function _mint(address _user, uint256 _mintAmount, uint256 _assetPrice) internal virtual {
        require(poolIssuedUSD + _mintAmount <= maxTotalMintAmount, "mint amount exceeds maximum mint amount");
        require(_mintAmount >= minMintAmount, "mint amount is below minimum mint amount");

        _updateFee();

        // try to call minterIncentivePool to refresh reward before update mint status
        if (mintIncentivePool != address(0)) {
            try IMultiIncentive(mintIncentivePool).refreshReward(_user) {} catch {}
        }

        if (borrowedAmount[_user] > 0) {
            uint256 generatedFee = getUserFee(_user);
            feeUnpaid[_user] += generatedFee;

            emit FeeAccrued(_user, generatedFee, block.timestamp);
        }

        uint256 mintFeeAmount = (_mintAmount * mintFee) / 10000;

        uint256 debtMintAmount = _mintAmount + mintFeeAmount;

        borrowedAmount[_user] += debtMintAmount; // increase debt
        poolIssuedUSD += debtMintAmount; // increase pool debt

        usdAsset.mint(_user, _mintAmount); // mint usdAsset excluding fee
        usdAsset.mint(feeReceiver, mintFeeAmount); // mint usdAsset fee to feeReceiver

        feeDebt[_user] = (borrowedAmount[_user] * feePerShare) / 1e18; // update feeDebt

        // check if user is in safe zone
        _inSafeZone(_user, _assetPrice);

        emit Mint(_user, _mintAmount, block.timestamp);
        emit FeeAccrued(_user, mintFeeAmount, block.timestamp);
    }

    function _repay(address _user, address _onBehalfOf, uint256 _amount) internal virtual {
        require(getBorrowedOf(_onBehalfOf) >= _amount, "repay amount exceeds borrowed amount");
        if (mintIncentivePool != address(0)) {
            try IMultiIncentive(mintIncentivePool).refreshReward(_onBehalfOf) {} catch {}
        }

        _updateFee();

        uint256 generatedFee = getUserFee(_onBehalfOf);
        if (generatedFee > 0) {
            feeUnpaid[_onBehalfOf] += generatedFee;

            emit FeeAccrued(_onBehalfOf, generatedFee, block.timestamp);
        }

        // 1. if there is feeUnpaid, repay fee first
        if (feeUnpaid[_onBehalfOf] > 0) {
            uint256 repayFee = _amount >= feeUnpaid[_onBehalfOf] ? feeUnpaid[_onBehalfOf] : _amount;

            // deduct fee unpaid , can be zero;
            feeUnpaid[_onBehalfOf] -= repayFee;
            usdAsset.transferFrom(_user, feeReceiver, repayFee);

            _amount -= repayFee;
        }

        if (_amount > 0) {
            usdAsset.transferFrom(_user, address(this), _amount);
            usdAsset.burn(address(this), _amount);

            borrowedAmount[_onBehalfOf] -= _amount;
            poolIssuedUSD -= _amount;
        }

        feeDebt[_onBehalfOf] = (borrowedAmount[_onBehalfOf] * feePerShare) / 1e18;

        emit Repay(_user, _onBehalfOf, _amount, block.timestamp);
    }

    function _withdraw(address _user, uint256 _amount) internal {
        require(collateralAmount[_user] >= _amount, "Withdraw amount exceeds deposited amount.");

        if (collateralIncentivePool != address(0)) {
            try IMultiIncentive(collateralIncentivePool).refreshReward(_user) {} catch {}
        }

        collateralAmount[_user] -= _amount;
        _safeTransferOut(_user, _amount);

        if (borrowedAmount[_user] > 0) {
            _inSafeZone(_user, getAssetPrice());
        }
        emit Withdraw(_user, _amount, block.timestamp);
    }

    /// @notice redemption func usdAsset to get collateral asset selecting any collateral provider with fee
    /// @param _target address of collateral provider
    /// @param _repayAmount amount of usdAsset to repay
    /// @return uint256 that returns amount of collateral asset to get
    function redeem(address _target, uint256 _repayAmount) external virtual returns (uint256) {
        require(_repayAmount > 0, " > 0 ");

        // 1. repay usdAsset
        _repay(msg.sender, _target, _repayAmount);

        uint256 assetPrice = getAssetPrice();
        uint256 assetAmount = (_repayAmount * _adjustDecimals()) / assetPrice;

        // 2. current mode
        uint256 currentPoolCollateralRatio =
            ((totalCollateralAmount() * assetPrice * 10000) / poolIssuedUSD / _adjustDecimals());

        uint256 redemptionFee =
            currentPoolCollateralRatio >= protectionCollateralRatio ? normalRedemptionFee : protectionRedemptionFee;

        assetAmount = (assetAmount * (10000 - redemptionFee)) / 10000;

        if (collateralIncentivePool != address(0)) {
            try IMultiIncentive(collateralIncentivePool).refreshReward(_target) {} catch {}
        }
        collateralAmount[_target] -= assetAmount;
        _safeTransferOut(msg.sender, assetAmount);

        emit Redemption(msg.sender, _target, _repayAmount, assetAmount, block.timestamp);

        if (borrowedAmount[_target] > 0) {
            require(
                ((collateralAmount[_target] * assetPrice * 10000) / getBorrowedOf(_target) / _adjustDecimals())
                    >= liquidationCollateralRatio,
                "collateral ratio is Below liquidationCollateralRatio, try liquidation"
            );
        }

        return assetAmount;
    }

    function liquidation(
        address onBehalfOf,
        uint256 assetAmount // collateral asset amount
    ) external virtual {
        uint256 assetPrice = getAssetPrice();
        uint256 onBehalfOfCollateralRatio =
            (collateralAmount[onBehalfOf] * assetPrice * 10000) / getBorrowedOf(onBehalfOf) / _adjustDecimals();
        require(
            onBehalfOfCollateralRatio < liquidationCollateralRatio,
            "Borrowers collateral ratio should below badCollateralRatio"
        );

        require(assetAmount * 2 <= collateralAmount[onBehalfOf], "a max of 50% collateral can be liquidated");

        uint256 usdAssetAmount = (assetAmount * assetPrice) / _adjustDecimals();

        _repay(msg.sender, onBehalfOf, usdAssetAmount);

        uint256 bonusAmount = (assetAmount * liquidationBonus) / 10000;

        uint256 protocolAmount = (bonusAmount * liquidationProtocolRatio) / 10000;

        uint256 reducedAsset = assetAmount + bonusAmount;

        if (collateralIncentivePool != address(0)) {
            try IMultiIncentive(collateralIncentivePool).refreshReward(onBehalfOf) {} catch {}
        }
        collateralAmount[onBehalfOf] -= reducedAsset;
        _safeTransferOut(msg.sender, reducedAsset - protocolAmount);
        _safeTransferOut(feeReceiver, protocolAmount);

        emit Liquidate(onBehalfOf, msg.sender, usdAssetAmount, reducedAsset, protocolAmount, block.timestamp);
    }

    function _safeTransferIn(address from, uint256 amount) internal virtual returns (bool) {
        if (address(collateralAsset) == address(0)) {
            require(msg.value == amount, "invalid msg.value");
            return true;
        } else {
            uint256 before = collateralAsset.balanceOf(address(this));
            collateralAsset.transferFrom(from, address(this), amount);
            require(collateralAsset.balanceOf(address(this)) >= before + amount, "transfer in failed");
            return true;
        }
    }

    function _safeTransferOut(address to, uint256 amount) internal virtual returns (bool) {
        if (address(collateralAsset) == address(0)) {
            (bool suc,) = payable(to).call{value: amount}("");
            require(suc, "transfer out failed");
            return true;
        } else {
            collateralAsset.transfer(to, amount);
            return true;
        }
    }

    /* Events */

    event Deposit(address indexed account, uint256 collateralAmount, uint256 timestamp);
    event Withdraw(address indexed account, uint256 collateralAmount, uint256 timestamp);
    event Mint(address indexed account, uint256 mintAmount, uint256 timestamp);
    event FeeAccrued(address indexed account, uint256 feeAmount, uint256 timestamp);
    event Repay(address account, address indexed onbehalfOf, uint256 repayAmount, uint256 timestamp);

    event Redemption(
        address account, address indexed provider, uint256 usdAssetAmount, uint256 assetAmount, uint256 timestamp
    );

    event Liquidate(
        address indexed accountToLiquidate,
        address indexed liquidator,
        uint256 repayAmount,
        uint256 collateralAmount,
        uint256 protocolAmount,
        uint256 timestamp
    );

    event SetGov(address prevAddress, address newAddress, uint256 timestamp);
    event SetFeeReceiver(address prevAddress, address newAddress, uint256 timestamp);
    event SetPriceCalculator(address prevAddress, address newAddress, uint256 timestamp);
    event SetMintIncentivePool(address prevAddress, address newAddress, uint256 timestamp);

    event SetCollateralIncentivePool(address prevAddress, address newAddress, uint256 timestamp);

    event SetPoolConfiguration(
        uint256 maxTotalMintAmount,
        uint256 minMintAmount,
        uint256 mintFee,
        uint256 mintInterest,
        uint256 normalRedemptionFee,
        uint256 protectionRedemptionFee,
        uint256 safeCollateralRatio,
        uint256 protectionCollateralRatio,
        uint256 liquidationCollateralRatio,
        uint256 liquidationBonus,
        uint256 liquidationProtocolRatio,
        uint256 timestamp
    );

    uint256[50] private __gap;

    receive() external payable {}
}
