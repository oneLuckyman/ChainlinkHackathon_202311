// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// 分账的目标地址：算法提出者，投资人、运营商或工程师，艺术家（NFT 资产持有者）

// 用 mapping 记录所有的分账目标的份额，地址等信息
// 支付功能
// 根据身份进行提款的功能

// 需要用 Chainlink 来定期根据数据库提供份额信息

// 定义一个与 Stakeholders 合约的 stakeholderInfo 相同的 struct
struct stakeholderInfo {
    string name;
    address payable payee;
    string asset;
    bool approval;
}

interface IStakeholders {
    function getStakeholderInfo() external view returns (stakeholderInfo memory);
}

contract Web3NST {
    IStakeholders[] stakeholdersInterfaces;

    function loadStakeholder(address _stakeholderAddress) public {
        stakeholdersInterfaces.push(IStakeholders(_stakeholderAddress));
    }

    function retrieveStakeholderInfo(uint256 _index) public view returns (stakeholderInfo memory) {
        return stakeholdersInterfaces[_index].getStakeholderInfo();
    }
}