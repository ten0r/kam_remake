unit KM_HandLogistics;
{$I KaM_Remake.inc}
interface
uses
  ComCtrls,
  {$IFDEF WDC}
  Generics.Collections, Generics.Defaults, System.Hash,
  {$ENDIF}
  KM_Units, KM_Houses, KM_ResHouses,
  KM_ResWares, KM_CommonClasses, KM_Defaults, KM_Points;


type
  TKMDemandType = (
    dtOnce,   // One-time demand like usual
    dtAlways  // Constant (store, barracks)
  );

  // Sorted from lowest to highest importance
  TKMDemandImportance = (
    diNorm,  //Everything (lowest importance)
    diHigh4, //Materials to workers
    diHigh3, //Food to Inn
    diHigh2, //Food to soldiers
    diHigh1  //Gold to School (highest importance)
  );

  TKMDeliveryJobStatus = (
    js_Empty, // Empty - empty spot for a new job
    js_Taken  // Taken - job is taken by some worker
  );

  PKMDeliveryOffer = ^TKMDeliveryOffer;
  TKMDeliveryOffer = record
    Ware: TWareType;
    Count: Cardinal; //How many items are offered
    Loc_House: TKMHouse;
    BeingPerformed: Cardinal; //How many items are being delivered atm from total Count offered
    //Keep offer until serfs that do it abandons it
    IsDeleted: Boolean;
  end;

  PKMDeliveryDemand = ^TKMDeliveryDemand;
  TKMDeliveryDemand =  record
    Ware: TWareType;
    DemandType: TKMDemandType; //Once for everything, Always for Store and Barracks
    Importance: TKMDemandImportance; //How important demand is, e.g. Workers and building sites should be di_High
    Loc_House: TKMHouse;
    Loc_Unit: TKMUnit;
    BeingPerformed: Cardinal; //Can be performed multiple times for dt_Always
    IsDeleted: Boolean; //So we don't get pointer issues
  end;

  {$IFDEF WDC}
  //Bids cache key
  TKMDeliveryBidKey = record
    FromUID: Integer; //House or Unit UID From where delivery path goes
    ToUID: Integer;   //same for To where delivery path goes
  end;

type
  //Custom key comparator. Probably TDictionary can handle it himself, but lets try our custom comparator
  TKMDeliveryBidKeyComparer = class(TEqualityComparer<TKMDeliveryBidKey>)
    function Equals(const Left, Right: TKMDeliveryBidKey): Boolean; override;
    function GetHashCode(const Value: TKMDeliveryBidKey): Integer; override;
  end;
  {$ENDIF}

type
  //We need to combine 2 approaches for wares > serfs and wares < serfs
  //Houses signal when they have new wares/needs
  //Serfs signal when they are free to perform actions
  //List should be able to override Idling Serfs action
  //List should not override serfs deliveries even if the other serf can do it quicker,
  //because it will look bad to player, if first serfs stops for no reason
  //List does the comparison between houses and serfs and picks best pairs
  //(logic can be quite complicated and try to predict serfs/wares ETA)
  //Comparison function could be executed more rare or frequent depending on signals from houses/serfs
  //e.g. with no houses signals it can sleep till first on. At any case - not more frequent than 1/tick
  //TKMDeliveryList = class; //Serfs, Houses/Warriors/Workers

  TKMDeliveries = class
  private
    fOfferCount: Integer;
    fOffer: array of TKMDeliveryOffer;
    fDemandCount: Integer;
    fDemand: array of TKMDeliveryDemand;
    fQueueCount: Integer;
    fQueue: array of
    record
      OfferID, DemandID: Integer;
      JobStatus: TKMDeliveryJobStatus; //Empty slot, resource Taken, job Done
      Item: TListItem;
    end;

    {$IFDEF WDC}
    // Cache of bid costs between offer object (house, serf) and demand object (house, unit - worker or warrior)
    fOfferToDemandCache: TDictionary<TKMDeliveryBidKey, Single>;
    // Cache of bid costs between serf and offer house
    fSerfToOfferCache: TDictionary<TKMDeliveryBidKey, Single>;
    {$ENDIF}

    fNodeList: TKMPointList; // Used to calc delivery bid

    procedure CloseDelivery(aID: Integer);
    procedure CloseDemand(aID: Integer);
    procedure CloseOffer(aID: Integer);
    function ValidDelivery(iO, iD: Integer; aIgnoreOffer: Boolean = False): Boolean;
    function SerfCanDoDelivery(iO, iD: Integer; aSerf: TKMUnitSerf): Boolean;
    function PermitDelivery(iO, iD: Integer; aSerf: TKMUnitSerf): Boolean;
    function CalculateBid(iO, iD: Integer; aSerf: TKMUnitSerf = nil): Single;
    function CalculateBidBasic(iO, iD: Integer; aSerf: TKMUnitSerf = nil): Single; overload;
    function CalculateBidBasic(aOfferUID: Integer; aOfferPos: TKMPoint; aOfferCnt: Cardinal; aOfferHouseType: THouseType; aOwner: TKMHandIndex;
                               iD: Integer; aSerf: TKMUnitSerf = nil): Single; overload;
    function CalcSerfBidValue(aSerf: TKMUnitSerf; aOfferPos: TKMPoint; aToUID: Integer): Single;
    function GetRouteCost(aFromPos, aToPos: TKMPoint; aPass: TKMTerrainPassability): Single;
    function GetUnitsCntOnPath(aNodeList: TKMPointList): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddOffer(aHouse: TKMHouse; aWare: TWareType; aCount: Integer);
    procedure RemAllOffers(aHouse: TKMHouse);
    procedure RemOffer(aHouse: TKMHouse; aWare: TWareType; aCount: Cardinal);

    procedure AddDemand(aHouse: TKMHouse; aUnit: TKMUnit; aResource: TWareType; aCount: Integer; aType: TKMDemandType; aImp: TKMDemandImportance);
    function TryRemoveDemand(aHouse: TKMHouse; aResource: TWareType; aCount: Word): word;
    procedure RemDemand(aHouse: TKMHouse); overload;
    procedure RemDemand(aUnit: TKMUnit); overload;

    function GetAvailableDeliveriesCount: Integer;
    procedure AssignDelivery(iO, iD: Integer; aSerf: TKMUnitSerf);
    procedure AskForDelivery(aSerf: TKMUnitSerf; aHouse: TKMHouse = nil);
    procedure CheckForBetterDemand(aDeliveryID: Integer; out aToHouse: TKMHouse; out aToUnit: TKMUnit; aSerf: TKMUnitSerf);
    procedure DeliveryFindBestDemand(aSerf: TKMUnitSerf; aDeliveryId: Integer; aResource: TWareType; out aToHouse: TKMHouse; out aToUnit: TKMUnit; out aForceDelivery: Boolean);
    procedure TakenOffer(aID: Integer);
    procedure GaveDemand(aID: Integer);
    procedure AbandonDelivery(aID: Integer); //Occurs when unit is killed or something alike happens

    procedure Save(SaveStream: TKMemoryStream);
    procedure Load(LoadStream: TKMemoryStream);
    procedure SyncLoad;

    procedure UpdateState(aTick: Cardinal);

    procedure ExportToFile(const aFileName: UnicodeString);
  end;

  TKMHandLogistics = class
  private
    fQueue: TKMDeliveries;

    fSerfCount: Integer;
    fSerfs: array of record //Not sure what else props we planned to add here
      Serf: TKMUnitSerf;
    end;

    procedure RemSerf(aIndex: Integer);
    procedure RemoveExtraSerfs;
    function GetIdleSerfCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddSerf(aSerf: TKMUnitSerf);
    property Queue: TKMDeliveries read fQueue;

    procedure Save(SaveStream: TKMemoryStream);
    procedure Load(LoadStream: TKMemoryStream);
    procedure SyncLoad;
    procedure UpdateState(aTick: Cardinal);
  end;


