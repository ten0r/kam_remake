unit KM_UnitTaskDelivery;
{$I KaM_Remake.inc}
interface
uses
  Classes, SysUtils,
  KM_CommonClasses, KM_Defaults, KM_Points,
  KM_Houses, KM_Units, KM_ResWares;


type
  TDeliverKind = (dk_ToHouse, dk_ToConstruction, dk_ToUnit);

  TTaskDeliver = class(TUnitTask)
  private
    fFrom: TKMHouse;
    fToHouse: TKMHouse;
    fToUnit: TKMUnit;
    fWareType: TWareType;
    fDeliverID: Integer;
    fDeliverKind: TDeliverKind;
    //Force delivery, even if fToHouse blocked ware from delivery.
    //Used in exceptional situation, when ware was carried by serf and delivery demand was destroyed and no one new was found
    fForceDelivery: Boolean;
    procedure CheckForBetterDestination;
    function FindBestDestination: Boolean;
  public
    constructor Create(aSerf: TKMUnitSerf; aFrom: TKMHouse; toHouse: TKMHouse; Res: TWareType; aID: Integer); overload;
    constructor Create(aSerf: TKMUnitSerf; aFrom: TKMHouse; toUnit: TKMUnit; Res: TWareType; aID: Integer); overload;
    constructor Load(LoadStream: TKMemoryStream); override;
    procedure SyncLoad; override;
    destructor Destroy; override;
    function WalkShouldAbandon: Boolean; override;
    property DeliverKind: TDeliverKind read fDeliverKind;
    function Execute: TTaskResult; override;
    procedure Save(SaveStream: TKMemoryStream); override;
  end;


implementation
uses
  Math,
  KM_HandsCollection, KM_Hand,
  KM_Units_Warrior, KM_HouseBarracks, KM_HouseTownHall,
  KM_UnitTaskBuild, KM_Log;


{ TTaskDeliver }
constructor TTaskDeliver.Create(aSerf: TKMUnitSerf; aFrom: TKMHouse; toHouse: TKMHouse; Res: TWareType; aID: Integer);
begin
  inherited Create(aSerf);
  fTaskName := utn_Deliver;

  Assert((aFrom <> nil) and (toHouse <> nil) and (Res <> wt_None), 'Serf ' + IntToStr(fUnit.UID) + ': invalid delivery task');

  gLog.LogDelivery('Serf ' + IntToStr(fUnit.UID) + ' created delivery task ' + IntToStr(fDeliverID));

  fFrom    := aFrom.GetHousePointer;
  fToHouse := toHouse.GetHousePointer;
  //Check it once to begin with as the house could become complete before the task exits (in rare circumstances when the task
  // does not exit until long after the ware has been delivered due to walk interactions)
  if toHouse.IsComplete then
    fDeliverKind := dk_ToHouse
  else
    fDeliverKind := dk_ToConstruction;

  fWareType   := Res;
  fDeliverID  := aID;
end;


constructor TTaskDeliver.Create(aSerf: TKMUnitSerf; aFrom: TKMHouse; toUnit: TKMUnit; Res: TWareType; aID: Integer);
begin
  inherited Create(aSerf);
  fTaskName := utn_Deliver;

  Assert((aFrom <> nil) and (toUnit <> nil) and ((toUnit is TKMUnitWarrior) or (toUnit is TKMUnitWorker)) and (Res <> wt_None), 'Serf '+inttostr(fUnit.UID)+': invalid delivery task');
  gLog.LogDelivery('Serf ' + IntToStr(fUnit.UID) + ' created delivery task ' + IntToStr(fDeliverID));

  fFrom    := aFrom.GetHousePointer;
  fToUnit  := toUnit.GetUnitPointer;
  fDeliverKind := dk_ToUnit;
  fWareType := Res;
  fDeliverID := aID;
end;


constructor TTaskDeliver.Load(LoadStream: TKMemoryStream);
begin
  inherited;
  LoadStream.Read(fFrom, 4);
  LoadStream.Read(fToHouse, 4);
  LoadStream.Read(fToUnit, 4);
  LoadStream.Read(fForceDelivery);
  LoadStream.Read(fWareType, SizeOf(fWareType));
  LoadStream.Read(fDeliverID);
  LoadStream.Read(fDeliverKind, SizeOf(fDeliverKind));
end;



