// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Holon {

    enum ConnectionType{
        none,
        oneWay,
        twoWayRequested,
        twoWayRequest,
        twoWay,
        blocked
    }

    struct Connection{
        uint256 to;
        ConnectionType type_;
    }

    mapping(uint256 => string) private _holons;
    mapping(bytes32 => uint256) private _index;
    mapping(uint256 => address) private _owner;
    uint256 private _numHolons;

    mapping (uint256 => mapping(uint256 => Connection)) private _connections;
    mapping (uint256 => uint256) private _numConnections;
    mapping (uint256 => mapping(uint256 => uint256)) private _connectionIdx;

    function create(string calldata data, bool canEdit_) public returns (uint256){
        bytes memory b = bytes(data);
        require(b.length<=64,"data too large");
        require(!exists(data),"Already exists");
        _holons[_numHolons] = data;
        _index[keccak256(abi.encode(data))] = _numHolons;
        if(canEdit_){
            _owner[_numHolons] = msg.sender;
        }
        uint256 index = _numHolons;
        _numHolons++;
        return index;
    }

    function exists(string memory data) public view returns (bool){
        bytes32 hash = keccak256(abi.encode(data));
        bytes32 compare = keccak256(abi.encode(_holons[_index[hash]]));
        return (compare==hash);
    }

    function getData(uint256 index) public view returns (string memory){
        require(index<_numHolons,"Index out of bounds");
        return _holons[index];
    }

    function getIndex(string calldata data) public view returns (uint256){
        require(exists(data),"data does not exist");
        return _index[keccak256(abi.encode(data))];
    }

    function canEdit(uint256 index) public view returns (bool){
        require(index<_numHolons,"Index out of bounds");
        return _owner[index]!=address(0);
    }

    function edit(uint256 index, string calldata newdata) public {
        require(index<_numHolons,"Index out of bounds");
        require(_owner[index]==msg.sender,"Not authorized to edit");
        bytes memory b = bytes(newdata);
        require(b.length<=64,"data too large");
        bytes32 hash = keccak256(abi.encode(_holons[index]));
        _index[hash] = 0;
        hash = keccak256(abi.encode(newdata));
        _holons[index] = newdata;
        _index[hash] = index;
    }

    function transferOwner(uint256 index, address newOwner) public {
        require(index<_numHolons,"Index out of bounds");
        require(_owner[index]==msg.sender,"Not authorized to transfer ownership");
        _owner[index] = newOwner;
    }

    function ownerOf(uint256 index) public view returns (address){
        require(index<_numHolons,"Index out of bounds");
        return _owner[index];
    }


    function addConnection(uint256 from, uint256 to, ConnectionType connectionType) public {
        require(connectionType!=ConnectionType.none && connectionType!=ConnectionType.blocked,"Invalid connection type");
        require(from<_numHolons,"from out of bounds");
        require(to<_numHolons,"to out of bounds");
        require(_owner[from]==msg.sender || !canEdit(from),"Not authorized to make connections from this holon");
        require(!connectionExists(from,to),"Connection already exists");
        require(!isBlocked(from,to) && !isBlocked(to,from),"Connection is blocked");
        ConnectionType typeFrom = connectionType;
        ConnectionType typeTo = connectionType;
        if(connectionType==ConnectionType.twoWay && canEdit(to) && _owner[to]!=msg.sender){
            typeFrom = ConnectionType.twoWayRequested;
            typeTo = ConnectionType.twoWayRequest;
        }
        uint256 idxFrom = _numConnections[from];
        uint256 idxTo = _numConnections[to];
        _connections[from][idxFrom] = Connection({to:to,type_:typeFrom});
        _connectionIdx[from][to] = idxFrom;
        _numConnections[from]++;
        if(connectionType!=ConnectionType.oneWay){
            _connections[to][_numConnections[to]] = Connection({to:from,type_:typeTo});
            _connectionIdx[to][from] = idxTo;
            _numConnections[to]++;
        }
    }

    function numConnections(uint256 index) public view returns (uint256){
        require(index<_numHolons,"from out of bounds");
        return _numConnections[index];
    }

    function getConnectionByIndex(uint256 from, uint256 index) public view returns (Connection memory){
        require(_numConnections[from]>index,"Index out of bounds");
        return _connections[from][index];
    }

    function connectionExists(uint256 from, uint256 to) public view returns (bool){
        require(from<_numHolons,"from out of bounds");
        require(to<_numHolons,"to out of bounds");
        Connection memory connection = _connections[from][_connectionIdx[from][to]];
        return (connection.type_ != ConnectionType.none);
    }

    function isBlocked(uint256 from, uint256 to) public view returns (bool){
        require(from<_numHolons,"from out of bounds");
        require(to<_numHolons,"to out of bounds");
        Connection memory connection1 = _connections[from][_connectionIdx[from][to]];
        Connection memory connection2 = _connections[to][_connectionIdx[to][from]];
        return (connection1.type_ == ConnectionType.blocked || connection2.type_ == ConnectionType.blocked);
    }

    function getConnection(uint256 from, uint256 to) public view returns (Connection memory){
        require(connectionExists(from,to),"Connection does not exist");
        return _connections[from][_connectionIdx[from][to]];
    }

    function respondToConnectionRequest(uint256 from, uint256 to, bool accept) public {
        require(connectionExists(to,from),"Connection does not exist");
        require(_owner[to]==msg.sender,"Unable to accept a connection for an unowned holon");
        Connection memory connection = _connections[to][_connectionIdx[to][from]];
        require(connection.type_==ConnectionType.twoWayRequest || connection.type_==ConnectionType.twoWay,"Invalid connection type");
        if(!accept) return deleteConnection(to, from);
    }
    
    function deleteConnection(uint256 from, uint256 to) public {
        require(connectionExists(from,to),"Connection does not exist");
        require(_owner[from]==msg.sender || _owner[to]==msg.sender,"Unauthorized to delete");
        uint256 id1 = _connectionIdx[from][to];
        uint256 id2 = _connectionIdx[to][from];
        require(_connections[from][id1].type_!=ConnectionType.blocked || _connections[to][id2].type_!=ConnectionType.blocked,"Cannot delete a blocked connection"); 
        _connections[from][id1].type_ = ConnectionType.none;
        _connections[to][id2].type_ = ConnectionType.none;
    }

    function setBlock(uint256 from, uint256 to, bool setBlocked) public {
        require(connectionExists(from,to),"Connection does not exist");
        require(_owner[from]==msg.sender,"Unauthorized to block");
        if(setBlocked){
            _connections[from][_connectionIdx[from][to]].type_ = ConnectionType.blocked;
        } else {
            deleteConnection(from,to);
        }
    }
    
}
