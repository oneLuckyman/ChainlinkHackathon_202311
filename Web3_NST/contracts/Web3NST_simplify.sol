// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Web3NST 的简化版本，为了方便演示，只有收钱发钱和记录的功能

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

contract Web3NST_simplify is FunctionsClient, ConfirmedOwner {
    // Error
    error Web3NST__NotOperator();
    error NotAllowedCaller(
        address caller,
        address owner,
        address automationRegistry
    );

    /* Type declarations */
    // 总的身份类型有三种
    enum StakeholderType {
        Operator,
        UnionMember,
        OtherStakeholders
    }

    /* State Variables */
    address private operatorAddress;
    uint256 private serviceFee;
    mapping (StakeholderType => uint256) private stakes;

    address[] private unionMembers;
    uint256 private totalUnionStakes;
    mapping (address => uint256) private unionMemberStakes;
    address private otherStakeholdersAddress;
    mapping (address => string) metadata;

    uint256 private distributionFraction;
    uint256 private minimumWithdrawalAmount;

    // 构造函数
    constructor(
        address router, uint256 _serviceFee, address _otherStakeholdersAddress
    ) FunctionsClient(router) ConfirmedOwner(msg.sender) {
        operatorAddress = msg.sender;
        serviceFee = _serviceFee;
        minimumWithdrawalAmount = 1 ether;
        distributionFraction = 10;
        otherStakeholdersAddress = _otherStakeholdersAddress;
        stakes[StakeholderType.Operator] = 7;           // Operator 拿 7/10
        stakes[StakeholderType.UnionMember] = 2;        // UnionMember 拿 2/10
        stakes[StakeholderType.OtherStakeholders] = 1;  // OtherStakeholders 拿 1/10
    }

    /* Modifier */
    // 修饰器 onlyOperator
    modifier onlyOperator() {
        if(msg.sender != operatorAddress){revert Web3NST__NotOperator();}
        _;
    }

    // 限定 owner 或 upkeepContract 才能调用
    modifier onlyAllowed() {
        if (msg.sender != owner() && msg.sender != upkeepContract)
            revert NotAllowedCaller(msg.sender, owner(), upkeepContract);
        _;
    }

    /* Setter */
    // 设置 upkeepContract
    function setAutomationCronContract(
        address _upkeepContract
    ) external onlyOwner {
        upkeepContract = _upkeepContract;
    }

    // 添加一个 UnionMember
    function addUnionMember(address _unionMemberAddress) public onlyOperator {
        unionMembers.push(_unionMemberAddress);
        unionMemberStakes[_unionMemberAddress] = 0;
    }


    /* Payment */
    // 通知运营商服务器的事件
    event PaymentReceived(address sender, uint amount);

    // 接收资金时触发事件
    function receivePayment() external payable {
        if(msg.value != serviceFee){revert Web3NST__IncorrectAmount();}
        emit PaymentReceived(msg.sender, msg.value);
    }

    // 发钱
    function distributeFunds() public payable onlyOperator {}

    // 设置 upkeepContract
    function setAutomationCronContract(
        address _upkeepContract
    ) external onlyOwner {
        upkeepContract = _upkeepContract;
    }

}