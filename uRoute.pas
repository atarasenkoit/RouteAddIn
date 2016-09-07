unit uRoute;
{$OPTIMIZATION OFF}
interface
//
uses Classes, Variants, Winapi.Windows, Math, DateUtils, FireDAC.VCLUI.Wait,
  FireDAC.Stan.Def, FireDAC.Stan.Async, FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef, FireDAC.Stan.Option,
  FireDAC.Dapt, FireDAC.Comp.Client, IniFiles, SysUtils, FireDAC.FMXUI.Wait, FireDAC.Stan.Pool,
  System.Generics.Collections, System.Generics.Defaults, {TypInfo, Rtti}
  System.Diagnostics, System.TimeSpan, uRouteCollection;

const
  cOrder = 'заказ';
  cPoint = 'пункт';
  cOperation = 'операция';
  cPool = 'Пул';
  cNewPool = 'НовПул';
  cNewMark = 'НовОценка';
  cRoute = 'маршрут';
  cLoad = 'погрузка';
  cUnload = 'разгрузка';
  cMark = 'оценка';
  cVehicle = 'ТС';
  cCapacity = 'ГрузоподъемностьТС';
  cMaxWeight = 'МаксимальныйВес';
  cMaxVolume = 'МаксимальныйОбъем';
  cVolumeVehicle = 'ОбъемКузоваТС';
  cPriority = 'ПорядокТС';
  cOrderNumber = 'заказномер';

type

  TRoute = class
  public
    fdDriverLink: TFDPhysSQLiteDriverLink;
    fdConnection: TFDConnection;
    fdVectorRoute: TFDQuery;
    fdOrders: TFDQuery;
    fdVehicles: TFDQuery;
    fdDistance: TFDQuery;
    fdSpeed: TFDQuery;
    fdRouteOrders: TFDQuery;
    fdRouteOrdersScript: TFDQuery;
    fdValidate: TFDSQLiteValidate;
    fdVehiclesModify: TFDQuery;
    fdOrdersModify: TFDQuery;
    fdDistancesModify: TFDQuery;
    fdSpeedModify: TFDQuery;

    ConnectionString: string;
    OSAuthent, Server, Database, Username, Password: string;
    TabOcenokList: TTabOcenokList;
    VehicleList: TVehicleList;
    DistanceList: TDistanceList;
    SpeedList: TSpeedList;
    VectorRouteList: TVectorRouteList;
    RecordPriority: integer;
    OrderList: TOrderList;
    CurOrder: TOrder;
    CurDistance: TDistance;
    Optimization: integer;
    Depo: string;
    destructor Destroy; override;
    function GetConnectionString(DatabasePath: string): string;
    function OpenDB(DatabasePath: string): boolean;
    function GetDistance(ref: String): TDistance; inline;
    procedure FillListsFromDB;
    procedure FillVectorRouteList;
    procedure FillDistanceList;
    procedure FillVehicleList;
    procedure FillSpeedList;
    procedure FillOrderList;
    procedure CalculateRoute(Depo: string; Optimization: integer; TimeLimit: variant; DepartureTime: single);
    function AddTimeHHMM(Time1, Time2: single): single;
    function AddTime1CHHMM(Time1C, TimeHHMM: single): single;
    procedure ClearMemory;
    procedure CopyPool;
    procedure PoolFromCopy;
    procedure ClearRouteOrders;
    function CloseConnection: boolean;
    function GetRouteCount: integer;
    procedure DeleteFromTable(tablename: string);
    procedure InsertIntoTable(tablename: string; arrColumns: Array of string; Params: Array of variant);
    procedure AddAvgSpeed(var vParams: array of variant);
    procedure AddVehicle(var vParams: array of variant);
    procedure AddPoint(vParams: array of variant);
    procedure AddOrder(var vParams: array of variant);
    procedure StartTransaction;
    procedure CommitTransaction;
    procedure RollbackTransaction;
    function IntegrityCheck: integer;
    procedure InitializeQueries;
    procedure GetRoute(index: integer; var order_guid, vehicle_guid: string; var operation: boolean);
  end;

implementation

var
  TabOcenok: TTabOcenok;
  DataPool, CopyDataPool: TDataPool;
  PoolList, CopyPoolList: TPoolList;
  MRez: TMRez;
  DataElement, OrderPointOperation, tmpOPO, CopyOrderPointOperation: TOrderPointOperation;
  CurRoute, NewPoolList, CopyNewPoolList: TNewPoolList;
  PrevPoolList: TPrevPoolList;

  SQLResource: TResourceStream;
  OPOContainer, NewPoolContainer, PrevPoolContainer, DataPoolContainer: TList;

function TRoute.AddTime1CHHMM(Time1C, TimeHHMM: single): single;
begin
  Result := Time1C + Trunc(TimeHHMM) * 60 * 60 + (TimeHHMM - Trunc(TimeHHMM)) * 100 * 60;
end;

function TRoute.AddTimeHHMM(Time1, Time2: single): single;
var
  Time1Hour, Time1Min, Time2Hour, Time2Min, TimeMin, TimeHour: single;
begin
  Time1Hour := Trunc(Time1);
  Time1Min := (Time1 - Time1Hour) * 100; // Frac(Time1)*100
  Time1Min := Time1Hour * 60 + Time1Min;

  Time2Hour := Trunc(Time2);
  Time2Min := (Time2 - Time2Hour) * 100; // Frac(Time2)*100
  Time2Min := Time2Hour * 60 + Time2Min;

  TimeMin := Time1Min + Time2Min;
  TimeHour := Trunc(TimeMin / 60);
  TimeMin := (TimeMin - TimeHour * 60) / 100;

  Result := TimeHour + TimeMin;
end;

procedure TRoute.ClearMemory;
var
  i: integer;
  OPOObj: TOrderPointOperation;
  NewPoolListObj: TNewPoolList;
  PrevPoolListObj: TPrevPoolList;
  DataPoolObj: TDataPool;
