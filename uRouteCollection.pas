unit uRouteCollection;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults, TypInfo, Rtti;

type

  TVisitedPoint = TObjectDictionary<string, byte>;

  TDictionaryHelpers<TKey, TValue> = class
  public
    class procedure CopyDictionary(ASource, ATarget: TDictionary<TKey, TValue>);
  end;

  TDataPool = class(TDictionary<string, TValue>)
  public
    procedure Structure(const Names: Array of string; Values: array of TValue);
  end;

  TPoolList = class(TList<TDataPool>)
  end;

  TOrderPointOperation = class(TDictionary<string, string>)
  public
    procedure Structure(const Names: Array of string; Values: array of string);
  end;

  TMRez = class(TDictionary<string, TValue>)
  public
    procedure Structure(const Names: Array of string; Values: array of TValue);
  end;

  TNewPoolList = class(TList<TOrderPointOperation>)
  end;

  TPrevPoolList = class(TList<TOrderPointOperation>)
  end;

  // Класс ТС
  TVehicle = class
  public
    FReference: string;
    FCapacity: single;
    FVolume: real;
    FPriority: single;
    constructor Create(Reference: string; Capacity, Volume, Priority: single);
  end;

  TVehicleList = TObjectList<TVehicle>;

  // Класс таблицы оценок
  TTabOcenok = class
  public
    FValue: TMRez;
    FMark: single;
    FPriority: smallint;
    FFieldMore: smallint;
    constructor Create(Value: TMRez; Mark: single; Priority: smallint; FieldMore: smallint);
    destructor Destroy; override;
  end;

  TTabOcenokList = TObjectList<TTabOcenok>;

  TOrder = class
  public
    FReference: string;
    FDeparturePoint: string;
    FDestinationPoint: string;
    FDepartureAddress: string;
    FDestinationAddress: string;
    FStayReceivedDeparturePoint: boolean;
    FStayReceivedDestinationPoint: boolean;
    FStayDeparturePoint: single;
    FStayDestinationPoint: single;
    FPriority: smallint;
    FWeight: single;
    FVolume: single;
    constructor Create(Reference, departurePoint, destinationPoint, departureAddress,
      destinationAddress: string; stayReceivedDeparturePoint, stayReceivedDestinationPoint: boolean;
      stayDeparturePoint, stayDestinationPoint: single; Priority: smallint; weight, Volume: single);
  end;

  TOrderList = TObjectDictionary<string, TOrder>;

  // Класс таблицы расстояния и времени между пунктами
  TDistance = class
  public
    FLength: single;
    FTime: single;
    FP1: string;
    FP2: string;
    constructor Create(length, time: single; p1, p2: string);
  end;

  TDistanceList = TObjectDictionary<string, TDistance>;

  TSpeed = class
  public
    FBeginPeriod: single;
    FEndPeriod: single;
    FAvgSpeed: single;
    constructor Create(beginPeriod, endPeriod, avgSpeed: single);
  end;

  TSpeedList = TObjectList<TSpeed>;

  TVectorRoute = class
  public
    FReference: string;
    FOrderName: string;
    FLoadPrice: single;
    FUnloadPrice: single;
    FPriority: integer;
    constructor Create(Reference: string; LoadPrice, UnloadPrice: single; Priority: integer);
  end;

  TVectorRouteList = TObjectList<TVectorRoute>;

  TValueHelper = record helper for TValue
    function asPoolList: TPoolList;
    function asMRez: TMRez;
    function asNewPoolList: TNewPoolList;
    function asPrevPoolList: TPrevPoolList;
    function asOPO: TOrderPointOperation;
    function asDataPool: TDataPool;
    function asTabOcenokList: TTabOcenokList;
    function asVehicle: TVehicle;
  end;

implementation

class procedure TDictionaryHelpers<TKey, TValue>.CopyDictionary(ASource, ATarget: TDictionary<TKey, TValue>);
var
  LKey: TKey;
begin
  for LKey in ASource.Keys do
    ATarget.Add(LKey, ASource.Items[LKey]);
end;

function TValueHelper.asPoolList: TPoolList;
begin
  Result := asObject as TPoolList;
