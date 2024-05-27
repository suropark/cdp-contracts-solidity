// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "../interfaces/IPriceCalculator.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PrimaryOracle is IPriceCalculator, OwnableUpgradeable {
    uint256 private THRESHOLD;

    IPriceCalculator public primaryPriceCalculator; // primary oracle
    IPriceCalculator public secondaryPriceCalculator; // secondary oracle

    mapping(address => ReferenceData) public references; // 18 decimals of precision, fallback

    mapping(address => bool) public isReporter;

    modifier onlyReporter() {
        require(isReporter[msg.sender], "PrimaryOracle: caller is not the reporter");
        _;
    }

    function initialize() external initializer {
        __Ownable_init();

        isReporter[msg.sender] = true;
        THRESHOLD = 15 minutes;
    }

    function priceOf(address asset) external view returns (uint256) {
        uint256 price;
        try primaryPriceCalculator.priceOf(asset) returns (uint256 primaryPrice) {
            price = primaryPrice;
        } catch {
            try secondaryPriceCalculator.priceOf(asset) returns (uint256 secondaryPrice) {
                price = secondaryPrice;
            } catch {
                ReferenceData memory referenceToken = references[asset];

                if (block.timestamp - referenceToken.lastUpdated > THRESHOLD) {
                    revert("price is too old");
                }

                price = referenceToken.lastData;
            }
        }

        if (price == 0) {
            revert("price is zero");
        }

        return price;
    }

    function setThreshold(uint256 _threshold) external onlyOwner {
        THRESHOLD = _threshold;

        emit SetThreshold(_threshold);
    }

    function setPrice(address asset, uint256 price) external onlyReporter {
        references[asset] = ReferenceData(price, block.timestamp);

        emit SetPrice(asset, price);
    }

    function setPrices(address[] calldata assets, uint256[] calldata prices) external onlyReporter {
        for (uint256 i = 0; i < assets.length; i++) {
            references[assets[i]] = ReferenceData(prices[i], block.timestamp);

            emit SetPrice(assets[i], prices[i]);
        }
    }

    function setReporter(address reporter, bool enabled) external onlyOwner {
        isReporter[reporter] = enabled;

        emit SetReporter(reporter, enabled);
    }

    function setPrimaryPriceCalculator(address _primaryPriceCalculator) external onlyOwner {
        primaryPriceCalculator = IPriceCalculator(_primaryPriceCalculator);

        emit SetPrimaryPriceCalculator(_primaryPriceCalculator);
    }

    event SetThreshold(uint256 threshold);
    event SetPrice(address indexed asset, uint256 price);
    event SetReporter(address indexed reporter, bool enabled);
    event SetPrimaryPriceCalculator(address indexed primaryPriceCalculator);
}
