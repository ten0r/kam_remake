unit KM_MapEditor;
{$I KaM_Remake.inc}
interface
uses
  Classes, Controls,
  KM_RenderPool, KM_TerrainPainter, KM_TerrainDeposits, KM_TerrainSelection,
  KM_CommonClasses, KM_Defaults, KM_Points;


type
  TMarkerType = (mtNone, mtDefence, mtRevealFOW);

  TKMMapEdMarker = record
    MarkerType: TMarkerType;
    Owner: TKMHandIndex;
    Index: SmallInt;
  end;

  //Collection of map editing classes and map editor specific data
  TKMMapEditor = class
  private
    fTerrainPainter: TKMTerrainPainter;
    fDeposits: TKMDeposits;
    fSelection: TKMSelection;
    fRevealers: array [0..MAX_HANDS-1] of TKMPointTagList;
    fVisibleLayers: TMapEdLayerSet;
    //When you load a map script/libx/wav/etc. files are "attached" then copied when
    //saving if the path is different
    fAttachedFiles: array of UnicodeString;

    function GetRevealer(aIndex: Byte): TKMPointTagList;
    procedure ProceedUnitsCursorMode;
    procedure UpdateField(aStageIncrement: Integer; aCheckPrevCell: Boolean);
    procedure EraseObject(aEraseAll: Boolean);
    function ChangeObjectOwner(aObject: TObject; aOwner: TKMHandIndex): Boolean;
    procedure ChangeOwner(aChangeOwnerForAll: Boolean);
  public
    ActiveMarker: TKMMapEdMarker;

    ResizeMapRect: TKMRect;
    RevealAll: array [0..MAX_HANDS-1] of Boolean;
    DefaultHuman: TKMHandIndex;
    PlayerHuman: array [0..MAX_HANDS - 1] of Boolean;
    PlayerAI: array [0..MAX_HANDS - 1] of Boolean;

    IsNewMap: Boolean;  // set True for new empty map
    WereSaved: Boolean; // set True when at least 1 map save has been done

    constructor Create;
    destructor Destroy; override;
    property TerrainPainter: TKMTerrainPainter read fTerrainPainter;
    property Deposits: TKMDeposits read fDeposits;
    property Selection: TKMSelection read fSelection;
    property Revealers[aIndex: Byte]: TKMPointTagList read GetRevealer;
    property VisibleLayers: TMapEdLayerSet read fVisibleLayers write fVisibleLayers;
    procedure DetectAttachedFiles(const aMissionFile: UnicodeString);
    procedure SaveAttachements(const aMissionFile: UnicodeString);
    function HitTest(X,Y: Integer): TKMMapEdMarker;
    function HumanCount: Integer;
    procedure MouseDown(Button: TMouseButton);
    procedure MouseMove;
    procedure MouseUp(Button: TMouseButton; aOverMap: Boolean);
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; X,Y: Integer);
    procedure Update;
    procedure UpdateStateIdle;
    procedure Paint(aLayer: TKMPaintLayer; aClipRect: TKMRect);
  end;


implementation
uses
  SysUtils, StrUtils, Math,
  KM_Terrain, KM_FileIO,
  KM_AIDefensePos, 
  KM_Units, KM_UnitGroups, KM_Houses, KM_HouseBarracks, KM_HouseTownHall, KM_HouseWoodcutters,
  KM_Game, KM_GameCursor, KM_ResMapElements, KM_ResHouses,
  KM_RenderAux, KM_Hand, KM_HandsCollection, KM_InterfaceMapEditor;


{ TKMMapEditor }
constructor TKMMapEditor.Create;
var
  I: Integer;
