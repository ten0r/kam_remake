unit KM_GameInputProcess;
{$I KaM_Remake.inc}
interface
uses
  KM_Units, KM_UnitGroups,
  KM_Houses, KM_HouseWoodcutters,
  KM_ResHouses, KM_ResWares,
  KM_CommonClasses, KM_Defaults, KM_Points;

{ A. This unit takes and adjoins players input from TGame and TGamePlayInterfaces clicks and keys
  Then passes it on to game events.
  E.g. there are 2 ways player can place an order to selected Warrior:
  1. Click on map
  2. Click on minimap

  B. And most important, it accumulates and feeds player input to the game.
  Thus making possible to:
   - record gameplay
   - playback replays
   - send input through LAN to make multiplayer games

  This is a polymorphic unit which is only used as the parent of TGameInputProcess_Single for single
  player or TGameInputProcess_Multi for multiplayer
  It contains a few common methods such as replays as well as abstract methods for the child classes to handle.
  Most importantly it converts all Cmd____ methods called by TGamePlayInterfaces into one procedure
  ProcessCommandFromPlayer. Single and Multi then use this according to their needs.
  Replays are stored and managed here, hidden from the child classes by private. They add new replay
  commands with StoreCommand, and in gipReplaying state commands are executed on Tick
  }

const MAX_PARAMS = 4; //There are maximum of 4 integers passed along with a command

type
  TGIPReplayState = (gipRecording, gipReplaying);

  TGameInputCommandType = (
    gic_None,
    //I.      Army commands, only warriors (TKMUnitWarrior, OrderInfo)
    gic_ArmyFeed,
    gic_ArmySplit,
    gic_ArmySplitSingle,
    gic_ArmyLink,
    gic_ArmyAttackUnit,
    gic_ArmyAttackHouse,
    gic_ArmyHalt,
    gic_ArmyFormation,    //Formation commands
    gic_ArmyWalk,         //Walking
    gic_ArmyStorm,        //StormAttack

    //II.     Building/road plans (what to build and where)
    gic_BuildAddFieldPlan,
    gic_BuildRemoveFieldPlan, //Removal of a plan
    gic_BuildRemoveHouse,     //Removal of house
    gic_BuildRemoveHousePlan, //Removal of house plan
    gic_BuildHousePlan,       //Build HouseType

    //III.    House repair/delivery/orders (TKMHouse, Toggle(repair, delivery, orders))
    gic_HouseRepairToggle,
    gic_HouseDeliveryToggle,          //Including storehouse. (On/Off, ResourceType)
    gic_HouseClosedForWorkerToggle,   //Toggle house state for worker - vacate or occupy
    gic_HouseOrderProduct,            //Place an order to manufacture warfare
    gic_HouseMarketFrom,              //Select wares to trade in marketplace
    gic_HouseMarketTo,                //Select wares to trade in marketplace
    gic_HouseWoodcutterMode,          //Switch the woodcutter mode
    gic_HouseArmorWSDeliveryToggle,   //Toggle resourse delivery to armor workshop
    gic_HouseStoreAcceptFlag,         //Control wares delivery to store
    gic_HouseSchoolTrain,             //Place an order to train citizen
    gic_HouseSchoolTrainChOrder,      //Change school training order
    gic_HouseSchoolTrainChLastUOrder, //Change school training order for last unit in queue
    gic_HouseBarracksAcceptFlag,      //Control wares delivery to barracks
    gic_HouseBarracksAcceptRecruitsToggle,  //Toggle are recruits allowed to enter barracks or not
    gic_HouseBarracksEquip,           //Place an order to train warrior in the Barracks
    gic_HouseBarracksRally,           //Set the rally point for the Barracks
    gic_HouseTownHallEquip,           //Place an order to train warrior in the TownHall
    gic_HouseTownHallRally,           //Set the rally point for the TownHall
    gic_HouseRemoveTrain,             //Remove unit being trained from School
    gic_HouseWoodcuttersCutting,      //Set the cutting point for the Woodcutters

    //IV.     Delivery ratios changes (and other game-global settings)
    gic_WareDistributionChange,   //Change of distribution for 1 ware
    gic_WareDistributions,        //Update distributions for all wares at ones

    //V.      Game changes
    gic_GameAlertBeacon,          //Signal alert (beacon)
    gic_GamePause,
    gic_GameAutoSave,
    gic_GameAutoSaveAfterPT,
    gic_GameSaveReturnLobby,
    gic_GameTeamChange,
    gic_GameHotkeySet,        //Hotkeys are synced for MP saves (UI keeps local copy to avoid GIP delays)
    gic_GameMessageLogRead,   //Player marks a message in their log as read
    gic_GamePlayerTypeChange, //Players can be changed to AI when loading a save
    gic_GamePlayerDefeat,     //Player can be defeated after intentional quit from the game

    //VI.      Cheatcodes affecting gameplay (props)

    //VII.     Temporary and debug commands
    gic_TempAddScout,
    gic_TempRevealMap, //Revealing the map can have an impact on the game. Events happen based on tiles being revealed
    gic_TempVictory,
    gic_TempDefeat,
    gic_TempDoNothing  //Used for "aggressive" replays that store a command every tick

    { Optional input }
    //VI.     Viewport settings for replay (location, zoom)
    //VII.    Message queue handling in gameplay interface
    //IX.     Text messages for multiplayer (moved to Networking)
    );

  TGameInputCommandPackType = (
    gicpt_NoParams,
    gicpt_Int1,
    gicpt_Int2,
    gicpt_Int3,
    gicpt_Int4,
    gicpt_Text,
    gicpt_Date);

