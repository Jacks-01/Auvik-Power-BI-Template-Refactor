let
    baseUrl = "https://auvikapi." & #"Auvik Server Cluster" & ".my.auvik.com/v1/",
    Source = Json.Document(
        Web.Contents(
            baseUrl,
            [
                RelativePath = "tenants/detail?tenantDomainPrefix=" & #"Domain Prefix of Main Site"
            ]
        )
    ),
    data = Source[data],
    #"Converted to Table" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(
        #"Converted to Table",
        "Column1",
        {"id", "attributes", "relationships"},
        {"Tenant Unique ID", "Column1.attributes", "Column1.relationships"}
    ),
    #"Expanded Column1.attributes" = Table.ExpandRecordColumn(
        #"Expanded Column1",
        "Column1.attributes",
        {
            "domainPrefix",
            "displayName",
            "tenantType",
            "enabled",
            "subscribed",
            "subscriptionOwner",
            "running",
            "trialStartDate",
            "trialEndDate"
        },
        {
            "Domain Prefix",
            "Site Name",
            "Site Type",
            "Site Enabled",
            "Site Subscribed",
            "Subscription Owner",
            "Site Running",
            "Start Date of Trial",
            "End Date of Trial"
        }
    ),
    #"Expanded Column1.relationships" = Table.ExpandRecordColumn(
        #"Expanded Column1.attributes", "Column1.relationships", {"parent"}, {"Column1.relationships.parent"}
    ),
    #"Expanded Column1.relationships.parent" = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships",
        "Column1.relationships.parent",
        {"data"},
        {"Column1.relationships.parent.data"}
    ),
    formattedSiteDetails = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships.parent",
        "Column1.relationships.parent.data",
        {"id"},
        {"Parent Site's Unique ID"}
    )
in
    formattedSiteDetails
