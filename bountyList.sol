// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
// 参考https://docs.soliditylang.org/en/latest/solidity-by-example.html#safe-remote-purchase
// 已部署的DCT合约 
abstract contract ERC20 {

  function totalSupply() virtual external view returns (uint256);
  function decimals() virtual external view returns (uint8);
  function symbol() virtual external view returns (string memory);
  function name() virtual external view returns (string memory);
  function getOwner() virtual external view returns (address);
  function balanceOf(address account) virtual external view returns (uint256);
  function transfer(address recipient, uint256 amount) virtual external returns (bool);
  function allowance(address _owner, address spender) virtual external view returns (uint256);
  function approve(address spender, uint256 amount) virtual external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) virtual external returns (bool);

}
// 悬赏榜 
// 作为后台
contract BountyList {
    // 空账户 辅助任务初始化
    address constant NULLADDRESS = 0x0000000000000000000000000000000000000000;
    // 总账户
    address cheif = 0x8C6A98a1dF10C4b0E2f0728383caA6d2fbdFA764;//
    
    // This declares a new complex type which will
    // be used for variables later.
    // It will represent a single voter.

    // 任务状态
    // 目前只能1对1发任务
    struct MissionDetail{
        uint State; // 1悬赏中2已领取3待审核4已完成0作废 
        address Boss;// 发起人
        string Title;// 任务标题 
        address Hunter;// 猎人
        string Detail;// 任务说明    
        uint reward;// 赏金
        bytes8 ddl;// 截止日期 20210908 暂用字符串
        string Performance;// 完成情况
        string OtherReward;// 赏金补充
        string Patch;// 任务补充
    }
    struct RelatedMissionBrief{
        uint MissionID;
        uint Role;
        uint state;
    }
    // 任务列表
    MissionDetail[] public MissionDetailList;
    // 进行任务的索引
    uint[] public bounties;
    
    // 发起人的相关任务
    // typedef bounty int
    // This declares a state variable that
    // stores a `bosses` struct for each possible address.
    mapping(address => uint[]) public bosses;

    // 猎人的相关任务
    // This declares a state variable that
    // stores a `hunters` struct for each possible address.
    mapping(address => uint[]) public hunters;

    constructor() payable {
        
    }
    // tooltip //
    // 钱包转账
    function MissionCheckOut(address payable hunter, address boss, uint amount) private {
        require(msg.sender == boss);
        transferTo(hunter, amount);
    }
    function transferTo(address payable recipient, uint amount)  private {
        recipient.transfer(amount);
    }

 
    function transferTo_DCT(address payable recipient, uint amount) private {
        address ERC20addr = 0xc3e0ef1aa049c71c0c56736837b0373fd6cd737c;
        ERC20 DCT = ERC20(ERC20addr);
        DCT.transfer(recipient, amount);
    }
    /**
    * Modifiers
    */
    // modifier hasValue() {
    //     require(msg.value > 0);
    //     _;
    // }
    // modifier validateDeadline(uint _newDeadline) {
    //     require(_newDeadline > block.timestamp);
    //     _;
    // }
    /**
    * Events
    */
    // event BountyIssued(uint bounty_id, address issuer, uint amount, string data);

    // 1 获取任务列表 NoNeed
    // function  getMissionDetailList() public view returns(MissionDetail[] memory){
    //     return MissionDetailList;
    // }

    // 2 查询任务状态
    function  queryMissionDetail(uint MissionID) public view returns(MissionDetail memory){
        return MissionDetailList[MissionID];
    }
    

    // 3 获取所有正在进行任务状态（悬赏榜）
    function  getMissionBrief() public view returns(MissionDetail[] memory){
        MissionDetail[] memory MissionBrief;
        // 遍历正在进行任务的索引，返回正在进行的任务
        for(uint index = 0; index < bounties.length; index++){
            // 过期的任务作废 暂不设置
            // if(uint(MissionDetailList[bounties[index]].ddl) > block.timestamp){
            // }
            // 返回正在进行的任务
            MissionBrief[index] =  MissionDetailList[bounties[index]];

        }
        return MissionBrief;
    }

    // 4 获取成员相关任务概述 getMemberRecord
    function  getMemberRecord() public view returns(RelatedMissionBrief[] memory){
        RelatedMissionBrief[] memory MemberRecord;
        uint recordIndex = 0;
        // 遍历作为发起者的任务的索引，返回正在进行的任务
        uint[] memory MissionIDList = bosses[msg.sender];
        for(uint index = 0; index < MissionIDList.length; index++){
            MemberRecord[recordIndex] =  RelatedMissionBrief(MissionIDList[index],0,MissionDetailList[MissionIDList[index]].State);
            recordIndex ++;
        }
        // 遍历作为猎人的索引，返回正在进行的任务
        MissionIDList = hunters[msg.sender];
        for(uint index = 0; index < MissionIDList.length; index++){
            MemberRecord[recordIndex] =  RelatedMissionBrief(MissionIDList[index],0,MissionDetailList[MissionIDList[index]].State);
            recordIndex ++;
        }
        return MemberRecord;
    }


    // 5 发起任务
    function issueMission(string memory Title, string memory Detail, uint reward, bytes8 ddl) public returns(uint, MissionDetail memory){
        // 生成悬赏任务
        // TODO verify  is type "memory",neither "storage"
        MissionDetail memory _MissionDetail = MissionDetail(1, msg.sender,Title, NULLADDRESS, Detail, reward, ddl, "", "", "");

        // 更新悬赏榜
        uint MissionID = MissionDetailList.length;// 任务列表的更新索引 加在队尾
        uint Bounty_Index = bounties.length;// 进行任务的索引的更新索引 加在队尾

        MissionDetailList[MissionID] = _MissionDetail;// 任务列表
        bounties[Bounty_Index] = MissionID;// 更新进行任务的索引
        bosses[msg.sender].push(MissionID);// 更新发起人的相关任务

        return (MissionID,_MissionDetail);
    }
    
    // 6 确认完成
    function confirmMission(uint MissionID) public returns(string memory, MissionDetail memory){
        string memory message = " ";
        // 获取悬赏任务
        MissionDetail storage _MissionDetail = MissionDetailList[MissionID];
        // 确认发起人权限
        require(msg.sender == _MissionDetail.Boss && 3 == _MissionDetail.State);
        // 确认任务
        _MissionDetail.State = 4;
        // 结算
        MissionCheckOut(payable(_MissionDetail.Hunter), _MissionDetail.Boss, _MissionDetail.reward);
        // 更新进行任务的索引
        // TODO verify  地址传递与值传递
        removeMissionID(MissionID);
        // 结算
        message = "sucessfull";
        return (message,_MissionDetail);
    }
    // 删除任务序号对应的任务
    function removeMissionID(uint MissionID) public returns (uint index){
        if (0 == bounties.length) return 0;
        uint i = 0;
        for (; i < bounties.length; i++) {
            if(bounties[i] == MissionID){
                delete bounties[i];
                break;
            }
        }
        return i;
    }
    // 7 补充需求（保留，暂不开发）reformMission
    // 8 驳回任务（保留，暂不开发）dismissHunter
    // HUNTER //
    // 9 领取任务（领取 触发）takeMission
    function takeMission(uint MissionID) public returns(string memory, MissionDetail memory){
        string memory message = " ";
        // 获取悬赏任务
        MissionDetail storage _MissionDetail = MissionDetailList[MissionID];
        // 确认悬赏中
        require(1 == _MissionDetail.State);
        // 领取任务
        _MissionDetail.State = 2;
        // 更新进行任务的索引
        hunters[msg.sender].push(MissionID);
        // 结算
        message = "sucessfull";
        return (message,_MissionDetail);
    }
    // 10 完成任务（完成 触发）completeMission
    function completeMission(uint MissionID, string memory Performance) public returns(string memory, MissionDetail memory){
        string memory message = " ";
        // 获取悬赏任务
        MissionDetail storage _MissionDetail = MissionDetailList[MissionID];
        // 确认发起人权限
        require(msg.sender == _MissionDetail.Hunter && 2 == _MissionDetail.State);
        // 提交任务
        _MissionDetail.State = 3;
        // 上传证明材料的文字描述，如果是pdf需要附带链接
        _MissionDetail.Performance = Performance;
        // 结算
        message = "sucessfull";
        return (message,_MissionDetail);
    }
    // 11 放弃任务 abandonMission
    function abandonMission(uint MissionID) public returns(string memory, MissionDetail memory){
        string memory message = " ";
        // 获取悬赏任务
        MissionDetail storage _MissionDetail = MissionDetailList[MissionID];
        // 确认发起人权限
        require(msg.sender == cheif && 4 != _MissionDetail.State);
        // 撤销任务
        _MissionDetail.State = 0;
        _MissionDetail.Hunter = NULLADDRESS;
        // 结算
        message = "sucessfull";
        return (message,_MissionDetail);
    }
    // CHEIF //
    // 12 取消任务 killMission
    function killMission(uint MissionID) public returns(string memory, MissionDetail memory){
        string memory message = " ";
        // 获取悬赏任务
        MissionDetail storage _MissionDetail = MissionDetailList[MissionID];
        // 确认发起人权限
        require(msg.sender == cheif && 4 != _MissionDetail.State);
        // 撤销任务
        _MissionDetail.State = 0;
        // 更新进行任务的索引
        // TODO verify  地址传递与值传递
        removeMissionID(MissionID);
        // 结算
        message = "sucessfull";
        return (message,_MissionDetail);
    }
    // // 安全通信设计
    // mapping(uint256 => bool) usedNonces;

    // function claimPayment(uint256 amount, uint256 nonce, bytes memory signature) external {
    //     require(!usedNonces[nonce]);
    //     usedNonces[nonce] = true;

    //     // this recreates the message that was signed on the client
    //     bytes32 message = prefixed(keccak256(abi.encodePacked(msg.sender, amount, nonce, this)));

    //     require(recoverSigner(message, signature) == msg.sender);

    //     payable(msg.sender).transfer(amount);
    // }

    // /// destroy the contract and reclaim the leftover funds.
    // function shutdown() external {
    //     require(msg.sender == msg.sender);
    //     selfdestruct(payable(msg.sender));
    // }

    // /// signature methods.
    // function splitSignature(bytes memory sig)
    //     internal
    //     pure
    //     returns (uint8 v, bytes32 r, bytes32 s)
    // {
    //     require(sig.length == 65);

    //     assembly {
    //         // first 32 bytes, after the length prefix.
    //         r := mload(add(sig, 32))
    //         // second 32 bytes.
    //         s := mload(add(sig, 64))
    //         // final byte (first byte of the next 32 bytes).
    //         v := byte(0, mload(add(sig, 96)))
    //     }

    //     return (v, r, s);
    // }

    // function recoverSigner(bytes32 message, bytes memory sig)
    //     internal
    //     pure
    //     returns (address)
    // {
    //     (uint8 v, bytes32 r, bytes32 s) = splitSignature(sig);

    //     return ecrecover(message, v, r, s);
    // }

    // /// builds a prefixed hash to mimic the behavior of eth_sign.
    // function prefixed(bytes32 hash) internal pure returns (bytes32) {
    //     return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    // }
}
// 发任务的时候交押金
// contract MissionCheckOut {
//     uint public value;
//     address public Boss;
//     address public Hunter;
//     enum State { Created, Locked, Inactive }
//     State public state;