begin
  inherited Create;

  for I := 0 to MAX_HANDS - 1 do
  begin
    PlayerHuman[I] := true;
    PlayerAI[I] := true;
  end;

  fDeposits := TKMDeposits.Create;

  fTerrainPainter := TKMTerrainPainter.Create;
  fSelection := TKMSelection.Create(fTerrainPainter);

  fVisibleLayers := [mlObjects, mlHouses, mlUnits, mlDeposits];

  ResizeMapRect := KMRECT_ZERO;

  for I := Low(fRevealers) to High(fRevealers) do
    fRevealers[I] := TKMPointTagList.Create;
end;


destructor TKMMapEditor.Destroy;
var
  I: Integer;
begin
  FreeAndNil(fTerrainPainter);
  FreeAndNil(fDeposits);
  FreeAndNil(fSelection);

  for I := Low(fRevealers) to High(fRevealers) do
    fRevealers[I].Free;

  inherited;
end;


function TKMMapEditor.GetRevealer(aIndex: Byte): TKMPointTagList;
begin
  Result := fRevealers[aIndex];
end;


procedure TKMMapEditor.DetectAttachedFiles(const aMissionFile: UnicodeString);

  procedure AddAttachment(var aAttachCnt: Integer; const aFileName: UnicodeString);
  begin
    if aAttachCnt >= Length(fAttachedFiles) then
      SetLength(fAttachedFiles, aAttachCnt + 8);

    fAttachedFiles[aAttachCnt] := aFileName;
    Inc(aAttachCnt);
  end;

var
  SearchRec: TSearchRec;
  MissionScriptFileName, MissionName, RecExt: UnicodeString;
  HasScript: Boolean;
  AttachCnt: Integer;
begin
  HasScript := False;
  AttachCnt := 0;
  SetLength(fAttachedFiles, 8);
  MissionName := ChangeFileExt(ExtractFileName(aMissionFile), '');
  FindFirst(ChangeFileExt(aMissionFile, '.*'), faAnyFile - faDirectory, SearchRec);
  try
    repeat
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        //Can't use ExtractFileExt because we want .eng.libx not .libx
        RecExt := RightStr(SearchRec.Name, Length(SearchRec.Name) - Length(MissionName));
        if (LowerCase(RecExt) = '.map')
          or (LowerCase(RecExt) = '.dat')
          or (LowerCase(RecExt) = '.mi' ) then
          Continue;

        if LowerCase(RecExt) = '.script' then
          HasScript := True;

        AddAttachment(AttachCnt, ExtractFilePath(aMissionFile) + SearchRec.Name);
      end;
    until (FindNext(SearchRec) <> 0);
  finally
    FindClose(SearchRec);
  end;

  //Add all scripts if we find main script
  if HasScript then
  begin
    MissionScriptFileName := MissionName + '.script';
    FindFirst(ExtractFilePath(aMissionFile) + '*.script', faAnyFile - faDirectory, SearchRec);
    try
      repeat
        if (SearchRec.Name <> '.') and (SearchRec.Name <> '..')
          and (SearchRec.Name <> MissionScriptFileName) then
          AddAttachment(AttachCnt, ExtractFilePath(aMissionFile) + SearchRec.Name);
      until (FindNext(SearchRec) <> 0);
    finally
      FindClose(SearchRec);
    end;
  end;

  SetLength(fAttachedFiles, AttachCnt);
end;


procedure TKMMapEditor.SaveAttachements(const aMissionFile: UnicodeString);
var
  I: Integer;
  MissionPath, Dest: UnicodeString;
begin
  MissionPath := ExtractFilePath(aMissionFile);
  for I := 0 to High(fAttachedFiles) do
    if FileExists(fAttachedFiles[I]) then
    begin
      Dest := MissionPath + ExtractFileName(fAttachedFiles[I]);
      if not SameFileName(Dest, fAttachedFiles[I]) then
      begin
        if FileExists(Dest) then
          DeleteFile(Dest);
        KMCopyFile(fAttachedFiles[I], Dest);
      end;
    end;

  //Update attached files to be in the new path
  SetLength(fAttachedFiles, 0);
  DetectAttachedFiles(aMissionFile);
end;