const
  BlockedByPeaceTime: set of TGameInputCommandType = [gic_ArmySplit, gic_ArmySplitSingle,
    gic_ArmyLink, gic_ArmyAttackUnit, gic_ArmyAttackHouse, gic_ArmyHalt,
    gic_ArmyFormation,  gic_ArmyWalk, gic_ArmyStorm, gic_HouseBarracksEquip];
  AllowedAfterDefeat: set of TGameInputCommandType = [gic_GameAlertBeacon, gic_GameAutoSave, gic_GameAutoSaveAfterPT, gic_GameSaveReturnLobby, gic_GameMessageLogRead, gic_TempDoNothing];
  AllowedInCinematic: set of TGameInputCommandType = [gic_GameAlertBeacon, gic_GameAutoSave, gic_GameAutoSaveAfterPT, gic_GameSaveReturnLobby, gic_GameMessageLogRead, gic_TempDoNothing];
  AllowedBySpectators: set of TGameInputCommandType = [gic_GameAlertBeacon, gic_GameAutoSave, gic_GameAutoSaveAfterPT, gic_GameSaveReturnLobby, gic_GamePlayerDefeat, gic_TempDoNothing];

  ArmyOrderCommands: set of TGameInputCommandType = [
    gic_ArmyFeed,
    gic_ArmySplit,
    gic_ArmySplitSingle,
    gic_ArmyLink,
    gic_ArmyAttackUnit,
    gic_ArmyAttackHouse,
    gic_ArmyHalt,
    gic_ArmyFormation,
    gic_ArmyWalk,
    gic_ArmyStorm];

  HouseOrderCommands: set of TGameInputCommandType = [
    gic_HouseRepairToggle,
    gic_HouseDeliveryToggle,
    gic_HouseClosedForWorkerToggle,
    gic_HouseOrderProduct,
    gic_HouseMarketFrom,
    gic_HouseMarketTo,
    gic_HouseWoodcutterMode,
    gic_HouseStoreAcceptFlag,
    gic_HouseSchoolTrain,
    gic_HouseSchoolTrainChOrder,
    gic_HouseSchoolTrainChLastUOrder,
    gic_HouseBarracksAcceptFlag,
    gic_HouseBarracksAcceptRecruitsToggle,
    gic_HouseBarracksEquip,
    gic_HouseBarracksRally,
    gic_HouseRemoveTrain,
    gic_HouseWoodcuttersCutting];


  CommandPackType: array[TGameInputCommandType] of TGameInputCommandPackType = (
    gicpt_NoParams, // gic_None
    //I.      Army commands, only warriors (TKMUnitWarrior, OrderInfo)
    gicpt_Int1,     // gic_ArmyFeed
    gicpt_Int1,     // gic_ArmySplit
    gicpt_Int1,     // gic_ArmySplitSingle
    gicpt_Int2,     // gic_ArmyLink
    gicpt_Int2,     // gic_ArmyAttackUnit
    gicpt_Int2,     // gic_ArmyAttackHouse
    gicpt_Int1,     // gic_ArmyHalt
    gicpt_Int3,     // gic_ArmyFormation
    gicpt_Int4,     // gic_ArmyWalk
    gicpt_Int1,     // gic_ArmyStorm
    //II.     Building/road plans (what to build and where)
    gicpt_Int3,     // gic_BuildAddFieldPlan
    gicpt_Int2,     // gic_BuildRemoveFieldPlan
    gicpt_Int2,     // gic_BuildRemoveHouse
    gicpt_Int2,     // gic_BuildRemoveHousePlan
    gicpt_Int3,     // gic_BuildHousePlan
    //III.    House repair/delivery/orders (TKMHouse, Toggle(repair, delivery, orders))
    gicpt_Int1,     // gic_HouseRepairToggle
    gicpt_Int2,     // gic_HouseDeliveryToggle
    gicpt_Int1,     // gic_HouseClosedForWorkerToggle
    gicpt_Int3,     // gic_HouseOrderProduct
    gicpt_Int2,     // gic_HouseMarketFrom
    gicpt_Int2,     // gic_HouseMarketTo
    gicpt_Int2,     // gic_HouseWoodcutterMode
    gicpt_Int2,     // gic_HouseArmorWSDeliveryToggle
    gicpt_Int2,     // gic_HouseStoreAcceptFlag
    gicpt_Int3,     // gic_HouseSchoolTrain
    gicpt_Int3,     // gic_HouseSchoolTrainChOrder
    gicpt_Int2,     // gic_HouseSchoolTrainChLastUOrder
    gicpt_Int2,     // gic_HouseBarracksAcceptFlag
    gicpt_Int1,     // gic_HouseBarracksAcceptRecruitsToggle
    gicpt_Int3,     // gic_HouseBarracksEquip
    gicpt_Int3,     // gic_HouseBarracksRally
    gicpt_Int3,     // gic_HouseTownHallEquip
    gicpt_Int3,     // gic_HouseTownHallRally
    gicpt_Int2,     // gic_HouseRemoveTrain
    gicpt_Int3,     // gic_HouseWoodcuttersCutting
    //IV.     Delivery ratios changes (and other game-global settings)
    gicpt_Int3,     // gic_WareDistributionChange
    gicpt_Text,     // gic_WareDistributions
    //V.      Game changes
    gicpt_Int4,     // gic_GameAlertBeacon
    gicpt_NoParams, // gic_GamePause
    gicpt_Date,     // gic_GameAutoSave
    gicpt_Date,     // gic_GameAutoSaveAfterPT
    gicpt_Date,     // gic_GameSaveReturnLobby
    gicpt_Int2,     // gic_GameTeamChange
    gicpt_Int2,     // gic_GameHotkeySet
    gicpt_Int1,     // gic_GameMessageLogRead
    gicpt_Int2,     // gic_GamePlayerTypeChange
    gicpt_Int1,     // gic_GamePlayerDefeat
    //VII.     Temporary and debug commands
    gicpt_Int2,     // gic_TempAddScout
    gicpt_NoParams, // gic_TempRevealMap
    gicpt_NoParams, // gic_TempVictory
    gicpt_NoParams, // gic_TempDefeat
    gicpt_NoParams  // gic_TempDoNothing
  );

type
  TGameInputCommand = record
    CommandType: TGameInputCommandType;
    Params: array[1..MAX_PARAMS]of integer;
    TextParam: UnicodeString;
    DateTimeParam: TDateTime;
    HandIndex: TKMHandIndex; //Player for which the command is to be issued. (Needed for multiplayer and other reasons)
  end;

  function IsSelectedObjectCommand(aGIC: TGameInputCommandType): Boolean;
  //As TGameInputCommand is no longer fixed size (due to the string) we cannot simply read/write it as a block
  procedure SaveCommandToMemoryStream(aCommand: TGameInputCommand; aMemoryStream: TKMemoryStream);
  procedure LoadCommandFromMemoryStream(out aCommand: TGameInputCommand; aMemoryStream: TKMemoryStream);