procedure TTaskDeliver.Save(SaveStream: TKMemoryStream);
begin
  inherited;
  if fFrom <> nil then
    SaveStream.Write(fFrom.UID) //Store ID, then substitute it with reference on SyncLoad
  else
    SaveStream.Write(Integer(0));
  if fToHouse <> nil then
    SaveStream.Write(fToHouse.UID) //Store ID, then substitute it with reference on SyncLoad
  else
    SaveStream.Write(Integer(0));
  if fToUnit <> nil then
    SaveStream.Write(fToUnit.UID) //Store ID, then substitute it with reference on SyncLoad
  else
    SaveStream.Write(Integer(0));
  SaveStream.Write(fForceDelivery);
  SaveStream.Write(fWareType, SizeOf(fWareType));
  SaveStream.Write(fDeliverID);
  SaveStream.Write(fDeliverKind, SizeOf(fDeliverKind));
end;


procedure TTaskDeliver.SyncLoad;
begin
  inherited;
  fFrom    := gHands.GetHouseByUID(Cardinal(fFrom));
  fToHouse := gHands.GetHouseByUID(Cardinal(fToHouse));
  fToUnit  := gHands.GetUnitByUID(Cardinal(fToUnit));
end;


destructor TTaskDeliver.Destroy;
begin
  gLog.LogDelivery('Serf ' + IntToStr(fUnit.UID) + ' abandoned delivery task ' + IntToStr(fDeliverID) + ' at phase ' + IntToStr(fPhase));

  if fDeliverID <> 0 then
    gHands[fUnit.Owner].Deliveries.Queue.AbandonDelivery(fDeliverID);

  if TKMUnitSerf(fUnit).Carry <> wt_None then
  begin
    gHands[fUnit.Owner].Stats.WareConsumed(TKMUnitSerf(fUnit).Carry);
    TKMUnitSerf(fUnit).CarryTake; //empty hands
  end;

  gHands.CleanUpHousePointer(fFrom);
  gHands.CleanUpHousePointer(fToHouse);
  gHands.CleanUpUnitPointer(fToUnit);
  inherited;
end;


//Note: Phase is -1 because it will have been increased at the end of last Execute
function TTaskDeliver.WalkShouldAbandon: Boolean;
begin
  Result := False;

  //After step 2 we don't care if From is destroyed or doesn't have the ware
  if fPhase <= 2 then
    Result := Result or fFrom.IsDestroyed or (not fFrom.ResOutputAvailable(fWareType, 1) {and (fPhase < 5)});

  //do not abandon the delivery if target is destroyed/dead, we will find new target later
  case fDeliverKind of
    dk_ToHouse:         if fPhase <= 8 then
                        begin
                          Result := Result or fToHouse.IsDestroyed
                                   or (not fForceDelivery
                                      and ((fToHouse.DeliveryMode <> dm_Delivery)
                                        or ((fToHouse is TKMHouseStore) and TKMHouseStore(fToHouse).NotAcceptFlag[fWareType])
                                        or ((fToHouse is TKMHouseBarracks) and TKMHouseBarracks(fToHouse).NotAcceptFlag[fWareType])
                                        or ((fToHouse is TKMHouseArmorWorkshop) and not TKMHouseArmorWorkshop(fToHouse).AcceptWareForDelivery(fWareType)))
                                        or ((fToHouse is TKMHouseTownHall) and (TKMHouseTownHall(fToHouse).GoldMaxCnt <= TKMHouseTownHall(fToHouse).GoldCnt)));
                        end;
    dk_ToConstruction:  if fPhase <= 6 then
                          Result := Result or fToHouse.IsDestroyed;
    dk_ToUnit:          if fPhase <= 6 then
                          Result := Result or (fToUnit = nil) or fToUnit.IsDeadOrDying;
  end;
end;


procedure TTaskDeliver.CheckForBetterDestination;
var
  NewToHouse: TKMHouse;
  NewToUnit: TKMUnit;
begin
  gHands[fUnit.Owner].Deliveries.Queue.CheckForBetterDemand(fDeliverID, NewToHouse, NewToUnit, TKMUnitSerf(fUnit));

  gHands.CleanUpHousePointer(fToHouse);
  gHands.CleanUpUnitPointer(fToUnit);
  if NewToHouse <> nil then
  begin
    fToHouse := NewToHouse.GetHousePointer;
    if fToHouse.IsComplete then
      fDeliverKind := dk_ToHouse
    else
      fDeliverKind := dk_ToConstruction;
  end
  else
  begin
    fToUnit := NewToUnit.GetUnitPointer;
    fDeliverKind := dk_ToUnit;
  end;
end;