//     //确保 `msg.value` 是一个偶数。
//     //如果它是一个奇数，则它将被截断。
//     //通过乘法检查它不是奇数。
//     constructor() public payable {
//         Boss = msg.sender;
//         value = msg.value / 2;
//         require((2 * value) == msg.value, "Value has to be even.");
//     }

//     modifier condition(bool _condition) {
//         require(_condition);
//         _;
//     }

//     modifier onlyHunter() {
//         require(
//             msg.sender == Hunter,
//             "Only Hunter can call this."
//         );
//         _;
//     }

//     modifier onlyBoss() {
//         require(
//             msg.sender == Boss,
//             "Only Boss can call this."
//         );
//         _;
//     }

//     modifier inState(State _state) {
//         require(
//             state == _state,
//             "Invalid state."
//         );
//         _;
//     }

//     event Aborted();
//     event PurchaseConfirmed();
//     event ItemReceived();

//     ///中止购买并回收以太币。
//     ///只能在合约被锁定之前由卖家调用。
//     function abort()
//         public
//         onlyBoss
//         inState(State.Created)
//     {
//         emit Aborted();
//         state = State.Inactive;
//         seller.transfer(address(this).balance);
//     }

//     /// 买家确认购买。
//     /// 交易必须包含 `2 * value` 个以太币。
//     /// 以太币会被锁定，直到 confirmReceived 被调用。
//     function confirmPurchase()
//         public
//         inState(State.Created)
//         condition(msg.value == (2 * value))
//         payable
//     {
//         emit PurchaseConfirmed();
//         Hunter = msg.sender;
//         state = State.Locked;
//     }

//     /// 确认你（发起人）已经完成任务。
//     /// 这会释放被锁定的以太币。
//     function confirmReceived()
//         public
//         onlyBoss
//         inState(State.Locked)
//     {
//         emit ItemReceived();
//         // 首先修改状态很重要，否则的话，由 `transfer` 所调用的合约可以回调进这里（再次接收以太币）。
//         state = State.Inactive;

//         // 注意: 这实际上允许买方和卖方阻止退款 - 应该使用取回模式。
//         Boss.transfer(value);
//         Boss.transfer(address(this).balance);
//     }
// }