type
  TGameInputProcess = class
  private
    fCount: Integer;
    fReplayState: TGIPReplayState;
  protected
    fCursor: Integer; //Used only in gipReplaying
    fQueue: array of packed record
      Tick: Cardinal;
      Command: TGameInputCommand;
      Rand: Cardinal; //acts as CRC check
    end;

    function MakeEmptyCommand(aGIC: TGameInputCommandType): TGameInputCommand;
    function MakeCommand(aGIC: TGameInputCommandType): TGameInputCommand; overload;
    function MakeCommand(aGIC: TGameInputCommandType; const aParam1: Integer): TGameInputCommand; overload;
    function MakeCommand(aGIC: TGameInputCommandType; const aParam1, aParam2: Integer): TGameInputCommand; overload;
    function MakeCommand(aGIC: TGameInputCommandType; const aParam1, aParam2, aParam3: Integer): TGameInputCommand; overload;
    function MakeCommand(aGIC: TGameInputCommandType; const aParam1, aParam2, aParam3, aParam4: Integer): TGameInputCommand; overload;
    function MakeCommand(aGIC: TGameInputCommandType; const aTextParam: UnicodeString): TGameInputCommand; overload;
    function MakeCommand(aGIC: TGameInputCommandType; aDateTimeParam: TDateTime): TGameInputCommand; overload;
    procedure TakeCommand(aCommand: TGameInputCommand); virtual; abstract;
    procedure ExecCommand(aCommand: TGameInputCommand);
    procedure StoreCommand(aCommand: TGameInputCommand);
    procedure ExecGameAlertBeaconCmd(aCommand: TGameInputCommand);
  public
    constructor Create(aReplayState: TGIPReplayState);
    destructor Destroy; override;

    procedure CmdArmy(aCommandType: TGameInputCommandType; aGroup: TKMUnitGroup); overload;
    procedure CmdArmy(aCommandType: TGameInputCommandType; aGroup: TKMUnitGroup; aUnit: TKMUnit); overload;
    procedure CmdArmy(aCommandType: TGameInputCommandType; aGroup1, aGroup2: TKMUnitGroup); overload;
    procedure CmdArmy(aCommandType: TGameInputCommandType; aGroup: TKMUnitGroup; aHouse: TKMHouse); overload;
    procedure CmdArmy(aCommandType: TGameInputCommandType; aGroup: TKMUnitGroup; aTurnAmount: TKMTurnDirection; aLineAmount:shortint); overload;
    procedure CmdArmy(aCommandType: TGameInputCommandType; aGroup: TKMUnitGroup; aLoc: TKMPoint; aDirection: TKMDirection); overload;

    procedure CmdBuild(aCommandType: TGameInputCommandType; aLoc: TKMPoint); overload;
    procedure CmdBuild(aCommandType: TGameInputCommandType; aLoc: TKMPoint; aFieldType: TFieldType); overload;
    procedure CmdBuild(aCommandType: TGameInputCommandType; aLoc: TKMPoint; aHouseType: THouseType); overload;

    procedure CmdHouse(aCommandType: TGameInputCommandType; aHouse: TKMHouse); overload;
    procedure CmdHouse(aCommandType: TGameInputCommandType; aHouse: TKMHouse; aItem, aAmountChange: Integer); overload;
    procedure CmdHouse(aCommandType: TGameInputCommandType; aHouse: TKMHouse; aWareType: TWareType); overload;
    procedure CmdHouse(aCommandType: TGameInputCommandType; aHouse: TKMHouse; aWoodcutterMode: TKMWoodcutterMode); overload;
    procedure CmdHouse(aCommandType: TGameInputCommandType; aHouse: TKMHouse; aUnitType: TUnitType; aCount: Integer); overload;
    procedure CmdHouse(aCommandType: TGameInputCommandType; aHouse: TKMHouse; aItem: Integer); overload;
    procedure CmdHouse(aCommandType: TGameInputCommandType; aHouse: TKMHouse; aLoc: TKMPoint); overload;
    procedure CmdHouse(aCommandType: TGameInputCommandType; aHouse: TKMHouse; aDeliveryMode: TDeliveryMode); overload;

    procedure CmdWareDistribution(aCommandType: TGameInputCommandType; aWare: TWareType; aHouseType: THouseType; aValue:integer); overload;
    procedure CmdWareDistribution(aCommandType: TGameInputCommandType; const aTextParam: UnicodeString); overload;

    procedure CmdGame(aCommandType: TGameInputCommandType; aValue:boolean); overload;
    procedure CmdGame(aCommandType: TGameInputCommandType; aDateTime: TDateTime); overload;
    procedure CmdGame(aCommandType: TGameInputCommandType; aParam1, aParam2: Integer); overload;
    procedure CmdGame(aCommandType: TGameInputCommandType; aLoc: TKMPointF; aOwner: TKMHandIndex; aColor: Cardinal); overload;
    procedure CmdGame(aCommandType: TGameInputCommandType; aValue: Integer); overload;

    procedure CmdTemp(aCommandType: TGameInputCommandType; aLoc: TKMPoint); overload;
    procedure CmdTemp(aCommandType: TGameInputCommandType); overload;

    function CommandsConfirmed(aTick: Cardinal): Boolean; virtual;
    procedure WaitingForConfirmation(aTick: Cardinal); virtual;
    procedure ReplayTimer(aTick: Cardinal); virtual;
    procedure RunningTimer(aTick: Cardinal); virtual;
    procedure UpdateState(aTick: Cardinal); virtual;

    //Replay methods
    procedure SaveToFile(const aFileName: UnicodeString);
    procedure LoadFromFile(const aFileName: UnicodeString);
    property Count: Integer read fCount;
    property ReplayState: TGIPReplayState read fReplayState;
    function GetLastTick: Cardinal;
    function ReplayEnded: Boolean;
  end;


implementation
uses
  SysUtils, TypInfo,
  KM_GameApp, KM_Game, KM_Hand, KM_HandsCollection,
  KM_HouseMarket, KM_HouseBarracks, KM_HouseSchool, KM_HouseTownHall,
  KM_ScriptingEvents, KM_Alerts, KM_CommonUtils;


function IsSelectedObjectCommand(aGIC: TGameInputCommandType): Boolean;
begin
  Result := (aGIC in ArmyOrderCommands) or (aGIC in HouseOrderCommands);
end;


procedure SaveCommandToMemoryStream(aCommand: TGameInputCommand; aMemoryStream: TKMemoryStream);
begin
  with aCommand do
  begin
    aMemoryStream.Write(CommandType, SizeOf(CommandType));
    case CommandPackType[CommandType] of
      gicpt_NoParams: ;
      gicpt_Int1:     aMemoryStream.Write(Params[1]);
      gicpt_Int2:     begin
                        aMemoryStream.Write(Params[1]);
                        aMemoryStream.Write(Params[2]);
                      end;
      gicpt_Int3:     begin
                        aMemoryStream.Write(Params[1]);
                        aMemoryStream.Write(Params[2]);
                        aMemoryStream.Write(Params[3]);
                      end;
      gicpt_Int4:     begin
                        aMemoryStream.Write(Params[1]);
                        aMemoryStream.Write(Params[2]);
                        aMemoryStream.Write(Params[3]);
                        aMemoryStream.Write(Params[4]);
                      end;
      gicpt_Text:     aMemoryStream.WriteW(TextParam);
      gicpt_Date:     aMemoryStream.Write(DateTimeParam);
    end;
    aMemoryStream.Write(HandIndex);
  end;
end;


