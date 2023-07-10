/* Description: Fetches Device uptime metrics for the specified time range on the sites that the user is authorized on.
  Input Parameter:
    Report Start Date - Start date of period to fetch Device uptime metrics for
    Report End Date - End date of period to fetch Device uptime metrics for
  Output Parameter:
   Device Uptime  - Table of Device Uptime metric data for the specified time range on the sites that the user is authorized on. The results are the Average uptime percentage for every hour for the reporting period.
*/
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
    /*  Description: Fetches one page of data
        url - URL to fetch data
      Output Parameter:
        ret - record consisting of two elements
        retData - data for current page
        retNext - URL for next page
  */
    baseUrl = "https://auvikapi." & #"Auvik Server Cluster" & ".my.auvik.com/v1/",

    getOnePage = (Path) as record =>
        let
            parsedResults = Json.Document(Web.Contents(baseUrl,
            [
                RelativePath = Path
            ])),
            parsedData = try @parsedResults[data] otherwise null,
            next = try Text.Replace(@parsedResults[links][next], baseUrl, "") otherwise null,
            ret = [retData = @parsedData, retNext = @next]
        in
            ret,
    /*  Description: Fetches data for one period
        periodStart - start date for the period
        periodEnd - end date for the period
      Output Parameter:
        periodDataList - data for the period
  */
    getOnePeriod = (periodStart as date, periodEnd as date) as list =>
        let
            auvikPeriodStart = toAuvikAPIDate(periodStart),
            auvikPeriodEnd = toAuvikAPIDate(Date.AddDays(periodEnd, 1)),
            urlPrefix = "https://auvikapi."
                & #"Auvik Server Cluster"
                & ".my.auvik.com/v1/stat/deviceAvailability/uptime",
            timeFilter = "filter[fromTime]="
                & auvikPeriodStart
                & "T00:00:00.000Z"
                & "&filter[thruTime]="
                & auvikPeriodEnd
                & "T00:00:00.000Z"
                & "&filter[interval]=hour",
            pagination = "page[first]=50",
            urlParameters = "stat/deviceAvailability/uptime" & "?" & timeFilter & "&",
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
    statsListTable = Table.FromList(statsList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    innerStatsListTable = Table.ExpandListColumn(statsListTable, "Column1"),
    statsTable = Table.ExpandListColumn(innerStatsListTable, "Column1"),
    #"Expanded Column1" = Table.ExpandRecordColumn(
        statsTable,
        "Column1",
        {"id", "attributes", "relationships"},
        {"ID of Statistic", "Column1.attributes", "Column1.relationships"}
    ),
    #"Expanded Column1.attributes" = Table.ExpandRecordColumn(
        #"Expanded Column1",
        "Column1.attributes",
        {"reportPeriod", "interval", "stats"},
        {"Column1.attributes.reportPeriod", "Reporting Interval", "Column1.attributes.stats"}
    ),
    #"Expanded Column1.attributes.reportPeriod" = Table.ExpandRecordColumn(
        #"Expanded Column1.attributes",
        "Column1.attributes.reportPeriod",
        {"fromTime", "thruTime"},
        {"Report Period - From Time", "Report Period - ThruTime"}
    ),
    #"Expanded Column1.attributes.stats" = Table.ExpandListColumn(
        #"Expanded Column1.attributes.reportPeriod", "Column1.attributes.stats"
    ),
    #"Expanded Column1.attributes.stats1" = Table.ExpandRecordColumn(
        #"Expanded Column1.attributes.stats", "Column1.attributes.stats", {"data"}, {"Column1.attributes.stats.data"}
    ),
    #"Expanded Column1.attributes.stats.data" = Table.ExpandListColumn(
        #"Expanded Column1.attributes.stats1", "Column1.attributes.stats.data"
    ),
    #"Extracted Values" = Table.TransformColumns(
        #"Expanded Column1.attributes.stats.data",
        {"Column1.attributes.stats.data", each Text.Combine(List.Transform(_, Text.From), ":"), type text}
    ),
    #"Replaced Errors" = Table.ReplaceErrorValues(
        #"Extracted Values", {{"Column1.attributes.stats.data", "no-data"}}
    ),
    #"Filtered Rows" = Table.SelectRows(#"Replaced Errors", each ([Column1.attributes.stats.data] <> "no-data")),
    #"Split Column by Delimiter" = Table.SplitColumn(
        #"Filtered Rows",
        "Column1.attributes.stats.data",
        Splitter.SplitTextByDelimiter(":", QuoteStyle.Csv),
        {"Unix-Minutes Timestamp", "Avg. Hourly Uptime (%)"}
    ),
    #"Changed Type" = Table.TransformColumnTypes(
        #"Split Column by Delimiter", {
            {"Unix-Minutes Timestamp", Int64.Type},
            {"Avg. Hourly Uptime (%)", Int64.Type}
        }
    ),
    #"Added Custom" = Table.AddColumn(
        #"Changed Type",
        "TimeStamp",
        each #datetime(1970, 1, 1, 0, 0, 0) + #duration(0, 0, 0, ([#"Unix-Minutes Timestamp"] * 60))
    ),
    #"Changed Type1" = Table.TransformColumnTypes(#"Added Custom", {{"TimeStamp", type datetime}}),
    #"Inserted Date" = Table.AddColumn(#"Changed Type1", "Date", each DateTime.Date([TimeStamp]), type date),
    #"Inserted Time" = Table.AddColumn(#"Inserted Date", "Time", each DateTime.Time([TimeStamp]), type time),
    #"Expanded Column1.relationships" = Table.ExpandRecordColumn(
        #"Inserted Time", "Column1.relationships", {"device"}, {"Column1.relationships.device"}
    ),
    #"Expanded Column1.relationships.device" = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships",
        "Column1.relationships.device",
        {"data"},
        {"Column1.relationships.device.data"}
    ),
    formattedUptimeStats = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships.device",
        "Column1.relationships.device.data",
        {"id", "deviceName"},
        {"Device Unique ID", "Device Name"}
    )
in
    formattedUptimeStats