end;

function TValueHelper.asMRez: TMRez;
begin
  Result := asObject as TMRez;
end;

function TValueHelper.asPrevPoolList: TPrevPoolList;
begin
  Result := asObject as TPrevPoolList;
end;

function TValueHelper.asNewPoolList: TNewPoolList;
begin
  Result := asObject as TNewPoolList;
end;

function TValueHelper.asOPO: TOrderPointOperation;
begin
  Result := asObject as TOrderPointOperation;
end;

function TValueHelper.asDataPool: TDataPool;
begin
  Result := asObject as TDataPool;
end;

function TValueHelper.asTabOcenokList: TTabOcenokList;
begin
  Result := asObject as TTabOcenokList;
end;

function TValueHelper.asVehicle: TVehicle;
begin
  Result := asObject as TVehicle;
end;

procedure TDataPool.Structure(const Names: Array of string; Values: array of TValue);
var
  i: integer;
begin
  if length(Names) <> length(Values) then
    raise Exception.Create('Неодинаковое количество элементов');

  for i := Low(Names) to High(Names) do
  begin
    Add(Names[i], Values[i]);
  end;
end;

procedure TOrderPointOperation.Structure(const Names: Array of string; Values: array of string);
var
  i: integer;
begin
  if length(Names) <> length(Values) then
    raise Exception.Create('Неодинаковое количество элементов');

  for i := Low(Names) to High(Names) do
  begin
    Add(Names[i], Values[i]);
  end;
end;

procedure TMRez.Structure(const Names: Array of string; Values: array of TValue);
var
  i: integer;
begin
  if length(Names) <> length(Values) then
    raise Exception.Create('Неодинаковое количество элементов');

  for i := Low(Names) to High(Names) do
  begin
    Add(Names[i], Values[i]);
  end;
end;

constructor TVectorRoute.Create(Reference: string; LoadPrice, UnloadPrice: single; Priority: integer);
begin
  self.FReference := Reference;
  self.FLoadPrice := LoadPrice;
  self.FUnloadPrice := UnloadPrice;
  self.FPriority := Priority;
end;

constructor TOrder.Create(Reference, departurePoint, destinationPoint, departureAddress,
  destinationAddress: string; stayReceivedDeparturePoint, stayReceivedDestinationPoint: boolean;
  stayDeparturePoint, stayDestinationPoint: single; Priority: smallint; weight, Volume: single);
begin
  self.FReference := Reference;
  self.FDeparturePoint := departurePoint;
  self.FDestinationPoint := destinationPoint;
  self.FDepartureAddress := departureAddress;
  self.FDestinationAddress := destinationAddress;
  self.FStayReceivedDeparturePoint := stayReceivedDeparturePoint;
  self.FStayReceivedDestinationPoint := stayReceivedDestinationPoint;
  self.FStayDeparturePoint := stayDeparturePoint;
  self.FStayDestinationPoint := stayDestinationPoint;
  self.FPriority := Priority;
  self.FWeight := weight;
  self.FVolume := Volume;
end;

constructor TTabOcenok.Create(Value: TMRez; Mark: single; Priority, FieldMore: smallint);
begin
  self.FValue := Value;
  self.FMark := Mark;
  self.FPriority := Priority;
  self.FFieldMore := FieldMore;
end;

constructor TDistance.Create(length, time: single; p1, p2: string);
begin
  self.FLength := length;
  self.FTime := time;
  self.FP1 := p1;
  self.FP2 := p2;
end;

constructor TSpeed.Create(beginPeriod, endPeriod, avgSpeed: single);
begin
  self.FBeginPeriod := beginPeriod;
  self.FEndPeriod := endPeriod;
  self.FAvgSpeed := avgSpeed;
end;

destructor TTabOcenok.Destroy;
begin
  FreeAndNil(self.FValue);
end;

constructor TVehicle.Create(Reference: string; Capacity, Volume, Priority: single);
begin
  self.FReference := Reference;
  self.FCapacity := Capacity;
  self.FVolume := Volume;
  self.FPriority := Priority;
end;

end.
