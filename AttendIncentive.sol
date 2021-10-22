pragma solidity ^0.4.25;
pragma experimental ABIEncoderV2;
import "./TableDefTools.sol";
import "./Token.sol";
import "./utils/StringUtil.sol";
import "./utils/TimeUtil.sol";


/*
* AttendIncentive合约实现用户出席某地或打卡时
* 进行记录并给予Token激励。当服务对用户地理位置信息进行计算后，
* 确认是在规定的活动有效时间以及地点进行打卡
* ，地点属于官方规定的“网红”打卡地，则将对应的地点的ID，
* 以及与之匹配的位置信息传入合约进行存证，然后根据链上位置信息表给
* 出的Token数量进行奖励。规定在一天之内只能进行一次打卡并获得奖励。
*
*/
contract AttendIncentive is TableDefTools {

    /*******   引入库  *******/
    using StringUtil for *;
    using TimeUtil for *;

    /******* 合约拥有者 *******/
    address public owner;

    /******* Token合约 *******/
    Token internal token;

    /******* 修饰器，只允许合约拥有者访问*******/
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }


   /*
    * UserGiveLikes合约的构造函数
    *
    * @param tokenAddress  通证Token合约的地址（Token合约唯一）
    *
    * @return   无
    */
    constructor(address tokenAddress) public{
        owner = msg.sender;
        token = Token(tokenAddress);
        initTableStruct(t_attend_location_struct, TABLE_ATTENDLOCATION_NAME, TABLE_ATTENDLOCATION_PRIMARYKEY, TABLE_ATTENDLOCATION_FIELDS);
        initTableStruct(t_locations_struct, TABLE_LOCATIONS_NAME, TABLE_LOCATIONS_PRIMARYKEY, TABLE_LOCATIONS_FIELDS);
    }


   /*
    * 打卡“圣地”地点数据初始化录入，假设录入五条
    *
    * @param 无
    *
    * @return 无
    *
    */
    function dataInit() public onlyOwner{
        // 打卡地点数据插入
        insertOneRecord(t_locations_struct, "001", "Festival De Cannes Location,1591422588,1757028188,100",false);
        insertOneRecord(t_locations_struct, "002", "Venice International Film Festival Location,1591422588,1757028188,80",false);
        insertOneRecord(t_locations_struct, "003", "Shanghai International Film Festival Location,1591422588,1757028188,85",false);
        insertOneRecord(t_locations_struct, "004", "Carrouseldu Louvre Location,1591422588,1757028188,60",false);
        insertOneRecord(t_locations_struct, "005", "Haitian Banquet Location,1591422588,1757028188,30",false);
    }


   /*
    * 每日“圣地”打卡，通过打卡获得Token奖励：
    * 通过服务端计算出用户打卡对应的locationID（地点），将该地点ID与具体位置信息上链公证；
    * 在一天之内只能打卡一次，若在规定的活动有效时间以及地点进行打卡，则给予对应的Token奖励。
    *
    * @param _bagID  打卡包包的ID
    * @param _fields 上传的打卡信息，包括locationID, longitude, latitude
    *
    * @return 执行状态码
    *
    * 测试
    * 参数一："BG00001"   参数二："001,X234,Y1134"
    *
    */
    function dailyAttendance(string _bagID, string _fields) public returns(int8){
        // 得到上传字段数据的数组
        string[] memory inputFieldsArray = getFieldsArray(_fields);
        // 当前日期时间
        (string memory nowDate, string memory nowTime) = TimeUtil.getNowDateTime();
        // 先查t_attend_location表，看是否已经领取当日奖励
        (int8 retStatusCode1, string[] memory retContent1) = selectOneRecordToArray(
            t_attend_location_struct,
            _bagID,
            ["rewarded_date",nowDate]);

        //返回数组详情:
        //retContent1[0]-location_id    地点标号
        //retContent1[1]-longitude      地点经度
        //retContent1[2]-latitude       地点维度
        //retContent1[3]-rewarded_date  奖励日期
        //retContent1[4]-rewarded_time  奖励时间
        //retContent1[5]-is_rewarded    是否已奖励

        //如果返回为空，则说明未进行打卡，进行奖励
        if(retStatusCode1 == FAIL_NULL_RETURN) {
            // 通过地点ID查询规定的打卡信息表，看该打卡地是否有奖励
            (int8 retStatusCode2, string[] memory retContent2) = selectOneRecordToArray(
                t_locations_struct,
                inputFieldsArray[0],
                ["location_id",inputFieldsArray[0]]);
            //根据inputFieldsArray[0]==>locationID 查表t_locations，看是否是指定地点
            //返回数组详情:
            //retContent2[0]-location_name          地点名称
            //retContent2[1]-activity_start_time    活动开始时间
            //retContent2[2]-activity_end_time      活动结束时间
            //retContent2[3]-reward_tokens          可获得奖励Token数量

            // 若该地点确实打卡奖励地点
            if(retStatusCode2 == SUCCESS_RETURN &&
                retContent2.length > 0 &&
                bytes(retContent2[3]).length > 0){
                // 用于奖励Token的用户地址
                address user = msg.sender;
                // 奖赏金额
                uint reward = TypeConvertUtil.stringToUint(retContent2[3]);
                // 打卡信息表字段处理
                string memory processedFileds = StringUtil.strConcat4(StringUtil.strConcat4(_fields, ",", nowDate, ","), nowTime, ",", "1");
                // Token奖励支付
                token.ownerTransfer(user, reward);
                // Token获得事件
                emit GET_TOKEN_EVENT(user, EVENT_ATTEND_LOCATION, reward, nowDate);
                // 将打卡信息存储
                return insertOneRecord(
                    t_attend_location_struct,
                    _bagID,
                    processedFileds,
                    true);
            }else{
                return FAIL_NO_REWARD;
            }
        }
        else{
            // t_attend表返回不为空
            // 查看is_rewarded字段是否为"1"
            if(keccak256(retContent1[5]) != keccak256("1") ||
              keccak256(retContent1[3]) != keccak256(nowDate)  ){
                return FAIL_RETURN;
            }
        }
        return SUCCESS_RETURN;
    }


}