procedure LoadCommandFromMemoryStream(out aCommand: TGameInputCommand; aMemoryStream: TKMemoryStream);
begin
  with aCommand do
  begin
    aMemoryStream.Read(CommandType, SizeOf(CommandType));
    case CommandPackType[CommandType] of
      gicpt_NoParams: ;
      gicpt_Int1:     aMemoryStream.Read(Params[1]);
      gicpt_Int2:     begin
                        aMemoryStream.Read(Params[1]);
                        aMemoryStream.Read(Params[2]);
                      end;
      gicpt_Int3:     begin
                        aMemoryStream.Read(Params[1]);
                        aMemoryStream.Read(Params[2]);
                        aMemoryStream.Read(Params[3]);
                      end;
      gicpt_Int4:     begin
                        aMemoryStream.Read(Params[1]);
                        aMemoryStream.Read(Params[2]);
                        aMemoryStream.Read(Params[3]);
                        aMemoryStream.Read(Params[4]);
                      end;
      gicpt_Text:     aMemoryStream.ReadW(TextParam);
      gicpt_Date:     aMemoryStream.Read(DateTimeParam);
    end;
    aMemoryStream.Read(HandIndex);
  end;
end;


{ TGameInputProcess }
constructor TGameInputProcess.Create(aReplayState: TGIPReplayState);
begin
  inherited Create;
  setlength(fQueue, 128);
  fCount := 0;
  fCursor := 1;
  fReplayState := aReplayState;
end;


destructor TGameInputProcess.Destroy;
begin
  inherited;
end;


function TGameInputProcess.MakeEmptyCommand(aGIC: TGameInputCommandType): TGameInputCommand;
begin
  Result.CommandType := aGIC;
  Result.HandIndex := gMySpectator.HandIndex;
end;


function TGameInputProcess.MakeCommand(aGIC: TGameInputCommandType): TGameInputCommand;
begin
  Assert(CommandPackType[aGIC] = gicpt_NoParams,
         Format('Wrong packing type for command %s: Expected: gicpt_NoParams Actual: [%s]',
                [GetEnumName(TypeInfo(TGameInputCommandType), Integer(aGIC)),
                 GetEnumName(TypeInfo(TGameInputCommandPackType), Integer(CommandPackType[aGIC]))]));
  Result := MakeEmptyCommand(aGIC);
end;


function TGameInputProcess.MakeCommand(aGIC: TGameInputCommandType; const aParam1: Integer): TGameInputCommand;
begin
  Assert(CommandPackType[aGIC] = gicpt_Int1,
         Format('Wrong packing type for command %s: Expected: gicpt_Int1 Actual: [%s]',
                [GetEnumName(TypeInfo(TGameInputCommandType), Integer(aGIC)),
                 GetEnumName(TypeInfo(TGameInputCommandPackType), Integer(CommandPackType[aGIC]))]));
  Result := MakeEmptyCommand(aGIC);
  Result.Params[1] := aParam1;
end;


function TGameInputProcess.MakeCommand(aGIC: TGameInputCommandType; const aParam1, aParam2: Integer): TGameInputCommand;
begin
  Assert(CommandPackType[aGIC] = gicpt_Int2,
         Format('Wrong packing type for command %s: Expected: gicpt_Int2 Actual: [%s]',
                [GetEnumName(TypeInfo(TGameInputCommandType), Integer(aGIC)),
                 GetEnumName(TypeInfo(TGameInputCommandPackType), Integer(CommandPackType[aGIC]))]));
  Result := MakeEmptyCommand(aGIC);
  Result.Params[1] := aParam1;
  Result.Params[2] := aParam2;
end;


function TGameInputProcess.MakeCommand(aGIC: TGameInputCommandType; const aParam1, aParam2, aParam3: Integer): TGameInputCommand;
begin
  Assert(CommandPackType[aGIC] = gicpt_Int3,
         Format('Wrong packing type for command %s: Expected: gicpt_Int3 Actual: [%s]',
                [GetEnumName(TypeInfo(TGameInputCommandType), Integer(aGIC)),
                 GetEnumName(TypeInfo(TGameInputCommandPackType), Integer(CommandPackType[aGIC]))]));
  Result := MakeEmptyCommand(aGIC);
  Result.Params[1] := aParam1;
  Result.Params[2] := aParam2;
  Result.Params[3] := aParam3;
end;


function TGameInputProcess.MakeCommand(aGIC: TGameInputCommandType; const aParam1, aParam2, aParam3, aParam4: Integer): TGameInputCommand;
begin
  Assert(CommandPackType[aGIC] = gicpt_Int4,
         Format('Wrong packing type for command %s: Expected: gicpt_Int4 Actual: [%s]',
                [GetEnumName(TypeInfo(TGameInputCommandType), Integer(aGIC)),
                 GetEnumName(TypeInfo(TGameInputCommandPackType), Integer(CommandPackType[aGIC]))]));
  Result := MakeEmptyCommand(aGIC);
  Result.Params[1] := aParam1;
  Result.Params[2] := aParam2;
  Result.Params[3] := aParam3;
  Result.Params[4] := aParam4;
end;


function TGameInputProcess.MakeCommand(aGIC: TGameInputCommandType; const aTextParam: UnicodeString): TGameInputCommand;
begin
  Assert(CommandPackType[aGIC] = gicpt_Text,
         Format('Wrong packing type for command %s: Expected: gicpt_Text Actual: [%s]',
                [GetEnumName(TypeInfo(TGameInputCommandType), Integer(aGIC)),
                 GetEnumName(TypeInfo(TGameInputCommandPackType), Integer(CommandPackType[aGIC]))]));
  Result := MakeEmptyCommand(aGIC);

  Result.TextParam := aTextParam;
end;


function TGameInputProcess.MakeCommand(aGIC: TGameInputCommandType; aDateTimeParam: TDateTime): TGameInputCommand;
begin
  Assert(CommandPackType[aGIC] = gicpt_Date,
         Format('Wrong packing type for command %s: Expected: gicpt_Date Actual: [%s]',
                [GetEnumName(TypeInfo(TGameInputCommandType), Integer(aGIC)),
                 GetEnumName(TypeInfo(TGameInputCommandPackType), Integer(CommandPackType[aGIC]))]));
  Result := MakeEmptyCommand(aGIC);

  Result.DateTimeParam := aDateTimeParam;
end;


procedure TGameInputProcess.ExecCommand(aCommand: TGameInputCommand);
var
  P: TKMHand;
  IsSilent: boolean;
  SrcGroup, TgtGroup: TKMUnitGroup;
  TgtUnit: TKMUnit;
  SrcHouse, TgtHouse: TKMHouse;
