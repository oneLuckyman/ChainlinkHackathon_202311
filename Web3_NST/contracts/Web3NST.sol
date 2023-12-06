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
error Web3NST__UnionVeto();
error Web3NST__InsufficientFunds();
error Web3NST__PayToUnionMemberFailed();
error Web3NST__PayToOtherStakeholders();
error Web3NST__PayToOperator();

// 定义一个与 UnionMembers 和 OtherStakeholders 合约相同的 struct
struct unionMemberInfo {
    string name;
    address payable payeeAddress;
    string asset;
    bool approval;
    bool veto;
}

struct otherStakeholdersInfo {
    string name;
    address payable payeeAddress;
    string asset;
}


/* Interfaces */
interface IUnionMembers {
    function getUnionMemberInfo() external view returns (unionMemberInfo memory);
}

interface IOtherStakeholders {
    function getOtherStakeholdersInfo() external view returns (otherStakeholdersInfo memory);
}

contract Web3NST {
    /* Type declarations */
    // 总的身份类型有三种
    enum StakeholderType {
        Operator,
        UnionMember,
        OtherStakeholders
    }

    /* State Variables */
    address private operatorAddress;
    address private operatorPayeeAddress;
    uint256 private serviceFee;
    mapping (StakeholderType => uint256) private stakes;

    address[] private unionMembers;
    mapping (address => IUnionMembers) private unionMembersInterface;
    uint256 private totalUnionStakes;                           // 初始总份额为 0，每当为用户进行一个 NST 服务就会增加 1，在运营商数据库中统计
    mapping (address => uint256) private unionMemberStakes;     // 记录每位成员贡献的份额数量

    address private otherStakeholdersAddress;
    IOtherStakeholders otherStakeholdersInterface;

    uint256 private distributionFraction;
    uint256 private minimumWithdrawalAmount;

    // 构造函数
    constructor(uint256 _serviceFee, address _otherStakeholdersAddress) {
        operatorAddress = msg.sender;       // 服务运营商负责部署本合约
        operatorPayeeAddress = msg.sender;  // 默认运营商收款地址为部署者地址
        serviceFee = _serviceFee;           // 确定一个初始的服务费
        minimumWithdrawalAmount = 100;      // 给定一个初始的最小提取金额
        distributionFraction = 10;          // 给定一个分账比例分数
        otherStakeholdersAddress = _otherStakeholdersAddress;
        otherStakeholdersInterface = IOtherStakeholders(_otherStakeholdersAddress);
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

    // 修饰器 unionApproval
    modifier unionApproval() {
        for (uint i = 0; i < unionMembers.length; i++) {
            if(!retrieveUnionMemberInfo(unionMembers[i]).approval){revert Web3NST__UnionNotApproval();}
        }
        _;
    }

    // 修饰器 unionVeto
    modifier unionVeto {
        for (uint i = 0; i < unionMembers.length; i++) {
            if(retrieveUnionMemberInfo(unionMembers[i]).veto){revert Web3NST__UnionVeto();}
        }
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
    function distributeFunds() public payable onlyOperator unionVeto {
        // 暂时没有添加重入攻击防御
        uint256 distributedAmount  = address(this).balance;

        if(distributedAmount < minimumWithdrawalAmount){revert Web3NST__InsufficientFunds();}
        uint256 unionMembersAmount = distributedAmount * stakes[StakeholderType.UnionMember] / distributionFraction;
        uint256 otherStakeholdersAmount = distributedAmount * stakes[StakeholderType.OtherStakeholders] / distributionFraction;
        uint256 operatorAmount = distributedAmount * stakes[StakeholderType.Operator] / distributionFraction;

        for (uint i = 0; i < unionMembers.length; i++) {
            address unionMemberAddress = unionMembers[i];
            address unionMemberPaymentAddress = retrieveUnionMemberInfo(unionMemberAddress).payeeAddress;
            uint256 unionMemberStake = unionMemberStakes[unionMemberAddress];

            // 计算该成员应获得的款项
            uint256 unionMemberPayment = unionMembersAmount * unionMemberStake / totalUnionStakes;

            // 向该成员发送资金
            (bool PayToUnionMember, ) = payable(unionMemberPaymentAddress).call{value: unionMemberPayment}("");
            if(!PayToUnionMember) {
                (bool PayToUnionMemberContract, ) = payable(unionMemberAddress).call{value: unionMemberPayment}("");    // 如果此处打款失败，就把款项支付到成员的合约地址上
            }
            unionMemberStakes[unionMemberAddress] = 0;
        }

        address otherStakeholdersPaymentAddress = retrieveOtherStakeholdersInfo().payeeAddress;
        (bool PayToOtherStakeholders, ) = payable(otherStakeholdersPaymentAddress).call{value: otherStakeholdersAmount}("");
        if(!PayToOtherStakeholders) {
            (bool PayToOtherStakeholdersContract, ) = payable(otherStakeholdersAddress).call{value: otherStakeholdersAmount}("");   // 如果此处打款失败，就把款项支付到 OtherStakeholders 合约地址上
        }

        (bool PayToOperatorContract, ) = payable(operatorPayeeAddress).call{value: operatorAmount}("");
        if(!PayToOperator) {
            (bool PayToOperatorOwner, ) = payable(operatorAddress).call{value: operatorAmount}("");   // 如果此处打款失败，就把款项支付到运营商地址上
        }
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

    // 获取一位工会成员的信息
    function retrieveUnionMemberInfo(address _unionMemberAddress) public view returns (unionMemberInfo memory) {
        return unionMembersInterface[_unionMemberAddress].getUnionMemberInfo();
    }

    // 获取其他利益相关者的信息
    function retrieveOtherStakeholdersInfo() public view returns (otherStakeholdersInfo memory) {
        return otherStakeholdersInterface.getOtherStakeholdersInfo();
    }

    /* Setter */
    // 设置当前服务费
    function setServiceFee(uint256 _serviceFee) public onlyOperator unionApproval {
        serviceFee = _serviceFee;
    }

    // 设置运营商收款地址
    function setOperatorPayeeAddress(address _operatorPayeeAddress) public onlyOperator {
        operatorPayeeAddress = _operatorPayeeAddress;
    }

    // 设置最低提款额度
    function setMinimumWithdrawalAmount(uint256 _minimumWithdrawalAmount) public onlyOperator unionApproval {
        minimumWithdrawalAmount = _minimumWithdrawalAmount;
    }

    // 添加一位工会成员的合约接口
    function addUnionMember(address _unionMemberAddress) public onlyOperator {
        unionMembers.push(_unionMemberAddress);
        unionMembersInterface[_unionMemberAddress] = IUnionMembers(_unionMemberAddress);
    }
}