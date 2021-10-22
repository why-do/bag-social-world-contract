pragma solidity ^0.4.25;
pragma experimental ABIEncoderV2;
import "./TableDefTools.sol";
import "./Token.sol";
import "./utils/TimeUtil.sol";
import "./utils/StringUtil.sol";


/*
* UserGiveLikes合约实现包包用户互相点赞的我功能，并对点赞双方进行通证激励。
* 对于每个用户，每日会赠送5个点赞，每次为包包点赞会消耗一个，消耗完5个点赞，
* 系统则会奖励给该用户1个token奖励。 对于每个包包，每获得5次点赞，则给该包包
* 对应的用户奖励1个token。
*/
contract UserGiveLikes is TableDefTools{

    /*******   引入库  *******/
    using TypeConvertUtil for *;
    using TimeUtil for *;
    using StringUtil for *;

    /*******  Token合约引入  *******/
    Token internal token;

    /*******  每天可获得的点赞数目  *******/
    uint8 constant EVERY_DAY_LIKES = 5;

    /******* 用户点赞分配状态 *******/
    struct LikesAssignStatus{
        string date;
        uint   likes;
        bool   isAssigned;
    }

    /*******  记录用户被分配点赞数的状态字典  *******/
    mapping(address => LikesAssignStatus) public todayLikesStatusOf;


   /*
    * UserGiveLikes合约的构造函数
    *
    * @param tokenAddress  通证Token合约的地址（Token合约唯一）
    *
    * @return   无
    */
    constructor(address tokenAddress){
        initTableStruct(t_bag_struct, TABLE_BAG_NAME, TABLE_BAG_PRIMARYKEY, TABLE_BAG_FIELDS);
        token=Token(tokenAddress);
    }


   /*
    * 用户给附近的包包点赞，并对点赞双方进行通证激励。
    * 对每个用户，每日会赠送5个点赞，消耗完5个点赞，系统则会奖励1个token
    * 包包ID每获5次点赞，给对应的用户奖励一个token。
    *
    * @param _fields  各字段值的字符串数组
    * @param index    待修改字段的位置
    * @param values   修改后的值
    *
    * @return         修改后的各字段值，并以字符串格式输出
    *
    * 测试 参数一："BG00001"  参数二："0x3325323c547f579a85b752dce623333e363fadfe"
    */
    function giveALikeToBag(address _userid, string _forBagid) public returns (int8){

        // 该包包当前被点赞数
        uint bagHasLikes;
        // 查询包包信息返回状态
        int8 queryRetCode;
        // 更新包包信息返回状态
        int8 updateRetCode;
        // 数据表返回信息
        string[] memory retArray;
        // 获得当前的日期
        string memory nowDate = TimeUtil.getNowDate();

        // 比较记录是否是最新
        if(!StringUtil.compareTwoString(todayLikesStatusOf[_userid].date, nowDate)){
           // 若不是，今日未分配，为其分配今天的点赞数并记录
            todayLikesStatusOf[_userid].date = nowDate;
            todayLikesStatusOf[_userid].isAssigned = true;
            todayLikesStatusOf[_userid].likes = EVERY_DAY_LIKES;
        }
        // 查看该包包记录信息
        (queryRetCode, retArray) = selectOneRecordToArray(t_bag_struct, _forBagid, ["bag_id", _forBagid]);
        // 若存在该包包记录
        if(queryRetCode == SUCCESS_RETURN){
            // 若没有点赞数，结束执行
            if(todayLikesStatusOf[_userid].likes  == uint(0)){
                 return FAIL_LACK_BALANCE;
            }

            bagHasLikes = TypeConvertUtil.stringToUint(retArray[10]);
            // 点赞数+1
            bagHasLikes += 1;
            // 更新包包信息表，将点赞数+1
            string memory changedFieldsStr = getChangeFieldsString(retArray, 10, TypeConvertUtil.uintToString(bagHasLikes));
            updateRetCode = updateOneRecord(t_bag_struct, _forBagid, changedFieldsStr);
            // 若更新成功
            if(updateRetCode == SUCCESS_RETURN){
                // 该用户今日点赞数-1
                todayLikesStatusOf[_userid].likes = todayLikesStatusOf[_userid].likes - 1;
                // 若该用户花光今日的点赞，则给与一个Token奖励
                if(todayLikesStatusOf[_userid].likes == uint(0)){
                    token.ownerTransfer(_userid, 1);
                    emit GET_TOKEN_EVENT(_userid, EVENT_GIVE_LIKES, uint(1), nowDate);
                }
                // 包包每5次被点赞，该包包的用户获得一个Token奖励
                if(bagHasLikes % 5 == uint(0)){
                    address bagUser = TypeConvertUtil.bytesToAddress(bytes(retArray[0]));
                    token.ownerTransfer(bagUser, 1);
                    emit GET_TOKEN_EVENT(_userid, EVENT_OBTAIN_LIKES, uint(1), nowDate);
                }
                return SUCCESS_RETURN;

            }else{
                // 若更新失败
                return FAIL_RETURN;
            }
        }else{
            // 若不存在该包包记录
            return FAIL_RETURN;
        }

    }


   /*
    * 修改各字段中某一个字段，字符串格式输出
    *
    * @param _fields  各字段值的字符串数组
    * @param index    待修改字段的位置
    * @param values   修改后的值
    *
    * @return         修改后的各字段值，并以字符串格式输出
    *
    */
    function getChangeFieldsString(string[] memory _fields, uint index, string values) public returns (string){
        string[] memory fieldsArray = _fields;
        fieldsArray[index] = values;

        return StringUtil.strConcatWithComma(fieldsArray);
    }


    // function setOneRecord(string _primaryKey) public returns(int8) {
    //     return insertOneRecord(t_bag_struct, _primaryKey, "0x1111111a547f579a85b752dce623333e363fadfe,jipinbao,1998-03-13,LV,oldschool,1,2020-05-28,20000,35000,0,0,0",false);
    // }


   /*
    * 通过bagid查看包包信息表中对应的记录
    *
    * @param _bagid  该表主键bagid值
    *
    * @return        返回该包包信息
    */
    function viewBagRecordOf(string _bagid) public returns(int8,string){
        return selectOneRecordToJson(t_bag_struct, _bagid);

    }

   /*
    * 查看用户对应的点赞状态
    *
    * @param _user  用户地址
    *
    * @return       点赞状态
    */
    function getLikesStatus(address _user) public returns(string,uint,bool){
        string s = todayLikesStatusOf[_user].date;
        bool b = todayLikesStatusOf[_user].isAssigned;
        uint u = todayLikesStatusOf[_user].likes;
        return (s, u, b);
    }


}