begin
  //NOTE: gMySpectator.PlayerIndex should not be used for important stuff here, use P instead (commands must be executed the same for all players)
  IsSilent := (aCommand.HandIndex <> gMySpectator.HandIndex);
  P := gHands[aCommand.HandIndex];
  SrcGroup := nil;
  TgtGroup := nil;
  SrcHouse := nil;
  TgtHouse := nil;
  TgtUnit := nil;

  with aCommand do
  begin
    //It is possible that units/houses have died by now
    if CommandType in [gic_ArmyFeed, gic_ArmySplit, gic_ArmySplitSingle, gic_ArmyLink,
                       gic_ArmyAttackUnit, gic_ArmyAttackHouse, gic_ArmyHalt,
                       gic_ArmyFormation, gic_ArmyWalk, gic_ArmyStorm]
    then
    begin
      SrcGroup := gHands.GetGroupByUID(Params[1]);
      if (SrcGroup = nil) or SrcGroup.IsDead //Group has died before command could be executed
      or (SrcGroup.Owner <> aCommand.HandIndex) then //Potential exploit
        Exit;
    end;
    if CommandType in [gic_ArmyLink] then
    begin
      TgtGroup := gHands.GetGroupByUID(Params[2]);
      if (TgtGroup = nil) or TgtGroup.IsDead //Unit has died before command could be executed
      or (TgtGroup.Owner <> aCommand.HandIndex) then //Potential exploit
        Exit;
    end;
    if CommandType in [gic_ArmyAttackUnit] then
    begin
      TgtUnit := gHands.GetUnitByUID(Params[2]);
      if (TgtUnit = nil) or TgtUnit.IsDeadOrDying then //Unit has died before command could be executed
        Exit;
    end;
    if CommandType in [gic_HouseRepairToggle, gic_HouseDeliveryToggle, gic_HouseWoodcuttersCutting,
      gic_HouseOrderProduct, gic_HouseMarketFrom, gic_HouseMarketTo, gic_HouseBarracksRally, gic_HouseTownHallRally,
      gic_HouseStoreAcceptFlag, gic_HouseBarracksAcceptFlag, gic_HouseBarracksEquip, gic_HouseTownHallEquip, gic_HouseClosedForWorkerToggle,
      gic_HouseSchoolTrain, gic_HouseSchoolTrainChOrder, gic_HouseSchoolTrainChLastUOrder, gic_HouseRemoveTrain,
      gic_HouseWoodcutterMode, gic_HouseBarracksAcceptRecruitsToggle, gic_HouseArmorWSDeliveryToggle] then
    begin
      SrcHouse := gHands.GetHouseByUID(Params[1]);
      if (SrcHouse = nil) or SrcHouse.IsDestroyed //House has been destroyed before command could be executed
      or (SrcHouse.Owner <> aCommand.HandIndex) then //Potential exploit
        Exit;
    end;
    if CommandType in [gic_ArmyAttackHouse] then
    begin
      TgtHouse := gHands.GetHouseByUID(Params[2]);
      if (TgtHouse = nil) or TgtHouse.IsDestroyed then Exit; //House has been destroyed before command could be executed
    end;

    //Some commands are blocked by peacetime (this is a fall back in case players try to cheat)
    if gGame.IsPeaceTime and (CommandType in BlockedByPeaceTime) then
       Exit;

    //No commands allowed after a player has lost (this is a fall back in case players try to cheat)
    if not (aCommand.CommandType in AllowedAfterDefeat) and gGame.IsMultiplayer and P.AI.HasLost then
      Exit;

    //Most commands blocked during cinematic (this is a fall back in case players try to cheat)
    if not (aCommand.CommandType in AllowedInCinematic) and (P.InCinematic) then
      Exit;

    case CommandType of
      gic_ArmyFeed:         SrcGroup.OrderFood(True);
      gic_ArmySplit:        SrcGroup.OrderSplit(True);
      gic_ArmySplitSingle:  SrcGroup.OrderSplit(True, True);
      gic_ArmyStorm:        SrcGroup.OrderStorm(True);
      gic_ArmyLink:         SrcGroup.OrderLinkTo(TgtGroup, True);
      gic_ArmyAttackUnit:   SrcGroup.OrderAttackUnit(TgtUnit, True);
      gic_ArmyAttackHouse:  SrcGroup.OrderAttackHouse(TgtHouse, True);
      gic_ArmyHalt:         SrcGroup.OrderHalt(True);
      gic_ArmyFormation:    SrcGroup.OrderFormation(TKMTurnDirection(Params[2]),Params[3], True);
      gic_ArmyWalk:         SrcGroup.OrderWalk(KMPoint(Params[2],Params[3]), True, TKMDirection(Params[4]));

      gic_BuildAddFieldPlan:      P.ToggleFieldPlan(KMPoint(Params[1],Params[2]), TFieldType(Params[3]), not gGame.IsMultiplayer); //Make sound in singleplayer mode only
      gic_BuildRemoveFieldPlan:   P.RemFieldPlan(KMPoint(Params[1],Params[2]), not gGame.IsMultiplayer); //Make sound in singleplayer mode only
      gic_BuildRemoveHouse:       P.RemHouse(KMPoint(Params[1],Params[2]), IsSilent);
      gic_BuildRemoveHousePlan:   P.RemHousePlan(KMPoint(Params[1],Params[2]));
      gic_BuildHousePlan:         if P.CanAddHousePlan(KMPoint(Params[2],Params[3]), THouseType(Params[1])) then
                                    P.AddHousePlan(THouseType(Params[1]), KMPoint(Params[2],Params[3]));

      gic_HouseRepairToggle:      SrcHouse.BuildingRepair := not SrcHouse.BuildingRepair;
      gic_HouseDeliveryToggle:    //Delivery mode has to be delayed, to avoid occasional delivery mode button clicks
                                  SrcHouse.NewDeliveryMode := TDeliveryMode(Params[2]);
      gic_HouseClosedForWorkerToggle: SrcHouse.IsClosedForWorker := not SrcHouse.IsClosedForWorker;                                  
      gic_HouseOrderProduct:      SrcHouse.ResOrder[Params[2]] := SrcHouse.ResOrder[Params[2]] + Params[3];
      gic_HouseMarketFrom:        TKMHouseMarket(SrcHouse).ResFrom := TWareType(Params[2]);
      gic_HouseMarketTo:          TKMHouseMarket(SrcHouse).ResTo := TWareType(Params[2]);
      gic_HouseStoreAcceptFlag:   TKMHouseStore(SrcHouse).ToggleAcceptFlag(TWareType(Params[2]));
      gic_HouseWoodcutterMode:    TKMHouseWoodcutters(SrcHouse).WoodcutterMode := TKMWoodcutterMode(Params[2]);
      gic_HouseBarracksAcceptFlag:
                                  TKMHouseBarracks(SrcHouse).ToggleAcceptFlag(TWareType(Params[2]));
      gic_HouseBarracksAcceptRecruitsToggle:
                                  TKMHouseBarracks(SrcHouse).ToggleAcceptRecruits;
      gic_HouseBarracksEquip:     TKMHouseBarracks(SrcHouse).Equip(TUnitType(Params[2]), Params[3]);
      gic_HouseBarracksRally:     TKMHouseBarracks(SrcHouse).FlagPoint := KMPoint(Params[2], Params[3]);
      gic_HouseTownHallEquip:     TKMHouseTownHall(SrcHouse).Equip(TUnitType(Params[2]), Params[3]);
      gic_HouseTownHallRally:     TKMHouseTownHall(SrcHouse).FlagPoint := KMPoint(Params[2], Params[3]);
      gic_HouseSchoolTrain:       TKMHouseSchool(SrcHouse).AddUnitToQueue(TUnitType(Params[2]), Params[3]);
      gic_HouseSchoolTrainChOrder:TKMHouseSchool(SrcHouse).ChangeUnitTrainOrder(Params[2], Params[3]);
      gic_HouseSchoolTrainChLastUOrder: TKMHouseSchool(SrcHouse).ChangeUnitTrainOrder(Params[2]);
      gic_HouseRemoveTrain:       TKMHouseSchool(SrcHouse).RemUnitFromQueue(Params[2]);
      gic_HouseWoodcuttersCutting: TKMHouseWoodcutters(SrcHouse).FlagPoint := KMPoint(Params[2], Params[3]);
      gic_HouseArmorWSDeliveryToggle:   TKMHouseArmorWorkshop(SrcHouse).ToggleResDelivery(TWareType(Params[2]));

      gic_WareDistributionChange: begin
                                    P.Stats.WareDistribution[TWareType(Params[1]), THouseType(Params[2])] := Params[3];
                                    P.Houses.UpdateResRequest
                                  end;
      gic_WareDistributions:      begin
                                    P.Stats.WareDistribution.LoadFromStr(TextParam);
                                    P.Houses.UpdateResRequest
                                  end;

      gic_TempAddScout:           if DEBUG_CHEATS and (MULTIPLAYER_CHEATS or not gGame.IsMultiplayer) then
                                    //Place a warrior
                                    P.AddUnit(ut_HorseScout, KMPoint(Params[1], Params[2]), True, 0, True);
      gic_TempRevealMap:          if DEBUG_CHEATS and (MULTIPLAYER_CHEATS or not gGame.IsMultiplayer) then
                                    P.FogOfWar.RevealEverything;
      gic_TempVictory:            if DEBUG_CHEATS and (MULTIPLAYER_CHEATS or not gGame.IsMultiplayer) then
                                    P.AI.Victory;
      gic_TempDefeat:             if DEBUG_CHEATS and (MULTIPLAYER_CHEATS or not gGame.IsMultiplayer) then
                                    P.AI.Defeat;
      gic_TempDoNothing:          ;

      gic_GamePause:              ;//if fReplayState = gipRecording then fGame.fGamePlayInterface.SetPause(boolean(Params[1]));
      gic_GameAutoSave:           if (fReplayState = gipRecording) and gGameApp.GameSettings.Autosave then
                                    gGame.AutoSave(DateTimeParam); //Timestamp is synchronised
      gic_GameAutoSaveAfterPT:    if (fReplayState = gipRecording) and gGameApp.GameSettings.Autosave then
                                    gGame.AutoSaveAfterPT(DateTimeParam); //Timestamp is synchronised
      gic_GameSaveReturnLobby:    if fReplayState = gipRecording then
                                  begin
                                    gGameApp.PrepareReturnToLobby(DateTimeParam); //Timestamp is synchronised
                                    Exit;
                                  end;
      gic_GameTeamChange:         begin
                                    //Currently unused, disabled to prevent potential exploitation
                                    {fGame.Networking.NetPlayers[Params[1]].Team := Params[2];
                                    fGame.UpdateMultiplayerTeams;
                                    fPlayers.SyncFogOfWar;
                                    if fGame.Networking.IsHost then
                                      fGame.Networking.SendPlayerListAndRefreshPlayersSetup;}
                                  end;
      gic_GameAlertBeacon:        ExecGameAlertBeaconCmd(aCommand);
      gic_GameHotkeySet:          P.SelectionHotkeys[Params[1]] := Params[2];
      gic_GameMessageLogRead:     P.MessageLog[Params[1]].IsReadGIP := True;
      gic_GamePlayerTypeChange:   begin
                                    Assert(fReplayState <> gipRecording); //Should only occur in replays
                                    gHands[Params[1]].HandType := THandType(Params[2]);
                                  end;
      gic_GamePlayerDefeat:       begin
                                    gHands.DisableGoalsForDefeatedHand(Params[1]);
                                    gHands[Params[1]].AI.Defeat(False);
                                  end
      else                        raise Exception.Create('Unexpected gic command');
    end;
  end;
