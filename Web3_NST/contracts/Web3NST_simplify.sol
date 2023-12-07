// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Web3NST 的简化版本，为了方便演示，只有收钱发钱和记录的功能

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

contract Web3NST_simplify is FunctionsClient, ConfirmedOwner {
    /* Chainlink Automation Functions */
    error NotAllowedCaller(
        address caller,
        address owner,
        address automationRegistry
    );
    error UnexpectedRequestID(bytes32 requestId);
    
    event Response(bytes32 indexed requestId, bytes response, bytes err);

    address public upkeepContract;
    bytes public request;
    uint64 public subscriptionId;
    uint32 public gasLimit;
    bytes32 public donID;
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    /// Web3NST
    // Error
    error Web3NST__NotOperator();
    error Web3NST__InsufficientFunds();
    error Web3NST__IncorrectAmount();

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
    mapping (address => string) private metadata;

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

    /* Chainlink Automation Functions */
    // 限定 owner 或 upkeepContract 才能调用
    modifier onlyAllowed() {
        if (msg.sender != owner() && msg.sender != upkeepContract)
            revert NotAllowedCaller(msg.sender, owner(), upkeepContract);
        _;
    }

    /* Chainlink Automation Functions */
    // 设置 upkeepContract 这是 onlyAllowed 的授权之一
    function setAutomationCronContract(
        address _upkeepContract
    ) external onlyOwner {
        upkeepContract = _upkeepContract;
    }

    /* Chainlink Automation Functions */
    // 配置请求的详细信息参数
    function updateRequest(
        bytes memory _request,
        uint64 _subscriptionId,
        uint32 _gasLimit,
        bytes32 _donID
    ) external onlyOwner {
        request = _request;
        subscriptionId = _subscriptionId;
        gasLimit = _gasLimit;
        donID = _donID;
    }

    /* Chainlink Automation Functions */
    // 发送一个预编码的 CBOR 请求
    function sendRequestCBOR()
        external
        onlyAllowed
        returns (bytes32 requestId)
    {
        s_lastRequestId = _sendRequest(
            request,
            subscriptionId,
            gasLimit,
            donID
        );
        return s_lastRequestId;
    }

    /* Chainlink Automation Functions */
    // 存储最近一次响应返回的结果
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId);
        }
        s_lastResponse = response;
        s_lastError = err;
        emit Response(requestId, s_lastResponse, s_lastError);
        // 添加响应处理逻辑
        totalUnionStakes += uint256(bytes32(response));
        uint256 remainder = totalUnionStakes % unionMembers.length;
        uint256 distributedStake = totalUnionStakes / unionMembers.length;
        unionMemberStakes[unionMembers[0]] += remainder;
        for (uint i = 0; i < unionMembers.length; i++) {
            unionMemberStakes[unionMembers[i]] += distributedStake;
        }
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
    function distributeFunds() public payable onlyOperator {
        // 暂时没有添加重入攻击防御
        uint256 distributedAmount  = address(this).balance;

        if(distributedAmount < minimumWithdrawalAmount){revert Web3NST__InsufficientFunds();}
        uint256 unionMembersAmount = distributedAmount * stakes[StakeholderType.UnionMember] / distributionFraction;
        uint256 otherStakeholdersAmount = distributedAmount * stakes[StakeholderType.OtherStakeholders] / distributionFraction;
        uint256 operatorAmount = distributedAmount * stakes[StakeholderType.Operator] / distributionFraction;

        for (uint i = 0; i < unionMembers.length; i++) {
            address unionMemberAddress = unionMembers[i];
            uint256 unionMemberStake = unionMemberStakes[unionMemberAddress];

            // 计算该成员应获得的款项
            uint256 unionMemberPayment = unionMembersAmount * unionMemberStake / totalUnionStakes;
            // 如果该成员这一次没有任何分账就跳到下一个成员的分账计算上
            if (unionMemberPayment == 0) {continue;}

            // 向该成员发送资金
            (bool PayToUnionMember, ) = payable(unionMemberAddress).call{value: unionMemberPayment}("");
            unionMemberStakes[unionMemberAddress] = 0;
        }
        totalUnionStakes = 0;

        (bool PayToOtherStakeholders, ) = payable(otherStakeholdersAddress).call{value: otherStakeholdersAmount}("");
        (bool PayToOperatorContract, ) = payable(operatorAddress).call{value: operatorAmount}("");
    }

    /* Getter */
    // 获取当前服务费价格
    function getServiceFee() public view returns (uint256) {
        return serviceFee;
    }

    // 获取当前最低提款额度
    function getMinimumWithdrawalAmount() public view returns (uint256) {
        return minimumWithdrawalAmount;
    }

    // 获取一位工会成员的份额信息
    function retrieveUnionMemberStake(address _unionMemberAddress) public view returns (uint256) {
        return unionMemberStakes[_unionMemberAddress];
    }

    // 获取当前的总份额信息
    function retrieveTotalUnionStakes() public view returns (uint256) {
        return totalUnionStakes;
    }

    /* Setter */
    // 添加一个 UnionMember
    function addUnionMember(address _unionMemberAddress) public onlyOperator {
        unionMembers.push(_unionMemberAddress);
        unionMemberStakes[_unionMemberAddress] = 0;
    }

    // 设置某个地址的 metadata
    function setMetadata(address _address, string memory _metadata) public onlyOperator {
        metadata[_address] = _metadata;
    }

    // 设置当前服务费
    function setServiceFee(uint256 _serviceFee) public onlyOperator {
        serviceFee = _serviceFee;
    }

    // 设置最低提款额度
    function setMinimumWithdrawalAmount(uint256 _minimumWithdrawalAmount) public onlyOperator {
        minimumWithdrawalAmount = _minimumWithdrawalAmount;
    }

    // 设置一个成员的份额，测试用
    function setUnionMemberStake(address _unionMemberAddress, uint256 _stake) public onlyOperator {
        unionMemberStakes[_unionMemberAddress] = _stake;
        totalUnionStakes = totalUnionStakes + _stake;
    }
}