implementation
uses
  Classes, SysUtils, Math,
  KM_Terrain,
  KM_FormLogistics,
  KM_Game, KM_Hand, KM_HandsCollection, KM_HouseBarracks, KM_HouseTownHall,
  KM_Resource, KM_ResUnits,
  KM_Log, KM_Utils, KM_CommonUtils;


const
  //Max distance to use pathfinding on calc delivery bids. No need to calc on very long distance
  BID_CALC_MAX_DIST_FOR_PATHF = 100;
  //Approx compensation to compare Bid cost calc with pathfinding and without it. Pathfinding is usually longer
  BID_CALC_PATHF_COMPENSATION = 0.9;
  CACHE_CLEAN_FREQ = 10; //in ticks. Clean cache every N ticks
  LENGTH_INC = 32; //Increment array lengths by this value


{ TKMHandLogistics }
constructor TKMHandLogistics.Create;
begin
  inherited;
  fQueue := TKMDeliveries.Create;
end;


destructor TKMHandLogistics.Destroy;
begin
  FreeAndNil(fQueue);
  inherited;
end;


procedure TKMHandLogistics.Save(SaveStream: TKMemoryStream);
var I: Integer;
begin
  SaveStream.WriteA('SerfList');

  SaveStream.Write(fSerfCount);
  for I := 0 to fSerfCount - 1 do
  begin
    if fSerfs[I].Serf <> nil then
      SaveStream.Write(fSerfs[I].Serf.UID)
    else
      SaveStream.Write(Integer(0));
  end;

  fQueue.Save(SaveStream);
end;


procedure TKMHandLogistics.Load(LoadStream: TKMemoryStream);
var I: Integer;
begin
  LoadStream.ReadAssert('SerfList');

  LoadStream.Read(fSerfCount);
  SetLength(fSerfs, fSerfCount);
  for I := 0 to fSerfCount - 1 do
    LoadStream.Read(fSerfs[I].Serf, 4);

  fQueue.Load(LoadStream);
end;


procedure TKMHandLogistics.SyncLoad;
var
  I: Integer;
  U: TKMUnit;
begin
  for I := 0 to fSerfCount - 1 do
  begin
    U := gHands.GetUnitByUID(Cardinal(fSerfs[I].Serf));
    Assert(U is TKMUnitSerf, 'Non-serf in delivery list');
    fSerfs[I].Serf := TKMUnitSerf(U);
  end;
  fQueue.SyncLoad;
end;


//Add the Serf to the List
procedure TKMHandLogistics.AddSerf(aSerf: TKMUnitSerf);
begin
  if fSerfCount >= Length(fSerfs) then
    SetLength(fSerfs, fSerfCount + LENGTH_INC);

  fSerfs[fSerfCount].Serf := TKMUnitSerf(aSerf.GetUnitPointer);
  Inc(fSerfCount);
end;


//Remove died Serf from the List
procedure TKMHandLogistics.RemSerf(aIndex: Integer);
begin
  gHands.CleanUpUnitPointer(TKMUnit(fSerfs[aIndex].Serf));

  //Serf order is not important, so we just move last one into freed spot
  if aIndex <> fSerfCount - 1 then
    fSerfs[aIndex] := fSerfs[fSerfCount - 1];

  Dec(fSerfCount);
end;


function TKMHandLogistics.GetIdleSerfCount: Integer;
var I: Integer;
begin
  Result := 0;
  for I := 0 to fSerfCount - 1 do
    if fSerfs[I].Serf.IsIdle then
      Inc(Result);
end;


//Remove dead serfs
procedure TKMHandLogistics.RemoveExtraSerfs;
var
  I: Integer;
begin
  for I := fSerfCount - 1 downto 0 do
    if fSerfs[I].Serf.IsDeadOrDying then
      RemSerf(I);
end;


procedure TKMHandLogistics.UpdateState(aTick: Cardinal);

  function AnySerfCanDoDelivery(iO,iD: Integer): Boolean;
  var I: Integer;
  begin
    Result := False;
    for I := 0 to fSerfCount - 1 do
      if fSerfs[I].Serf.IsIdle and fQueue.SerfCanDoDelivery(iO, iD, fSerfs[I].Serf) then
      begin
        Result := True;
        Exit;
      end;
  end;

var
  I, K, iD, iO, FoundO, FoundD: Integer;
  Bid, BestBid: Single;
  BestImportance: TKMDemandImportance;
  AvailableDeliveries, AvailableSerfs: Integer;
  Serf: TKMUnitSerf;
begin
  fQueue.UpdateState(aTick);
  RemoveExtraSerfs;

  AvailableDeliveries := fQueue.GetAvailableDeliveriesCount;
  AvailableSerfs := GetIdleSerfCount;
  if AvailableSerfs * AvailableDeliveries = 0 then Exit;

  if AvailableDeliveries > AvailableSerfs then
  begin
    for I := 0 to fSerfCount - 1 do
      if fSerfs[I].Serf.IsIdle then
        fQueue.AskForDelivery(fSerfs[I].Serf);
  end
  else
    //I is not used anywhere, but we must loop through once for each delivery available so each one is taken
    for I := 1 to AvailableDeliveries do
    begin
      //First we decide on the best delivery to be done based on current Offers and Demands
      //We need to choose the best delivery out of all of them, otherwise we could get
      //a further away storehouse when there are multiple possibilities.
      //Note: All deliveries will be taken, because we have enough serfs to fill them all.
      //The important concept here is to always get the shortest delivery when a delivery can be taken to multiple places.
      BestBid := MaxSingle;
      BestImportance := Low(TKMDemandImportance);
      FoundO := -1;
      FoundD := -1;
      for iD := 1 to fQueue.fDemandCount do
        if (fQueue.fDemand[iD].Ware <> wt_None)
          and (fQueue.fDemand[iD].Importance >= BestImportance) then //Skip any less important than the best we found
          for iO := 1 to fQueue.fOfferCount do
            if (fQueue.fOffer[iO].Ware <> wt_None)
              and fQueue.ValidDelivery(iO,iD)
              and AnySerfCanDoDelivery(iO,iD) then //Only choose this delivery if at least one of the serfs can do it
            begin
              Bid := fQueue.CalculateBid(iO,iD,nil);
              if (Bid < BestBid) or (fQueue.fDemand[iD].Importance > BestImportance) then
              begin
                BestBid := Bid;
                BestImportance := fQueue.fDemand[iD].Importance;
                FoundO := iO;
                FoundD := iD;
              end;
            end;

      //FoundO and FoundD give us the best delivery to do at this moment. Now find the best serf for the job.
      if (FoundO <> -1) and (FoundD <> -1) then
      begin
        Serf := nil;
        BestBid := MaxSingle;
        for K := 0 to fSerfCount - 1 do
          if fSerfs[K].Serf.IsIdle then
            if fQueue.SerfCanDoDelivery(FoundO,FoundD,fSerfs[K].Serf) then
            begin
              Bid := KMLength(fSerfs[K].Serf.GetPosition, fQueue.fOffer[FoundO].Loc_House.Entrance);
              if (Bid < BestBid) then
              begin
                BestBid := Bid;
                Serf := fSerfs[K].Serf;
              end;
            end;
        if Serf <> nil then
          fQueue.AssignDelivery(FoundO, FoundD, Serf);
      end;
    end;
end;


{ TKMDeliveries }
constructor TKMDeliveries.Create;
{$IFDEF WDC}
var
  CacheKeyComparer: TKMDeliveryBidKeyComparer;
{$ENDIF}
begin
  inherited;

  {$IFDEF WDC}
  if CACHE_DELIVERY_BIDS then
  begin
    CacheKeyComparer := TKMDeliveryBidKeyComparer.Create;
    fOfferToDemandCache := TDictionary<TKMDeliveryBidKey, Single>.Create(CacheKeyComparer);
    fSerfToOfferCache := TDictionary<TKMDeliveryBidKey, Single>.Create(CacheKeyComparer);
  end;

  if DELIVERY_BID_CALC_USE_PATHFINDING then
    fNodeList := TKMPointList.Create;
  {$ENDIF}
