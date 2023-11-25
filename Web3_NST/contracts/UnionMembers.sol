// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Error
error UnionMembers__NowOwner();
error UnionMembers__NotForSale();
error UnionMembers__InsufficientFunds();

contract UnionMembers {
    /* Type declarations */
    // 销售状态
    enum stateForSale {
        NotForSale,
        IsForSale
    }

    // UnionMembers 信息
    struct unionMemberInfo {
        string name;            // 工会成员的称呼
        address payee;          // 收款地址
        string asset;           // 指向资产的元数据，可以是作品链接，论文地址，运营商地址，JSON 链接等
        bool approval;          // 默认为 false，每当有重大决策需要投票时，所有工会成员需要手动改为 true 才能使决策落地。
        bool veto;              // 默认为 false，一旦工会成员有对日常事务存在质疑，就可以发起 veto，以阻止链上信息的进一步改变
    }

    /* State Variables */
    address private immutable i_creator;
    address private s_owner;
    stateForSale private saleState;
    uint256 private salePrice;
    unionMemberInfo private personalInfo;

    // 构造函数
    constructor(uint256 _price) {
        i_creator = msg.sender;                 // 固定创建者为合约部署者
        s_owner = msg.sender;                   // 初始拥有者为合约部署者
        personalInfo.payee = msg.sender;        // 默认个人信息中的收款地址是合约拥有者的地址
        saleState = stateForSale.NotForSale;    // 初始状态为不出售
        salePrice = _price;                     // 设置一个初始的定价
    }

    // 修饰器 onlyOwner
    modifier onlyOwner() {
        if(msg.sender != s_owner){revert UnionMembers__NowOwner();}
        _;
    }

    // 将 owner 身份交易给其他人
    function purchaseOwnership() public payable {
        
        if(saleState == stateForSale.NotForSale){revert UnionMembers__NotForSale();}
        if(msg.value < salePrice){revert UnionMembers__InsufficientFunds();}

        address oldOwner = s_owner;
        s_owner = msg.sender;
        payable(oldOwner).transfer(msg.value);

        personalInfo.payee = msg.sender;        // 交易后将个人信息的收款地址切换为新的拥有者
        saleState = stateForSale.NotForSale;    // 购买后设置为 NotForSale 状态
        salePrice = msg.value;                  // 设置 salePrice 为最新的交易价格
    }

    /* Getter Functions */
    // 获取创建者地址
    function getCreator() public view returns (address) {
        return i_creator;
    }

    // 获取当前 owner 地址
    function getOwner() public view returns (address) {
        return s_owner;
    }

    // 查看合约销售状态
    function checkSaleState() public view returns(stateForSale) {
        return saleState;
    }

    // 查看合约当前价格
    function checkSalePrice() public view returns(uint256) {
        return salePrice;
    }

    // 查看工会成员信息
    function getUnionMemberInfo() public view returns(unionMemberInfo memory) {
        return personalInfo;
    }

    /* Setter Functions */
    // 设置销售状态
    function setSaleState(uint256 _price) public onlyOwner {
        salePrice = _price;
        saleState = stateForSale.IsForSale;
    }

    // 设置销售价格
    function setSalePrice(uint256 _price) public onlyOwner {
        salePrice = _price;
    }

    // 取消销售状态
    function cancelSale() public onlyOwner {
        saleState = stateForSale.NotForSale;
    }

    // 设置重要的工会成员信息
    function setUnionMemberInfo(string memory _name, address payable _payee, string memory _asset) public onlyOwner {
        personalInfo = unionMemberInfo({
            name: _name,
            payee: _payee,
            asset: _asset,
            approval: false,
            veto: false
        });
    }

    // 设置许可
    function setApproval(bool _approval) public onlyOwner {
        personalInfo.approval = _approval;
    }

    // 设置否决
    function switchVeto() public onlyOwner {
        personalInfo.veto = !personalInfo.veto;
    }
}