begin
  for i := 0 to OPOContainer.Count - 1 do
  begin
    OPOObj := OPOContainer[i];
    if OPOObj <> nil then
    begin
      FreeAndNil(OPOObj);
    end;
  end;
  OPOContainer.Clear;

  for i := 0 to NewPoolContainer.Count - 1 do
  begin
    NewPoolListObj := NewPoolContainer[i];
    if NewPoolListObj <> nil then
    begin
      FreeAndNil(NewPoolListObj);
    end;
  end;
  NewPoolContainer.Clear;

  for i := 0 to PrevPoolContainer.Count - 1 do
  begin
    PrevPoolListObj := PrevPoolContainer[i];
    if PrevPoolListObj <> nil then
    begin
      FreeAndNil(PrevPoolListObj);
    end;
  end;
  PrevPoolContainer.Clear;

  for i := 0 to DataPoolContainer.Count - 1 do
  begin
    DataPoolObj := DataPoolContainer[i];
    if DataPoolObj <> nil then
    begin
      FreeAndNil(DataPoolObj);
    end;
  end;
  DataPoolContainer.Clear;
end;

procedure TRoute.ClearRouteOrders;
begin
  fdRouteOrdersScript := TFDQuery.Create(nil);
  try
    with fdRouteOrdersScript do
    begin
      Close;
      Connection := fdConnection;
      SQL.Add('delete from RouteOrders;');
      ExecSQL;
    end;
  finally
    fdRouteOrdersScript := TFDQuery.Create(nil);
  end;
end;

function TRoute.CloseConnection: boolean;
begin
  fdConnection.Close;
  Result := fdConnection.Connected;
end;

procedure TRoute.CopyPool;
var
  i, j: integer;
begin
  // Скопировать PoolList в CopyPoolList
  CopyPoolList := TPoolList.Create;
  for i := 0 to PoolList.Count - 1 do
  begin
    CopyDataPool := TDataPool.Create();

    CopyNewPoolList := TNewPoolList.Create;
    for j := 0 to PoolList[i].Items[cRoute].asNewPoolList.Count - 1 do
    begin
      OrderPointOperation := TOrderPointOperation.Create();
      TDictionaryHelpers<string, string>.CopyDictionary(PoolList[i].Items[cRoute].asNewPoolList[j],
        OrderPointOperation);
      CopyNewPoolList.Add(OrderPointOperation);
    end;

    CopyDataPool.Structure([cVehicle, cCapacity, cVolumeVehicle, cPriority, cMark, cRoute, cMaxWeight, cMaxVolume],
      [PoolList[i].Items[cVehicle], PoolList[i].Items[cCapacity], PoolList[i].Items[cVolumeVehicle],
      PoolList[i].Items[cPriority], PoolList[i].Items[cMark], CopyNewPoolList, PoolList[i].Items[cMaxWeight],
      PoolList[i].Items[cMaxVolume]]);

    CopyPoolList.Add(CopyDataPool);
  end;

  // Удалить PoolList
  PoolList.Clear;
  FreeAndNil(PoolList);
end;

procedure TRoute.DeleteFromTable(tablename: string);
var
  fdQuery: TFDQuery;
begin
  fdQuery := TFDQuery.Create(nil);
  try
    with fdQuery do
    begin
      Connection := fdConnection;
      SQL.Text := 'delete from ' + tablename;
      ExecSQL;
      fdConnection.Close;
    end;
  finally
    FreeAndNil(fdQuery);
  end;
end;

destructor TRoute.Destroy;
begin
  inherited;
  if fdConnection <> nil then
  begin
    if fdConnection.Connected then
    begin
      fdConnection.Close;
    end;
    FreeAndNil(fdConnection);
  end;
end;

procedure TRoute.PoolFromCopy;
var
  i, j: integer;
begin
  // Скоприровать CopyPoolList в PoolList
  PoolList := TPoolList.Create;
  for i := 0 to CopyPoolList.Count - 1 do
  begin
    DataPool := TDataPool.Create();
    DataPoolContainer.Add(DataPool);

    NewPoolList := TNewPoolList.Create;
    NewPoolContainer.Add(NewPoolList);
    for j := 0 to CopyPoolList[i].Items[cRoute].asNewPoolList.Count - 1 do
    begin
      OrderPointOperation := TOrderPointOperation.Create();
      OPOContainer.Add(OrderPointOperation);
      TDictionaryHelpers<string, string>.CopyDictionary(CopyPoolList[i].Items[cRoute].asNewPoolList[j],
        OrderPointOperation);
      NewPoolList.Add(OrderPointOperation);
    end;

    DataPool.Structure([cVehicle, cCapacity, cVolumeVehicle, cPriority, cMark, cRoute, cMaxWeight, cMaxVolume],
      [CopyPoolList[i].Items[cVehicle], CopyPoolList[i].Items[cCapacity], CopyPoolList[i].Items[cVolumeVehicle],
      CopyPoolList[i].Items[cPriority], CopyPoolList[i].Items[cMark], NewPoolList, CopyPoolList[i].Items[cMaxWeight],
      CopyPoolList[i].Items[cMaxVolume]]);

    PoolList.Add(DataPool);
  end;

  // Удалить CopyPoolList
  for i := 0 to CopyPoolList.Count - 1 do
  begin
    CopyDataPool := CopyPoolList[i];
    if CopyDataPool <> nil then
    begin
      for j := 0 to CopyDataPool.Items[cRoute].asNewPoolList.Count - 1 do
      begin
        OrderPointOperation := CopyPoolList[i].Items[cRoute].asNewPoolList[j];
        if OrderPointOperation <> nil then
        begin
          if OrderPointOperation.Count <> 0 then
          begin
            OrderPointOperation.Clear;
            FreeAndNil(OrderPointOperation);
          end;
        end;
      end;
      CopyDataPool.Clear;
      FreeAndNil(CopyDataPool);
    end;
  end;
  CopyPoolList.Clear;
  FreeAndNil(CopyPoolList);
end;

function TRoute.GetConnectionString(DatabasePath: string): string;
var
  SBParams: TStringBuilder;
