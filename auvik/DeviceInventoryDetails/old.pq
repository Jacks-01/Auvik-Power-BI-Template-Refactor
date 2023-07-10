/* Description: Fetches the device inventory details for the sites that the user is authorized on.
  Input Parameter:
   Request for inventory details
  Output Parameter:
    Device Inventory Details - Table of devices details data for the sites that the user is authorized on.
*/
let
    startUrl = "https://auvikapi."
        & #"Auvik Server Cluster"
        & ".my.auvik.com/v1/inventory/device/detail?page[first]=50",
    getOnePage = (url) as record =>
        let
            devicePage = Json.Document(Web.Contents(url)),
            deviceData = try devicePage[data] otherwise null,
            next = try devicePage[links][next] otherwise null,
            ret = [retData = deviceData, retNext = next]
        in
            ret,
    deviceList = List.Generate(
        () => [ret = getOnePage(startUrl)],
        each[ret][retData] <> null,
        each [ret = getOnePage([ret][retNext])],
        each[ret][retData]
    ),
    deviceListTable = Table.FromList(deviceList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    deviceTable = Table.ExpandListColumn(deviceListTable, "Column1"),
    #"Expanded Column1" = Table.ExpandRecordColumn(
        deviceTable, "Column1", {"id", "attributes"}, {"Device Unique ID", "Column1.attributes"}
    ),
    #"Expanded Column1.attributes" = Table.ExpandRecordColumn(
        #"Expanded Column1",
        "Column1.attributes",
        {"discoveryStatus", "manageStatus", "trafficInsightsStatus"},
        {"Column1.attributes.discoveryStatus", "Managed by Auvik Status", "Auvik TrafficInsights Status"}
    ),
    formattedDeviceDetails = Table.ExpandRecordColumn(
        #"Expanded Column1.attributes",
        "Column1.attributes.discoveryStatus",
        {"snmp", "login", "wmi", "vmware"},
        {
            "SNMP Credentials Status",
            "Login Credentials Status",
            "WMI Credentials Status",
            "VMWare Credentials Status"
        }
    )
in
    formattedDeviceDetails