function TKMMapEditor.HitTest(X, Y: Integer): TKMMapEdMarker;
var I,K: Integer;
begin
  if mlDefences in fVisibleLayers then
  begin
    for I := 0 to gHands.Count - 1 do
      for K := 0 to gHands[I].AI.General.DefencePositions.Count - 1 do
        if (gHands[I].AI.General.DefencePositions[K].Position.Loc.X = X)
        and (gHands[I].AI.General.DefencePositions[K].Position.Loc.Y = Y) then
        begin
          Result.MarkerType := mtDefence;
          Result.Owner := I;
          Result.Index := K;
          Exit;
        end;
  end;

  if mlRevealFOW in fVisibleLayers then
  begin
    for I := 0 to gHands.Count - 1 do
      for K := 0 to fRevealers[I].Count - 1 do
        if (fRevealers[I][K].X = X) and (fRevealers[I][K].Y = Y) then
        begin
          Result.MarkerType := mtRevealFOW;
          Result.Owner := I;
          Result.Index := K;
          Exit;
        end;
  end;

  //Else nothing is found
  Result.MarkerType := mtNone;
  Result.Owner := PLAYER_NONE;
  Result.Index := -1;
end;


//How many human players there are in the mission
function TKMMapEditor.HumanCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(PlayerHuman) do
  if PlayerHuman[I] then
    Inc(Result);
end;


//aStageIncrement - stage increment, can be negative
//aCheckPrevCell - do we check prev cell under the cursor to differ from current cell under the cursor
procedure TKMMapEditor.UpdateField(aStageIncrement: Integer; aCheckPrevCell: Boolean);
var
  P: TKMPoint;
  FieldStage: Integer;
begin
  if aStageIncrement = 0 then Exit;

  FieldStage := -1;
  P := gGameCursor.Cell;
  case gGameCursor.Mode of
    cmField:  begin
                if gTerrain.TileIsCornField(P) then
                begin
                  if not KMSamePoint(P, gGameCursor.PrevCell) or not aCheckPrevCell then
                    FieldStage := (gTerrain.GetCornStage(P) + aStageIncrement + CORN_STAGES_COUNT) mod CORN_STAGES_COUNT;
                end else if gMySpectator.Hand.CanAddFieldPlan(P, ft_Corn) then
                  FieldStage := 0;
                if FieldStage >= 0 then
                  gMySpectator.Hand.AddField(P, ft_Corn, FieldStage);
              end;
    cmWine:   begin
                if gTerrain.TileIsWineField(P) then
                begin
                  if not KMSamePoint(P, gGameCursor.PrevCell) or not aCheckPrevCell then
                    FieldStage := (gTerrain.GetWineStage(P) + aStageIncrement + WINE_STAGES_COUNT) mod WINE_STAGES_COUNT;
                end else if gMySpectator.Hand.CanAddFieldPlan(P, ft_Wine) then
                  FieldStage := 0;
                if FieldStage >= 0 then
                  gMySpectator.Hand.AddField(P, ft_Wine, FieldStage);
              end;
  end;
end;


//aEraseAll - if true all objects under the cursor will be deleted
procedure TKMMapEditor.EraseObject(aEraseAll: Boolean);
var Obj: TObject;
    P: TKMPoint;
begin
  P := gGameCursor.Cell;
  Obj := gMySpectator.HitTestCursor(True);

  //Delete unit/house
  if Obj is TKMUnit then
  begin
    gHands.RemAnyUnit(TKMUnit(Obj).GetPosition);
    if not aEraseAll then Exit;
  end
  else
  if Obj is TKMHouse then
  begin
    gHands.RemAnyHouse(P);
    if not aEraseAll then Exit;
  end;

  //Delete tile object (including corn/wine objects as well)
  if (gTerrain.Land[P.Y,P.X].Obj <> 255) then
  begin
    fTerrainPainter.MakeCheckpoint;
    if gTerrain.TileIsCornField(P) and (gTerrain.GetCornStage(P) in [4,5]) then
      gTerrain.SetField(P, gTerrain.Land[P.Y,P.X].TileOwner, ft_Corn, 3)  // For corn, when delete corn object reduce field stage to 3
    else if gTerrain.TileIsWineField(P) then
      gTerrain.RemField(P)
    else
      gTerrain.SetObject(P, 255);
    if not aEraseAll then Exit;
  end;

  //Delete tile overlay (road/corn/wine)
  if gTerrain.Land[P.Y,P.X].TileOverlay = to_Road then
    gTerrain.RemRoad(P);
  if gTerrain.TileIsCornField(P) or gTerrain.TileIsWineField(P) then
    gTerrain.RemField(P);
