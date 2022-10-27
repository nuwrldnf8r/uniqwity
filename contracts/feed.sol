// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Feed {
     
    mapping(bytes32 => uint256) private _keyIdx;
    uint256 private _lastKeyIdx;
    
    mapping(uint256 => mapping(uint256 => uint256)) private _feed;
    mapping(uint256 => uint256) private _feedNum;

    struct Post{
        address creator;
        uint256 parent;
    }

    mapping(uint256 => string) private _cids;
    mapping(uint256 => Post) private _posts;
    mapping(uint256 => address) private _feedCreator;
    mapping(uint256 => uint256) private _parent;
    mapping(uint256 => mapping(address => bool)) private _blocked;
    

    constructor(){}

    function _getKeyIdx(string calldata key) private view returns (uint256){
        return _keyIdx[keccak256(abi.encode(key))];
    }
    
    function _getKeyIdx(address key) private view returns (uint256){
        return _keyIdx[keccak256(abi.encode(key))];
    }

    function _createFeed() private returns (uint256){
        _lastKeyIdx++;
        uint256 idx = _lastKeyIdx;
        _keyIdx[keccak256(abi.encode(msg.sender))] = idx;
        _feedCreator[idx] = msg.sender;
        return idx;
    }

    function _createFeed(string calldata CID) private returns (uint256){
        bytes32 cid = keccak256(abi.encode(CID));
        uint256 idx = _keyIdx[cid];
        if(idx==0){
            _lastKeyIdx++;
            idx = _lastKeyIdx;
            _keyIdx[cid] = idx;
            _feedCreator[idx] = msg.sender;
            _cids[idx] = CID;
        } else {
            if(_posts[idx].creator!=address(0)){
                _feedCreator[idx] = _posts[idx].creator;
            } else {
                _feedCreator[idx] = msg.sender;
            }
        }      
        return idx;
    }

    function post(string calldata CID) public {
        uint256 feedIdx = _getKeyIdx(msg.sender);
        if(feedIdx==0) feedIdx = _createFeed();
        _post(feedIdx,CID);
    }

    function post(string calldata feedCID, string calldata CID) public {
        uint256 feedIdx = _getKeyIdx(msg.sender);
        if(feedIdx == 0) feedIdx = _createFeed(feedCID);
        _post(feedIdx,CID);
    }

    
    function _post(uint256 feedIdx, string calldata CID) private {
        require(_getKeyIdx(CID)==0,"Post already exists");
        require(!isBlocked(msg.sender,feedIdx),"User is blocked from this feed");
        _lastKeyIdx++;
        uint256 idx = _lastKeyIdx;
        //create key for CID
        _keyIdx[keccak256(abi.encode(CID))] = idx;
        _posts[idx] = Post({
            creator: msg.sender,
            parent: feedIdx
        });
        _feed[feedIdx][_feedNum[feedIdx]] = idx;
        _feedNum[feedIdx] ++;
    }
    

    function getFeedIdx(address account) public view returns (uint256){
        return _getKeyIdx(account);
    }

    function getFeedIdx(string calldata feedCID) public view returns (uint256){
        return _getKeyIdx(feedCID);
    }

    function getFeedLength(uint256 feedIdx) public view returns (uint256){
        if(feedIdx==0) return 0;
        return _feedNum[feedIdx];
    }

    function getPost(uint256 feedIdx, uint256 idx) public view returns (string memory){
        require(getFeedLength(feedIdx)>idx,"Index out of bounds");
        uint256 _idx = _feed[feedIdx][idx];
        return _cids[_idx];
    }

    function getCreator(uint256 idx) public view returns (address){
        if(_posts[idx].creator != address(0)) return _posts[idx].creator;
        return _feedCreator[idx];
    }

    function getKey(string calldata CID) public view returns (uint256){
        return _getKeyIdx(CID);
    }

    function edit(uint256 idx, string calldata newCID) public {
        require(getCreator(idx)==msg.sender,"Not authorized to edit");
        require(_getKeyIdx(newCID)==0,"CID already exists");
        _keyIdx[keccak256(abi.encode(newCID))] = idx;
        _cids[idx] = newCID;
    }

    function getParentFeed(uint256 idx) public view returns (uint256){
        while(true){
            if(_posts[idx].parent==0) break;
            idx = _posts[idx].parent;
        }
        return idx;
    }

    function isBlocked(address account, uint256 feedIdx) public view returns (bool){
        feedIdx = getParentFeed(feedIdx);
        return _blocked[feedIdx][account];
    }

    function setBlockAccount(address account, bool isBlocked_) public {
        uint256 feedIdx = _getKeyIdx(msg.sender);
        if(feedIdx==0) feedIdx = _createFeed();
        setBlockAccount(account,feedIdx,isBlocked_);
    }

    function setBlockAccount(address account, uint256 feedIdx, bool isBlocked_) public {
        feedIdx = getParentFeed(feedIdx);
        require(account!=msg.sender,"You cannot block yourself");
        require(_feedCreator[feedIdx] == msg.sender,"Not authorized to block accounts in this feed");
        _blocked[feedIdx][account] = isBlocked_;
    } 


}