end;


procedure TGameInputProcess.ExecGameAlertBeaconCmd(aCommand: TGameInputCommand);
  function DoAddPlayerBeacon: Boolean;
  var IsPlayerMuted: Boolean;
  begin
    // Check if player, who send beacon, is muted
    IsPlayerMuted := (gGame.Networking <> nil) and gGame.Networking.IsMuted(gGame.Networking.GetNetPlayerIndex(aCommand.Params[3]));

    Result := (gHands.CheckAlliance(aCommand.Params[3], gMySpectator.HandIndex) = at_Ally)
      and (gHands[aCommand.Params[3]].ShareBeacons[gMySpectator.HandIndex])
      and not IsPlayerMuted; // do not show beacons sended by muted players
  end;

var
  AddBeacon: Boolean;
begin
  // Beacon script event must always be run by all players for consistency
  gScriptEvents.ProcBeacon(aCommand.Params[3], 1 + (aCommand.Params[1] div 10), 1 + (aCommand.Params[2] div 10));

  AddBeacon := False;

  case gGame.GameMode of
    gmSingle,
    gmCampaign,
    gmMulti:          AddBeacon := (aCommand.Params[3] <> PLAYER_NONE) and DoAddPlayerBeacon;
    gmMultiSpectate:  AddBeacon := (aCommand.Params[3] = PLAYER_NONE) // Show spectators beacons while spectating
                                    or (gGameApp.GameSettings.SpecShowBeacons and DoAddPlayerBeacon);
    gmReplaySingle,
    gmReplayMulti:    AddBeacon := (aCommand.Params[3] <> PLAYER_NONE)  // Do not show spectators beacons in replay
                                    and gGameApp.GameSettings.ReplayShowBeacons and DoAddPlayerBeacon;
  end;

  if AddBeacon then
      gGame.GamePlayInterface.Alerts.AddBeacon(KMPointF(aCommand.Params[1]/10,
                                                        aCommand.Params[2]/10),
                                                        aCommand.Params[3],
                                                        (aCommand.Params[4] or $FF000000),
                                                        gGameApp.GlobalTickCount + ALERT_DURATION[atBeacon]);