begin
  Database := DatabasePath;
  try
    SBParams := TStringBuilder.Create;
    with SBParams do
    begin
      AppendLine('DriverID=SQlite');
      AppendLine('Database=' + Database);
      AppendLine('journalMode=WAL');
      AppendLine('lockingMode=normal');
      AppendLine('Synchronous=Full');
      AppendLine('SharedCache=False');
    end;
    Result := SBParams.ToString;
  finally
    FreeAndNil(SBParams);
  end;
end;

function TRoute.OpenDB(DatabasePath: string): boolean;
begin
  fdConnection := TFDConnection.Create(nil);
  try
    with fdConnection do
    begin
      Close;
      UpdateOptions.LockWait := true;
//      TxOptions.Isolation := xiSnapshot;
      with Params do
      begin
        Clear;
        Text := GetConnectionString(DatabasePath);
      end;
      Open;
      Result := Connected;
    end;
  except
    Result := false;
  end;
end;

procedure TRoute.FillVectorRouteList;
begin
  fdVectorRoute := TFDQuery.Create(nil);
  try
    with fdVectorRoute do
    begin
      Connection := fdConnection;
      Close;
      SQL.Text := 'select reference, LoadPrice, UnloadPrice, priority ' + 'from ' + '(select o.reference, ' +
        '  case :depo when o.departurePoint then 0 else ' +
        '       case :OptimizationMode when 0 then tdp1.time else tdp1.length end ' + '  end as LoadPrice, ' +
        '  case :depo when o.destinationPoint then 0 else ' +
        '       case :OptimizationMode when 0 then tdp2.time else tdp2.length end ' + '  end as UnloadPrice, ' +
        '       o.priority ' + 'from orders o ' +
        'left join timeDistancePoints tdp1 on (tdp1.firstPoint = :depo) and (tdp1.lastPoint = o.departurePoint) ' +
        'left join timeDistancePoints tdp2 on (tdp2.firstPoint = :depo) and (tdp2.lastPoint = o.destinationPoint)) ' +
        'order by 2,3,4 desc';
      ParamByName('OptimizationMode').AsInteger := Optimization;
      ParamByName('Depo').AsString := Depo;
      Open;
      while not eof do
      begin
        VectorRouteList.Add(TVectorRoute.Create(FieldByName('reference').AsString, FieldByName('LoadPrice').AsFloat,
          FieldByName('UnloadPrice').AsFloat, FieldByName('priority').AsInteger));
        Next;
      end;
    end;
  finally
    FreeAndNil(fdVectorRoute);
  end;
end;

procedure TRoute.FillSpeedList;
begin
  fdSpeed := TFDQuery.Create(nil);
  try
    with fdSpeed do
    begin
      Connection := fdConnection;
      Close;
      SQL.Text := 'SELECT avgSpeed, (strftime(''%H'', beginperiod)+ strftime(''%M'', beginperiod)/100) as beginperiod,'
        + '(strftime(''%H'', endperiod)+ strftime(''%M'', endperiod)/100) as endperiod ' + 'from avgSpeed';
      Open;
      while not eof do
      begin
        SpeedList.Add(TSpeed.Create(FieldByName('beginPeriod').AsFloat, FieldByName('endPeriod').AsFloat,
          FieldByName('avgSpeed').AsFloat));
        Next;
      end;
    end;
  finally
    FreeAndNil(fdSpeed);
  end;
end;

procedure TRoute.FillVehicleList;
begin
  fdVehicles := TFDQuery.Create(nil);
  try
    with fdVehicles do
    begin
      Connection := fdConnection;
      Close;
      SQL.Text := 'select reference, capacity, volume, priority from vehicles order by priority';
      Open;

      while not eof do
      begin
        VehicleList.Add(TVehicle.Create(FieldByName('reference').AsString, FieldByName('capacity').AsFloat,
          FieldByName('volume').AsFloat, FieldByName('priority').AsFloat));
        Next;
      end;
    end;
  finally
    FreeAndNil(fdVehicles);
  end;
end;

procedure TRoute.FillDistanceList;
begin
  fdDistance := TFDQuery.Create(nil);
  try
    with fdDistance do
    begin
      Connection := fdConnection;
      Close;
      SQL.Text := 'select firstPoint, lastPoint, length, time from timeDistancePoints order by firstPoint, lastPoint';
      Open;

      while not eof do
      begin
        DistanceList.Add(FieldByName('firstPoint').AsString + ';' + FieldByName('lastPoint').AsString + ';',
          TDistance.Create(FieldByName('length').AsFloat, FieldByName('time').AsFloat,
          FieldByName('firstPoint').AsString, FieldByName('lastPoint').AsString));
        Next;
      end;
    end;
  finally
    FreeAndNil(fdDistance);
  end;
end;

procedure TRoute.GetRoute(index: integer; var order_guid, vehicle_guid: string; var operation: boolean);
var
  fdQuery: TFDQuery;
begin
  fdQuery := TFDQuery.Create(nil);
  with fdQuery do
  begin
    Connection := fdConnection;
    Close;
    SQL.Text := 'select order_guid, vehicle_guid, operation from RouteOrders where recno =:index';
    Open();
    order_guid := FieldByName('order_guid').AsString;
    vehicle_guid := FieldByName('vehicle_guid').AsString;
    operation := FieldByName('operation').AsBoolean;
  end;
end;

function TRoute.GetRouteCount: integer;
var
  fdQuery: TFDQuery;
begin
  fdQuery := TFDQuery.Create(nil);
  with fdQuery do
  begin
    Connection := fdConnection;
    Close;
    SQL.Text := 'select count(*) as counter from RouteOrders';
    Open;
    Result := FieldByName('counter').AsInteger;
  end;
end;

