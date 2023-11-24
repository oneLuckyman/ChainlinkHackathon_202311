// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// 分账的目标地址：算法提出者，投资人、运营商或工程师，艺术家（NFT 资产持有者）

// 用 mapping 记录所有的分账目标的份额，地址等信息
// 支付功能
// 根据身份进行提款的功能

// 需要用 Chainlink 来定期根据数据库提供份额信息

// Error
error Web3NST__IncorrectAmount();
error Web3NST__NotOperator();
error Web3NST__UnionNotApproval();
error Web3NST__InsufficientFunds();

// 定义一个与 UnionMembers 和 OtherStakeholders 合约相同的 struct
struct unionMemberInfo {
    string name;
    address payable payee;
    string asset;
    bool approval;
}

struct otherStakeholderInfo {
    string name;
    address payable payee;
    string asset;
}


/* Interfaces */
interface IUnionMembers {
    function getUnionMemberInfo() external view returns (unionMemberInfo memory);
}

interface IOtherStakeholders {
    function getOtherStakeholderInfo() external view returns (otherStakeholderInfo memory);
}

contract Web3NST {
    /* Type declarations */
    // 总的身份类型有三种
    enum StakeholderType {
        Operator;
        UnionMember;
        OtherStakeholder;
    }

    /* State Variables */
    address private operatorAddress;
    uint256 private serviceFee;
    IUnionMembers[] private unionMemberInterfaces;
    IOtherStakeholders[] private otherStakeholderInterfaces;
    uint256 private distributionFraction;
    mapping (StakeholderType => uint) private stakes;
    mapping (address => uint) unionStakes;
    mapping (address => uint) otherStakeholderStakes;
    uint256 private minimumWithdrawalAmount;

    // 构造函数
    constructor(uint256 _serviceFee) {
        operatorAddress = msg.sender;   // 服务运营商负责部署本合约
        serviceFee = _serviceFee;       // 确定一个初始的服务费
        minimumWithdrawalAmount = 100;  // 给定一个初始的最小提取金额
        distributionFraction = 10;      // 定下一个分账比例分数
        stakes[StakeholderType.Operator] = 7;           // Operator 拿 7/10
        stakes[StakeholderType.UnionMember] = 2;        // UnionMember 拿 2/10
        stakes[StakeholderType.OtherStakeholder] = 1;   // OtherStakeholder 拿 1/10
    }

    /* Modifier */
    // 修饰器 onlyOperator
    modifier onlyOperator() {
        if(msg.sender != s_owner){revert Web3NST__NotOperator();}
        _;
    }

    // 修饰器 unionApproval
    modifier unionApproval() {
        _;
    }

    /* Payment */
    // 通知运营商服务器的事件
    event PaymentReceived(address sender, uint amount);

    // 接收资金时触发事件
    function receivePayment() external payable {
        if(msg.value != serviceFee){revert Web3NST__IncorrectAmount();}
        emit PaymentReceived(msg.sender, msg.value);
    }

    /* Withdraw */
    function distributeFunds() public onlyOperator unionApproval {
        uint distributedAmount  = (address(this).balance / minimumWithdrawalAmount) * minimumWithdrawalAmount;
        if(distributedAmount < minimumWithdrawalAmount){revert Web3NST__InsufficientFunds();}
        uint unionMembersAmount = distributedAmount * stakes[StakeholderType.UnionMember] / distributionFraction
        uint otherStakeholdersAmount = distributedAmount * stakes[StakeholderType.OtherStakeholder] / distributionFraction
        uint operatorAmount = distributedAmount * stakes[StakeholderType.OtherStakeholder] / distributionFraction

        // for (uint)


        (bool PayToOperator, ) = payable(operatorAddress).call{value: operatorAmount}("");
    }

    /* Getter */
    // 获取当前服务费
    function getServiceFee() public view returns (uint256) {
        return serviceFee;
    }

    // 获取当前最低提款额度
    function getMinimumWithdrawalAmount() public view returns (uint256) {
        return minimumWithdrawalAmount;
    }

    /* Setter */
    // 设置当前服务费
    function setServiceFee(uint256 _serviceFee) public onlyOperator unionApproval {
        serviceFee = _serviceFee;
    }

    // 设置最低提款额度
    function setMinimumWithdrawalAmount(uint256 _minimumWithdrawalAmount) public onlyOperator unionApproval {
        minimumWithdrawalAmount = _minimumWithdrawalAmount
    }





    // 添加一个其他利益相关者
    function addOtherStakeholder(address _otherStakeholderAddress) public onlyOperator {
        otherStakeholderInterfaces.push(IOtherStakeholders(_otherStakeholderAddress));
    }

    // 获取一个其他利益相关者的信息
    function retrieveOtherStakeholderInfo(uint256 _index) public view returns (otherStakeholderInfo memory) {
        return otherStakeholderInterfaces[_index].getOtherStakeholderInfo();
    }
}