end;


procedure TKMMapEditor.ChangeOwner(aChangeOwnerForAll: Boolean);
var P: TKMPoint;
begin
  P := gGameCursor.Cell;
  //Fisrt try to change owner of object on tile
  if not ChangeObjectOwner(gMySpectator.HitTestCursorWGroup, gMySpectator.HandIndex) or aChangeOwnerForAll then
    //then try to change owner tile (road/field/wine)
    if ((gTerrain.Land[P.Y, P.X].TileOverlay = to_Road) or (gTerrain.Land[P.Y, P.X].CornOrWine <> 0))
      and (gTerrain.Land[P.Y, P.X].TileOwner <> gMySpectator.HandIndex) then
      gTerrain.Land[P.Y, P.X].TileOwner := gMySpectator.HandIndex;
end;


//Change owner for specified object
//returns True if owner was changed successfully
function TKMMapEditor.ChangeObjectOwner(aObject: TObject; aOwner: TKMHandIndex): Boolean;
var House: TKMHouse;
begin
  Result := False;
  if (aObject = nil) then Exit;

  if aObject is TKMHouse then
  begin
    House := TKMHouse(aObject);
    if House.Owner <> aOwner then
    begin
      House.OwnerUpdate(aOwner, True);
      gTerrain.SetHouseAreaOwner(House.GetPosition, House.HouseType, aOwner); // Update minimap colors
      Result := True;
    end;
  end
  else if aObject is TKMUnit then
  begin
    if (TKMUnit(aObject).Owner <> aOwner) and (TKMUnit(aObject).Owner <> PLAYER_ANIMAL) then
    begin
      TKMUnit(aObject).OwnerUpdate(aOwner, True);
      Result := True;
    end;
  end else if aObject is TKMUnitGroup then
    if TKMUnitGroup(aObject).Owner <> aOwner then
    begin
      TKMUnitGroup(aObject).OwnerUpdate(aOwner, True);
      Result := True;
    end
end;


procedure TKMMapEditor.MouseWheel(Shift: TShiftState; WheelDelta: Integer; X,Y: Integer);
begin
  UpdateField(Sign(WheelDelta), False);
end;


procedure TKMMapEditor.MouseDown(Button: TMouseButton);
var
  P: TKMPoint;
begin
  P := gGameCursor.Cell;
  if (Button = mbLeft) then
    case gGameCursor.Mode of
      cmSelection:  fSelection.Selection_Start;
      cmField,
      cmWine:       UpdateField(1, False);
  end;
end;


procedure TKMMapEditor.MouseMove;
var
  P: TKMPoint;
