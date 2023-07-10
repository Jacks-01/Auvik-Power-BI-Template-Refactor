/* Description: Fetches the Warranty Data from all the available devices for the sites that the user is authorized on.
  Input Parameter:
    Warranty Data request
  Output Parameter:
    Warranty Data - Table of Warranty Data from all the available devices for the sites that the user is authorized on.
*/
let
    // Build the URL for the API call
    baseUrl = "https://auvikapi." & #"Auvik Server Cluster" & ".my.auvik.com/v1/",
    /* Description: Fetches one page of data
      url - URL to fetch data
    Output Parameter:
      ret - record consisting of two elements
      retData - data for current page
      retNext - URL for next page
  */
    getOnePage = (Path) as record =>
        let
            // Get the specified URL and parse the JSON response
            devicePage = Json.Document(Web.Contents(baseUrl, [RelativePath = Path])),
            // Extract the data and links fields and return it
            deviceData = try @devicePage[data] otherwise null,
            next = try Text.Replace(@devicePage[links][next], baseUrl, "") otherwise null,
            ret = [retData = @deviceData, retNext = @next]
        in
            ret,
    // Fetch each page until there are no more pages by following the next link. Append subsequent pages.
    deviceList = List.Generate(
        // Fetch the first page
        () => [ret = getOnePage("inventory/device/warranty")],
        // Stop when there is no more data
        each[ret][retData] <> null,
        // Get the next page using the next link
        each [ret = getOnePage([ret][retNext])],
        // Return only the data
        each[ret][retData]
    ),
    // Convert the list into a table
    deviceListTable = Table.FromList(deviceList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    // Expand the first column into a separate row for each list item
    deviceTable = Table.ExpandListColumn(deviceListTable, "Column1"),
    // Expand each field in the attributes column into a separate column
    #"Expanded Column1" = Table.ExpandRecordColumn(
        deviceTable, "Column1", {"id", "attributes"}, {"Device Unique ID", "Column1.attributes"}
    ),
    // Expand each field in the attributes column into a separate column
    formattedWarrantyDataTable = Table.ExpandRecordColumn(
        #"Expanded Column1",
        "Column1.attributes",
        {
            "deviceName",
            "serviceCoverageStatus",
            "serviceAttachmentStatus",
            "contractRenewalAvailability",
            "warrantyCoverageStatus",
            "warrantyExpirationDate",
            "recommendedSoftwareVersion"
        },
        {
            "Device Name",
            "Service Coverage Status",
            "Service Attachment Status",
            "Contract Renewal Availability",
            "Warranty Coverage Status",
            "Warranty Expiration Date",
            "Vendor Suggested Software Version"
        }
    )
in
    formattedWarrantyDataTable