end;


procedure TGameInputProcess.CmdArmy(aCommandType: TGameInputCommandType; aGroup: TKMUnitGroup);
begin
  Assert(aCommandType in [gic_ArmyFeed, gic_ArmySplit, gic_ArmySplitSingle, gic_ArmyStorm, gic_ArmyHalt]);
  TakeCommand(MakeCommand(aCommandType, aGroup.UID));
end;


procedure TGameInputProcess.CmdArmy(aCommandType: TGameInputCommandType; aGroup: TKMUnitGroup; aUnit: TKMUnit);
begin
  Assert(aCommandType in [gic_ArmyAttackUnit]);
  TakeCommand(MakeCommand(aCommandType, aGroup.UID, aUnit.UID));
end;


procedure TGameInputProcess.CmdArmy(aCommandType: TGameInputCommandType; aGroup1, aGroup2: TKMUnitGroup);
begin
  Assert(aCommandType in [gic_ArmyLink]);
  TakeCommand(MakeCommand(aCommandType, aGroup1.UID, aGroup2.UID));
end;


procedure TGameInputProcess.CmdArmy(aCommandType: TGameInputCommandType; aGroup: TKMUnitGroup; aHouse: TKMHouse);
begin
  Assert(aCommandType = gic_ArmyAttackHouse);
  TakeCommand(MakeCommand(aCommandType, aGroup.UID, aHouse.UID));
end;


procedure TGameInputProcess.CmdArmy(aCommandType: TGameInputCommandType; aGroup: TKMUnitGroup; aTurnAmount: TKMTurnDirection; aLineAmount:shortint);
begin
  Assert(aCommandType = gic_ArmyFormation);
  TakeCommand(MakeCommand(aCommandType, aGroup.UID, Byte(aTurnAmount), aLineAmount));
end;


procedure TGameInputProcess.CmdArmy(aCommandType: TGameInputCommandType; aGroup: TKMUnitGroup; aLoc: TKMPoint; aDirection: TKMDirection);
begin
  Assert(aCommandType = gic_ArmyWalk);
  TakeCommand(MakeCommand(aCommandType, aGroup.UID, aLoc.X, aLoc.Y, Byte(aDirection)));
end;


procedure TGameInputProcess.CmdBuild(aCommandType: TGameInputCommandType; aLoc: TKMPoint);
begin
  Assert(aCommandType in [gic_BuildRemoveFieldPlan, gic_BuildRemoveHouse, gic_BuildRemoveHousePlan]);

  //Remove fake markup that will be visible only to gMySpectator until Server verifies it.
  //Must go before TakeCommand as it could execute command immediately (in singleplayer)
  //and the fake markup must be added first otherwise our logic in FieldsList fails
  if gGame.IsMultiplayer and (aCommandType = gic_BuildRemoveFieldPlan) then
    gMySpectator.Hand.RemFakeFieldPlan(aLoc);

  TakeCommand(MakeCommand(aCommandType, aLoc.X, aLoc.Y));
end;


procedure TGameInputProcess.CmdBuild(aCommandType: TGameInputCommandType; aLoc: TKMPoint; aFieldType: TFieldType);
begin
  Assert(aCommandType in [gic_BuildAddFieldPlan]);

  //Add fake markup that will be visible only to gMySpectator until Server verifies it.
  //Must go before TakeCommand as it could execute command immediately (in singleplayer)
  //and the fake markup must be added first otherwise our logic in FieldsList fails
  if gGame.IsMultiplayer then
    gMySpectator.Hand.ToggleFakeFieldPlan(aLoc, aFieldType);

  TakeCommand(MakeCommand(aCommandType, aLoc.X, aLoc.Y, Byte(aFieldType)));
end;


procedure TGameInputProcess.CmdBuild(aCommandType: TGameInputCommandType; aLoc: TKMPoint; aHouseType: THouseType);
begin
  Assert(aCommandType = gic_BuildHousePlan);
  TakeCommand(MakeCommand(aCommandType, Byte(aHouseType), aLoc.X, aLoc.Y));
end;


procedure TGameInputProcess.CmdHouse(aCommandType: TGameInputCommandType; aHouse: TKMHouse);
begin
  Assert(aCommandType in [gic_HouseRepairToggle, gic_HouseClosedForWorkerToggle, gic_HouseBarracksAcceptRecruitsToggle]);
  TakeCommand(MakeCommand(aCommandType, aHouse.UID));
end;


procedure TGameInputProcess.CmdHouse(aCommandType: TGameInputCommandType; aHouse: TKMHouse; aItem, aAmountChange: Integer);
begin
  Assert(aCommandType in [gic_HouseOrderProduct, gic_HouseSchoolTrainChOrder]);
  TakeCommand(MakeCommand(aCommandType, aHouse.UID, aItem, aAmountChange));
end;


procedure TGameInputProcess.CmdHouse(aCommandType: TGameInputCommandType; aHouse: TKMHouse; aWareType: TWareType);
begin
  Assert(aCommandType in [gic_HouseStoreAcceptFlag, gic_HouseBarracksAcceptFlag, gic_HouseMarketFrom, gic_HouseMarketTo, gic_HouseArmorWSDeliveryToggle]);
  TakeCommand(MakeCommand(aCommandType, aHouse.UID, Byte(aWareType)));
end;


procedure TGameInputProcess.CmdHouse(aCommandType: TGameInputCommandType; aHouse: TKMHouse; aWoodcutterMode: TKMWoodcutterMode);
begin
  Assert(aCommandType = gic_HouseWoodcutterMode);
  TakeCommand(MakeCommand(aCommandType, aHouse.UID, Byte(aWoodcutterMode)));
end;


procedure TGameInputProcess.CmdHouse(aCommandType: TGameInputCommandType; aHouse: TKMHouse; aUnitType: TUnitType; aCount: Integer);
begin
  Assert(aCommandType in [gic_HouseSchoolTrain, gic_HouseBarracksEquip, gic_HouseTownHallEquip]);
  TakeCommand(MakeCommand(aCommandType, aHouse.UID, Byte(aUnitType), aCount));
end;


procedure TGameInputProcess.CmdHouse(aCommandType: TGameInputCommandType; aHouse: TKMHouse; aItem:integer);
begin
  Assert(aCommandType in [gic_HouseRemoveTrain, gic_HouseSchoolTrainChLastUOrder]);
  Assert(aHouse is TKMHouseSchool);
  TakeCommand(MakeCommand(aCommandType, aHouse.UID, aItem));
