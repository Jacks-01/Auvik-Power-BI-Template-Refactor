/* Description: Fetches the device inventory for the sites that the user is authorized on.
  Input Parameter:
   Request for inventory list
  Output Parameter:
    Device Inventory - Table of devices data for the sites that the user is authorized on.
*/
let
    // Build the URL for the API call
    // startUrl = "https://auvikapi.us3.my.auvik.com/v1/inventory/device/info?page[first]=50",
    /*  Description: Fetches one page of data
        url - URL to fetch data
      Output Parameter:
        ret - record consisting of two elements
        retData - data for current page
        retNext - URL for next page
  */
    getOnePage = (Path) as record =>
        let
            baseUrl = "https://auvikapi." & #"Auvik Server Cluster" & ".my.auvik.com/v1/",
            // Get the specified URL and parse the JSON response
            devicePage = Json.Document(Web.Contents(baseUrl, [RelativePath = Path])),
            // Extract the data and links fields and return it
            deviceData = try @devicePage[data] otherwise null,
            next = try Text.Replace(@devicePage[links][next], baseUrl, "") otherwise null,
            // result = try deviceData & @getOnePage(next) otherwise @deviceData,
            ret = [retData = @deviceData, retNext = @next]
        in
            ret,
    // Fullset = getOnePage("inventory/device/info"),
    //   newList = List.Generate(Fullset),
    // Fetch each page until there are no more pages by following the next link. Append subsequent pages.
    deviceList = List.Generate(
        // Fetch the first page
        () => [ret = getOnePage("inventory/device/info")],
        // Stop when there is no more data
        each[ret][retData] <> null,
        // Get the next page using the next link
        each [ret = getOnePage([ret][retNext])],
        // Return only the data
        each[ret][retData]
    ),
    // Convert the list into a table
    deviceListTable = Table.FromList(deviceList, Splitter.SplitByNothing(), null, null),
    // Expand the first column into a separate row for each list item
    deviceTable = Table.ExpandListColumn(deviceListTable, "Column1"),
    // Expand the API response into a column for each first level field
    #"Expanded Column1" = Table.ExpandRecordColumn(
        deviceTable,
        "Column1",
        {"id", "attributes", "relationships"},
        {"Unique ID of the Device", "Column1.attributes", "Column1.relationships"}
    ),
    // Expand each field in the attributes column into a separate column
    #"Expanded Column1.attributes" = Table.ExpandRecordColumn(
        #"Expanded Column1",
        "Column1.attributes",
        {
            "ipAddresses",
            "deviceName",
            "deviceType",
            "makeModel",
            "vendorName",
            "softwareVersion",
            "serialNumber",
            "description",
            "firmwareVersion",
            "lastModified",
            "lastSeenTime",
            "onlineStatus"
        },
        {
            "LAN IP Address(es)",
            "Device Name",
            "Device Type",
            "Device Model",
            "Device Vendor",
            "Device Software Version",
            "Device Serial Number",
            "Device Description",
            "Device Firmware Version",
            "Last Time Device Attributes Were Modified",
            "Last Time the Device Was Seen",
            "Device Status"
        }
    ),
    // Convert the IP addresses list into a single string
    #"Extracted Values" = Table.TransformColumns(
        #"Expanded Column1.attributes",
        {"LAN IP Address(es)", each Text.Combine(List.Transform(_, Text.From), ","), type text}
    ),
    // Expand the data field in the relationships column
    #"Expanded Column1.relationships" = Table.ExpandRecordColumn(
        #"Extracted Values", "Column1.relationships", {"tenant"}, {"Column1.relationships.tenant"}
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
        {"Domain Prefix"}
    ),
    // Creating a new column that generates distinct names by combining the Device Name and the IP addresses of each device
    formattedDeviceInventoryTable = Table.AddColumn(
        #"Expanded Column1.relationships.tenant.data.attributes",
        "Unique Device Name (DeviceName & LAN IP(s)",
        each [Device Name] & "@" & [#"LAN IP Address(es)"]
    )
in
    formattedDeviceInventoryTable