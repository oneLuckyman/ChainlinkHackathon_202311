// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

error Stakeholders__NowOwner();
error Stakeholders__NotForSale();
error Stakeholders__InsufficientFunds();

contract Stakeholders {
    /* Type declarations */
    // 销售状态
    enum stateForSale {
        NotForSale,
        IsForSale
    }

    // Stakeholders 信息
    struct stakeholderInfo {
        string name;            // 利益相关者的称呼
        address payable payee;  // 收款地址
        string asset;           // 指向资产的元数据，可以是作品链接，运营商地址，JSON 链接等
        bool approval;          // approval 为项目许可，默认为 false,所有利益相关者需要手动改为 true 才能使项目实际开始。
        // 此外一旦利益相关者有任何质疑，都可以手动撤销许可，以阻止链上信息的进一步改变
    }

    /* State Variables */
    address private immutable i_creator;
    address private s_owner;
    stateForSale private saleState;
    uint256 private salePrice;
    stakeholderInfo private personalInfo;

    // 构造函数
    constructor(uint256 _price) {
        i_creator = msg.sender;                 // 固定的初始拥有者为合约部署者
        s_owner = msg.sender;                   // 初始拥有者为合约部署者
        saleState = stateForSale.NotForSale;    // 初始状态为不出售
        salePrice = _price;                     // 设置一个初始的定价
    }

    // 修饰器 onlyOwner
    modifier onlyOwner() {
        if(msg.sender != s_owner){revert Stakeholders__NowOwner();}
        _;
    }

    // 将 owner 身份交易给其他人
    function purchaseOwnership() public payable {
        
        if(saleState == stateForSale.NotForSale){revert Stakeholders__NotForSale();}
        if(msg.value < salePrice){revert Stakeholders__InsufficientFunds();}

        address oldOwner = s_owner;
        s_owner = msg.sender;
        payable(oldOwner).transfer(msg.value);

        saleState = stateForSale.NotForSale;   // 购买后设置为 NotForSale 状态
        salePrice = msg.value;
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

    // 查看利益相关者信息
    function getStakeholderInfo() public view returns(stakeholderInfo memory) {
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

    // 设置重要的利益相关者信息
    function setStakeholderInfo(string memory _name, address payable _payee, string memory _asset, bool _approval) public onlyOwner {
        personalInfo = stakeholderInfo({
            name: _name,
            payee: _payee,
            asset: _asset,
            approval: _approval
        });
    }

    // 专门设置许可的函数
    function setApproval(bool _approval) public onlyOwner {
        personalInfo.approval = _approval;
    }
}