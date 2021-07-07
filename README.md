<!--
 * @Author: Zehui
 * @Date: 2020-07-11 23:56:36
 * @LastEditTime : 2021-06-17 22:23:38
 * @LastEditors  : Please set LastEditors
 * @Description: readme
 * @FilePath: \cos-contract-com\README.md
-->


# 合约如何搭建本地环境
1. 使用npm安装remixd工具，该工具会在本地建立一个websocket服务器，然后就可以使用网页remix端与其进行连接了， 运行命令
    ```
       npm install -g @remix-project/remixd
    ```
2. 打开remix (https://remix.ethereum.org)
3. 启动,
   ```
    remixd -s  [你的源码目录] --remix-ide  https://remix.ethereum.org
   ```
   在当前项目中， 我已经为大家配置好了， 直接运行
   ```
    yarn remixed
   ```

4. 点击 Home -> file -> connect to local host;
5. 可以看到左侧的侧边栏loading本地文件
6. loading 后 happy coding
7. 如果是本地调试， 没有必要部署测试网：
    1. 在remix: Deploy -> environment -> javascript VM （浏览器内存有限， 部署多了会崩）
    2. 本地安装gaanche,  Deploy -> environment -> web3 Provider (原理是利用本机内存搭建了一个私链，纵享丝滑吧)
    3. 如果需要与后端调试， 需要部署在测试网
    
# uniswap 部署过程
1. 先部署factory 得到address1
2. 在部署ERc20 合约， tokenzehu1（ 真实部署  _WETH  的地址）
3. 再部署ERC20 合约， tokenzehui2
4. 使用address1, 和 tokenzehui1 的地址部署 router01 得到 address2
5. tokenzehu1 approval 给 address2;  tokenzehui2 approval 给  address2
6. 调用 address2 的 addLiquidy 方法

# cos-contract-com comunion 合约介绍

- Startup.sol 对应 startup 的合约
- IRO.sol 对应 Setting 的合约
- Bounty.sol 对应 bounty 的合约
- Disco.sol 对应 DISCO 的合约
- UniswapV2Router01.sol

# 文件结构说明

- contracts 目录下是合约文件
- migrations 合约部署

# 说明

- 合约由 truffle 初始化创建
- 编译： truffle compile
- 部署： truffle migrate

# Additional
1. prior to migrate UniswapV2Factory 
2. UniswapV2Factory: https://github.com/Uniswap/uniswap-v2-core


# 合约的部署地址, 请部署后及时更新， 前端需要从此处获取地址信息来创建合约 
1. comunion new start up 部署地址
   
   >  0x2d065EBe8C310cE7c8d4169ab918261A5673b9E3
   
2. comunion setting 部署地址

   >0xEE7Ed784Bd68e992a0fF6F5f7DD8b5578d6e55b2

3. comunion bounty 部署地址

   >0x650996C9bb5EdE015B2876ace365F81a65884b20

4. hunter 向 comunion 部署地址

   >0x69EAB953C4a286Bb2216153EaA842d4c3e651aa2

5. Disco 部署地址

   >0xB39475E3077591c0f1E79b2BEdcbC9501F48E307

6. UNISWAPV2ROUTER01 的部署地址

   >0xa37fB09aA7bc4c0f18C9503c397BdB255BD6daa2

7. factory Address : 部署UniswapV2Router01前定义好的

   >0x1AB23C05C7Dfd5f11C4fB3dc497C1F57e1B14740

8. _WETH: 部署UniswapV2Router01前定义好的

   >0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6

9. proposal 部署合约地址

   >0x8690E581600A5924ce109Fc67669Fe8d3eaFd1F0

   

