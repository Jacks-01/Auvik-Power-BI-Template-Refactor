let
    /*  Description: Takes in a date and converts it to the format needed for the Auvik API.
      Input Parameter:
        origDate - Date to convert
      Output Parameter:
        auvikDate - origDate converted to format needed for Auvik API 
  */
    toAuvikAPIDate = (origDate as date) as text =>
        let
            auvikDate = Number.ToText(Date.Year(origDate))
                & "-"
                & Text.PadStart(Number.ToText(Date.Month(origDate)), 2, "0")
                & "-"
                & Text.PadStart(Number.ToText(Date.Day(origDate)), 2, "0")
        in
            auvikDate,
    baseUrl = "https://auvikapi." & #"Auvik Server Cluster" & ".my.auvik.com/v1/",
    getOnePage = (Path) as record =>
        let
            parsedResults = Json.Document(Web.Contents(baseUrl, [
                RelativePath = Path
            ])),
            parsedData = try @parsedResults[data] otherwise null,
            next = try Text.Replace(@parsedResults[links][next], baseUrl, "") otherwise null,
            ret = [retData = @parsedData, retNext = @next]
        in
            ret,
    getOnePeriod = (periodStart as date, periodEnd as date) as list =>
        let
            auvikPeriodStart = toAuvikAPIDate(periodStart),
            auvikPeriodEnd = toAuvikAPIDate(Date.AddDays(periodEnd, 1)),
            urlPrefix = "https://auvikapi." & #"Auvik Server Cluster" & ".my.auvik.com/v1/stat/snmppoller/string",
            timeFilter = "filter[fromTime]="
                & auvikPeriodStart
                & "T00:00:00.000Z"
                & "&filter[thruTime]="
                & auvikPeriodEnd
                & "T00:00:00.000Z"
                & "&filter[interval]=hour"
                & "&filter[compact]=true",
            tenants = "tenants="
                & "987248487654760189,987248487654792957,992315340152315645,997394647852326653,997394647855636221,997394647856422653,997394647856455421,997394647859404541,997394647859666685,997394647860059901,997394647860354813,997394647862910717,997394647863009021,997394647863041789,997394647863303933,1002475458819137277",
            pagination = "page[first]=50",
            urlParameters = "stat/snmppoller/string" & "?" & timeFilter & "&" & tenants,
            periodDataList = List.Generate(
                () => [ret = getOnePage(urlParameters)],
                each[ret][retData] <> null,
                each [ret = getOnePage([ret][retNext])],
                each[ret][retData]
            )
        in
            periodDataList,
    // Determine how many separate queries we have to make to get the entire desired time range
    // API hourly data limit in days
    maxHourlyPeriod = 30,
    startDate = #"Report Start Date",
    endDate = #"Report End Date",
    numPeriods = Number.RoundUp((Duration.Days(Duration.From(endDate - startDate)) + 1) / maxHourlyPeriod),
    currEndDate = if numPeriods = 1 then endDate else Date.AddDays(startDate, maxHourlyPeriod - 1),
    // Iterate through each period and combine the data
    statsList = List.Generate(
        () =>
            [
                currentPeriod = 1,
                currentStartDate = startDate,
                currentEndDate = currEndDate,
                ret = getOnePeriod(currentStartDate, currentEndDate)
            ],
        each [currentPeriod] <= numPeriods,
        each
            [
                currentPeriod = [currentPeriod] + 1,
                currentStartDate = Date.AddDays([currentStartDate], maxHourlyPeriod),
                currentEndDate = if currentPeriod = numPeriods then
                    endDate
                else
                    Date.AddDays([currentEndDate], maxHourlyPeriod),
                ret = getOnePeriod(currentStartDate, currentEndDate)
            ],
        each [ret]
    ),
    // statsListTable = Table.FromList(statsList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    // innerStatsListTable = Table.ExpandListColumn(statsListTable, "Column1"),
    // statsTable = Table.ExpandListColumn(innerStatsListTable, "Column1"),
    //* changed data to statsList in below step
    #"Converted to Table" = Table.FromList(statsList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(
        #"Converted to Table",
        "Column1",
        {"attributes", "id", "relationships", "type"},
        {"Column1.attributes", "Column1.id", "Column1.relationships", "Column1.type"}
    ),
    #"Expanded Column1.relationships" = Table.ExpandRecordColumn(
        #"Expanded Column1",
        "Column1.relationships",
        {"device", "tenant"},
        {"Column1.relationships.device", "Column1.relationships.tenant"}
    ),
    #"Expanded Column1.relationships.device" = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships",
        "Column1.relationships.device",
        {"data"},
        {"Column1.relationships.device.data"}
    ),
    #"Expanded Column1.relationships.device.data" = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships.device",
        "Column1.relationships.device.data",
        {"id"},
        {"Column1.relationships.device.data.id"}
    ),
    #"Expanded Column1.relationships.tenant" = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships.device.data",
        "Column1.relationships.tenant",
        {"data"},
        {"Column1.relationships.tenant.data"}
    ),
    #"Expanded Column1.relationships.tenant.data" = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships.tenant",
        "Column1.relationships.tenant.data",
        {"id"},
        {"Column1.relationships.tenant.data.id"}
    ),
    #"Expanded Column1.attributes" = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships.tenant.data",
        "Column1.attributes",
        {"reportPeriod", "stats"},
        {"Column1.attributes.reportPeriod", "Column1.attributes.stats"}
    ),
    #"Removed Columns" = Table.RemoveColumns(#"Expanded Column1.attributes", {"Column1.attributes.reportPeriod"}),
    #"Expanded Column1.attributes.stats" = Table.ExpandRecordColumn(
        #"Removed Columns", "Column1.attributes.stats", {"data"}, {"Column1.attributes.stats.data"}
    ),
    #"Expanded Column1.attributes.stats.data" = Table.ExpandListColumn(
        #"Expanded Column1.attributes.stats", "Column1.attributes.stats.data"
    ),
    #"Added Custom" = Table.AddColumn(
        #"Expanded Column1.attributes.stats.data", "Custom", each[Column1.attributes.stats.data]{0}
    ),
    #"Added Custom1" = Table.AddColumn(#"Added Custom", "Custom.1", each[Column1.attributes.stats.data]{1}),
    #"Reordered Columns" = Table.ReorderColumns(
        #"Added Custom1",
        {
            "Column1.attributes.stats.data",
            "Custom",
            "Custom.1",
            "Column1.id",
            "Column1.relationships.device.data.id",
            "Column1.relationships.tenant.data.id",
            "Column1.type"
        }
    ),
    #"Removed Columns1" = Table.RemoveColumns(#"Reordered Columns", {"Column1.attributes.stats.data"}),
    #"Reordered Columns1" = Table.ReorderColumns(
        #"Removed Columns1",
        {
            "Column1.relationships.device.data.id",
            "Custom",
            "Custom.1",
            "Column1.id",
            "Column1.relationships.tenant.data.id",
            "Column1.type"
        }
    ),
    #"Renamed Columns" = Table.RenameColumns(
        #"Reordered Columns1",
        {
            {"Custom.1", "Page Count"},
            {"Custom", "DateTime"},
            {"Column1.relationships.device.data.id", "Device Id"},
            {"Column1.relationships.tenant.data.id", "Tenant Id"}
        }
    ),
    #"Removed Columns2" = Table.RemoveColumns(#"Renamed Columns", {"Column1.type"}),
    #"Renamed Columns1" = Table.RenameColumns(#"Removed Columns2", {{"Column1.id", "SNMP Id"}}),
    #"Reordered Columns2" = Table.ReorderColumns(
        #"Renamed Columns1", {"Device Id", "DateTime", "Page Count", "Tenant Id", "SNMP Id"}
    ),
    #"Changed Type" = Table.TransformColumnTypes(
        #"Reordered Columns2", {{"DateTime", type datetime}, {"Page Count", Int64.Type}}
    ),
    #"Grouped Rows" = Table.Group(
        #"Changed Type",
        {"Device Id"},
        {
            {"MinCount", each List.Min([Page Count]), type nullable number},
            {"MaxCount", each List.Max([Page Count]), type nullable number},
            {"MinDate", each List.Min([DateTime]), type nullable datetime},
            {"MaxDate", each List.Max([DateTime]), type nullable datetime}
        }
    )
in
    #"Grouped Rows"
