pragma solidity ^0.4.25;
pragma experimental ABIEncoderV2;

import "./TableDefTools.sol";


/*
* BagUserAdmin实现包包及用户的链上信息管理，
* 以Table的形式进行存储。当用户拿到包包后可进行查看，
* 看包包是否处于激活状态，若未激活，则可以进行激活。
* 包包激活实际上是在合约包包信息表中插入一条记录，描述该包包的详细情况。
* 包包处于激活状态才会有记录信息，因此，激活后方可使用打卡（AttendIncentive）
* 以及点赞（UserGiveLikes）功能合约。
*
*/
contract BagUserAdmin is TableDefTools{

   /*
    * 构造函数，初始化使用到的表结构
    *
    * @param    无
    *
    * @return   无
    */
    constructor() public{

        initTableStruct(t_bag_struct, TABLE_BAG_NAME, TABLE_BAG_PRIMARYKEY, TABLE_BAG_FIELDS);

    }

   /*
    * 激活包包
    *
    * @param _bagid  包包id
    * @param _fields 包包信息表各字段值拼接成的字符串（除最后三个字段；用逗号分隔），包括如下：
    *                   包包ID
    *                   包包名称
    *                   出厂时间
    *                   品牌
    *                   花色样式
    *                   包包状态（0-未激活、1-已激活）
    *                   激活时间
    *                   原价格
    *                   现估价
    *
    * @return 执行状态码
    *
    * 测试举例  参数一："BG00001"  参数二："0x5fc079ca547f579a85b752dce623333e363fadfe,jipinbao,1998-03-13,LV,oldschool,1,2020-05-28,20000,35000"
    */
    function activateBag(string memory _bagid, string memory _fields) public returns(int8){
        string memory lastThreeParams = ",0,0,0";
        string memory storeFields = StringUtil.strConcat2(_fields, lastThreeParams);

        return insertOneRecord(t_bag_struct, _bagid, storeFields, false);
    }

   /*
    * 查询包包是否已经激活
    *
    * @param _bagid  包包id
    *
    * @return 激活状态，1为已激活，0为未激活
    *
    * 测试举例  参数一："BG00001"
    */
    function isBagActivated(string bagid) public view returns (string) {
         int8 retCode;
         string[] memory retArray;
         (retCode, retArray) = getBagRecordArray(bagid);
         return retArray[5];
    }


   /*
    * 查询包包信息并以字符串数组方式输出
    *
    * @param _bagid  包包id
    *
    * @return 执行状态码
    * @return 该包包信息的字符串数组
    *
    * 测试举例  参数一："BG00001"
    */
    function getBagRecordArray(string bagid) public view returns(int8, string[]){

        return selectOneRecordToArray(t_bag_struct, bagid, ["bag_id",bagid]);
    }


   /*
    * 查询包包信息并以Json字符串方式输出
    *
    * @param _bagid  包包id
    *
    * @return 执行状态码
    * @return 该包包信息的Json字符串
    *
    * 测试举例  参数一："BG00001"
    */
    function getBagRecordJson(string bagid) public view returns(int8, string){

        return selectOneRecordToJson(t_bag_struct, bagid);
    }


}