begin
  // Only allow placing of roads etc. with the left mouse button
  if not (ssLeft in gGameCursor.SState) then Exit;

  P := gGameCursor.Cell;
  case gGameCursor.Mode of
    cmRoad:       if gMySpectator.Hand.CanAddFieldPlan(P, ft_Road) then
                  begin
                    //If there's a field remove it first so we don't get road on top of the field tile (undesired in MapEd)
                    if gTerrain.TileIsCornField(P) or gTerrain.TileIsWineField(P) then
                      gTerrain.RemField(P);
                    gMySpectator.Hand.AddRoad(P);
                  end;
    cmField,
    cmWine:       UpdateField(1, True);
    cmUnits:      ProceedUnitsCursorMode;
    cmErase:      begin
                    gHands.RemAnyHouse(P);
                    if gTerrain.Land[P.Y,P.X].TileOverlay = to_Road then
                      gTerrain.RemRoad(P);
                    if gTerrain.TileIsCornField(P) or gTerrain.TileIsWineField(P) then
                      gTerrain.RemField(P);
                  end;
    cmSelection:  fSelection.Selection_Resize;
    cmPaintBucket:      ChangeOwner(ssShift in gGameCursor.SState);
    cmUniversalEraser:  EraseObject(ssShift in gGameCursor.SState);
  end;
end;


procedure TKMMapEditor.ProceedUnitsCursorMode;
var
  P: TKMPoint;
  Obj: TObject;
begin
  P := gGameCursor.Cell;

  if gGameCursor.Tag1 = 255 then
  begin
    Obj := gMySpectator.HitTestCursor(True);
    if Obj is TKMUnit then
      gHands.RemAnyUnit(TKMUnit(Obj).GetPosition);
  end else
  if gTerrain.CanPlaceUnit(P, TUnitType(gGameCursor.Tag1)) then
  begin
    //Check if we can really add a unit
    if TUnitType(gGameCursor.Tag1) in [CITIZEN_MIN..CITIZEN_MAX] then
      gMySpectator.Hand.AddUnit(TUnitType(gGameCursor.Tag1), P, False)
    else
    if TUnitType(gGameCursor.Tag1) in [WARRIOR_MIN..WARRIOR_MAX] then
      gMySpectator.Hand.AddUnitGroup(TUnitType(gGameCursor.Tag1), P, dir_S, 1, 1)
    else
      gHands.PlayerAnimals.AddUnit(TUnitType(gGameCursor.Tag1), P);
  end;
end;


procedure TKMMapEditor.MouseUp(Button: TMouseButton; aOverMap: Boolean);
var
  P: TKMPoint;