end;


procedure TGameInputProcess.CmdHouse(aCommandType: TGameInputCommandType; aHouse: TKMHouse; aLoc: TKMPoint);
begin
  Assert((aCommandType = gic_HouseBarracksRally) or (aCommandType = gic_HouseTownHallRally) or (aCommandType = gic_HouseWoodcuttersCutting));
  Assert((aHouse is TKMHouseBarracks) or (aHouse is TKMHouseTownHall) or (aHouse is TKMHouseWoodcutters));
  TakeCommand(MakeCommand(aCommandType, aHouse.UID, aLoc.X, aLoc.Y));
end;


procedure TGameInputProcess.CmdHouse(aCommandType: TGameInputCommandType; aHouse: TKMHouse; aDeliveryMode: TDeliveryMode);
begin
  Assert(aCommandType = gic_HouseDeliveryToggle);
  TakeCommand(MakeCommand(aCommandType, aHouse.UID, Integer(aDeliveryMode)));
end;


procedure TGameInputProcess.CmdWareDistribution(aCommandType: TGameInputCommandType; aWare: TWareType; aHouseType: THouseType; aValue:integer);
begin
  Assert(aCommandType = gic_WareDistributionChange);
  TakeCommand(MakeCommand(aCommandType, Byte(aWare), Byte(aHouseType), aValue));
end;


procedure TGameInputProcess.CmdWareDistribution(aCommandType: TGameInputCommandType; const aTextParam: UnicodeString);
begin
  Assert(aCommandType = gic_WareDistributions);
  TakeCommand(MakeCommand(aCommandType, aTextParam));
end;


procedure TGameInputProcess.CmdGame(aCommandType: TGameInputCommandType; aValue: Boolean);
begin
  Assert(aCommandType = gic_GamePause);
  TakeCommand(MakeCommand(aCommandType, Integer(aValue)));
end;


procedure TGameInputProcess.CmdGame(aCommandType: TGameInputCommandType; aDateTime: TDateTime);
begin
  Assert(aCommandType in [gic_GameAutoSave, gic_GameAutoSaveAfterPT, gic_GameSaveReturnLobby]);
  TakeCommand(MakeCommand(aCommandType, aDateTime));
end;


procedure TGameInputProcess.CmdGame(aCommandType: TGameInputCommandType; aParam1, aParam2: Integer);
begin
  Assert(aCommandType in [gic_GameTeamChange, gic_GameHotkeySet]);
  TakeCommand(MakeCommand(aCommandType, aParam1, aParam2));
end;


procedure TGameInputProcess.CmdGame(aCommandType: TGameInputCommandType; aValue: Integer);
begin
  Assert(aCommandType in [gic_GameMessageLogRead, gic_GamePlayerDefeat]);
  TakeCommand(MakeCommand(aCommandType, aValue));
end;


procedure TGameInputProcess.CmdGame(aCommandType: TGameInputCommandType; aLoc: TKMPointF; aOwner: TKMHandIndex; aColor: Cardinal);
begin
  Assert(aCommandType = gic_GameAlertBeacon);
  TakeCommand(MakeCommand(aCommandType, Round(aLoc.X * 10), Round(aLoc.Y * 10), aOwner, (aColor and $FFFFFF)));
end;


procedure TGameInputProcess.CmdTemp(aCommandType: TGameInputCommandType; aLoc: TKMPoint);
begin
  Assert(aCommandType = gic_TempAddScout);
  TakeCommand(MakeCommand(aCommandType, aLoc.X, aLoc.Y));
end;


procedure TGameInputProcess.CmdTemp(aCommandType: TGameInputCommandType);
begin
  Assert(aCommandType in [gic_TempRevealMap, gic_TempVictory, gic_TempDefeat, gic_TempDoNothing]);
  TakeCommand(MakeCommand(aCommandType));
end;


procedure TGameInputProcess.SaveToFile(const aFileName: UnicodeString);
var
  I: integer;
  S: TKMemoryStream;
begin
  S := TKMemoryStream.Create;
  S.WriteA(GAME_REVISION);
  S.Write(fCount);
  for I := 1 to fCount do
  begin
    S.Write(fQueue[I].Tick);
    SaveCommandToMemoryStream(fQueue[I].Command, S);
    S.Write(fQueue[I].Rand);
  end;

  S.SaveToFile(aFileName);
  S.Free;
end;


procedure TGameInputProcess.LoadFromFile(const aFileName: UnicodeString);
var
  FileVersion: AnsiString;
  I: Integer;
  S: TKMemoryStream;
begin
  if not FileExists(aFileName) then exit;
  S := TKMemoryStream.Create;
  S.LoadFromFile(aFileName);
  S.ReadA(FileVersion);
  Assert(FileVersion = GAME_REVISION, 'Old or unexpected replay file. '+GAME_REVISION+' is required.');
  S.Read(fCount);
  SetLength(fQueue, fCount+1);
  for I := 1 to fCount do
  begin
    S.Read(fQueue[I].Tick);
    LoadCommandFromMemoryStream(fQueue[I].Command, S);
    S.Read(fQueue[I].Rand);
  end;

  S.Free;
end;


{ Return last recorded tick }
function TGameInputProcess.GetLastTick: Cardinal;
begin
  Result := fQueue[fCount].Tick;
end;


{ See if replay has ended (no more commands in queue) }
function TGameInputProcess.ReplayEnded: Boolean;
begin
  if ReplayState = gipReplaying then
    Result := fCursor > fCount
  else
    Result := false;
end;


//Store commands for the replay
//While in replay there are no commands to process, but for debug we might allow ChangePlayer
procedure TGameInputProcess.StoreCommand(aCommand: TGameInputCommand);
begin
  if ReplayState = gipReplaying then
    Exit;

  Assert(ReplayState = gipRecording);
  Inc(fCount);
  if Length(fQueue) <= fCount then SetLength(fQueue, fCount+128);

  fQueue[fCount].Tick    := gGame.GameTickCount;
  fQueue[fCount].Command := aCommand;
  fQueue[fCount].Rand    := Cardinal(KaMRandom(maxint)); //This will be our check to ensure everything is consistent
end;


function TGameInputProcess.CommandsConfirmed(aTick: Cardinal): Boolean;
begin
  Result := True;
end;


procedure TGameInputProcess.WaitingForConfirmation(aTick: Cardinal);
begin
end;


procedure TGameInputProcess.ReplayTimer(aTick: Cardinal);
begin
end;


procedure TGameInputProcess.RunningTimer(aTick: Cardinal);
begin
end;


procedure TGameInputProcess.UpdateState(aTick: Cardinal);
begin
  //Only used in GIP_Multi
end;


end.
