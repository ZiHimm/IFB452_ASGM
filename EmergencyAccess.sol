// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EmergencyAccess {
    //Defining roles
    enum Role { None, Paramedic, Physician}

    //How does Provider look like
    struct Provider{
        address wallet;
        Role role;
        bool isRegistered; //proof that healthcare provider is registered
    }

    //How does Patient look like
    struct PatientRecord{
        string patientID; //stores Patient's ID
        string recordHash; //stores hash of patient record
        string dbReference; //SQLite row reference
        bool exists; //if the patient exists
    }

    //Access granted system
    struct accessSession{
        address provider;
        string patientID;
        uint startTime; //record start time of session
        bool isActive; //access session state
    }

    //Stores Variables
    address public admin ; //deployer (instituion)

    mapping (address => Provider) public providers;
    mapping (string => PatientRecord) public patientRecords;
    mapping (address => accessSession) public activeSessions;

    //Events that goes into Audit Log
    event ProviderRegistered (address provider, Role role);
    event RecordSubmitted (string patientID, string recordHash);
    event AccessGranted (address Provider, string patientID, Role role, uint startTime);
    event AccessRevoked (address Provider, string patientID, uint timestamp);

    //Constructors and Modiefiers
    constructor(){
        admin = msg.sender;
    }

    modifier onlyAdmin(){
        require (msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyRegisteredProvider(){
        require (providers[msg.sender].isRegistered, "Provider not registered");
        _;
    }

    //institution functions
    //institution registers as provider
    function registerProvider(address _provider, Role _role)public onlyAdmin{
        providers[_provider] = Provider(_provider, _role, true);
        emit ProviderRegistered (_provider, _role);
    }
    
    //institution submits Patient record
    function submitRecord(
        string memory _patientID,
        string memory _recordHash,
        string memory _dbReference
    ) public onlyAdmin {
        patientRecords[_patientID] = PatientRecord(
            _patientID,
            _recordHash,
            _dbReference,
            true
        );
        emit RecordSubmitted (_patientID, _recordHash);
    }

    //Emergency situtation
    function requestEmergencyAccess (string memory _patientID) public onlyRegisteredProvider {
        require (patientRecords [_patientID].exists, "Patient record not found");
        require (!activeSessions[msg.sender].isActive, "Active session already exists");

        //session starts
        activeSessions[msg.sender]= accessSession(
            msg.sender,
            _patientID,
            block.timestamp,
            true
        );
        emit AccessGranted(msg.sender, _patientID, providers[msg.sender].role, block.timestamp);
    }

        //role-based data retrieval
        function getPatientData(string memory _patientID) public view onlyRegisteredProvider returns (string memory dataScope, string memory dbReference) {
            accessSession memory session = activeSessions [msg.sender];

            require(session.isActive, "No active session for this patient");
            require ( keccak256(bytes(session.patientID)) == keccak256(bytes(_patientID)),"No active session for this patient");
            require(block.timestamp <= session.startTime + 15 minutes, "Acccess window Expired");
        
            //role base scoping
            if (providers[msg.sender].role == Role.Paramedic){
                dataScope = "Triage"; //frontend only fetches triage fields
            } else {
                dataScope = "FULL"; //frontend fetches full record
            }

            dbReference = patientRecords[_patientID].dbReference;
        }
        
        //Revoking access
        function revokeAccess () public onlyRegisteredProvider {
            require (activeSessions[msg.sender].isActive, "No active session");
            
            string memory patientID = activeSessions[msg.sender].patientID;
            activeSessions[msg.sender].isActive = false;

            emit AccessRevoked(msg.sender, patientID, block.timestamp);
        } 
    }