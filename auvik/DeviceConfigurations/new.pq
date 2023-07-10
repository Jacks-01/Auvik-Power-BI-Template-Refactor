/* Description: Fetches the configuration's backup details for the sites that the user is authorized on.
  Input Parameter:
   Request for configuration details
  Output Parameter:
    Device Configurations - Table of configuration details data for the sites that the user is authorized on.
*/
let
    baseUrl = "https://auvikapi." & #"Auvik Server Cluster" & ".my.auvik.com/v1/",
    getOnePage = (Path) as record =>
        let
            devicePage = Json.Document(Web.Contents(baseUrl, [
                RelativePath = Path
            ])),
            deviceData = try @devicePage[data] otherwise null,
            next = try Text.Replace(@devicePage[links][next], baseUrl, "") otherwise null,
            ret = [retData = @deviceData, retNext = @next]
        in
            ret,
    configList = List.Generate(
        () => [ret = getOnePage("inventory/configuration")],
        each[ret][retData] <> null,
        each [ret = getOnePage([ret][retNext])],
        each[ret][retData]
    ),
    configListTable = Table.FromList(configList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    configTable = Table.ExpandListColumn(configListTable, "Column1"),
    #"Expanded Column1" = Table.ExpandRecordColumn(
        configTable,
        "Column1",
        {"id", "attributes", "relationships"},
        {"Configuration Unique ID", "Column1.attributes", "Column1.relationships"}
    ),
    #"Expanded Column1.attributes" = Table.ExpandRecordColumn(
        #"Expanded Column1",
        "Column1.attributes",
        {"backupTime", "isRunning"},
        {"Time of Configuration Backup", "Is this configuration running?"}
    ),
    #"Expanded Column1.relationships" = Table.ExpandRecordColumn(
        #"Expanded Column1.attributes", "Column1.relationships", {"device"}, {"Column1.relationships.device"}
    ),
    #"Expanded Column1.relationships.device" = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships",
        "Column1.relationships.device",
        {"data"},
        {"Column1.relationships.device.data"}
    ),
    formattedConfigurationData = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships.device", "Column1.relationships.device.data", {"id"}, {"Device Unique ID"}
    )
in
    formattedConfigurationData
