/* Description: Fetches the alerts history for the specified time range on the sites that the user is authorized on.
  Input Parameter:
    Report Start Date - Start date of period to fetch alerts history for
    Report End Date - End date of period to fetch alerts history for
  Output Parameter:
    Alerts History - Table of alerts history data for the specified time range on the sites that the user is authorized on.
*/
let
    /*  Description: Takes in a date and converts it to the format needed for the Auvik API. Auvik API expects the format to be 
      yyyy-MM-ddTHH:mm:ss.SSSZ. This function takes a date variable and creates a string with the date in the format: yyyy-MM-dd.
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
    getOnePage = (Path) as record =>
        let
            // Get the specified URL and parse the JSON response
            baseUrl = "https://auvikapi." & #"Auvik Server Cluster" & ".my.auvik.com/v1/",
            alertPage = Json.Document(Web.Contents(baseUrl, [
                RelativePath = Path
            ])),
            // Extract the data and links fields and return it
            alertData = try @alertPage[data] otherwise null,
            next = try Text.Replace(@alertPage[links][next], baseUrl, "") otherwise null,
            ret = [retData = @alertData, retNext = @next]
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
            // Convert the dates to the format required for the Auvik API
            auvikPeriodStart = toAuvikAPIDate(periodStart),
            auvikPeriodEnd = toAuvikAPIDate(Date.AddDays(periodEnd, 1)),
            // Build the URL for the API call
            timefilter = "filter[detectedTimeAfter]="
                & auvikPeriodStart
                & "T00:00:00.000Z"
                & "&filter[detectedTimeBefore]="
                & auvikPeriodEnd
                & "T00:00:00.000Z",
            // pagination = "page[first]=50",
            urlParameters = "alert/history/info" & "?" & timefilter & "&",
            // Fetch each page until there are no more pages by following the next link. Append subsequent pages.
            periodDataList = List.Generate(
                // Fetch the first page
                () => [ret = getOnePage(urlParameters)],
                // Stop when there is no more data
                each[ret][retData] <> null,
                // Get the next page using the next link
                each [ret = getOnePage([ret][retNext])],
                // Return only the data
                each[ret][retData]
            )
        in
            periodDataList,
    // Determine how many separate queries we have to make to get the entire desired time range
    // API data limit in days
    maxPeriod = 30,
    startDate = #"Report Start Date",
    endDate = #"Report End Date",
    // Determine how many time periods we need to fetch the data for the requested date range
    numPeriods = Number.RoundUp((Duration.Days(Duration.From(endDate - startDate)) + 1) / maxPeriod),
    currEndDate = if numPeriods = 1 then endDate else Date.AddDays(startDate, maxPeriod - 1),
    // Iterate through each period and combine the data
    alertList = List.Generate(
        // Get the first period
        () =>
            [
                currentPeriod = 1,
                currentStartDate = startDate,
                currentEndDate = currEndDate,
                ret = getOnePeriod(currentStartDate, currentEndDate)
            ],
        // Stop when we hit the calculated number of periods
        each [currentPeriod] <= numPeriods,
        // Get the next period
        each
            [
                currentPeriod = [currentPeriod] + 1,
                currentStartDate = Date.AddDays([currentStartDate], maxPeriod),
                currentEndDate = if currentPeriod = numPeriods then endDate else Date.AddDays(
                    [currentEndDate], maxPeriod
                ),
                ret = getOnePeriod(currentStartDate, currentEndDate)
            ],
        each [ret]
    ),
    // Convert the list into a table
    alertListTable = Table.FromList(alertList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    // Expand the first column into a separate row for each list item
    innerAlertListTable = Table.ExpandListColumn(alertListTable, "Column1"),
    // Expand the first column into a separate row for each list item
    alertTable = Table.ExpandListColumn(innerAlertListTable, "Column1"),
    // Expand the API response into a column for each first level field
    #"Expanded Column1" = Table.ExpandRecordColumn(
        alertTable,
        "Column1",
        {"id", "attributes", "relationships"},
        {"Unique ID for the Alert", "Column1.attributes", "Column1.relationships"}
    ),
    // Expand each field in the attributes column into a separate column
    #"Expanded Column1.attributes" = Table.ExpandRecordColumn(
        #"Expanded Column1",
        "Column1.attributes",
        {
            "name",
            "severity",
            "status",
            "specificationId",
            "detectedOn",
            "description",
            "dismissed",
            "dispatched",
            "externalTicket"
        },
        {
            "Name of Alert",
            "Alert Severity",
            "Alert Status",
            "Alert Definition ID",
            "Date-Time When the Alert's Message Was Detected",
            "Alert Description",
            "Has the Alert Been Dismissed?",
            "Has the Alert Been Dispatched?",
            "Column1.attributes.externalTicket"
        }
    ),
    // Expand the external tiket column into a separate row for each external ticket
    #"Expanded Column1.attributes.externalTicket" = Table.ExpandListColumn(
        #"Expanded Column1.attributes", "Column1.attributes.externalTicket"
    ),
    // Expand the externalTicket column into a separate column for each field
    #"Expanded Column1.attributes.externalTicket1" = Table.ExpandRecordColumn(
        #"Expanded Column1.attributes.externalTicket",
        "Column1.attributes.externalTicket",
        {"id", "system"},
        {"External Ticket ID", "External Ticket Source System"}
    ),
    // Expand the relationships column into separate columns for each field
    #"Expanded Column1.relationships" = Table.ExpandRecordColumn(
        #"Expanded Column1.attributes.externalTicket1",
        "Column1.relationships",
        {"tenant", "relatedAlert", "entity"},
        {"Column1.relationships.tenant", "Column1.relationships.relatedAlert", "Column1.relationships.entity"}
    ),
    // Expand the data field in the relationships.tenant column
    #"Expanded Column1.relationships.tenant" = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships",
        "Column1.relationships.tenant",
        {"data"},
        {"Column1.relationships.tenant.data"}
    ),
    // Expand the relationships.tenant.data column into separate columns for each field
    #"Expanded Column1.relationships.tenant.data" = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships.tenant",
        "Column1.relationships.tenant.data",
        {"id", "attributes"},
        {"Site Unique ID", "Column1.relationships.tenant.data.attributes"}
    ),
    // Expand the domainPrefix field in the relationships.tenant.data.attributes column
    #"Expanded Column1.relationships.tenant.data.attributes" = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships.tenant.data",
        "Column1.relationships.tenant.data.attributes",
        {"domainPrefix"},
        {"Site Domain Prefix"}
    ),
    // Expand the data field in the relationships.relatedAlert column
    #"Expanded Column1.relationships.relatedAlert" = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships.tenant.data.attributes",
        "Column1.relationships.relatedAlert",
        {"data"},
        {"Column1.relationships.relatedAlert.data"}
    ),
    // Expand the data field in the relationships.entity columns
    #"Expanded Column1.relationships.entity" = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships.relatedAlert",
        "Column1.relationships.entity",
        {"data"},
        {"Column1.relationships.entity.data"}
    ),
    // Expand the relationships.entity.data column into a separate column for each field
    #"Expanded Column1.relationships.entity.data" = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships.entity",
        "Column1.relationships.entity.data",
        {"type", "id"},
        {"Entity Type Associated with Alert", "Unique ID For Related Entity"}
    ),
    // Duplicate the Detected On date
    #"Detected On: Date (Copy)" = Table.DuplicateColumn(
        #"Expanded Column1.relationships.entity.data",
        "Date-Time When the Alert's Message Was Detected",
        "Column1.attributes.detectedOn - Copy"
    ),
    // Extract the date and time into 2 separate columns
    #"Split Column by Positions" = Table.SplitColumn(
        #"Detected On: Date (Copy)",
        "Column1.attributes.detectedOn - Copy",
        Splitter.SplitTextByPositions({0, 10, 11, 23}),
        {
            "Date of Detection",
            "Column1.attributes.detectedOn - Copy.2",
            "Hour of Detection",
            "Column1.attributes.detectedOn - Copy.4"
        }
    ),
    #"Changed Type" = Table.TransformColumnTypes(
        #"Split Column by Positions",
        {
            {"Date of Detection", type date},
            {"Column1.attributes.detectedOn - Copy.2", type text},
            {"Hour of Detection", type time},
            {"Column1.attributes.detectedOn - Copy.4", type text}
        }
    ),
    #"Removed Columns" = Table.RemoveColumns(
        #"Changed Type", {"Column1.attributes.detectedOn - Copy.2", "Column1.attributes.detectedOn - Copy.4"}
    ),
    // Expand the relationships.relatedAlert.data column into a separate column for each field
    #"Expanded Column1.relationships.relatedAlert.data" = Table.ExpandRecordColumn(
        #"Removed Columns",
        "Column1.relationships.relatedAlert.data",
        {"id", "attributes"},
        {"Unique ID for Related Alert", "Column1.relationships.relatedAlert.data.attributes"}
    ),
    // Expand the name from the relationships.relatedAlert.data.attributes column
    formattedAlertsHistory = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships.relatedAlert.data",
        "Column1.relationships.relatedAlert.data.attributes",
        {"name"},
        {"Name of Related Alert"}
    ),
    #"Renamed Columns" = Table.RenameColumns(formattedAlertsHistory, {{"Site Domain Prefix", "Domain Prefix"}})
in
    #"Renamed Columns"
