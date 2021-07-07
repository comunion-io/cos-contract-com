// Disco 上链
pragma solidity >=0.4.21 <0.7.0;

import "./libraries/SafeMath.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IErc20.sol";
import "./common/FundPool.sol";
import "./interfaces/IWETH.sol";
import "@nomiclabs/buidler/console.sol";

pragma experimental ABIEncoderV2;

contract Disco {
    address private _owner;
    using SafeMath for uint256;
    IUniswapV2Router01 uniswap;
    uint256 preFee;

    // disco
    struct DiscoInfo {
        string id;
        address payable walletAddr;
        address tokenAddr;
        string description;
        uint256 fundRaisingStartedAt;
        uint256 fundRaisingEndedAt;
        uint256 investmentReward;
        uint256 rewardDeclineRate;
        uint256 shareToken;
        uint256 minFundRaising;
        uint256 addLiquidityPool;
        uint256 totalDepositToken;
    }

    // disco 投资人信息
    struct DiscoInvestor {
        // 投资人地址
        address payable investor;
        // 投资金额, 可以多次投资
        uint256 value;
        // 时间
        uint256 time;
        // dead投资记录
        bool isDead;
        // // 募资比例获得TOKEN
        // uint256 sharedToken;
        // // 奖励TOKEN
        // uint256 rewardedToken;
    }

    // disco的状态
    struct DiscoStatus {
        // 募资是否结束
        bool isFinished;
        // 募资是否成功
        bool isSuccess;
        // 募资是否开启；
        bool isEnabled;
    }

    struct DiscoInvestAddr {
        // deposit pool.
        DiscoAddr discoAddr;
        //issue coin
        IERC20 token;
        //record deposit account when use to refund.
        address payable depositAccount;
        //初始流动性
        uint256 initLiquidity;
        //reserve eth
        uint256 swapEth;
        //reserve token
        uint256 swapToken;
    }

    //Raise status: start->all begin(init), end->all end(finally).
    enum RaiseStatus{Start, Raising, Succeed, Failed, End}

    // 记录创建的disco
    mapping(string => DiscoInfo) public discos;
    // 记录投资人
    mapping(string => DiscoInvestor[]) public investors;
    // 记录投资的状态
    mapping(string => DiscoStatus) public status;
    // 记录 disco 的募资地址
    mapping(string => DiscoInvestAddr) public discoAddress;

    // 创建
    event createdDisco(string discoId, DiscoAddr addr);
    // 开启
    // event enabledDisco(string discoId, address discoAddr);
    event enabledDisco(string discoId);
    // 募资成功的时候
    event fundraisingSucceed(string discoId);
    //募资结束（成功）
    event fundraisingFinished(string discoIdo, bool success);
    // 募资失败
    event fundraisingFailed(string discoId);
    // 投资者向 disco 投钱
    event investToDisco(string discoId, address investorAddr, uint256 amount);

    // 判断是否是本人
    modifier isOwner() {
        require(msg.sender == _owner, "Caller is not owner!");
        _;
    }

    modifier canInvest(string memory id) {
        uint256 checkPoint = getDate();
        DiscoStatus memory discoStatus = status[id];
        DiscoInfo memory discoInfo = discos[id];
        require(discoStatus.isEnabled && !discoStatus.isFinished);
        require(discoInfo.fundRaisingStartedAt < checkPoint, 'now must greater than the disco fund raising start time');
        require(discoInfo.fundRaisingEndedAt > checkPoint, 'now must less than the disco fund raising end time');
        _;
    }

    constructor()
    public {
        _owner = msg.sender;
    }

    function setSwap(address swapAddr)
    isOwner
    public {
        uniswap = IUniswapV2Router01(swapAddr);
    }

    function setPreFee(uint256 pf)
    isOwner
    public {
        preFee = pf;
    }

    function getPreFee() internal
    returns (uint256){
        if (preFee == 0) {
            preFee = 0.1 * 10 ** 18;
        }
        return preFee;
    }

    //  获取当前时间
    function getDate() public view returns (uint256){
        return now;
    }

    // 创建Disco
    /**
    * @param d  tuple forward.
    **/
    function newDisco(DiscoInfo memory d) public payable {
         console.log('*******************************************************************');
        require(bytes(d.id).length != 0);
        DiscoStatus memory s = DiscoStatus(
            false,
            false,
            false
        );
        discos[d.id] = d;
        status[d.id] = s;

        // 生成新的合约地址, discoAddr 既是DiscoAddr 的实例， 也是上链部署的地址
        DiscoAddr addr = new DiscoAddr(d.id);
        IERC20 token = IERC20(d.tokenAddr);
        addr.setToken(token);
        addr.setSwap(uniswap);
        console.log('1111');

        // disco id 与 disco 合约地址的映射
        DiscoInvestAddr memory discoInvestAddr = DiscoInvestAddr(addr, token, address(0), 0, 0, 0);
        discoAddress[d.id] = discoInvestAddr;
        // disco 创建成功
        emit createdDisco(d.id, addr);
    }


    /**
     * @dev 开启disco
     */
    function enableDisco(string memory id) public payable {
        // require(address(uniswap) != address(0), 'need init uniswap');
        uint256 fee = getPreFee();
        require(msg.value >= fee, "fee not enough!");
        uint256 checkPoint = getDate();
        DiscoInfo memory disco = discos[id];
        require(disco.fundRaisingStartedAt < checkPoint, 'now must greater than the disco fund raising start time');
        require(disco.fundRaisingEndedAt > checkPoint, 'now must less than the disco fund raising end time');
        DiscoStatus memory discoStatus = status[id];
        require(!discoStatus.isEnabled, 'the disco must has not been started');

        DiscoInvestAddr storage investAddr = discoAddress[id];
        DiscoAddr discoAddr = investAddr.discoAddr;
        discoAddr.getPool().transfer(fee);

        IERC20 token = investAddr.token;
        token.transferFrom(msg.sender, discoAddr.getPool(), disco.totalDepositToken);
        discoStatus.isEnabled = true;
        status[id] = discoStatus;
        investAddr.depositAccount = msg.sender;

        // 发送开启募资的事件
        emit enabledDisco(id);
    }

    function getDeadline(uint256 pendingSecs) internal view returns (uint256){
        return getDate() + pendingSecs;
    }

    function discoToken(string calldata id) external view returns (IERC20){
        DiscoInvestAddr memory investAddr = discoAddress[id];
        return investAddr.token;
    }

    function poolEthBalance(string calldata id) external view isOwner returns (uint256) {
        DiscoInvestAddr memory investAddr = discoAddress[id];
        DiscoAddr discoAddr = investAddr.discoAddr;
        return discoAddr.ethBalance();
    }

    function poolTokenBalance(string calldata id) external view returns (uint256){
        DiscoInvestAddr memory investAddr = discoAddress[id];
        DiscoAddr discoAddr = investAddr.discoAddr;
        IERC20 token = investAddr.token;
        return discoAddr.tokenBalance(token);
    }

    /**
    * @dev 后端调用， 触发disco的结束， 由合约来判断disco的募资是否成功
    */
    function finishedDisco(string calldata id) external {
        DiscoStatus storage discoStatus = status[id];
        require(!discoStatus.isFinished && discoStatus.isEnabled);
        discoStatus.isFinished = true;
        (,uint256 investAmt) = getInvestAmt(id);
        DiscoInfo memory info = discos[id];
        //if minFundRaising is a bottom of pool.
        discoStatus.isSuccess = investAmt >= info.minFundRaising;
        status[id] = discoStatus;
        console.log('1111');
        if (discoStatus.isSuccess) {
            assign(id, investAmt);
        } else {
            refund(id);
        }
        emit fundraisingFinished(id, discoStatus.isSuccess);
    }

    function getInvestAmt(string memory id) public view returns (uint256, uint256){
        uint256 investAmt = 0;
        uint256 invCount = 0;
        for (uint256 i = 0; i < investors[id].length; i++) {
            DiscoInvestor memory investor = investors[id][i];
            if (!investor.isDead) {
                investAmt += investor.value;
                invCount++;
            }
        }
        return (invCount, investAmt);
    }


    function assign(string memory id, uint256 investAmt) public payable returns (uint256, uint256)  {
        //uniswap add liquidity.
        assignLiquidity(id);
        //assign ether
        uint256 platFee = assignEth(id, investAmt);
        //assign token
        uint256 refundToken = assignToken(id);
        return (platFee, refundToken);
    }


    function assignEth(string memory id, uint256 investAmt) public payable returns (uint256)  {
        DiscoInfo memory disco = discos[id];
        DiscoInvestAddr memory investAddr = discoAddress[id];
        DiscoAddr discoAddr = investAddr.discoAddr;
        // 2% platFee
        uint256 platFee = investAmt.mul(2).div(100);
        //no chance to send another one except msg.sender. if need, use weth with uniswap.
        if (platFee > 0) {
            //the account for receiving platFee has not been confirmed.
            discoAddr.ethTransfer(address(0), platFee);
            investAmt -= platFee;
        }
        //remainAmt to wallet
        uint256 withdrawEth = investAmt - platFee - investAddr.swapEth;
        discoAddr.ethTransfer(disco.walletAddr, withdrawEth);
        return platFee;
    }

    function assignToken(string memory id) public payable returns (uint256) {
        DiscoInfo memory disco = discos[id];
        DiscoInvestAddr memory investAddr = discoAddress[id];
        DiscoInvestor[] memory assignInvestors = investors[id];
        IERC20 token = investAddr.token;
        uint256 payToken = 0;
        for (uint256 i = 0; i < assignInvestors.length; i++) {
            DiscoInvestor memory investor = assignInvestors[i];
            if (investor.isDead) {
                continue;
            }
            uint256 diff = investor.time.sub(investor.time).div(60 * 60 * 24);
            uint256 declineDiff = disco.rewardDeclineRate.sub(diff);
            if (declineDiff <= 0) {
                declineDiff = 0;
            }

            //get the Liquidity - Uniswap when deposit to exchange factory.
            //uint256 tokenAmt = investor.value.mul(investAddr.initLiquidity).mul(declineDiff.add(1)).div(100);
            //the algorithm (need confirmed)
            uint256 tokenAmt = 1;
            investAddr.discoAddr.approve(token,address(this),tokenAmt);
            token.transferFrom(investAddr.discoAddr.getPool(),investor.investor, tokenAmt);
            payToken = payToken.add(tokenAmt);
        }

        //return the money to the original path(depositAccount).
        uint256 refundToken = disco.totalDepositToken - investAddr.swapToken - payToken;
        if (refundToken > 0) {
            investAddr.discoAddr.approve(token,address(this),refundToken);
            token.transferFrom(investAddr.discoAddr.getPool(), investAddr.depositAccount, refundToken);
        }
        return refundToken;
    }

    function assignLiquidity(string memory id) public payable {
        DiscoInfo memory disco = discos[id];
        DiscoInvestAddr memory investAddr = discoAddress[id];
        DiscoAddr discoAddr = investAddr.discoAddr;
        uint256 deadline = getDeadline(60);
        (,uint256 investAmt) = getInvestAmt(id);

        //deposit transfer
        uint256 desiredEth = investAmt.mul(disco.addLiquidityPool).div(100);
        discoAddr.depositWETH(desiredEth);

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = discoAddr.addLiquidityETH(disco.shareToken, desiredEth, 0, 0, address(investAddr.discoAddr), deadline);
        investAddr.initLiquidity = liquidity;
        investAddr.swapToken = amountToken;
        investAddr.swapEth = amountETH;
        discoAddress[id] = investAddr;
    }

    /**
     * refund-anti-pattern 适合的方案是外部控制执行批量一对一退款。
     */
    function refund(string memory id) public payable {
        require(bytes(id).length != 0,'empty id');
        DiscoInvestAddr memory investAddr = discoAddress[id];
        DiscoAddr discoAddr = investAddr.discoAddr;
        require(bytes(discoAddr.getDiscoId()).length != 0,'discoId lost');
        require(investAddr.depositAccount != address(0),'depositAccount lost');
        // solidity > 0.6 address payable pool = payable(address(discoAddr)) ;
        // as follow is 0.5.x
        // refund ether
        for (uint256 i = 0; i < investors[id].length; i++) {
            DiscoInvestor storage investor = investors[id][i];
            discoAddr.ethTransfer(investor.investor,investor.value);
            investor.isDead = true;
        }

        //refund token
        DiscoInfo memory info = discos[id];
        IERC20 token = investAddr.token;
        discoAddr.approve(token,address(this),info.totalDepositToken);
        token.transferFrom(discoAddr.getPool(),investAddr.depositAccount, info.totalDepositToken);
    }


    // 发起募资, 记录募资的信息， 可能会多次募资
    function investor(string memory id, uint256 time) public payable canInvest(id) {
        require(msg.value > 0, 'invest amt must > 0.');
        DiscoInvestor memory d = DiscoInvestor(
            msg.sender,
            msg.value,
            time,
            false
        );
        DiscoAddr discoAddr = discoAddress[id].discoAddr;
        // solidity > 0.6 address payable pool = payable(address(discoAddr)) ;
        // as follow is 0.5.x
        discoAddr.getPool().transfer(msg.value);
        investors[id].push(d);
        emit investToDisco(id, msg.sender, msg.value);
    }
}

