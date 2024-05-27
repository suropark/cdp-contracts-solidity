// SPDX-License-Identifier: UNLICENSED

import "../interfaces/IPriceCalculator.sol";

contract MockPrimaryOracle is IPriceCalculator {
    address internal constant NATIVE = 0x0000000000000000000000000000000000000000;
    uint256 private constant THRESHOLD = 7 days;

    /* ========== STATE VARIABLES ========== */
    address public gov;
    address public keeper;
    mapping(address => ReferenceData) public references; // 8 decimals of precision

    /* ========== MODIFIERS ========== */

    /// @dev `msg.sender` 가 keeper 또는 owner 인지 검증
    modifier onlyKeeper() {
        require(msg.sender == keeper || msg.sender == gov, "PriceCalculator: caller is not the owner or keeper");
        _;
    }

    /* ========== INITIALIZER ========== */

    constructor() {
        gov = msg.sender;
        keeper = msg.sender;

        references[NATIVE] = ReferenceData({lastData: 2e18, lastUpdated: block.timestamp});
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setKeeper(address _keeper) external onlyKeeper {
        require(_keeper != address(0), "PriceCalculator: invalid keeper address");
        keeper = _keeper;
    }

    /// @notice Set price by keeper
    /// @param assets Array of asset addresses to set
    /// @param prices Array of asset prices to set
    /// @param timestamp Timstamp of price information
    function setPrices(address[] memory assets, uint256[] memory prices, uint256 timestamp) external onlyKeeper {
        require(
            timestamp <= block.timestamp && block.timestamp - timestamp <= THRESHOLD,
            "PriceCalculator: invalid timestamp"
        );

        for (uint256 i = 0; i < assets.length; i++) {
            references[assets[i]] = ReferenceData({lastData: prices[i], lastUpdated: block.timestamp});
        }
    }

    /* ========== VIEWS ========== */

    function priceOf(address asset) public view override returns (uint256 priceInUSD) {
        if (asset == address(0)) {
            return priceOfETH();
        }

        ReferenceData memory data = references[asset];

        return data.lastData;
    }

    function priceOfETH() public view returns (uint256 priceInUSD) {
        ReferenceData memory data = references[NATIVE];

        return data.lastData;
    }
}