begin
  //If the mouse is released over controls, most actions don't happen
  if not aOverMap then
  begin
    //Still need to make a checkpoint since painting has now stopped
    if gGameCursor.Mode in [cmElevate, cmEqualize, cmBrush, cmObjects, cmTiles] then
      fTerrainPainter.MakeCheckpoint;
    Exit;
  end;

  P := gGameCursor.Cell; //Get cursor position tile-wise
  case Button of
    mbLeft:   case gGameCursor.Mode of
                cmRoad:       if gMySpectator.Hand.CanAddFieldPlan(P, ft_Road) then
                              begin
                                //If there's a field remove it first so we don't get road on top of the field tile (undesired in MapEd)
                                if gTerrain.TileIsCornField(P) or gTerrain.TileIsWineField(P) then
                                  gTerrain.RemField(P);
                                gMySpectator.Hand.AddRoad(P);
                              end;
                cmHouses:     if gMySpectator.Hand.CanAddHousePlan(P, THouseType(gGameCursor.Tag1)) then
                              begin
                                gMySpectator.Hand.AddHouse(THouseType(gGameCursor.Tag1), P.X, P.Y, true);
                                //Holding shift allows to place that house multiple times
                                if not (ssShift in gGameCursor.SState) then
                                begin
                                  gGameCursor.Tag1 := 0; //Reset tag
                                  gGameCursor.Mode := cmRoad;
                                end;
                              end;
                cmElevate, cmEqualize,
                cmBrush, cmObjects,
                cmTiles:      fTerrainPainter.MakeCheckpoint;
                cmMagicWater: fTerrainPainter.MagicWater(P);
                cmEyedropper: begin
                                fTerrainPainter.Eyedropper(P);
                                if (gGame.ActiveInterface is TKMapEdInterface) then
                                  TKMapEdInterface(gGame.ActiveInterface).GuiTerrain.GuiTiles.TilesTableScrollToTileTexId(gGameCursor.Tag1);
                                if not (ssShift in gGameCursor.SState) then  //Holding shift allows to choose another tile
                                  gGameCursor.Mode := cmTiles;
                              end;
                cmRotateTile: fTerrainPainter.RotateTile(P);
                cmUnits:      ProceedUnitsCursorMode;
                cmMarkers:    case gGameCursor.Tag1 of
                                MARKER_REVEAL:        fRevealers[gMySpectator.HandIndex].Add(P, gGameCursor.MapEdSize);
                                MARKER_DEFENCE:       gMySpectator.Hand.AI.General.DefencePositions.Add(KMPointDir(P, dir_N), gt_Melee, 10, adt_FrontLine);
                                MARKER_CENTERSCREEN:  begin
                                                        gMySpectator.Hand.CenterScreen := P;
                                                        //Updating XY display is done in InterfaceMapEd
                                                      end;
                                MARKER_AISTART:       gMySpectator.Hand.AI.Setup.StartPosition := P;
                                MARKER_RALLY_POINT:   if gMySpectator.Selected is TKMHouseWFlagPoint then
                                                        TKMHouseWFlagPoint(gMySpectator.Selected).FlagPoint := P;
                              end;
                cmErase:      begin
                                gHands.RemAnyHouse(P);
                                if gTerrain.Land[P.Y,P.X].TileOverlay = to_Road then
                                  gTerrain.RemRoad(P);
                                if gTerrain.TileIsCornField(P) or gTerrain.TileIsWineField(P) then
                                  gTerrain.RemField(P);
                              end;
                cmPaintBucket:      ChangeOwner(ssShift in gGameCursor.SState);
                cmUniversalEraser:  EraseObject(ssShift in gGameCursor.SState);
              end;
    mbRight:  case gGameCursor.Mode of
                cmElevate,
                cmEqualize:   begin
                                //Actual change was made in UpdateStateIdle, we just register it is done here
                                fTerrainPainter.MakeCheckpoint;
                              end;
                cmEyedropper,
                cmRotateTile: gGameCursor.Mode := cmNone;
              end;
  end;
end;


procedure TKMMapEditor.Update;
begin
  if mlDeposits in VisibleLayers then
    fDeposits.UpdateAreas([rdStone, rdCoal, rdIron, rdGold, rdFish]);

  //todo: if mlNavMesh in VisibleLayers then
    //gAIFields.NavMesh.Init;
end;


procedure TKMMapEditor.Paint(aLayer: TKMPaintLayer; aClipRect: TKMRect);
var
  I, K: Integer;
  Loc, P: TKMPoint;
  G: TKMUnitGroup;
  DP: TAIDefencePosition;
