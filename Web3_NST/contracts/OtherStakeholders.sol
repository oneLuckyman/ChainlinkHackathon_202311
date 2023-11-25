// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Error
error OtherStakeholders__NowOwner();
error OtherStakeholders__NotForSale();
error OtherStakeholders__InsufficientFunds();

contract OtherStakeholders {
    /* Type declarations */
    // 销售状态
    enum stateForSale {
        NotForSale,
        IsForSale
    }

    // OtherStakeholders 信息，与 UnionMembers 不同的是 OtherStakeholders 只有利润分配而没有投票权
    struct otherStakeholdersInfo {
        string name;            // 利益相关者的称呼
        address payeeAddress;   // 收款地址
        string asset;           // 指向资产的元数据，可以是作品链接，论文地址，运营商地址，JSON 链接等
    }

    /* State Variables */
    address private immutable i_creator;
    address private s_owner;
    stateForSale private saleState;
    uint256 private salePrice;
    otherStakeholdersInfo private personalInfo;

    // 构造函数
    constructor(uint256 _price) {
        i_creator = msg.sender;                 // 固定创建者为合约部署者
        s_owner = msg.sender;                   // 初始拥有者为合约部署者
        personalInfo.payeeAddress = msg.sender; // 默认个人信息中的收钱地址为合约部署者的地址
        saleState = stateForSale.NotForSale;    // 初始状态为不出售
        salePrice = _price;                     // 设置一个初始的定价
    }

    // 修饰器 onlyOwner
    modifier onlyOwner() {
        if(msg.sender != s_owner){revert OtherStakeholders__NowOwner();}
        _;
    }

    // 将 owner 身份交易给其他人
    function purchaseOwnership() public payable {
        
        if(saleState == stateForSale.NotForSale){revert OtherStakeholders__NotForSale();}
        if(msg.value < salePrice){revert OtherStakeholders__InsufficientFunds();}

        address oldOwner = s_owner;
        s_owner = msg.sender;
        payable(oldOwner).transfer(msg.value);

        personalInfo.payeeAddress = msg.sender; // 交易后将个人信息的收款地址切换为新的拥有者
        saleState = stateForSale.NotForSale;    // 购买后设置为 NotForSale 状态
        salePrice = msg.value;  // 设置 salePrice 为最新的交易价格
    }

    // 如果 payee 地址出现意外，则款项会支付到本合约的地址，因此可能需要提款
    function withdraw(address _payeeAddress) public payable onlyOwner {
        payable(_payeeAddress).transfer(address(this).balance);
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
    function getOtherStakeholdersInfo() public view returns(otherStakeholdersInfo memory) {
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
    function setOtherStakeholdersInfo(string memory _name, address _payeeAddress, string memory _asset) public onlyOwner {
        personalInfo = otherStakeholdersInfo({
            name: _name,
            payeeAddress: _payeeAddress,
            asset: _asset
        });
    }
}