// 生成募资合约
//Fund-Raising Contract
contract DiscoAddr is FundPool {

    string public id;

    IUniswapV2Router01 poolUniswap;

    IERC20 poolToken;

    // suppose the deployed contract has a purpose

    //0.6.x
    //receive() external payable {}
    function() external payable {}

    constructor(string memory discoId) FundPool(discoId) public {
        id = discoId;
    }

    function getDiscoId() public view returns (string memory) {
        return id;
    }

    function ethTransfer(address payable to, uint256 amount) external payable {
        to.transfer(amount);
    }

    function approve(IERC20 token, address to, uint256 amount) external {
        require(token.approve(to, amount));
    }

    function depositWETH(uint256 amount) external payable {
        IWETH WETH = IWETH(poolUniswap.WETH());
        WETH.deposit.value(amount)();
    }

    function transferFrom(IERC20 token, address to, uint256 amount) external {
        require(token.transferFrom(address(this),to, amount));
    }

    function transfer(IERC20 token, address to, uint256 amount) external {
        require(token.transfer(to, amount));
    }

    function ethBalance() external view returns(uint256) {
        return address(this).balance;
    }

    function tokenBalance(IERC20 token) external view returns(uint256) {
        return token.balanceOf(address(this));
    }

    function getPool() public view returns (address payable) {
        return address(uint160(address(this)));
    }

    function setSwap(IUniswapV2Router01 pu) public {
        poolUniswap = pu;
    }

    function setToken(IERC20 pt) public {
        poolToken = pt;
    }

    function addLiquidityETH(uint256 amountTokenDesired,uint256 amountETHDesired,
        uint256 amountTokenMin,uint256 amountETHMin,
        address to,uint256 deadline)
    external payable returns (
        uint256 amountToken,
        uint256 amountETH,
        uint256 liquidity
    ) {
        require(poolToken.approve(address(poolUniswap), amountTokenDesired));
        IERC20 WETH = IERC20(poolUniswap.WETH());
        require(WETH.approve(address(poolUniswap), amountETHDesired));
        return poolUniswap.addLiquidity(address(poolToken), poolUniswap.WETH(), amountTokenDesired, amountETHDesired, amountTokenMin, amountETHMin, to, deadline);

    }

}