// Try to find best destination
function TTaskDeliver.FindBestDestination: Boolean;
var
  NewToHouse: TKMHouse;
  NewToUnit: TKMUnit;
begin
  if fPhase <= 2 then
  begin
    Result := False;
    Exit;
  end else
  if InRange(fPhase, 3, 4) then
  begin
    Result := True;
    Exit;
  end;

  fForceDelivery := False; //Reset ForceDelivery from previous runs
  gHands[fUnit.Owner].Deliveries.Queue.DeliveryFindBestDemand(TKMUnitSerf(fUnit), fDeliverID, fWareType, NewToHouse, NewToUnit, fForceDelivery);

  gHands.CleanUpHousePointer(fToHouse);
  gHands.CleanUpUnitPointer(fToUnit);

  // New House
  if (NewToHouse <> nil) and (NewToUnit = nil) then
  begin
    fToHouse := NewToHouse.GetHousePointer;
    if fToHouse.IsComplete then
      fDeliverKind := dk_ToHouse
    else
      fDeliverKind := dk_ToConstruction;
    Result := True;
    if fPhase > 5 then
      fPhase := 5;
  end
  else
  // New Unit
  if (NewToHouse = nil) and (NewToUnit <> nil) then
  begin
    fToUnit := NewToUnit.GetUnitPointer;
    fDeliverKind := dk_ToUnit;
    Result := True;
    if fPhase > 5 then
      fPhase := 5;
  end
  else
  // No alternative
  if (NewToHouse = nil) and (NewToUnit = nil) then
    Result := False
  else
  // Error
    raise Exception.Create('Both destinations could not be');
end;

function TTaskDeliver.Execute: TTaskResult;
var
  Worker: TKMUnit;
