// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
// import "./IERC20.sol";
// 参考https://docs.soliditylang.org/en/latest/solidity-by-example.html#safe-remote-purchase
// 已部署的DCT合约 
// import "./DCT.sol";
interface ERC20 {
  function transfer(address recipient, uint256 amount) external returns (bool);
  function balanceOf(address account) external view returns (uint256);
  function allowance(address _owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
  function transfer_Internal(address sender, address recipient, uint256 amount) external returns (bool);
}


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable {
  address private _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev Initializes the contract setting the deployer as the initial owner.
   */
  constructor () {
    address msgSender = msg.sender;
    _owner = msgSender;
    emit OwnershipTransferred(address(0), msgSender);
  }

  /**
   * @dev Returns the address of the current owner.
   */
  function owner() public view returns (address) {
    return _owner;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(_owner == msg.sender, "Ownable: caller is not the owner");
    _;
  }

  /**
   * @dev Leaves the contract without owner. It will not be possible to call
   * `onlyOwner` functions anymore. Can only be called by the current owner.
   *
   * NOTE: Renouncing ownership will leave the contract without an owner,
   * thereby removing any functionality that is only available to the owner.
   */
  function renounceOwnership() public onlyOwner {
    emit OwnershipTransferred(_owner, address(0));
    _owner = address(0);
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   * Can only be called by the current owner.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    _transferOwnership(newOwner);
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   */
  function _transferOwnership(address newOwner) internal {
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
  
}
// 悬赏榜  作为后台
contract BountyList is Ownable{

    // 空账户 辅助任务初始化
    address constant NULLADDRESS = 0x0000000000000000000000000000000000000000;
    address ERC20addr = 0xb9efd1AC2044CF7b9f9C01026fD9a0292EC5E9Ac;
    ERC20 DCT = ERC20(ERC20addr);
    function rewriteERC20addr(address NewERC20addr) public onlyOwner{
        DCT = ERC20(NewERC20addr);
    }
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
    uint[] public MissionIDList;
    // 进行任务的索引
    uint public bountyOngoing_NUM = 0;
    mapping(uint => bool) public bountyOngoing;
    
    // 发起人的相关任务
    mapping(address => uint[]) public bosses;
    // 猎人的相关任务
    mapping(address => uint[]) public hunters;

    constructor() payable {
        issueMission("B1","TEST",500);
        issueMission("B2","TEST",500);
        takeMission(0);
        completeMission(0, "wow");
    }
    // tooltip //
    // 钱包转账
    function transferTo_DCT_Internal(address recipient, uint256 amount) public {
        ERC20(ERC20addr).transfer_Internal(msg.sender, recipient, amount * 10000000000000000);
    }
    // 1 获取任务列表
    function  getMissionList() public view returns(MissionDetail[] memory){
        return MissionDetailList;
    }
    // 2 查询任务状态 等价于 MissionList(MissionID)
    function  queryMissionDetail(uint MissionID) public view returns(MissionDetail memory){
        return MissionDetailList[MissionID];
    }

    // 3 获取所有正在进行任务状态（悬赏榜）
    function  getMissionBrief() public view returns(uint, MissionDetail[] memory){
        MissionDetail[] memory MissionBrief = new MissionDetail[](bountyOngoing_NUM);

        // 遍历正在进行任务的索引，返回正在进行的任务
        for(uint index = 0; index < MissionIDList.length; index++){
            // 过期的任务作废 暂不设置
            // if(uint(MissionDetailList[bounties[index]].ddl) > block.timestamp){
            // }
            // 返回正在进行的任务
            if(true == bountyOngoing[index]){
                MissionDetail memory _MissionBrief = MissionDetailList[index];
                MissionBrief[index] = _MissionBrief;
            }

        }
        return (bountyOngoing_NUM, MissionBrief);
    }

    // 4 获取成员相关任务概述 getMemberRecord
    function  getMemberRecord() public view returns(RelatedMissionBrief[] memory){
        uint recordlength = bosses[msg.sender].length + hunters[msg.sender].length;
        RelatedMissionBrief[] memory MemberRecord = new RelatedMissionBrief[](recordlength);
        uint recordIndex = 0;
        uint[] memory _MissionIDList;
        // 遍历作为发起人的索引，返回正在进行的任务
        _MissionIDList = bosses[msg.sender];
        for(uint index = 0; index < _MissionIDList.length; index++){
            MemberRecord[recordIndex] = RelatedMissionBrief(_MissionIDList[index],0,MissionDetailList[_MissionIDList[index]].State);
            recordIndex ++;
        }
        // 遍历作为猎人的索引，返回正在进行的任务
        _MissionIDList = hunters[msg.sender];
        for(uint index = 0; index < _MissionIDList.length; index++){
            MemberRecord[recordIndex] = RelatedMissionBrief(_MissionIDList[index],0,MissionDetailList[_MissionIDList[index]].State);
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
        MissionDetailList.push(_MissionDetail);// 任务列表
        MissionIDList.push(MissionID);
        bountyOngoing[MissionID] = true;// 更新进行任务的索引
        bountyOngoing_NUM ++;
        bosses[msg.sender].push(MissionID);// 更新发起人的相关任务

        return (MissionID, _MissionDetail);
    }
    
    // 6 确认完成
    event BountyConfirm(MissionDetail Mission);
    function confirmMission(uint MissionID) public returns(string memory, MissionDetail memory){
        string memory message = " ";
        // 获取悬赏任务
        MissionDetail storage _MissionDetail = MissionDetailList[MissionID];
        // 确认发起人权限
        require(msg.sender == _MissionDetail.Boss, "Only access the BOSS");
        require(3 == _MissionDetail.State, "The MissionState can't access this behavior");
        // 确认任务
        _MissionDetail.State = 4;
        // 结算
        transferTo_DCT_Internal(_MissionDetail.Hunter, _MissionDetail.reward);
        // 更新进行任务的索引
        // TODO verify  地址传递与值传递
        bountyOngoing[MissionID] = false;// 更新进行任务的索引
        bountyOngoing_NUM --;
        // 结算
        message = "sucessfull";
        emit BountyConfirm(_MissionDetail);
        return (message,_MissionDetail);
    }
    // 7 补充需求（保留，暂不开发）reformMission
    // 8 驳回任务（保留，暂不开发）dismissHunter
    // HUNTER //
    // 9 领取任务（领取 触发）takeMission
    event BountyTaken(uint bounty_id, address hunter, string detail );
    function takeMission(uint MissionID) public returns(string memory, MissionDetail memory){
        string memory message = " ";
        // 获取悬赏任务
        MissionDetail storage _MissionDetail = MissionDetailList[MissionID];
        // 确认悬赏中
        require(1 == _MissionDetail.State, "The MissionState can't access this behavior");
        // 领取任务
        _MissionDetail.State = 2;
        _MissionDetail.Hunter = msg.sender;
        // 更新进行任务的索引
        hunters[msg.sender].push(MissionID);
        // 结算
        message = "sucessfull";
        emit BountyTaken(MissionID, msg.sender, _MissionDetail.Detail); 
        return (message, _MissionDetail);
    }
    // 10 完成任务（完成 触发）completeMission
    event BountyComplete(uint bounty_id, address hunter, string Performance);
    function completeMission(uint MissionID, string memory Performance) public returns(string memory, MissionDetail memory){
        string memory message = " ";
        // 获取悬赏任务
        MissionDetail storage _MissionDetail = MissionDetailList[MissionID];
        // 确认发起人权限
        require(msg.sender == _MissionDetail.Hunter, "Only access the Hunter");
        require(2 == _MissionDetail.State, "The MissionState can't access this behavior");
        // 提交任务
        _MissionDetail.State = 3;
        // 上传证明材料的文字描述，如果是pdf需要附带链接
        _MissionDetail.Performance = Performance;
        // 结算
        message = "sucessfull";
        emit BountyComplete(MissionID, msg.sender, Performance); 
        return (message, _MissionDetail);
    }
    // 11 放弃任务 abandonMission
    event BountyAbandon(uint bounty_id, address hunter, string detail );
    function abandonMission(uint MissionID) public returns(string memory, MissionDetail memory){
        string memory message = " ";
        // 获取悬赏任务
        MissionDetail storage _MissionDetail = MissionDetailList[MissionID];
        // 确认发起人权限
        require(msg.sender == _MissionDetail.Hunter, "Only access the Hunter");
        require(2 == _MissionDetail.State, "The MissionState can't access this behavior");
        // 放弃任务
        _MissionDetail.State = 1;
        _MissionDetail.Hunter = NULLADDRESS;
        // 结算
        message = "sucessfull";
        emit BountyAbandon(MissionID, msg.sender, _MissionDetail.Detail); 
        return (message,_MissionDetail);
    }
    // CHEIF // 未测试
    // 12 取消任务 killMission
    function killMission(uint MissionID) public returns(string memory, MissionDetail memory){
        string memory message = " ";
        // 获取悬赏任务
        MissionDetail storage _MissionDetail = MissionDetailList[MissionID];
        // 确认发起人权限
        require(msg.sender == cheif, "Only access the cheif");
        require(4 != _MissionDetail.State, "The MissionState can't access this behavior");
        // 撤销任务
        _MissionDetail.State = 0;
        // 更新进行任务的索引
        // TODO verify  地址传递与值传递
        bountyOngoing[MissionID] = false;// 更新进行任务的索引
        bountyOngoing_NUM --;
        // 结算
        message = "sucessfull";
        return (message,_MissionDetail);
    }
}