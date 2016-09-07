unit RouteComponent;

{
  ***********************************
  Описание кодов ошибок БД

  0 Все ОК
  1 Ошибка подключения к БД
  2 Ошибка выполнения запроса
  3 Соединение с БД не активно
  4 Ошибка закрытия соединения
  5 Ошибка удаления БД
  6 Ошибка старта транзакции
  7 Ошибка выполнения транзакции
  8 Ошибка отмены транзакции
  ***********************************
}

/// /

interface

uses Winapi.Windows, Classes, SysUtils, Variants, addinlib2000,
  DateUtils, uRoute;

const
  DBFileName = 'RouteOrders.db';

type
  TRouteOrders = class(TNativeComponent)
  private
    FConnected: boolean;
  public
    FRoute: TRoute;
    property Connected: boolean read FConnected write FConnected;
    constructor Create; override;
    destructor Destroy; override;
    class function NCClassName: WideString; override;
    function GetVersion(var Params: VarArrayData): Variant;
    function GetRouteCount(var Params: VarArrayData): Variant;
    function GetRoute(var Params: VarArrayData): Variant;
    function InitializeDatabase(var Params: VarArrayData): Variant;
    function CloseConnection(var Params: VarArrayData): Variant;
    function DeleteDatabase(var Params: VarArrayData): Variant;
    function CalculateRouteOrders(var Params: VarArrayData): Variant;
    function DeletePoints(var Params: VarArrayData): Variant;
    function DeleteOrders(var Params: VarArrayData): Variant;
    function DeleteVehicles(var Params: VarArrayData): Variant;
    function DeleteAvgSpeed(var Params: VarArrayData): Variant;
    function DeleteRoute(var Params: VarArrayData): Variant;
    function AddPoint(var Params: VarArrayData): Variant;
    function AddOrder(var Params: VarArrayData): Variant;
    function AddVehicle(var Params: VarArrayData): Variant;
    function AddAvgSpeed(var Params: VarArrayData): Variant;
    function DeleteFromTable(Table: string): integer;
    function InsertIntoTable(Table: string; arrColums: Array of string; var Params: VarArrayData): integer;
    function StartTransaction(var Params: VarArrayData): Variant;
    function CommitTransaction(var Params: VarArrayData): Variant;
    function RollbackTransaction(var Params: VarArrayData): Variant;
  end;

implementation

constructor TRouteOrders.Create;
begin
  inherited;
  mt_Add('Инициализация', 'InitRouteOrders', 1, InitializeDatabase);
  mt_Add('ЗакрытьСоединение', 'CloseConnection', 0, CloseConnection);
  mt_Add('УдалитьБД', 'DeleteDB', 1, DeleteDatabase);
  mt_Add('СтартоватьТранзакцию', 'StartTransaction', 0, StartTransaction);
  mt_Add('ПодтвердитьТранзакцию', 'CommitTransaction', 0, CommitTransaction);
  mt_Add('ОткатитьТранзакцию', 'RollbackTransaction', 0, RollbackTransaction);
  mt_Add('ПолучитьВерсиюКомпоненты', 'GetVersionComponent', 1, GetVersion);
  mt_Add('ПолучитьКоличествоСтрокМаршрутов', 'GetRouteCount', 1, GetRouteCount);
  mt_Add('ПолучитьМаршрут', 'GetRoute', 4, GetRoute);
  mt_Add('РассчитатьМаршруты', 'CalculateRouteOrders', 4, CalculateRouteOrders);
  mt_Add('ОчиститьПункты', 'DeletePoints', 0, DeletePoints);
  mt_Add('ОчиститьЗаказы', 'DeleteOrders', 0, DeleteOrders);
  mt_Add('ОчиститьТранспорт', 'DeleteVehicles', 0, DeleteVehicles);
  mt_Add('ОчиститьСреднююСкорость', 'DeleteAvgSpeed', 0, DeleteAvgSpeed);
  mt_Add('ОчиститьМаршрут', 'DeleteRoute', 0, DeleteRoute);
  mt_Add('ДобавитьПункт', 'AddPoint', 4, AddPoint);
  mt_Add('ДобавитьЗаказ', 'AddOrder', 12, AddOrder);
  mt_Add('ДобавитьТранспорт', 'AddVehicle', 4, AddVehicle);
  mt_Add('ДобавитьСреднююСкорость', 'AddAvgSpeed', 3, AddAvgSpeed);
end;

destructor TRouteOrders.Destroy;
begin
  inherited;
  if FRoute <> nil then
    FreeAndNil(FRoute);
end;

function TRouteOrders.InsertIntoTable(Table: string; arrColums: Array of string; var Params: VarArrayData): integer;
begin
  if not FConnected then
  begin
    result := 3;
    exit;
  end;

  try
    FRoute.InsertIntoTable(Table, arrColums, Params);
    result := 0;
  except
    result := 2;
  end;
end;

function TRouteOrders.DeleteFromTable(Table: string): integer;
begin
  if not FConnected then
  begin
    result := 3;
    exit;
  end;
  try
    FRoute.DeleteFromTable(Table);
    result := 0;
  except
    result := 2;
  end;
end;

function TRouteOrders.DeleteAvgSpeed(var Params: VarArrayData): Variant;
begin
  result := DeleteFromTable('AvgSpeed');