begin
  Result := tr_TaskContinues;

  if WalkShouldAbandon and fUnit.Visible and not FindBestDestination then
  begin
    Result := tr_TaskDone;
    Exit;
  end;

  with TKMUnitSerf(fUnit) do
  case fPhase of
    0:  begin
          SetActionWalkToSpot(fFrom.PointBelowEntrance);
        end;
    1:  begin
          SetActionGoIn(ua_Walk, gd_GoInside, fFrom);
        end;
    2:  begin
          //Barracks can consume the resource (by equipping) before we arrive
          //All houses can have resources taken away by script at any moment
          if not fFrom.ResOutputAvailable(fWareType, 1) then
          begin
            SetActionGoIn(ua_Walk, gd_GoOutside, fFrom); //Step back out
            fPhase := 99; //Exit next run
            Exit;
          end;
          SetActionLockedStay(5,ua_Walk); //Wait a moment inside
          fFrom.ResTakeFromOut(fWareType);
          CarryGive(fWareType);
          CheckForBetterDestination; //Must run before TakenOffer so Offer is still valid
          gHands[Owner].Deliveries.Queue.TakenOffer(fDeliverID);
        end;
    3:  if fFrom.IsDestroyed then //We have the resource, so we don't care if house is destroyed
          SetActionLockedStay(0, ua_Walk)
        else
          SetActionGoIn(ua_Walk, gd_GoOutside, fFrom);
    4:  SetActionLockedStay(0, ua_Walk); //Thats a placeholder left for no obvious reason
  end;

  //Deliver into complete house
  if (fDeliverKind = dk_ToHouse) then
  with TKMUnitSerf(fUnit) do
  case fPhase of
    0..4:;
    5:  SetActionWalkToSpot(fToHouse.PointBelowEntrance);
    6:  SetActionGoIn(ua_Walk, gd_GoInside, fToHouse);
    7:  SetActionLockedStay(5, ua_Walk); //wait a bit inside
    8:  begin
          fToHouse.ResAddToIn(Carry);
          CarryTake;

          gHands[Owner].Deliveries.Queue.GaveDemand(fDeliverID);
          gHands[Owner].Deliveries.Queue.AbandonDelivery(fDeliverID);
          fDeliverID := 0; //So that it can't be abandoned if unit dies while trying to GoOut

          //Now look for another delivery from inside this house
          if TKMUnitSerf(fUnit).TryDeliverFrom(fToHouse) then
          begin
            //After setting new unit task we should free self.
            //Note do not set tr_TaskDone := true as this will affect the new task
            Self.Free;
            Exit;
          end else
            //No delivery found then just step outside
            SetActionGoIn(ua_Walk, gd_GoOutside, fToHouse);
        end;
    else Result := tr_TaskDone;
  end;

  //Deliver into wip house
  if (fDeliverKind = dk_ToConstruction) then
  with TKMUnitSerf(fUnit) do
  case fPhase of
    0..4:;
        // First come close to point below house entrance
    5:  SetActionWalkToSpot(fToHouse.PointBelowEntrance, ua_Walk, 1.42);
    6:  begin
          // Then check if there is a worker hitting house just from the entrance
          Worker := gHands[fUnit.Owner].UnitsHitTest(fToHouse.PointBelowEntrance, ut_Worker);
          if (Worker <> nil) and (Worker.UnitTask <> nil)
            and (Worker.UnitTask is TTaskBuildHouse)
            and (Worker.UnitTask.Phase >= 2) then
            // If so, then allow to bring resources diagonally
            SetActionWalkToSpot(fToHouse.Entrance, ua_Walk, 1.42)
          else
            // else ask serf to bring resources from point below entrance (not diagonally)
            SetActionWalkToSpot(fToHouse.PointBelowEntrance);
        end;
    7:  begin
          Direction := KMGetDirection(GetPosition, fToHouse.Entrance);
          fToHouse.ResAddToBuild(Carry);
          gHands[Owner].Stats.WareConsumed(Carry);
          CarryTake;
          gHands[Owner].Deliveries.Queue.GaveDemand(fDeliverID);
          gHands[Owner].Deliveries.Queue.AbandonDelivery(fDeliverID);
          fDeliverID := 0; //So that it can't be abandoned if unit dies while staying
          SetActionStay(1, ua_Walk);
        end;
    else Result := tr_TaskDone;
  end;

  //Deliver to builder or soldier
  if fDeliverKind = dk_ToUnit then
  with TKMUnitSerf(fUnit) do
  case fPhase of
    0..4:;
    5:  SetActionWalkToUnit(fToUnit, 1.42, ua_Walk); //When approaching from diagonal
    6:  begin
          //See if the unit has moved. If so we must try again
          if KMLengthDiag(fUnit.GetPosition, fToUnit.GetPosition) > 1.5 then
          begin
            SetActionWalkToUnit(fToUnit, 1.42, ua_Walk); //Walk to unit again
            fPhase := 6;
            Exit;
          end;
          //Worker
          if (fToUnit.UnitType = ut_Worker) and (fToUnit.UnitTask <> nil) then
          begin
            //ToDo: Replace phase numbers with enums to avoid hardcoded magic numbers
            // Check if worker is still digging
            if ((fToUnit.UnitTask is TTaskBuildWine) and (fToUnit.UnitTask.Phase < 5))
              or ((fToUnit.UnitTask is TTaskBuildRoad) and (fToUnit.UnitTask.Phase < 4)) then
            begin
              SetActionLockedStay(5, ua_Walk); //wait until worker finish digging process
              fPhase := 6;
              Exit;
            end;
            fToUnit.UnitTask.Phase := fToUnit.UnitTask.Phase + 1;
            fToUnit.SetActionLockedStay(0, ua_Work1); //Tell the worker to resume work by resetting his action (causes task to execute)
          end;
          //Warrior
          if (fToUnit is TKMUnitWarrior) then
          begin
            fToUnit.Feed(UNIT_MAX_CONDITION); //Feed the warrior
            TKMUnitWarrior(fToUnit).RequestedFood := False;
          end;
          gHands[Owner].Stats.WareConsumed(Carry);
          CarryTake;
          gHands[Owner].Deliveries.Queue.GaveDemand(fDeliverID);
          gHands[Owner].Deliveries.Queue.AbandonDelivery(fDeliverID);
          fDeliverID := 0; //So that it can't be abandoned if unit dies while staying
          SetActionLockedStay(5, ua_Walk); //Pause breifly (like we are handing over the ware/food)
        end;
    7:  begin
          //After feeding troops, serf should walk away, but ToUnit could be dead by now
          if (fToUnit is TKMUnitWarrior) then
          begin
            if TKMUnitSerf(fUnit).TryDeliverFrom(nil) then
            begin
              //After setting new unit task we should free self.
              //Note do not set tr_TaskDone := true as this will affect the new task
              Self.Free;
              Exit;
            end else
              //No delivery found then just walk back to our From house
              //even if it's destroyed, its location is still valid
              //Don't walk to spot as it doesn't really matter
              SetActionWalkToHouse(fFrom, 5);
          end else
            SetActionStay(0, ua_Walk); //If we're not feeding a warrior then ignore this step
        end;
    else Result := tr_TaskDone;
  end;

  Inc(fPhase);
end;


end.
