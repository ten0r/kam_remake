unit KM_HouseWoodcutters;
{$I KaM_Remake.inc}
interface
uses
  KM_Houses, KM_ResHouses,
  KM_CommonClasses, KM_Points, KM_Defaults;
  
type
  TKMWoodcutterMode = (wcm_Chop, wcm_Plant, wcm_ChopAndPlant);
  
  TKMHouseWoodcutters = class(TKMHouse)
  private
    fWoodcutterMode: TKMWoodcutterMode;
    fCuttingPoint: TKMPoint;
    procedure SetWoodcutterMode(aWoodcutterMode: TKMWoodcutterMode);
    procedure SetCuttingPoint(aValue: TKMPoint);
    function GetCuttingPointTexId: Word;
  public
    property WoodcutterMode: TKMWoodcutterMode read fWoodcutterMode write SetWoodcutterMode;
    constructor Create(aUID: Integer; aHouseType: THouseType; PosX, PosY: Integer; aOwner: TKMHandIndex; aBuildState: THouseBuildState);
    constructor Load(LoadStream: TKMemoryStream); override;
    procedure Save(SaveStream: TKMemoryStream); override;

    function IsCuttingPointSet: Boolean;
    procedure ValidateCuttingPoint;
    property CuttingPoint: TKMPoint read fCuttingPoint write SetCuttingPoint;
    function GetValidCuttingPoint(aPoint: TKMPoint): TKMPoint;
    property CuttingPointTexId: Word read GetCuttingPointTexId;
  end;

  
implementation
uses
  KM_Terrain;

{ TKMHouseWoodcutters }
constructor TKMHouseWoodcutters.Create(aUID: Integer; aHouseType: THouseType; PosX, PosY: Integer; aOwner: TKMHandIndex; aBuildState: THouseBuildState);
begin
  inherited;
  WoodcutterMode := wcm_ChopAndPlant;
  CuttingPoint := PointBelowEntrance;
end;


constructor TKMHouseWoodcutters.Load(LoadStream: TKMemoryStream);
begin
  inherited;
  LoadStream.Read(fWoodcutterMode, SizeOf(fWoodcutterMode));
  LoadStream.Read(fCuttingPoint);
end;


procedure TKMHouseWoodcutters.Save(SaveStream: TKMemoryStream);
begin
  inherited;
  SaveStream.Write(fWoodcutterMode, SizeOf(fWoodcutterMode));
  SaveStream.Write(fCuttingPoint);
end;

function TKMHouseWoodcutters.IsCuttingPointSet: Boolean;
begin
  Result := not KMSamePoint(fCuttingPoint, PointBelowEntrance);
end;


procedure TKMHouseWoodcutters.ValidateCuttingPoint;
begin
  //this will automatically update cutting point to valid value
  SetCuttingPoint(fCuttingPoint);
end;


function TKMHouseWoodcutters.GetCuttingPointTexId: Word;
begin
  Result := 660;
end;


//Check if specified point is valid
//if it is valid - return it
//if it is not valid - return appropriate valid point, within segment between PointBelowEntrance and specified aPoint
function TKMHouseWoodcutters.GetValidCuttingPoint(aPoint: TKMPoint): TKMPoint;
begin
  Result := gTerrain.GetPassablePointWithinSegment(PointBelowEntrance, aPoint, tpWalk, MAX_WOODCUTTER_CUT_PNT_DISTANCE);
end;


procedure TKMHouseWoodcutters.SetCuttingPoint(aValue: TKMPoint);
begin
  fCuttingPoint := GetValidCuttingPoint(aValue);
end;


procedure TKMHouseWoodcutters.SetWoodcutterMode(aWoodcutterMode: TKMWoodcutterMode);
begin

  //If we're allowed to plant only again or chop only
  //we should reshow the depleted message if we are changed to cut and run out of trees
  if (fWoodcutterMode <> aWoodcutterMode)
    and (aWoodcutterMode in [wcm_Chop, wcm_Plant]) then
    ResourceDepletedMsgIssued := False;

  fWoodcutterMode := aWoodcutterMode;
end;


end.