begin
  P := gGameCursor.Cell;

  if aLayer = plCursors then
    //With Buildings tab see if we can remove Fields or Houses
    if gGameCursor.Mode = cmErase then
      if gTerrain.TileIsCornField(P)
      or gTerrain.TileIsWineField(P)
      or (gTerrain.Land[P.Y,P.X].TileOverlay=to_Road)
      or (gHands.HousesHitTest(P.X, P.Y) <> nil) then
        gRenderPool.RenderWireTile(P, $FFFFFF00) //Cyan quad
      else
        gRenderPool.RenderSpriteOnTile(P, TC_BLOCK); //Red X


  if mlDefences in fVisibleLayers then
  begin
    case aLayer of
      plCursors:  for I := 0 to gHands.Count - 1 do
                  for K := 0 to gHands[I].AI.General.DefencePositions.Count - 1 do
                  begin
                    DP := gHands[I].AI.General.DefencePositions[K];
                    gRenderPool.RenderSpriteOnTile(DP.Position.Loc, 510 + Byte(DP.Position.Dir), gHands[I].FlagColor);
                  end;
      plTerrain:  if ActiveMarker.MarkerType = mtDefence then
                    //Render the radius only for the selected defence position, otherwise it's too much overlap
                    if InRange(ActiveMarker.Index, 0, gHands[ActiveMarker.Owner].AI.General.DefencePositions.Count - 1) then
                    begin
                      DP := gHands[ActiveMarker.Owner].AI.General.DefencePositions[ActiveMarker.Index];
                      gRenderAux.CircleOnTerrain(DP.Position.Loc.X-0.5, DP.Position.Loc.Y-0.5, DP.Radius,
                                                 gHands[ActiveMarker.Owner].FlagColor AND $40FFFF80,
                                                 gHands[ActiveMarker.Owner].FlagColor);
                    end;
    end;
  end;

  if mlRevealFOW in fVisibleLayers then
  for I := 0 to gHands.Count - 1 do
  for K := 0 to fRevealers[I].Count - 1 do
  begin
    Loc := fRevealers[I][K];
    case aLayer of
      plTerrain:  gRenderAux.CircleOnTerrain(Loc.X-0.5, Loc.Y-0.5,
                                           fRevealers[I].Tag[K],
                                           gHands[I].FlagColor and $20FFFFFF,
                                           gHands[I].FlagColor);
      plCursors:  gRenderPool.RenderSpriteOnTile(Loc,
                      394, gHands[I].FlagColor);
    end;
  end;

  if mlCenterScreen in fVisibleLayers then
  for I := 0 to gHands.Count - 1 do
  if gHands[I].HasAssets then
  begin
    Loc := gHands[I].CenterScreen;
    case aLayer of
      plTerrain:  gRenderAux.SquareOnTerrain(Loc.X - 3, Loc.Y - 2.5,
                                             Loc.X + 2, Loc.Y + 1.5,
                                             gHands[I].FlagColor);
      plCursors:  gRenderPool.RenderSpriteOnTile(Loc, 391, gHands[I].FlagColor);
    end;
  end;

  if mlAIStart in fVisibleLayers then
  for I := 0 to gHands.Count - 1 do
  if gHands[I].HasAssets then
  begin
    Loc := gHands[I].AI.Setup.StartPosition;
    case aLayer of
      plTerrain:  gRenderAux.SquareOnTerrain(Loc.X - 3, Loc.Y - 2.5,
                                             Loc.X + 2, Loc.Y + 1.5,
                                             gHands[I].FlagColor);
      plCursors:  gRenderPool.RenderSpriteOnTile(Loc, 390, gHands[I].FlagColor);
    end;
  end;

  if mlSelection in fVisibleLayers then
    fSelection.Paint(aLayer, aClipRect);

  if (mlMapResize in fVisibleLayers) and not KMSameRect(ResizeMapRect, KMRECT_ZERO) then
    gRenderAux.RenderResizeMap(ResizeMapRect);

  if mlWaterFlow in fVisibleLayers then
  begin
    for I := aClipRect.Top to aClipRect.Bottom do
    for K := aClipRect.Left to aClipRect.Right do
    if gTerrain.TileIsWater(K,I) then
    begin
      //TODO: Waterflow indication here
      //gRenderPool.RenderSpriteOnTile(KMPoint(K,I), )
    end;
  end;


  //Show selected group order target
  if gMySpectator.Selected is TKMUnitGroup then
  begin
    G := TKMUnitGroup(gMySpectator.Selected);
    if G.MapEdOrder.Order <> ioNoOrder then
    begin
      gRenderAux.Quad(G.MapEdOrder.Pos.Loc.X, G.MapEdOrder.Pos.Loc.Y, $40FF00FF);
      gRenderAux.LineOnTerrain(G.Position.X - 0.5, G.Position.Y - 0.5, G.MapEdOrder.Pos.Loc.X - 0.5, G.MapEdOrder.Pos.Loc.Y - 0.5, $FF0000FF);
    end;
  end;
end;


procedure TKMMapEditor.UpdateStateIdle;
begin
  if fTerrainPainter <> nil then
    fTerrainPainter.UpdateStateIdle;
end;


end.
