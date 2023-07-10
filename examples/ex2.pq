 let
        GetPages = (Path)=>
        let
            Host = "https://management.azure.com/subscriptions/",
            Source = Json.Document(
                Web.Contents(
                    Host, 
                    [RelativePath = Path]
                )),
            LL= @Source[value],
            Next = Text.Replace(Source[#"nextLink"], Host, ""),
            result = try @ll & @GetPages(Next) otherwise @ll
        in
        result,
    
        Fullset = GetPages(SubscriptionId&"/resources?api-version=2019-05-01"),