end;


destructor TKMDeliveries.Destroy;
begin
  {$IFDEF WDC}
  if CACHE_DELIVERY_BIDS then
  begin
    FreeAndNil(fSerfToOfferCache);
    FreeAndNil(fOfferToDemandCache);
  end;
  
  if DELIVERY_BID_CALC_USE_PATHFINDING then
    FreeAndNil(fNodeList);
  {$ENDIF}

  inherited;
end;


//Adds new Offer to the list. List is stored without sorting
//(it matters only for Demand to keep everything in waiting its order in line),
//so we just find an empty place and write there.
procedure TKMDeliveries.AddOffer(aHouse: TKMHouse; aWare: TWareType; aCount: Integer);
var
  I, K: Integer;
begin
  if aCount = 0 then Exit;

  //Add Count of resource to old offer
  for I := 1 to fOfferCount do
    if (fOffer[I].Loc_House = aHouse)
    and (fOffer[I].Ware = aWare) then
    begin
      if fOffer[I].IsDeleted then
      begin
        //Revive old offer because some serfs are still walking to perform it
        Assert(fOffer[I].BeingPerformed > 0);
        fOffer[I].Count :=  aCount;
        fOffer[I].IsDeleted := False;
        Exit; //Count added, thats all
      end
      else
      begin
        Inc(fOffer[I].Count, aCount);
        Exit; //Count added, thats all
      end;
    end;

  //Find empty place or allocate new one
  I := 1;
  while (I <= fOfferCount) and (fOffer[I].Ware <> wt_None) do
    Inc(I);
  if I > fOfferCount then
  begin
    Inc(fOfferCount, LENGTH_INC);
    SetLength(fOffer, fOfferCount + 1);
    for K := I to fOfferCount do
      FillChar(fOffer[K], SizeOf(fOffer[K]), #0); //Initialise the new queue space
  end;

  //Add offer
  with fOffer[I] do
  begin
    if aHouse <> nil then
      Loc_House := aHouse.GetHousePointer;
    Ware := aWare;
    Count := aCount;
    Assert((BeingPerformed = 0) and not IsDeleted); //Make sure this item has been closed properly, if not there is a flaw
  end;
end;


//Remove Offer from the list. E.G on house demolish
//List is stored without sorting so we have to parse it to find that entry..
procedure TKMDeliveries.RemAllOffers(aHouse: TKMHouse);
var I: Integer;
begin
  //We need to parse whole list, never knowing how many offers the house had
  for I := 1 to fOfferCount do
  if fOffer[I].Loc_House=aHouse then
    if fOffer[I].BeingPerformed > 0 then
    begin
      //Keep it until all associated deliveries are abandoned
      fOffer[I].IsDeleted := true; //Don't reset it until serfs performing this offer are done with it
      fOffer[I].Count := 0; //Make the count 0 so no one else tries to take this offer
    end
    else
      CloseOffer(I);
end;


procedure TKMDeliveries.RemOffer(aHouse: TKMHouse; aWare: TWareType; aCount: Cardinal);
var
  I: Integer;
begin
  //Add Count of resource to old offer
  for I := 1 to fOfferCount do
    if (fOffer[I].Loc_House = aHouse)
      and (fOffer[I].Ware = aWare)
      and not fOffer[I].IsDeleted then
    begin
      Assert(fOffer[I].Count >= aCount, 'Removing too many offers');
      Dec(fOffer[I].Count, aCount);
      if fOffer[I].Count = 0 then
      begin
        if fOffer[i].BeingPerformed > 0 then
          fOffer[i].IsDeleted := True
        else
          CloseOffer(i);
      end;
      Exit; //Count decreased, that's all
    end;
  raise Exception.Create('Failed to remove offer');
end;


//Remove Demand from the list
// List is stored without sorting so we parse it to find all entries..
procedure TKMDeliveries.RemDemand(aHouse: TKMHouse);
var
  I: Integer;
begin
  assert(aHouse <> nil);
  for I := 1 to fDemandCount do
    if fDemand[I].Loc_House=aHouse then
    begin
      if fDemand[I].BeingPerformed > 0 then
        //Can't free it yet, some serf is using it
        fDemand[I].IsDeleted := true
      else
        CloseDemand(I); //Clear up demand
      //Keep on scanning cos House can have multiple demands entries
    end;
end;


//Remove Demand from the list
// List is stored without sorting so we parse it to find all entries..
procedure TKMDeliveries.RemDemand(aUnit:TKMUnit);
var
  i:integer;
begin
  assert(aUnit <> nil);
  for i:=1 to fDemandCount do
  if fDemand[i].Loc_Unit=aUnit then
  begin
    if fDemand[i].BeingPerformed > 0 then
      //Can't free it yet, some serf is using it
      fDemand[i].IsDeleted := true
    else
      CloseDemand(i); //Clear up demand
    //Keep on scanning cos Unit can have multiple demands entries (foreseeing Walls building)
  end;
end;


//Attempt to remove aCount demands from this house and report the number (only ones that are not yet being performed)
function TKMDeliveries.TryRemoveDemand(aHouse:TKMHouse; aResource:TWareType; aCount:word):word;
var i:integer;
begin
  Result := 0;
  if aCount = 0 then exit;
  assert(aHouse <> nil);
  for i:=1 to fDemandCount do
    if (fDemand[i].Loc_House = aHouse) and (fDemand[i].Ware = aResource) then
      if fDemand[i].BeingPerformed = 0 then
      begin
        CloseDemand(i); //Clear up demand
        inc(Result);
        if Result = aCount then exit; //We have removed enough demands
      end;
end;


//Adds new Demand to the list. List is stored sorted, but the sorting is done upon Deliver completion,
//so we just find an empty place (which is last one) and write there.
procedure TKMDeliveries.AddDemand(aHouse: TKMHouse; aUnit: TKMUnit; aResource: TWareType; aCount: Integer; aType: TKMDemandType; aImp: TKMDemandImportance);
var I,K,J:integer;
begin
  Assert(aResource <> wt_None, 'Demanding rt_None');
  if aCount <= 0 then Exit;


  for K := 1 to aCount do
  begin
    I := 1;
    while (I <= fDemandCount) and (fDemand[I].Ware <> wt_None) do
      Inc(I);
    if I > fDemandCount then
    begin
      Inc(fDemandCount, LENGTH_INC);
      SetLength(fDemand, fDemandCount + 1);
      for J := I to fDemandCount do
        FillChar(fDemand[J], SizeOf(fDemand[J]), #0); //Initialise the new queue space
    end;

    with fDemand[I] do
    begin
      if aHouse <> nil then Loc_House := aHouse.GetHousePointer;
      if aUnit <> nil then Loc_Unit := aUnit.GetUnitPointer;
      DemandType := aType; //Once or Always
      Ware := aResource;
      Importance := aImp;
      Assert((not IsDeleted) and (BeingPerformed = 0)); //Make sure this item has been closed properly, if not there is a flaw

      //Gold to Schools
      if (Ware = wt_Gold)
        and (Loc_House <> nil) and (Loc_House.HouseType = ht_School) then
        Importance := diHigh1;

      //Food to Inn
      if (Ware in [wt_Bread, wt_Sausages, wt_Wine, wt_Fish])
        and (Loc_House <> nil) and (Loc_House.HouseType = ht_Inn) then
        Importance := diHigh3;
    end;
  end;
end;


//IgnoreOffer means we don't check whether offer was already taken or deleted (used after offer was already claimed)
function TKMDeliveries.ValidDelivery(iO,iD: Integer; aIgnoreOffer: Boolean = False): Boolean;
var
  I: Integer;
  B: TKMHouseBarracks;
begin
  //If Offer Resource matches Demand
  Result := (fDemand[iD].Ware = fOffer[iO].Ware) or
            (fDemand[iD].Ware = wt_All) or
            ((fDemand[iD].Ware = wt_Warfare) and (fOffer[iO].Ware in [WARFARE_MIN..WARFARE_MAX])) or
            ((fDemand[iD].Ware = wt_Food) and (fOffer[iO].Ware in [wt_Bread, wt_Sausages, wt_Wine, wt_Fish]));

  //If Demand and Offer aren't reserved already
  Result := Result and (((fDemand[iD].DemandType = dtAlways) or (fDemand[iD].BeingPerformed = 0))
                   and (aIgnoreOffer or (fOffer[iO].BeingPerformed < fOffer[iO].Count)));

  //If Demand and Offer aren't deleted
  Result := Result and (not fDemand[iD].IsDeleted) and (aIgnoreOffer or not fOffer[iO].IsDeleted);

  //If Demand house has WareDelivery toggled ON
  Result := Result and ((fDemand[iD].Loc_House = nil) or (fDemand[iD].Loc_House.DeliveryMode = dm_Delivery));

  //If Demand is a ArmorWorkshop and it accepts current ware delivery
  Result := Result and ((fDemand[iD].Loc_House = nil) or
                        (fDemand[iD].Loc_House.HouseType <> ht_ArmorWorkshop) or
                        (TKMHouseArmorWorkshop(fDemand[iD].Loc_House).AcceptWareForDelivery(fOffer[iO].Ware)));

  //If Demand is TownHall and its max gold count value > gold count value
  Result := Result and ((fDemand[iD].Loc_House = nil) or
                        (fDemand[iD].Loc_House.HouseType <> ht_TownHall) or
                        (TKMHouseTownHall(fDemand[iD].Loc_House).GoldMaxCnt > TKMHouseTownHall(fDemand[iD].Loc_House).GoldCnt));

  //If Demand is a Storehouse and it has WareDelivery toggled ON
  Result := Result and ((fDemand[iD].Loc_House = nil) or
                        (fDemand[iD].Loc_House.HouseType <> ht_Store) or
                        (not TKMHouseStore(fDemand[iD].Loc_House).NotAcceptFlag[fOffer[iO].Ware]));

  //Warfare has a preference to be delivered to Barracks
  if Result
    and (fOffer[iO].Ware in [WARFARE_MIN..WARFARE_MAX])
    and (fDemand[iD].Loc_House <> nil) then
  begin
    //If Demand is a Barracks and it has WareDelivery toggled OFF
    if (fDemand[iD].Loc_House.HouseType = ht_Barracks)
    and TKMHouseBarracks(fDemand[iD].Loc_House).NotAcceptFlag[fOffer[iO].Ware] then
      Result := False;

    //Permit delivery of warfares to Store only if player has no Barracks or they all have blocked ware
    if (fDemand[iD].Loc_House <> nil)
      and (fDemand[iD].Loc_House.HouseType = ht_Store) then
    begin
      //Scan through players Barracks, if none accepts - allow deliver to Store
      I := 1;
      repeat
        B := TKMHouseBarracks(gHands[fDemand[iD].Loc_House.Owner].FindHouse(ht_Barracks, I));
        //If the barracks will take the ware, don't allow the store to take it (disallow current delivery)
        if (B <> nil) and (B.DeliveryMode = dm_Delivery) and not B.NotAcceptFlag[fOffer[iO].Ware] then
        begin
          Result := False;
          Break;
        end;
        Inc(I);
      until (B = nil);
    end;
  end;

  //If Demand and Offer are different HouseTypes, means forbid Store<->Store deliveries except the case where 2nd store is being built and requires building materials
  Result := Result and ((fDemand[iD].Loc_House = nil)
                        or not ((fOffer[iO].Loc_House.HouseType = ht_Store) and (fDemand[iD].Loc_House.HouseType = ht_Store))
                        or (fOffer[iO].Loc_House.IsComplete <> fDemand[iD].Loc_House.IsComplete));

  //Do not allow transfers between Barracks (for now)
  Result := Result and ((fDemand[iD].Loc_House = nil)
                        or not ((fOffer[iO].Loc_House.HouseType = ht_Barracks) and (fDemand[iD].Loc_House.HouseType = ht_Barracks)));

  //Do not permit Barracks -> Store deliveries
  Result := Result and ((fDemand[iD].Loc_House = nil) or
                        (fDemand[iD].Loc_House.HouseType <> ht_Store) or
                        (fOffer[iO].Loc_House.HouseType <> ht_Barracks));

  Result := Result and (
            ( //House-House delivery should be performed only if there's a connecting road
            (fDemand[iD].Loc_House <> nil) and
            (gTerrain.Route_CanBeMade(fOffer[iO].Loc_House.PointBelowEntrance, fDemand[iD].Loc_House.PointBelowEntrance, tpWalkRoad, 0))
            )
            or
            ( //House-Unit delivery can be performed without connecting road
            (fDemand[iD].Loc_Unit <> nil) and
            (gTerrain.Route_CanBeMade(fOffer[iO].Loc_House.PointBelowEntrance, fDemand[iD].Loc_Unit.GetPosition, tpWalk, 1))
            ));
end;


// Delivery is only permitted if the serf can access the From house.
function TKMDeliveries.SerfCanDoDelivery(iO,iD: Integer; aSerf: TKMUnitSerf): Boolean;
var
  LocA, LocB: TKMPoint;
begin
  LocA := aSerf.GetPosition;
  LocB := fOffer[iO].Loc_House.PointBelowEntrance;

  //If the serf is inside the house (invisible) test from point below
  if not aSerf.Visible then
    LocA := KMPointBelow(LocA);

  Result := aSerf.CanWalkTo(LocA, LocB, tpWalk, 0);
end;


function TKMDeliveries.PermitDelivery(iO,iD: Integer; aSerf: TKMUnitSerf): Boolean;
begin
  Result := ValidDelivery(iO, iD) and SerfCanDoDelivery(iO, iD, aSerf);
end;


//Get the total number of possible deliveries with current Offers and Demands
function TKMDeliveries.GetAvailableDeliveriesCount: Integer;
var
  iD,iO:integer;
  OffersTaken:Cardinal;
  DemandTaken:array of Boolean; //Each demand can only be taken once in our measurements
begin
  SetLength(DemandTaken,fDemandCount+1);
  FillChar(DemandTaken[0], SizeOf(Boolean)*(fDemandCount+1), #0);

  Result := 0;
  for iO := 1 to fOfferCount do
    if (fOffer[iO].Ware <> wt_None) then
    begin
      OffersTaken := 0;
      for iD := 1 to fDemandCount do
        if (fDemand[iD].Ware <> wt_None) and not DemandTaken[iD] and ValidDelivery(iO,iD) then
        begin
          if fDemand[iD].DemandType = dtOnce then
          begin
            DemandTaken[iD] := True;
            Inc(Result);
            Inc(OffersTaken);
            if fOffer[iO].Count-OffersTaken = 0 then
              Break; //Finished with this offer
          end
          else
          begin
            //This demand will take all the offers, so increase result by that many
            Inc(Result, fOffer[iO].Count - OffersTaken);
            Break; //This offer is finished (because this demand took it all)
          end;
        end;
    end;
end;


//Calc bid cost between serf and offer house
function TKMDeliveries.CalcSerfBidValue(aSerf: TKMUnitSerf; aOfferPos: TKMPoint; aToUID: Integer): Single;
var
  BelowOfferPos: TKMPoint;
  {$IFDEF WDC}
  BidKey: TKMDeliveryBidKey;
  CachedBid: Single;
  {$ENDIF}
begin
  Result := 0;
  if aSerf = nil then Exit;

  BelowOfferPos := KMPointBelow(aOfferPos);

  {$IFDEF WDC}
  if CACHE_DELIVERY_BIDS then
  begin
    BidKey.FromUID := aSerf.UID;
    BidKey.ToUID := aToUID;

    if fSerfToOfferCache.TryGetValue(BidKey, CachedBid) then
    begin
      Result := Result + CachedBid;
      Exit;
    end;
  end;
  {$ENDIF}

  //Also prefer deliveries near to the serf
  if aSerf <> nil then
    Result := GetRouteCost(aSerf.GetPosition, BelowOfferPos, tpWalkRoad);

  {$IFDEF WDC}
  if CACHE_DELIVERY_BIDS then
    fSerfToOfferCache.Add(BidKey, Result);
  {$ENDIF}
end;


function TKMDeliveries.GetUnitsCntOnPath(aNodeList: TKMPointList): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to aNodeList.Count - 1 do
    Inc(Result, Byte(gTerrain.Land[aNodeList[I].Y,aNodeList[I].X].IsUnit <> nil));
end;


//Calc route cost
function TKMDeliveries.GetRouteCost(aFromPos, aToPos: TKMPoint; aPass: TKMTerrainPassability): Single;
var Distance: Single;
begin
  {$IFDEF WDC}
  Distance := KMLength(aFromPos, aToPos);
  if DELIVERY_BID_CALC_USE_PATHFINDING and (Distance < BID_CALC_MAX_DIST_FOR_PATHF) then
  begin
    fNodeList.Clear;
    //Try to make the route to get delivery cost
    gGame.Pathfinding.Route_Make(aFromPos, aToPos, [tpWalkRoad], 1, nil, fNodeList); //Use tpWalkRoad to get to house
    Result := KMPathLength(fNodeList) * BID_CALC_PATHF_COMPENSATION //to equalize routes with Pathfinding and without
              + GetUnitsCntOnPath(fNodeList); // units on path are also considered
  end
  else
  {$ENDIF}
    //Basic Bid is length of route
    Result := KMLengthDiag(aFromPos, aToPos); //Use KMLengthDiag, as it closer to what distance serf will actually cover
end;


function TKMDeliveries.CalculateBidBasic(iO, iD: Integer; aSerf: TKMUnitSerf = nil): Single;
begin
  Result := CalculateBidBasic(fOffer[iO].Loc_House.UID, fOffer[iO].Loc_House.Entrance, fOffer[iO].Count,
                              fOffer[iO].Loc_House.HouseType, fOffer[iO].Loc_House.Owner, iD, aSerf);
end;


//Calc bid cost between offer object (house, serf) and demand object (house, unit - worker or warrior)
function TKMDeliveries.CalculateBidBasic(aOfferUID: Integer; aOfferPos: TKMPoint; aOfferCnt: Cardinal; aOfferHouseType: THouseType;
                                         aOwner: TKMHandIndex; iD: Integer; aSerf: TKMUnitSerf = nil): Single;
var
  BelowOfferPos: TKMPoint;
  SerfBidValue: Single;
  {$IFDEF WDC}
  BidKey: TKMDeliveryBidKey;
  OfferToDemandCache: Single;
  {$ENDIF}
begin
  SerfBidValue := CalcSerfBidValue(aSerf, aOfferPos, aOfferUID);

  BelowOfferPos := KMPointBelow(aOfferPos);

  {$IFDEF WDC}
  if CACHE_DELIVERY_BIDS then
  begin
    BidKey.FromUID := aOfferUID;
    if (fDemand[iD].Loc_House <> nil) then
      BidKey.ToUID := fDemand[iD].Loc_House.UID
    else
      BidKey.ToUID := fDemand[iD].Loc_Unit.UID;

    if fOfferToDemandCache.TryGetValue(BidKey, OfferToDemandCache) then
    begin
      Result := SerfBidValue + OfferToDemandCache;
      Exit;
    end;
  end;
  {$ENDIF}

  //For weapons production in cases with little resources available, they should be distributed
  //evenly between places rather than caring about route length.
  //This means weapon and armour smiths should get same amount of iron, even if one is closer to the smelter.
  if (fDemand[iD].Loc_House <> nil) and fDemand[iD].Loc_House.IsComplete
    and gRes.Houses[fDemand[iD].Loc_House.HouseType].DoesOrders
    and (aOfferCnt <= 3) //Little resources to share around
    and (fDemand[iD].Loc_House.CheckResIn(fDemand[iD].Ware) <= 2) then //Few resources already delivered
    Result := 10
    //Resource ratios are also considered
    + KaMRandom(25 - 2*gHands[aOwner].Stats.WareDistribution[fDemand[iD].Ware, fDemand[iD].Loc_House.HouseType])
  else
  begin
    //For all other cases - use distance approach. Direct length (rough) or pathfinding (exact)
    if fDemand[iD].Loc_House <> nil then
    begin
      //Calc cost between offer and demand houses
      Result := GetRouteCost(BelowOfferPos, fDemand[iD].Loc_House.PointBelowEntrance, tpWalkRoad);
      Result := Result
        //Resource ratios are also considered
        + KaMRandom(15 - 3*gHands[aOwner].Stats.WareDistribution[fDemand[iD].Ware, fDemand[iD].Loc_House.HouseType]);
    end
    else
      //Calc bid cost between offer house and demand Unit (digged worker or hungry warrior)
      Result := GetRouteCost(BelowOfferPos, fDemand[iD].Loc_Unit.GetPosition, tpWalk);
  end;

  //Deliver wood first to equal distance construction sites
  if (fDemand[iD].Loc_House <> nil)
    and not fDemand[iD].Loc_House.IsComplete then
  begin
    //Only add a small amount so houses at different distances will be prioritized separately
    if (fDemand[iD].Ware = wt_Stone) then
      Result := Result + 0.1
  end
  else
    //For all other deliveries, add some random element so in the case of identical
    //bids the same resource will not always be chosen (e.g. weapons storehouse->barracks
    //should take random weapon types not sequentially)
    Result := Result + KaMRandom(5);

  if (fDemand[iD].Ware = wt_All)        // Always prefer deliveries House>House instead of House>Store
    or ((aOfferHouseType = ht_Store)    // Prefer taking wares from House rather than Store...
    and (fDemand[iD].Ware <> wt_Warfare)) then //...except weapons Store>Barracks, that is also prefered
    Result := Result + 1000;

  {$IFDEF WDC}
  if CACHE_DELIVERY_BIDS then
    fOfferToDemandCache.Add(BidKey, Result);
  {$ENDIF}

  Result := Result + SerfBidValue;
end;


function TKMDeliveries.CalculateBid(iO, iD: Integer; aSerf: TKMUnitSerf = nil): Single;
begin
  Result := CalculateBidBasic(iO, iD, aSerf);

  //Modifications for bidding system
  if (fDemand[iD].Loc_House <> nil) //Prefer delivering to houses with fewer supply
    and (fDemand[iD].Ware <> wt_All)
    and (fDemand[iD].Ware <> wt_Warfare) then //Except Barracks and Store, where supply doesn't matter or matter less
    Result := Result + 20 * fDemand[iD].Loc_House.CheckResIn(fDemand[iD].Ware);

  //Delivering weapons from store to barracks, make it lowest priority when there are >50 of that weapon in the barracks.
  //In some missions the storehouse has vast amounts of weapons, and we don't want the serfs to spend the whole game moving these.
  //In KaM, if the barracks has >200 weapons the serfs will stop delivering from the storehouse. I think our solution is better.
  if (fDemand[iD].Loc_House <> nil)
    and (fDemand[iD].Loc_House.HouseType = ht_Barracks)
    and (fOffer[iO].Loc_House.HouseType = ht_Store)
    and (fDemand[iD].Loc_House.CheckResIn(fOffer[iO].Ware) > 50) then
    Result := Result + 10000;

  //When delivering food to warriors, add a random amount to bid to ensure that a variety of food is taken. Also prefer food which is more abundant.
  if (fDemand[iD].Loc_Unit <> nil)
    and (fDemand[iD].Ware = wt_Food) then
    Result := Result + KaMRandom(5+(100 div fOffer[iO].Count)); //The more resource there is, the smaller Random can be. >100 we no longer care, it's just random 5.
end;


procedure TKMDeliveries.CheckForBetterDemand(aDeliveryID: Integer; out aToHouse: TKMHouse; out aToUnit: TKMUnit; aSerf: TKMUnitSerf);
var
  iD, iO, BestD, OldD: Integer;
  Bid, BestBid: Single;
  BestImportance: TKMDemandImportance;
begin
  iO := fQueue[aDeliveryID].OfferID;
  OldD := fQueue[aDeliveryID].DemandID;

  //Special rule to prevent an annoying situation: If we were delivering to a unit
  //do not look for a better demand. Deliveries to units are closely watched/controlled
  //by the player. For example if player orders food for group A, then after serfs start
  //walking to storehouse orders food for closer group B. Player expects A to be fed first
  //even though B is closer.
  //Another example: School is nearly finished digging at start of game. Serf is getting
  //stone for a labourer making a road. School digging finishes and the stone goes to the
  //school (which is closer). Now the road labourer is waiting even though the player saw
  //the serf fetching the stone for him before the school digging was finished.
  //This "CheckForBetterDemand" feature is mostly intended to optimise house->house
  //deliveries within village and reduce delay in serf decision making.
  if fDemand[OldD].Loc_Unit <> nil then
  begin
    aToHouse := fDemand[OldD].Loc_House;
    aToUnit := fDemand[OldD].Loc_Unit;
    Exit;
  end;

  //By default we keep the old demand, so that's our starting bid
  BestD := OldD;
  if not fDemand[OldD].IsDeleted then
  begin
    BestBid := CalculateBid(iO, OldD, aSerf);
    BestImportance := fDemand[OldD].Importance;
  end
  else
  begin
    //Our old demand is no longer valid (e.g. house destroyed), so give it minimum weight
    //If no other demands are found we can still return this invalid one, TaskDelivery handles that
    BestBid := MaxSingle;
    BestImportance := Low(TKMDemandImportance);
  end;

  for iD := 1 to fDemandCount do
    if (fDemand[iD].Ware <> wt_None)
    and (OldD <> Id)
    and (fDemand[iD].Importance >= BestImportance) //Skip any less important than the best we found
    and ValidDelivery(iO, iD, True) then
    begin
      Bid := CalculateBid(iO, iD, aSerf);
      if (Bid < BestBid) or (fDemand[iD].Importance > BestImportance) then
      begin
        BestD := iD;
        BestBid := Bid;
        BestImportance := fDemand[iD].Importance;
      end;
    end;

  //Did we switch jobs?
  if BestD <> OldD then
  begin
    //Remove old demand
    Dec(fDemand[OldD].BeingPerformed);
    if (fDemand[OldD].BeingPerformed = 0) and fDemand[OldD].IsDeleted then
      CloseDemand(OldD);

    //Take new demand
    fQueue[aDeliveryID].DemandID := BestD;
    Inc(fDemand[BestD].BeingPerformed); //Places a virtual "Reserved" sign on Demand
  end;
  //Return chosen unit and house
  aToHouse := fDemand[BestD].Loc_House;
  aToUnit := fDemand[BestD].Loc_Unit;
end;

// Find best Demand for the given delivery. Could return same or nothing
procedure TKMDeliveries.DeliveryFindBestDemand(aSerf: TKMUnitSerf; aDeliveryId: Integer; aResource: TWareType; out aToHouse: TKMHouse; out aToUnit: TKMUnit; out aForceDelivery: Boolean);

  function ValidBestDemand(iD: Integer): Boolean;
  begin
    Result := (fDemand[iD].Ware = aResource) or
              ((fDemand[iD].Ware = wt_Warfare) and (aResource in [WARFARE_MIN..WARFARE_MAX])) or
              ((fDemand[iD].Ware = wt_Food) and (aResource in [wt_Bread, wt_Sausages, wt_Wine, wt_Fish]));

    //Check if unit is alive
    Result := Result and ((fDemand[iD].Loc_Unit = nil) or not fDemand[iD].Loc_Unit.IsDeadOrDying);

    //Check if demand house has enabled delivery
    if fDemand[iD].Loc_House <> nil then
    begin
      //Check delivery flag
      Result := Result and (fDemand[iD].Loc_House.DeliveryMode = dm_Delivery);
      //for ArmorWorkshop also check accept ware flag
      if fDemand[iD].Loc_House is TKMHouseArmorWorkshop then
        Result := Result and TKMHouseArmorWorkshop(fDemand[iD].Loc_House).AcceptWareForDelivery(fDemand[iD].Ware);
      if fDemand[iD].Loc_House is TKMHouseTownHall then
        Result := Result and (TKMHouseTownHall(fDemand[iD].Loc_House).GoldMaxCnt > TKMHouseTownHall(fDemand[iD].Loc_House).GoldCnt);
    end;

    //If Demand aren't reserved already
    Result := Result and ((fDemand[iD].DemandType = dtAlways) or (fDemand[iD].BeingPerformed = 0));
  end;

  function FindBestDemandId: Integer;
  var
    iD: Integer;
    Bid, BestBid: Single;
    BestImportance: TKMDemandImportance;
  begin
    Result := -1;
    aForceDelivery := False;
    BestImportance := Low(TKMDemandImportance);
    BestBid := MaxSingle;
    //Try to find house or unit demand first (not storage)
    for iD := 1 to fDemandCount do
      if (fDemand[iD].Ware <> wt_None)
        and (iD <> fQueue[aDeliveryId].DemandID)
        and (fDemand[iD].Importance >= BestImportance)
        and ValidBestDemand(iD) then
      begin
        Bid := CalculateBidBasic(aSerf.UID, aSerf.GetPosition, 1, ht_None, aSerf.Owner, iD); //Calc bid to find the best demand
        if (Bid < BestBid) or (fDemand[iD].Importance > BestImportance) then
        begin
          Result := iD;
          BestBid := Bid;
          BestImportance := fDemand[iD].Importance;
        end;
      end;

    // If nothing was found, then try to deliver to open for delivery Storage
    if Result = -1 then
      for iD := 1 to fDemandCount do
        if (fDemand[iD].Ware = wt_All)
          and (iD <> fQueue[aDeliveryId].DemandID)
          and (fDemand[iD].Loc_House.DeliveryMode = dm_Delivery)
          and (fDemand[iD].Loc_House is TKMHouseStore)
          and not TKMHouseStore(fDemand[iD].Loc_House).NotAcceptFlag[aResource] then
        begin
          Bid := CalculateBidBasic(aSerf.UID, aSerf.GetPosition, 1, ht_None, aSerf.Owner, iD); //Choose the closest storage
          if (Bid < BestBid) then
          begin
            Result := iD;
            BestBid := Bid;
          end;
        end;

    // If no open storage for delivery found, then try to find any storage or any barracks
    if Result = -1 then
      for iD := 1 to fDemandCount do
        if (fDemand[iD].Ware = wt_All)
          and not fDemand[iD].Loc_House.IsDestroyed then //choose between all storages, including current delivery. But not destroyed
        begin
          Bid := CalculateBidBasic(aSerf.UID, aSerf.GetPosition, 1, ht_None, aSerf.Owner, iD); //Choose the closest storage
          if (Bid < BestBid) then
          begin
            Result := iD;
            BestBid := Bid;
            aForceDelivery := True;
          end;
        end;
  end;
var
  BestDemandId, OldDemandId: Integer; // Keep Int to assign to Delivery down below
begin
  OldDemandId := fQueue[aDeliveryId].DemandID;
  BestDemandId := FindBestDemandId;

  // Did we find anything?
  if BestDemandId = -1 then
  begin
    // Remove old demand
    Dec(fDemand[OldDemandId].BeingPerformed);
    if (fDemand[OldDemandId].BeingPerformed = 0) and fDemand[OldDemandId].IsDeleted then
      CloseDemand(OldDemandId);

    // Delivery should be cancelled now
    CloseDelivery(aDeliveryId);
    aToHouse := nil;
    aToUnit := nil;
  end
  else
  begin
    // Did we switch jobs?
    if BestDemandId <> OldDemandId then
    begin
      // Remove old demand
      Dec(fDemand[OldDemandId].BeingPerformed);
      if (fDemand[OldDemandId].BeingPerformed = 0) and fDemand[OldDemandId].IsDeleted then
        CloseDemand(OldDemandId);

      // Take new demand
      fQueue[aDeliveryId].DemandId := BestDemandId;
      Inc(fDemand[BestDemandId].BeingPerformed); //Places a virtual "Reserved" sign on Demand
    end;

    // Return chosen unit and house
    aToHouse := fDemand[BestDemandId].Loc_House;
    aToUnit := fDemand[BestDemandId].Loc_Unit;
  end;
end;

//Should issue a job based on requesters location and job importance
//Serf may ask for a job from within a house after completing previous delivery
procedure TKMDeliveries.AskForDelivery(aSerf: TKMUnitSerf; aHouse: TKMHouse = nil);
var
  iD, iO, BestD, BestO: Integer;
  Bid, BestBid: Single;
  BestImportance: TKMDemandImportance;
begin
  //Find Offer matching Demand
  //TravelRoute Asker>Offer>Demand should be shortest
  BestBid := MaxSingle;
  BestO := -1;
  BestD := -1;
  BestImportance := Low(TKMDemandImportance);

  for iD := 1 to fDemandCount do
    if (fDemand[iD].Ware <> wt_None)
    and (fDemand[iD].Importance >= BestImportance) then //Skip any less important than the best we found
      for iO := 1 to fOfferCount do
        if ((aHouse = nil) or (fOffer[iO].Loc_House = aHouse))  //Make sure from house is the one requested
        and (fOffer[iO].Ware <> wt_None)
        and PermitDelivery(iO, iD, aSerf) then
        begin
          Bid := CalculateBid(iO, iD, aSerf);
          if (Bid < BestBid) or (fDemand[iD].Importance > BestImportance) then
          begin
            BestO := iO;
            BestD := iD;
            BestBid := Bid;
            BestImportance := fDemand[iD].Importance;
          end;
        end;

  if (BestO <> -1) and (BestD <> -1) then
    AssignDelivery(BestO, BestD, aSerf);
end;


procedure TKMDeliveries.AssignDelivery(iO,iD: Integer; aSerf: TKMUnitSerf);
var I: Integer;
begin
  //Find a place where Delivery will be written to after Offer-Demand pair is found
  I := 1;
  while (I <= fQueueCount) and (fQueue[I].JobStatus <> js_Empty) do
    Inc(I);

  if I > fQueueCount then
  begin
    inc(fQueueCount, LENGTH_INC);
    SetLength(fQueue, fQueueCount + 1);
  end;

  fQueue[I].DemandID := iD;
  fQueue[I].OfferID := iO;
  fQueue[I].JobStatus := js_Taken;
  fQueue[I].Item := nil;

  if Assigned(FormLogistics) then
  begin
    fQueue[I].Item := FormLogistics.ListView.Items.Add;
    fQueue[I].Item.Caption := gRes.Wares[fOffer[fQueue[I].OfferID].Ware].Title;

    if fOffer[fQueue[I].OfferID].Loc_House = nil then
      fQueue[I].Item.SubItems.Add('Destroyed')
    else
      fQueue[I].Item.SubItems.Add(gRes.Houses[fOffer[fQueue[I].OfferID].Loc_House.HouseType].HouseName);

    if fDemand[fQueue[I].DemandID].Loc_House = nil then
      fQueue[I].Item.SubItems.Add('Destroyed')
    else
      fQueue[I].Item.SubItems.Add(gRes.Houses[fDemand[fQueue[I].DemandID].Loc_House.HouseType].HouseName);
  end;

  Inc(fOffer[iO].BeingPerformed); //Places a virtual "Reserved" sign on Offer
  Inc(fDemand[iD].BeingPerformed); //Places a virtual "Reserved" sign on Demand

  gLog.LogDelivery('Creating delivery ID '+ IntToStr(I));

  //Now we have best job and can perform it
  if fDemand[iD].Loc_House <> nil then
    aSerf.Deliver(fOffer[iO].Loc_House, fDemand[iD].Loc_House, fOffer[iO].Ware, I)
  else
    aSerf.Deliver(fOffer[iO].Loc_House, fDemand[iD].Loc_Unit, fOffer[iO].Ware, I)
end;


//Resource has been taken from Offer
procedure TKMDeliveries.TakenOffer(aID: Integer);
var iO: Integer;
begin
  gLog.LogDelivery('Taken offer from delivery ID ' + IntToStr(aID));

  iO := fQueue[aID].OfferID;
  fQueue[aID].OfferID := 0; //We don't need it any more

  Dec(fOffer[iO].BeingPerformed); //Remove reservation
  Dec(fOffer[iO].Count); //Remove resource from Offer list

  if fOffer[iO].Count = 0 then
    if fOffer[iO].BeingPerformed > 0 then
      fOffer[iO].IsDeleted := True
    else
      CloseOffer(iO);
end;


//Resource has been delivered to Demand
procedure TKMDeliveries.GaveDemand(aID: Integer);
var iD: Integer;
begin
  gLog.LogDelivery('Gave demand from delivery ID ' + IntToStr(aID));
  iD := fQueue[aID].DemandID;
  fQueue[aID].DemandID := 0; //We don't need it any more

  Dec(fDemand[iD].BeingPerformed); //Remove reservation

  if (fDemand[iD].DemandType = dtOnce)
  or (fDemand[iD].IsDeleted and (fDemand[iD].BeingPerformed = 0)) then
    CloseDemand(iD) //Remove resource from Demand list
end;


//AbandonDelivery
procedure TKMDeliveries.AbandonDelivery(aID: Integer);
begin
  gLog.LogDelivery('Abandoned delivery ID ' + IntToStr(aID));

  //Remove reservations without removing items from lists
  if fQueue[aID].OfferID <> 0 then
  begin
    Dec(fOffer[fQueue[aID].OfferID].BeingPerformed);
    //Now see if we need to delete the Offer as we are the last remaining pointer
    if fOffer[fQueue[aID].OfferID].IsDeleted and (fOffer[fQueue[aID].OfferID].BeingPerformed = 0) then
      CloseOffer(fQueue[aID].OfferID);
  end;

  if fQueue[aID].DemandID <> 0 then
  begin
    Dec(fDemand[fQueue[aID].DemandID].BeingPerformed);
    if fDemand[fQueue[aID].DemandID].IsDeleted and (fDemand[fQueue[aID].DemandID].BeingPerformed = 0) then
      CloseDemand(fQueue[aID].DemandID);
  end;

  CloseDelivery(aID);
end;


//Job successfully done and we ommit it
procedure TKMDeliveries.CloseDelivery(aID: Integer);
begin
  gLog.LogDelivery('Closed delivery ID ' + IntToStr(aID));

  fQueue[aID].OfferID := 0;
  fQueue[aID].DemandID := 0;
  fQueue[aID].JobStatus := js_Empty; //Open slot
  if Assigned(fQueue[aID].Item) then
    fQueue[aID].Item.Delete;
end;


procedure TKMDeliveries.CloseDemand(aID: Integer);
begin
  Assert(fDemand[aID].BeingPerformed = 0);
  fDemand[aID].Ware := wt_None;
  fDemand[aID].DemandType := dtOnce;
  fDemand[aID].Importance := Low(TKMDemandImportance);
  gHands.CleanUpHousePointer(fDemand[aID].Loc_House);
  gHands.CleanUpUnitPointer(fDemand[aID].Loc_Unit);
  fDemand[aID].IsDeleted := False;
end;


procedure TKMDeliveries.CloseOffer(aID: Integer);
begin
  assert(fOffer[aID].BeingPerformed = 0);
  fOffer[aID].IsDeleted := false;
  fOffer[aID].Ware := wt_None;
  fOffer[aID].Count := 0;
  gHands.CleanUpHousePointer(fOffer[aID].Loc_House);
end;


procedure TKMDeliveries.Save(SaveStream: TKMemoryStream);
var
  I: Integer;
begin
  SaveStream.WriteA('Deliveries');
  SaveStream.Write(fOfferCount);
  for I := 1 to fOfferCount do
  begin
    SaveStream.Write(fOffer[I].Ware, SizeOf(fOffer[I].Ware));
    SaveStream.Write(fOffer[I].Count);
    if fOffer[I].Loc_House <> nil then
      SaveStream.Write(fOffer[I].Loc_House.UID)
    else
      SaveStream.Write(Integer(0));
    SaveStream.Write(fOffer[I].BeingPerformed);
    SaveStream.Write(fOffer[I].IsDeleted);
  end;

  SaveStream.Write(fDemandCount);
  for I := 1 to fDemandCount do
  with fDemand[I] do
  begin
    SaveStream.Write(Ware, SizeOf(Ware));
    SaveStream.Write(DemandType, SizeOf(DemandType));
    SaveStream.Write(Importance, SizeOf(Importance));
    if Loc_House <> nil then SaveStream.Write(Loc_House.UID) else SaveStream.Write(Integer(0));
    if Loc_Unit  <> nil then SaveStream.Write(Loc_Unit.UID ) else SaveStream.Write(Integer(0));
    SaveStream.Write(BeingPerformed);
    SaveStream.Write(IsDeleted);
  end;

  SaveStream.Write(fQueueCount);
  for I := 1 to fQueueCount do
  begin
    SaveStream.Write(fQueue[I].OfferID);
    SaveStream.Write(fQueue[I].DemandID);
    SaveStream.Write(fQueue[I].JobStatus, SizeOf(fQueue[I].JobStatus));
  end;
end;


procedure TKMDeliveries.Load(LoadStream: TKMemoryStream);
var I: Integer;
begin
  {$IFDEF WDC}
  fOfferToDemandCache.Clear;
  fSerfToOfferCache.Clear;
  {$ENDIF}

  LoadStream.ReadAssert('Deliveries');
  LoadStream.Read(fOfferCount);
  SetLength(fOffer, fOfferCount+1);
  for I := 1 to fOfferCount do
  begin
    LoadStream.Read(fOffer[I].Ware, SizeOf(fOffer[I].Ware));
    LoadStream.Read(fOffer[I].Count);
    LoadStream.Read(fOffer[I].Loc_House, 4);
    LoadStream.Read(fOffer[I].BeingPerformed);
    LoadStream.Read(fOffer[I].IsDeleted);
  end;

  LoadStream.Read(fDemandCount);
  SetLength(fDemand, fDemandCount+1);
  for I := 1 to fDemandCount do
  with fDemand[I] do
  begin
    LoadStream.Read(Ware, SizeOf(Ware));
    LoadStream.Read(DemandType, SizeOf(DemandType));
    LoadStream.Read(Importance, SizeOf(Importance));
    LoadStream.Read(Loc_House, 4);
    LoadStream.Read(Loc_Unit, 4);
    LoadStream.Read(BeingPerformed);
    LoadStream.Read(IsDeleted);
  end;

  LoadStream.Read(fQueueCount);
  SetLength(fQueue, fQueueCount+1);
  for I:=1 to fQueueCount do
  begin
    LoadStream.Read(fQueue[I].OfferID);
    LoadStream.Read(fQueue[I].DemandID);
    LoadStream.Read(fQueue[I].JobStatus, SizeOf(fQueue[I].JobStatus));
  end;
end;


procedure TKMDeliveries.SyncLoad;
var I:integer;
begin
  for I := 1 to fOfferCount do
    fOffer[I].Loc_House := gHands.GetHouseByUID(cardinal(fOffer[I].Loc_House));

  for I := 1 to fDemandCount do
  with fDemand[I] do
  begin
    Loc_House := gHands.GetHouseByUID(cardinal(Loc_House));
    Loc_Unit := gHands.GetUnitByUID(cardinal(Loc_Unit));
  end;
end;


procedure TKMDeliveries.UpdateState(aTick: Cardinal);
begin
  {$IFDEF WDC}
  if CACHE_DELIVERY_BIDS and ((aTick mod CACHE_CLEAN_FREQ) = 0) then //Clear cache every 10 ticks
  begin
    fOfferToDemandCache.Clear;
    fSerfToOfferCache.Clear;
  end;
  {$ENDIF}
end;


procedure TKMDeliveries.ExportToFile(const aFileName: UnicodeString);
var
  I: Integer;
  SL: TStringList;
  tmpS: UnicodeString;
begin
  SL := TStringList.Create;

  SL.Append('Demand:');
  SL.Append('---------------------------------');
  for I := 1 to fDemandCount do
  if fDemand[I].Ware <> wt_None then
  begin
    tmpS := #9;
    if fDemand[I].Loc_House <> nil then tmpS := tmpS + gRes.Houses[fDemand[I].Loc_House.HouseType].HouseName + #9 + #9;
    if fDemand[I].Loc_Unit  <> nil then tmpS := tmpS + gRes.Units[fDemand[I].Loc_Unit.UnitType].GUIName + #9 + #9;
    tmpS := tmpS + gRes.Wares[fDemand[I].Ware].Title;
    if fDemand[I].Importance <> diNorm then
      tmpS := tmpS + '^';

    SL.Append(tmpS);
  end;

  SL.Append('Offer:');
  SL.Append('---------------------------------');
  for I := 1 to fOfferCount do
  if fOffer[I].Ware <> wt_None then
  begin
    tmpS := #9;
    if fOffer[I].Loc_House <> nil then tmpS := tmpS + gRes.Houses[fOffer[I].Loc_House.HouseType].HouseName + #9 + #9;
    tmpS := tmpS + gRes.Wares[fOffer[I].Ware].Title + #9;
    tmpS := tmpS + IntToStr(fOffer[I].Count);

    SL.Append(tmpS);
  end;

  SL.Append('Running deliveries:');
  SL.Append('---------------------------------');
  for I := 1 to fQueueCount do
  if fQueue[I].OfferID <> 0 then
  begin
    tmpS := 'id ' + IntToStr(I) + '.' + #9;
    tmpS := tmpS + gRes.Wares[fOffer[fQueue[I].OfferID].Ware].Title + #9;

    if fOffer[fQueue[I].OfferID].Loc_House = nil then
      tmpS := tmpS + 'Destroyed' + ' >>> '
    else
      tmpS := tmpS + gRes.Houses[fOffer[fQueue[I].OfferID].Loc_House.HouseType].HouseName + ' >>> ';

    if fDemand[fQueue[I].DemandID].Loc_House = nil then
      tmpS := tmpS + 'Destroyed'
    else
      tmpS := tmpS + gRes.Houses[fDemand[fQueue[I].DemandID].Loc_House.HouseType].HouseName;

    SL.Append(tmpS);
  end;

  SL.SaveToFile(aFileName);
  SL.Free;
end;


{$IFDEF WDC}
{ TKMDeliveryBidKeyComparer }
function TKMDeliveryBidKeyComparer.Equals(const Left, Right: TKMDeliveryBidKey): Boolean;
begin
  Result := (Left.FromUID = Right.FromUID) and (Left.ToUID = Right.ToUID);
end;


//example taken from https://stackoverflow.com/questions/18068977/use-objects-as-keys-in-tobjectdictionary
{$IFOPT Q+}
  {$DEFINE OverflowChecksEnabled}
  {$Q-}
{$ENDIF}
function CombinedHash(const Values: array of Integer): Integer;
var
  Value: Integer;
begin
  Result := 17;
  for Value in Values do begin
    Result := Result*37 + Value;
  end;
end;
{$IFDEF OverflowChecksEnabled}
  {$Q+}
{$ENDIF}


function TKMDeliveryBidKeyComparer.GetHashCode(const Value: TKMDeliveryBidKey): Integer;
begin
  Result := CombinedHash([THashBobJenkins.GetHashValue(Value.FromUID, SizeOf(Integer), 0),
                          THashBobJenkins.GetHashValue(Value.ToUID, SizeOf(Integer), 0)]);
end;
{$ENDIF}


end.
