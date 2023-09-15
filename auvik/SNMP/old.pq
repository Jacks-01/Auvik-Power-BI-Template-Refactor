let


    Source = Json.Document(
        Web.Contents(
            "https://auvikapi.us3.my.auvik.com/v1"
                & "/stat"
                & "/snmppoller"
                & "/string"
                & "?filter[fromTime]=2023-09-01 08:00:00&filter[compact]=true&tenants=992315340152315645"
        )
    ),
    data = Source[data],
    #"Converted to Table" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
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