procedure TRoute.InitializeQueries;
begin
  fdVehiclesModify := TFDQuery.Create(nil);
  with fdVehiclesModify do
  begin
    Connection := fdConnection;
    SQL.Text := 'insert into vehicles (reference, capacity, volume, priority) values ' +
      '(:reference, :capacity, :volume, :priority)';
  end;

  fdOrdersModify := TFDQuery.Create(nil);
  with fdOrdersModify do
  begin
    Connection := fdConnection;
    SQL.Text := 'insert into orders (reference, departurePoint, destinationPoint, ' +
      'stayReceivedDeparturePoint, stayReceivedDestinationPoint, stayDeparturePoint, stayDestinationPoint, priority, ' +
      'weight, volume, departureAddress, destinationAddress) values (' +
      ':reference, :departurePoint, :destinationPoint, ' +
      ':stayReceivedDeparturePoint, :stayReceivedDestinationPoint, :stayDeparturePoint, :stayDestinationPoint, :priority, '
      + ':weight, :volume, :departureAddress, :destinationAddress)';
  end;

  fdDistancesModify := TFDQuery.Create(nil);
  with fdDistancesModify do
  begin
    Connection := fdConnection;
    SQL.Text := 'insert into timeDistancePoints (firstPoint, lastPoint, time, length) values ' +
      '(:firstPoint, :lastPoint, :time, :length)';
  end;

  fdSpeedModify := TFDQuery.Create(nil);
  with fdSpeedModify do
  begin
    Connection := fdConnection;
    SQL.Text := 'insert into avgSpeed (beginperiod, endperiod, avgspeed) values ' +
      '(:beginperiod, :endperiod, :avgspeed)';
  end;
end;

procedure TRoute.InsertIntoTable(tablename: string; arrColumns: Array of string; Params: Array of variant);
var
  fdQuery: TFDQuery;
  i: integer;
  strcolumns, strparams: string;
begin
  strcolumns := '';
  strparams := '';
  fdQuery := TFDQuery.Create(nil);
  try
    fdQuery.Connection := fdConnection;
    fdQuery.Close;
    for i := 0 to length(arrColumns) - 1 do
    begin
      strcolumns := strcolumns + arrColumns[i] + ', ';
      strparams := strparams + ':' + arrColumns[i] + ', ';
    end;
    strcolumns := Copy(strcolumns, 1, length(strcolumns) - 2);
    strparams := Copy(strparams, 1, length(strparams) - 2);
    fdQuery.SQL.Text := 'insert into ' + tablename + ' ( ' + strcolumns + ' ) values ( ' + strparams + ' ) ';
    for i := 0 to length(arrColumns) - 1 do
    begin
      if VarType(Params[i]) = varDate then
        fdQuery.ParamByName(arrColumns[i]).AsDateTime := Params[i]
      else if VarType(Params[i]) = varBoolean then
        fdQuery.ParamByName(arrColumns[i]).AsBoolean := Params[i]
      else
        fdQuery.ParamByName(arrColumns[i]).AsString := Params[i];
    end;
    fdQuery.ExecSQL;
  finally
    FreeAndNil(fdQuery);
  end;
end;

procedure TRoute.FillOrderList;
begin
  fdOrders := TFDQuery.Create(nil);
  try
    with fdOrders do
    begin
      Connection := fdConnection;
      Close;
      SQL.Text := 'select reference, departurePoint, destinationPoint, departureAddress, destinationAddress, ' +
        'stayReceivedDeparturePoint, stayReceivedDestinationPoint, ' +
        'stayDeparturePoint, stayDestinationPoint, priority, weight, volume from orders order by reference';
      Open;
      while not eof do
      begin
        OrderList.Add(FieldByName('reference').AsString, TOrder.Create(FieldByName('reference').AsString,
          FieldByName('departurePoint').AsString, FieldByName('destinationPoint').AsString,
          FieldByName('departureAddress').AsString, FieldByName('destinationAddress').AsString,
          FieldByName('stayReceivedDeparturePoint').AsBoolean, FieldByName('stayReceivedDestinationPoint').AsBoolean,
          FieldByName('stayDeparturePoint').AsFloat, FieldByName('stayDestinationPoint').AsFloat,
          FieldByName('priority').AsInteger, FieldByName('weight').AsFloat, FieldByName('volume').AsFloat));
        Next;
      end;
    end;
  finally
    FreeAndNil(fdOrders);
  end;
end;

procedure TRoute.FillListsFromDB;
begin
  try
    FillVehicleList; // Заполнить список ТС
    FillDistanceList; // Заполнить список расстояний
    FillOrderList; // Заполнить список заказов
    FillSpeedList; // Заполнить список скоростей
    FillVectorRouteList; // Построить вектор обхода
  except
    on E: Exception do
      raise Exception.Create(E.Message);
  end;
end;

function TRoute.GetDistance(ref: String): TDistance;
var
  Distance: TDistance;
begin
  if DistanceList.TryGetValue(ref, Distance) then
    Result := Distance
  else
    Result := nil;
end;

procedure TRoute.CalculateRoute(Depo: string; Optimization: integer; TimeLimit: variant; DepartureTime: single);
var
  VisitedPoint: TVisitedPoint;
  TotalTime, TotalDistance: single;
  Ins: boolean;
  RouteCount: integer;
  StartPoint, FinishPoint: string;
  mTime, mDistance: single;
  MaxWeight, MaxVolume: single;
  CurrentWeight, CurrentVolume: single;
  NewSpeed, TimeInPoint: single;
  CurrentVehicleRef: string;
  i, j, k, m: integer;
  vIndex, vIndexBuf, slIndex: integer;
  ref: string;
  Capacity, Volume, Priority: single;
  outCounter, inCounter, Counter1, Counter2: integer;
  flagPoolCorrect, flagChecked: boolean;
  addDelay: single;
  CurMark, DeltaMark: single;
  Counter: integer;
  VectorRoute: TVectorRoute;
  sValue: byte;
