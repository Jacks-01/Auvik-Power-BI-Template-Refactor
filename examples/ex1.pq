let
    Host = "https://management.azure.com/subscriptions/",
    Path = SubscriptionId & "/providers/microsoft.Security/alerts?api-version=2015-06-01-preview",
    iterations = 10,
    FuncGetOnePage = (Path) as record =>
        let
            Source = Json.Document(Web.Contents(Host, [RelativePath = Path])),
            data = try Source[value] otherwise null,
            next = try Source[nextLink] otherwise null,
            res = [Data = data, Next = next]
        in
            res,
    GeneratedListOfPages = List.Generate(
        () => [i = 0, res = FuncGetOnePage(Path)],
        each [i] < iterations and[res][Data] <> null,
        each [i = [i] + 1, res = FuncGetOnePage([res][Next])],
        each[res][Data]
    )
in
    GeneratedListOfPages
