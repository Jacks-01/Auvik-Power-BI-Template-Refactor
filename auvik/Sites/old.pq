/* Description: Fetches a list of the sites for which the user is authorized on.
  Input Parameter:
    Request for tenant list
  Output Parameter:
    Tenants list - Table of the sites for which the user is authorized on.
*/
let
    // Get the specified URL and parse the JSON response
    
  Source = Json.Document(
      Web.Contents(
        "https://auvikapi." & #"Auvik Server Cluster" & ".my.auvik.com/v1/tenants"
        )
      ),
    data = Source[data],
    // Convert the list into a table
    tenantListTable = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    // Expand the API response into a column for each first level field
    #"Expanded Column1" = Table.ExpandRecordColumn(
        tenantListTable,
        "Column1",
        {"id", "attributes", "relationships"},
        {"Client Unique ID", "Column1.attributes", "Column1.relationships"}
    ),
    // Expand each field in the attributes column into a separate column
    #"Expanded Column1.attributes" = Table.ExpandRecordColumn(
        #"Expanded Column1", "Column1.attributes", {"domainPrefix", "tenantType"}, {"Domain Prefix", "Site Type"}
    ),
    // Expand the relationships column into separate columns for each field
    #"Expanded Column1.relationships" = Table.ExpandRecordColumn(
        #"Expanded Column1.attributes", "Column1.relationships", {"parent"}, {"Column1.relationships.parent"}
    ),
    // Expand the relationships.parent column into separate columns for each field
    #"Expanded Column1.relationships.parent" = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships",
        "Column1.relationships.parent",
        {"data"},
        {"Column1.relationships.parent.data"}
    ),
    // Expand the relationships.parent.data column into separate columns for each field
    formattedSitesTable = Table.ExpandRecordColumn(
        #"Expanded Column1.relationships.parent",
        "Column1.relationships.parent.data",
        {"id"},
        {"Unique ID of Client's Parent"}
    ),
    #"Renamed Columns" = Table.RenameColumns(
        formattedSitesTable,
        {{"Client Unique ID", "Site Unique ID"}, {"Unique ID of Client's Parent", "Unique ID of Site's Parent"}}
    )
in
    #"Renamed Columns"