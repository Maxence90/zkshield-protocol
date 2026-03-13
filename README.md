# Foundry ZK Private Lending Protocol

# 简介
这是一个基于Foundry的去中心化稳定币项目，已升级为**零知识(ZK)私有借贷协议**。该协议结合了传统DeFi的稳定币功能与先进的隐私保护技术，为用户提供安全、私密的借贷体验。

## 核心特性

### 🏛️ 传统稳定币功能
- **超额抵押**: 支持WETH和WBTC作为抵押品
- **算法稳定**: DSC代币与美元1:1挂钩
- **去中心化铸造**: 用户可自由铸造和销毁DSC
- **自动清算**: 维护协议健康性的清算机制

### 🔒 零知识隐私保护
- **隐私存款/借贷**: 使用ZK证明保护交易隐私
- **信用评分证明**: 基于零知识的信用评估系统
- **MEV保护拍卖**: 隐私保护的MEV拍卖机制
- **清算证明**: 防止不良清算的证明系统
- **Merkle树管理**: 高效的隐私数据结构

## 架构模块

### 核心合约
- **DSCEngine**: 稳定币引擎，处理抵押、铸造、清算
- **DecentralizedStableCoin**: ERC20稳定币代币
- **ZKVerifier**: 零知识证明验证器
- **MerkleTreeManager**: Merkle树管理器

### ZK隐私模块
- **PrivateLendingCore**: 隐私借贷核心功能
- **ZKLiquidationProof**: 清算保护证明
- **ZKMEVAuction**: MEV拍卖系统
- **ZKCreditScore**: 信用评分证明
- **PrivacyRegistry**: 用户隐私注册

## 目录
- [简介](#简介)
- [快速开始](#快速开始)
  - [要求](#要求)
  - [快速上手](#快速上手)
- [使用方法](#使用方法)
  - [启动本地节点](#启动本地节点)
  - [依赖安装](#依赖安装)
  - [部署](#部署)
  - [部署-其他网络](#部署-其他网络)
  - [测试](#测试)
  - [测试覆盖率](#测试覆盖率)
- [部署到测试网或主网](#部署到测试网或主网)
- [Script脚本](#script脚本)
- [估算Gas费用](#估算gas费用)
- [格式化](#格式化)
- [贡献](#贡献)
- [Thank you!](#thank-you)

# 快速开始

## 要求

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - 如果你运行`git --version`可以看到类似`git version x.x.x`的响应，就说明可以继续。
- [foundry](https://getfoundry.sh/)
  - 如果你运行`forge --version`可以看到`forge 1.4.x(2025-10-14)`的响应，就说明可以继续。

## 快速上手

```bash
git clone https://github.com/Maxence90/foundry-defi-stablecoin
cd foundry-defi-stablecoin
forge install
forge build
```

# 使用方法

## 启动本地节点

```bash
make anvil
```

## 依赖安装

安装必要的库依赖：

```bash
forge install smartcontractkit/chainlink-brownie-contracts@latest
forge install OpenZeppelin/openzeppelin-contracts
forge install foundry-rs/forge-std
forge install zk-kit/zk-kit
forge install semaphore-protocol/semaphore
```

## 部署

这将默认为本地节点部署。您需要在另一个终端运行它。

```bash
make deploy
```

## 部署-其他网络

[请参见下方](#部署到测试网或主网)

## 测试

运行完整测试套件：

```bash
forge test
```

运行分叉测试：

```bash
forge test --fork-url $SEPOLIA_RPC_URL
```

## 测试覆盖率

```bash
forge coverage
```
# 部署到测试网或主网

1. 设置环境变量

您需要将以下环境变量添加到`.env`文件中：

- `PRIVATE_KEY`: 您的账户私钥（仅用于开发）
- `SEPOLIA_RPC_URL`: Sepolia测试网RPC URL
- `ETHERSCAN_API_KEY`: 用于合约验证（可选）

2. 获取测试网ETH

访问[faucets.chain.link](https://faucets.chain.link)获取测试网ETH。

3. 部署到Sepolia测试网

```bash
make deploy ARGS="--network sepolia"
```

## Script脚本
在部署到测试网或本地网后，可以运行脚本。

使用本地部署的 cast 示例：
1. 获取一些 WETH
```
cast send 0x694AA1769357215DE4FAC081bf1f309aDC325306 "deposit()" --value 0.1ether --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```
2. 批准 WETH
```
cast send 0x694AA1769357215DE4FAC081bf1f309aDC325306 "approve(address,uint256)" 0xD6982Cf3f4268586367Afe7dc2a4FE1ba0334fFB 1000000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY"
```
3. 存款和铸造 DSC
```
cast send 0xD6982Cf3f4268586367Afe7dc2a4FE1ba0334fFB "depositCollateralAndMintDsc(address,uint256,uint256)" 0x694AA1769357215DE4FAC081bf1f309aDC325306 100000000000000000 10000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

## 估算Gas费用
你可以通过运行以下命令来估算 gas 费用：
```
forge snapshot
```
你会看到一个名为 .gas-snapshot 的输出文件

# 格式化

```bash
forge fmt
```

# 贡献

欢迎提交Issue和Pull Request！

## 开发路线图

- [ ] 实现完整的Circom ZK电路
- [ ] 添加前端界面
- [ ] 安全审计
- [ ] 主网部署

# Thank you!

感谢您对ZK隐私DeFi的兴趣！这个项目展示了传统金融与前沿密码学的完美结合。