end;

function TRouteOrders.DeleteOrders(var Params: VarArrayData): Variant;
begin
  result := DeleteFromTable('Orders');
end;

function TRouteOrders.DeletePoints(var Params: VarArrayData): Variant;
begin
  result := DeleteFromTable('timeDistancePoints');
end;

function TRouteOrders.DeleteRoute(var Params: VarArrayData): Variant;
begin
  result := DeleteFromTable('RouteOrders');
end;

function TRouteOrders.DeleteVehicles(var Params: VarArrayData): Variant;
begin
  result := DeleteFromTable('Vehicles');
end;

function TRouteOrders.AddAvgSpeed(var Params: VarArrayData): Variant;
begin
  try
    FRoute.AddAvgSpeed(Params);
    result := 0;
  except
    result := 2;
  end;
end;

function TRouteOrders.AddOrder(var Params: VarArrayData): Variant;
begin
  try
    FRoute.AddOrder(Params);
    result := 0;
  except
    result := 2;
  end;
end;

function TRouteOrders.AddPoint(var Params: VarArrayData): Variant;
begin
  try
    FRoute.AddPoint(Params);
    result := 0;
  except
    result := 2;
  end;
end;

function TRouteOrders.AddVehicle(var Params: VarArrayData): Variant;
begin
  try
    FRoute.AddVehicle(Params);
    result := 0;
  except
    result := 2;
  end;
end;

function TRouteOrders.GetVersion(var Params: VarArrayData): Variant;
begin
  Params[0] := GetFileVersion;
  result := 0;
end;

function TRouteOrders.CalculateRouteOrders(var Params: VarArrayData): Variant;
begin
  FRoute.CalculateRoute(Params[0], Params[1], Params[2], Params[3]);
  result := 0;
end;

function TRouteOrders.CloseConnection(var Params: VarArrayData): Variant;
begin
  result := 0;
  if FRoute <> nil then
  begin
    try
      FConnected := FRoute.CloseConnection;
      result := 0;
    except
      result := 4;
    end;
  end;
end;

function TRouteOrders.InitializeDatabase(var Params: VarArrayData): Variant;
var
  Database: string;

  procedure CopyDBFromTemplate;
  var
    Resource: TResourceStream;
  begin
    Resource := TResourceStream.Create(HInstance, 'database', RT_RCDATA);
    try
      Resource.SaveToFile(Database);
    finally
      FreeAndNil(Resource);
    end;
  end;

  function ConnectDB: integer;
  begin
    if FRoute.OpenDB(Database) then
    begin
      FRoute.Database := Database;
      case FRoute.IntegrityCheck of
        0: // Контроль целостности пройден
          begin
            FConnected := true;
            result := 0;
          end;
        1: // бд вероятно испорчена
          begin
            result := 1;
          end;
        2: // проверить не удалось
          begin
            result := 0;
          end;
      end;
    end
    else
      result := 1;
  end;

begin
  FRoute := TRoute.Create;
  Database := ExcludeTrailingPathDelimiter(Params[0]) + '\' + DBFileName;

  if FileExists(Database) then
  begin
    result := ConnectDB;
    if result <> 0 then
    begin
      CopyDBFromTemplate;
      result := ConnectDB;
    end;
  end
  else
  begin
    CopyDBFromTemplate;
    result := ConnectDB;
  end;

  if result = 0 then
    FRoute.InitializeQueries;
end;

function TRouteOrders.GetRoute(var Params: VarArrayData): Variant;
var
  order_guid, vehicle_guid: string;
  operation: boolean;
begin
  FRoute.GetRoute(Params[0], order_guid, vehicle_guid, operation);
  Params[1] := order_guid;
  Params[2] := vehicle_guid;
  Params[3] := operation;

  result := 0;
end;

function TRouteOrders.GetRouteCount(var Params: VarArrayData): Variant;
begin
  if not FConnected then
  begin
    result := 3;
    exit;
  end;

  try
    Params[0] := FRoute.GetRouteCount;
    result := 0;
  except
    result := 1;
  end;
end;

function TRouteOrders.DeleteDatabase(var Params: VarArrayData): Variant;
var
  Filename: string;
begin
  Filename := ExcludeTrailingPathDelimiter(Params[0]) + '\' + DBFileName;
  try
    if FileExists(Filename) then
      DeleteFile(Filename);
    result := 0;
  except
    result := 5;
  end;
end;

class function TRouteOrders.NCClassName: WideString;
begin
  result := 'RouteOrders';
end;

function TRouteOrders.RollbackTransaction(var Params: VarArrayData): Variant;
begin
  try
    FRoute.RollbackTransaction;
    result := 0;
  except
    result := 8;
  end;
end;

function TRouteOrders.StartTransaction(var Params: VarArrayData): Variant;
begin
  try
    FRoute.StartTransaction;
    result := 0;
  except
    result := 6;
  end;
end;

function TRouteOrders.CommitTransaction(var Params: VarArrayData): Variant;
begin
  try
    FRoute.CommitTransaction;
    result := 0;
  except
    result := 7;
  end;
end;

initialization

RegisterNativeComponentClass(TRouteOrders);

finalization

end.
