// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
// 参考https://docs.soliditylang.org/en/latest/solidity-by-example.html#safe-remote-purchase
// 已部署的DCT合约 
abstract contract ERC20 {
  function transfer(address recipient, uint256 amount) virtual external returns (bool);
}
// 悬赏榜 
// 作为后台
contract BountyList {
    // 空账户 辅助任务初始化
    address constant NULLADDRESS = 0x0000000000000000000000000000000000000000;
    // 总账户
    address cheif = 0x8C6A98a1dF10C4b0E2f0728383caA6d2fbdFA764;//
    // 任务状态
    // 目前只能1对1发任务
    struct MissionDetail{
        uint State; // 1悬赏中2已领取3待审核4已完成0作废 
        address Boss;// 发起人
        string Title;// 任务标题 
        address Hunter;// 猎人
        string Detail;// 任务说明    
        uint reward;// 赏金
        uint ddl;// 截止日期 20210908 暂用字符串
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
    mapping(address => uint[]) public bosses;

    // 猎人的相关任务
    mapping(address => uint[]) public hunters;

    constructor() payable {
        MissionDetail memory _MissionDetail = MissionDetail(1, msg.sender,"nothing", NULLADDRESS, "nothing", 1, block.timestamp, "", "", "");
        // 更新悬赏榜
        uint MissionID = MissionDetailList.length;// 任务列表的更新索引 加在队尾
        emit BountyIssued(MissionID, msg.sender, 1, "nothing"); 

        uint Bounty_Index = bounties.length;// 进行任务的索引的更新索引 加在队尾

        MissionDetailList[MissionID] = _MissionDetail;// 任务列表
        bounties[Bounty_Index] = MissionID;// 更新进行任务的索引
        bosses[msg.sender].push(MissionID);// 更新发起人的相关任务
        
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
        // address ERC20addr = 0x8C6A98a1dF10C4b0E2f0728383caA6d2fbdFA764;
        address ERC20addr = 0xC3E0ef1aa049C71c0c56736837B0373FD6cD737c;
        ERC20 DCT = ERC20(ERC20addr);
        DCT.transfer(recipient, amount);
    }

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


    event BountyIssued(uint bounty_id, address issuer, uint amount, string data);
    // 5 发起任务
    function issueMission(string memory Title, string memory Detail, uint reward) public returns(uint, MissionDetail memory){
        // 生成悬赏任务
        // TODO verify  is type "memory",neither "storage"
        MissionDetail memory _MissionDetail = MissionDetail(1, msg.sender,Title, NULLADDRESS, Detail, reward, block.timestamp, "", "", "");
        // 更新悬赏榜
        uint MissionID = MissionDetailList.length;// 任务列表的更新索引 加在队尾
        emit BountyIssued(MissionID, msg.sender, reward, Detail); 

        uint Bounty_Index = bounties.length;// 进行任务的索引的更新索引 加在队尾

        MissionDetailList[MissionID] = _MissionDetail;// 任务列表
        bounties[Bounty_Index] = MissionID;// 更新进行任务的索引
        bosses[msg.sender].push(MissionID);// 更新发起人的相关任务

        return (MissionID, _MissionDetail);
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
}