begin
  OPOContainer := TList.Create;
  PrevPoolContainer := TList.Create;
  NewPoolContainer := TList.Create;
  DataPoolContainer := TList.Create;

  OrderList := TOrderList.Create([doOwnsValues]);
  VehicleList := TVehicleList.Create;
  DistanceList := TDistanceList.Create([doOwnsValues]);
  SpeedList := TSpeedList.Create;
  VectorRouteList := TVectorRouteList.Create;

  self.Optimization := Optimization;
  self.Depo := Depo;
  FillListsFromDB;

  PoolList := TPoolList.Create;
  try
    for VectorRoute in VectorRouteList do
    begin
      // 1-я часть алгоритма
      // В цикле вектора обхода

      TabOcenokList := TTabOcenokList.Create;
      try
        OrderList.TryGetValue(VectorRoute.FReference, CurOrder);

        for i := 0 to PoolList.Count - 1 do
        begin
          PrevPoolList := TPrevPoolList.Create;
          PrevPoolContainer.Add(PrevPoolList);

          for j := 0 to (PoolList[i].Items[cRoute].asNewPoolList).Count - 1 do
            PrevPoolList.Add(PoolList[i].Items[cRoute].asNewPoolList.Items[j]);

          OrderPointOperation := TOrderPointOperation.Create();
          OPOContainer.Add(OrderPointOperation);
          OrderPointOperation.Structure([cOrder, cPoint, cOperation],
            [CurOrder.FReference, CurOrder.FDeparturePoint, cLoad]);

          PrevPoolList.Add(OrderPointOperation);

          OrderPointOperation := TOrderPointOperation.Create();
          OPOContainer.Add(OrderPointOperation);
          OrderPointOperation.Structure([cOrder, cPoint, cOperation], [CurOrder.FReference, CurOrder.FDestinationPoint,
            cUnload]);

          PrevPoolList.Add(OrderPointOperation);

          outCounter := PrevPoolList.Count - 1;

          while true do
          begin
            if outCounter < 0 then
              break;
            inCounter := outCounter - 1;

            while true do
            begin
              if inCounter < 0 then
                inCounter := PrevPoolList.Count - 1;

              if inCounter = outCounter then
                break;
              NewPoolList := TNewPoolList.Create;
              NewPoolContainer.Add(NewPoolList);
              for k := 0 to PrevPoolList.Count - 1 do
                NewPoolList.Add(PrevPoolList[k]);

              OrderPointOperation := NewPoolList[outCounter];
              NewPoolList.Delete(outCounter);
              NewPoolList.Insert(inCounter, OrderPointOperation);

              flagPoolCorrect := true;

              for Counter1 := 0 to NewPoolList.Count - 1 do
              begin
                flagChecked := false;
                if (NewPoolList[Counter1].Items[cOperation] = cLoad) then
                begin
                  for Counter2 := Counter1 + 1 to NewPoolList.Count - 1 do
                  begin
                    if (NewPoolList[Counter2].Items[cOrder] = NewPoolList[Counter1].Items[cOrder]) and
                      (NewPoolList[Counter2].Items[cOperation] = cUnload) then
                    begin
                      flagChecked := true;
                      break;
                    end;
                  end;
                end
                else
                  Continue;

                if not flagChecked then
                begin
                  flagPoolCorrect := false;
                  break;
                end;
              end;

              if not flagPoolCorrect then
              begin
                inCounter := inCounter - 1;
                Continue;
              end;

              Ins := true;
              TotalTime := 0;
              TotalDistance := 0;

              VisitedPoint := TVisitedPoint.Create;
              try
                for RouteCount := -1 to NewPoolList.Count - 2 do
                begin
                  addDelay := 0;

                  if (RouteCount = -1) then
                    StartPoint := Depo
                  else
                    StartPoint := NewPoolList[RouteCount].Items[cPoint];

                  FinishPoint := NewPoolList[RouteCount + 1].Items[cPoint];

                  if StartPoint = FinishPoint then
                  begin
                    mTime := 0;
                    mDistance := 0;
                  end
                  else
                  begin
                    CurDistance := GetDistance(StartPoint + ';' + FinishPoint + ';');

                    if CurDistance = nil then
                    begin
                      Ins := false;
                      break;
                    end;

                    mTime := CurDistance.FTime;
                    mDistance := CurDistance.FLength;
                  end;

                  NewSpeed := 0;
                  TimeInPoint := AddTimeHHMM(DepartureTime, TotalTime);

                  for slIndex := 0 to SpeedList.Count - 1 do
                  begin
                    if ((SpeedList[slIndex].FBeginPeriod > SpeedList[slIndex].FEndPeriod) and
                      ((TimeInPoint >= SpeedList[slIndex].FBeginPeriod) or
                      (TimeInPoint <= SpeedList[slIndex].FEndPeriod))) or
                      ((TimeInPoint >= SpeedList[slIndex].FBeginPeriod) and
                      (TimeInPoint <= SpeedList[slIndex].FEndPeriod)) then
                    begin
                      NewSpeed := SpeedList[slIndex].FAvgSpeed;
                      break;
                    end;
                  end;

                  if (NewSpeed <> 0) then
                    mTime := mDistance / NewSpeed;

                  if not(RouteCount < 0) then
                  begin
                    OrderList.TryGetValue(NewPoolList[RouteCount].Items[cOrder], CurOrder);
                    if NewPoolList[RouteCount].Items[cOperation] = cLoad then
                    begin
                      if (not((VisitedPoint.ContainsKey(CurOrder.FDepartureAddress)) and
                        (CurOrder.FStayReceivedDeparturePoint))) then
                      begin
                        mTime := AddTimeHHMM(mTime, CurOrder.FStayDeparturePoint);
                        VisitedPoint.AddOrSetValue(CurOrder.FDepartureAddress, 0);
                      end
                    end
                    else
                    begin
                      if (not((VisitedPoint.ContainsKey(CurOrder.FDestinationAddress)) and
                        (CurOrder.FStayReceivedDestinationPoint))) then
                      begin
                        mTime := AddTimeHHMM(mTime, CurOrder.FStayDestinationPoint);
                        VisitedPoint.AddOrSetValue(CurOrder.FDestinationAddress, 0);
                      end
                    end;
                  end;

                  OrderList.TryGetValue(NewPoolList[RouteCount + 1].Items[cOrder], CurOrder);
                  if NewPoolList[RouteCount + 1].Items[cOperation] = cLoad then
                  begin
                    if (not((VisitedPoint.ContainsKey(CurOrder.FDepartureAddress)) and
                      (CurOrder.FStayReceivedDeparturePoint))) then
                    begin
                      mTime := AddTimeHHMM(mTime, CurOrder.FStayDeparturePoint);
                      VisitedPoint.AddOrSetValue(CurOrder.FDepartureAddress, 0);
                    end
                  end
                  else
                  begin
                    if (not((VisitedPoint.ContainsKey(CurOrder.FDestinationAddress)) and
                      (CurOrder.FStayReceivedDestinationPoint))) then
                    begin
                      mTime := AddTimeHHMM(mTime, CurOrder.FStayDestinationPoint);
                      VisitedPoint.AddOrSetValue(CurOrder.FDestinationAddress, 0);
                    end;
                  end;
                  TotalTime := AddTimeHHMM(TotalTime, mTime);
                  TotalDistance := TotalDistance + mDistance;

                end;
              finally
                FreeAndNil(VisitedPoint);
              end;

              if not Ins then
              begin
                inCounter := inCounter - 1;
                Continue;
              end;

              CurMark := IfThen(Optimization = 0, TotalTime, TotalDistance);

              if (not(TimeLimit = unassigned) and (TotalTime > TimeLimit)) then
              begin
                Ins := false;
                inCounter := inCounter - 1;
                Continue;
              end;

              if Ins then
              begin
                MRez := TMRez.Create();
                MRez.Structure([cPool, cNewPool, cNewMark], [PoolList[i], NewPoolList, CurMark]);

                DeltaMark := CurMark - (PoolList[i]).Items[cMark].AsExtended;

                TabOcenokList.Add(TTabOcenok.Create(MRez, DeltaMark, CurOrder.FPriority, 1));
              end;

              inCounter := inCounter - 1;
            end;
            outCounter := outCounter - 1;
          end;
        end;

        // 2-я часть алгоритма
        if VehicleList.Count > 0 then
        begin
          TotalTime := 0;
          TotalDistance := 0;
          Ins := true;
          VisitedPoint := TVisitedPoint.Create;
          try
            for RouteCount := 0 to 1 do
            begin
              if RouteCount = 0 then
              begin
                StartPoint := Depo;
                FinishPoint := CurOrder.FDeparturePoint;
              end
              else
              begin
                StartPoint := CurOrder.FDeparturePoint;
                FinishPoint := CurOrder.FDestinationPoint;
              end;

              if StartPoint = FinishPoint then
              begin
                mTime := 0;
                mDistance := 0;
              end
              else
              begin
                CurDistance := GetDistance(StartPoint + ';' + FinishPoint + ';');
                if CurDistance = nil then
                begin
                  Ins := false;
                  break;
                end;
                mTime := CurDistance.FTime;
                mDistance := CurDistance.FLength;
              end;

              NewSpeed := 0;
              TimeInPoint := AddTimeHHMM(DepartureTime, TotalTime);

              for slIndex := 0 to SpeedList.Count - 1 do
              begin
                if ((SpeedList[slIndex].FBeginPeriod > SpeedList[slIndex].FEndPeriod) and
                  ((TimeInPoint >= SpeedList[slIndex].FBeginPeriod) or (TimeInPoint <= SpeedList[slIndex].FEndPeriod)))
                  or ((TimeInPoint >= SpeedList[slIndex].FBeginPeriod) and
                  (TimeInPoint <= SpeedList[slIndex].FEndPeriod)) then
                begin
                  NewSpeed := SpeedList[slIndex].FAvgSpeed;
                  break;
                end;
              end;

              if (NewSpeed <> 0) then
                mTime := mDistance / NewSpeed;

              if (not((VisitedPoint.ContainsKey(CurOrder.FDepartureAddress)) and
                (CurOrder.FStayReceivedDeparturePoint))) then
              begin
                mTime := AddTimeHHMM(mTime, CurOrder.FStayDeparturePoint);
                VisitedPoint.AddOrSetValue(CurOrder.FDepartureAddress, 0);
              end;

              if (not((VisitedPoint.ContainsKey(CurOrder.FDestinationAddress)) and
                (CurOrder.FStayReceivedDestinationPoint))) then
              begin
                mTime := AddTimeHHMM(mTime, CurOrder.FStayDestinationPoint);
                VisitedPoint.AddOrSetValue(CurOrder.FDestinationAddress, 0);
              end;

              TotalTime := AddTimeHHMM(TotalTime, mTime);
              TotalDistance := TotalDistance + mDistance;

              if (IfThen(TimeLimit = unassigned, 0, IfThen(TotalTime > TimeLimit, 1, 0))) > 0 then
              begin
                Ins := false;
                break;
              end;

              if not Ins then
                break;
            end;

            if Ins then
            begin
              NewPoolList := TNewPoolList.Create;
              NewPoolContainer.Add(NewPoolList);

              OrderPointOperation := TOrderPointOperation.Create();
              OPOContainer.Add(OrderPointOperation);
              OrderPointOperation.Structure([cOrder, cPoint, cOperation],
                [CurOrder.FReference, CurOrder.FDeparturePoint, cLoad]);

              NewPoolList.Add(OrderPointOperation);

              OrderPointOperation := TOrderPointOperation.Create();
              OPOContainer.Add(OrderPointOperation);
              OrderPointOperation.Structure([cOrder, cPoint, cOperation],
                [CurOrder.FReference, CurOrder.FDestinationPoint, cUnload]);

              NewPoolList.Add(OrderPointOperation);
              MRez := TMRez.Create();
              CurMark := IfThen(Optimization = 0, TotalTime, TotalDistance);
              MRez.Structure([cPool, cNewPool, cNewMark], [nil, NewPoolList, CurMark]);

              TabOcenokList.Add(TTabOcenok.Create(MRez, IfThen(Optimization = 0, TotalTime, TotalDistance),
                CurOrder.FPriority, 2));
            end;
          finally
            FreeAndNil(VisitedPoint);
          end;
        end;
        TabOcenokList.Sort(TComparer<TTabOcenok>.Construct(
          function(const L, R: TTabOcenok): integer
          begin
            if L.FMark < R.FMark then
              Result := -1
            else if L.FMark > R.FMark then
              Result := 1
            else if L.FPriority < R.FPriority then
              Result := 1
            else if L.FPriority > R.FPriority then
              Result := -1
            else if L.FFieldMore < R.FFieldMore then
              Result := -1
            else if L.FFieldMore > R.FFieldMore then
              Result := 1
            else
              Result := 0;
          end));

        // 3-я часть алгоритма
        for i := 0 to TabOcenokList.Count - 1 do
        begin
          if (TTabOcenok(TabOcenokList[i]).FValue.Items[cPool].asObject = nil) then
          begin
            MaxWeight := CurOrder.FWeight;
            MaxVolume := CurOrder.FVolume;
          end
          else
          begin
            MaxWeight := 0;
            MaxVolume := 0;

            CurrentWeight := 0;
            CurrentVolume := 0;

            for j := 0 to TTabOcenok(TabOcenokList[i]).FValue.Items[cNewPool].asNewPoolList.Count - 1 do
            begin
              ref := TTabOcenok(TabOcenokList[i]).FValue.Items[cNewPool].asNewPoolList[j].Items[cOrder];
              OrderList.TryGetValue(ref, CurOrder);
              if (TTabOcenok(TabOcenokList[i]).FValue.Items[cNewPool].asNewPoolList[j].Items[cOperation] = cLoad) then
              begin
                CurrentWeight := CurrentWeight + CurOrder.FWeight;
                CurrentVolume := CurrentVolume + CurOrder.FVolume;
              end
              else
              begin
                CurrentWeight := CurrentWeight - CurOrder.FWeight;
                CurrentVolume := CurrentVolume - CurOrder.FVolume;
              end;

              MaxWeight := Max(MaxWeight, CurrentWeight);
              MaxVolume := Max(MaxVolume, CurrentVolume);
            end;
          end;

          if (TTabOcenok(TabOcenokList[i]).FValue.Items[cPool].asObject = nil) then
          begin
            CurrentVehicleRef := '';
            for vIndex := 0 to VehicleList.Count - 1 do
            begin
              if (TVehicle(VehicleList[vIndex]).FCapacity >= MaxWeight) and
                (TVehicle(VehicleList[vIndex]).FVolume >= MaxVolume) then
              begin
                CurrentVehicleRef := TVehicle(VehicleList[vIndex]).FReference;
                vIndexBuf := vIndex;
                break;
              end;
            end;

            vIndex := vIndexBuf;
            if CurrentVehicleRef <> '' then
            begin
              Capacity := TVehicle(VehicleList[vIndex]).FCapacity;
              Volume := TVehicle(VehicleList[vIndex]).FVolume;
              Priority := TVehicle(VehicleList[vIndex]).FPriority;

              NewPoolList := TNewPoolList.Create;
              NewPoolContainer.Add(NewPoolList);

              OrderPointOperation := TOrderPointOperation.Create();
              OPOContainer.Add(OrderPointOperation);
              OrderPointOperation.Structure([cOrder, cPoint, cOperation],
                [CurOrder.FReference, CurOrder.FDeparturePoint, cLoad]);

              NewPoolList.Add(OrderPointOperation);

              OrderPointOperation := TOrderPointOperation.Create();
              OPOContainer.Add(OrderPointOperation);
              OrderPointOperation.Structure([cOrder, cPoint, cOperation],
                [CurOrder.FReference, CurOrder.FDestinationPoint, cUnload]);

              NewPoolList.Add(OrderPointOperation);

              DataPool := TDataPool.Create();
              DataPoolContainer.Add(DataPool);

              DataPool.Structure([cVehicle, cCapacity, cVolumeVehicle, cPriority, cMark, cRoute, cMaxWeight,
                cMaxVolume], [(VehicleList[vIndex] as TVehicle).FReference, Capacity, Volume, Priority,
                TTabOcenok(TabOcenokList[i]).FValue.Items[cNewMark], NewPoolList, MaxWeight, MaxVolume]);

              PoolList.Add(DataPool);
              VehicleList.Delete(vIndex);

              break;
            end;
          end
          else
          begin
            if (TabOcenokList[i].FValue.Items[cPool].asDataPool.Items[cCapacity].AsExtended < MaxWeight) or
              (TabOcenokList[i].FValue.Items[cPool].asDataPool.Items[cVolumeVehicle].AsExtended < MaxVolume) then
            begin
              CurrentVehicleRef := '';

              for vIndex := 0 to VehicleList.Count - 1 do
              begin
                if (TVehicle(VehicleList[vIndex]).FCapacity >= MaxWeight) and
                  (TVehicle(VehicleList[vIndex]).FVolume >= MaxVolume) then
                begin
                  CurrentVehicleRef := TVehicle(VehicleList[vIndex]).FReference;
                  break;
                end;
              end;

              if CurrentVehicleRef <> '' then
                Continue
              else
              begin
                VehicleList.Add(TVehicle.Create(TabOcenokList[i].FValue.Items[cPool].asDataPool.Items[cVehicle]
                  .AsString, TabOcenokList[i].FValue.Items[cPool].asDataPool.Items[cCapacity].AsExtended,
                  TabOcenokList[i].FValue.Items[cPool].asDataPool.Items[cVolumeVehicle].AsExtended,
                  TabOcenokList[i].FValue.Items[cPool].asDataPool.Items[cPriority].AsExtended));

                TabOcenokList[i].FValue.Items[cPool].asDataPool.Items[cVehicle] := (VehicleList[vIndex] as TVehicle)
                  .FReference;
                TabOcenokList[i].FValue.Items[cPool].asDataPool.Items[cCapacity] := (VehicleList[vIndex] as TVehicle)
                  .FCapacity;
                TabOcenokList[i].FValue.Items[cPool].asDataPool.Items[cVolumeVehicle] :=
                  (VehicleList[vIndex] as TVehicle).FVolume;
                TabOcenokList[i].FValue.Items[cPool].asDataPool.Items[cPriority] := (VehicleList[vIndex] as TVehicle)
                  .FPriority;

                VehicleList.Delete(vIndex);

                VehicleList.Sort(TComparer<TVehicle>.Construct(
                  function(const L, R: TVehicle): integer
                  begin
                    if L.FPriority < R.FPriority then
                      Result := -1
                    else if L.FPriority > R.FPriority then
                      Result := 1
                    else
                      Result := 0;
                  end));
              end;
            end;

            TabOcenokList[i].FValue.Items[cPool].asDataPool.Items[cRoute].asNewPoolList.Clear;

            for k := 0 to TabOcenokList[i].FValue.Items[cNewPool].asNewPoolList.Count - 1 do
            begin
              TabOcenokList[i].FValue.Items[cPool].asDataPool.Items[cRoute].asNewPoolList.Add
                (TabOcenokList[i].FValue.Items[cNewPool].asNewPoolList[k]);
            end;

            break;
          end;
        end;

      finally
        CopyPool;
        ClearMemory;
        FreeAndNil(TabOcenokList);
        PoolFromCopy;
      end;
    end;

  finally
    FreeAndNil(OPOContainer);
    FreeAndNil(PrevPoolContainer);
    FreeAndNil(NewPoolContainer);
    FreeAndNil(DataPoolContainer);
    FreeAndNil(OrderList);
    FreeAndNil(VehicleList);
    FreeAndNil(DistanceList);
    FreeAndNil(SpeedList);
    FreeAndNil(VectorRouteList);
  end;

  // Запись результата в БД
  try
    fdRouteOrders := TFDQuery.Create(nil);
    fdConnection.StartTransaction;
    ClearRouteOrders;
    RecordPriority := 0;
    with fdRouteOrders do
    begin
      Close;
      Connection := fdConnection;
      SQL.Text :=
        'insert into RouteOrders (order_guid, vehicle_guid, operation, recno) values (:order_guid, :vehicle_guid, :operation, :recno)';
      for i := 0 to PoolList.Count - 1 do
      begin
        DataPool := PoolList[i];
        for j := 0 to DataPool.Items[cRoute].asNewPoolList.Count - 1 do
        begin
          ParamByName('order_guid').AsString := DataPool.Items[cRoute].asNewPoolList.Items[j].Items[cOrder];
          ParamByName('vehicle_guid').AsString := DataPool.Items[cVehicle].AsString;
          ParamByName('operation').AsString := DataPool.Items[cRoute].asNewPoolList.Items[j].Items[cOperation];
          ParamByName('recno').AsInteger := RecordPriority;
          ExecSQL;
          Inc(RecordPriority);
        end;
      end;
    end;
    fdConnection.Commit;
  finally
    FreeAndNil(fdRouteOrders);
  end;

  FreeAndNil(PoolList);
end;

function TRoute.IntegrityCheck: integer;
begin
  fdDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  fdValidate := TFDSQLiteValidate.Create(nil);
  try
    fdConnection.Close;
    fdValidate.DriverLink := fdDriverLink;
    fdValidate.Database := Database;
    try
      if fdValidate.CheckOnly then
      begin
        try
          fdValidate.Sweep;
        except
        end;
        fdConnection.Params.Text := GetConnectionString(Database);
        fdConnection.Open;
        result := 0;
      end
      else
        result := 1;
    except
      fdConnection.Params.Text := GetConnectionString(Database);
      fdConnection.Open;
      result := 2;
    end;
  finally
    FreeAndNil(fdValidate);
    FreeAndNil(fdDriverLink);
  end;
end;

procedure TRoute.AddAvgSpeed(var vParams: array of variant);
begin
  with fdSpeedModify do
  begin
    Close;
    ParamByName('beginperiod').AsDateTime := vParams[0];
    ParamByName('endperiod').AsDateTime := vParams[1];
    ParamByName('avgspeed').AsFloat := vParams[2];
    ExecSQL;
  end;
end;

procedure TRoute.AddOrder(var vParams: array of variant);
begin
  with fdOrdersModify do
  begin
    Close;
    ParamByName('reference').AsString := vParams[0];
    ParamByName('departurePoint').AsString := vParams[1];
    ParamByName('destinationPoint').AsString := vParams[2];
    ParamByName('stayReceivedDeparturePoint').AsFloat := vParams[3];
    ParamByName('stayReceivedDestinationPoint').AsFloat := vParams[4];
    ParamByName('stayDeparturePoint').AsBoolean := vParams[5];
    ParamByName('stayDestinationPoint').AsBoolean := vParams[6];
    ParamByName('weight').AsFloat := vParams[7];
    ParamByName('volume').AsFloat := vParams[8];
    ParamByName('priority').AsInteger := vParams[9];
    ParamByName('departureAddress').AsString := vParams[10];
    ParamByName('destinationAddress').AsString := vParams[11];
    ExecSQL;
  end;
end;

procedure TRoute.AddPoint(vParams: array of variant);
begin
  with fdDistancesModify do
  begin
    Close;
    ParamByName('firstPoint').AsString := vParams[0];
    ParamByName('lastPoint').AsString := vParams[1];
    ParamByName('time').AsFloat := vParams[2];
    ParamByName('length').AsFloat := vParams[3];
    ExecSQL;
  end;
end;

procedure TRoute.AddVehicle(var vParams: array of variant);
begin
  with fdVehiclesModify do
  begin
    Close;
    ParamByName('reference').AsString := vParams[0];
    ParamByName('capacity').AsFloat := vParams[1];
    ParamByName('volume').AsFloat := vParams[2];
    ParamByName('priority').AsFloat := vParams[3];
    ExecSQL;
  end;
end;

procedure TRoute.StartTransaction;
begin
  fdConnection.StartTransaction;
end;

procedure TRoute.CommitTransaction;
begin
  fdConnection.Commit;
end;

procedure TRoute.RollbackTransaction;
begin
  fdConnection.Rollback;
end;

end.
