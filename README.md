# POSH-Vsts
Powershell extension for VSTS

# Example Usage

Initial setup
```powershell
PS> import-module -force VstsUtils.psm1

# encrypts and stores this information in your home directory
# so it can be used in subsequent calls
PS> Set-VstsConfig

Supply values for the following parameters:
AccountName: tommclaughlin
Project: testproject
User: tom.mclaughlin@nebraska.gov
Token: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```
### Get Work Item
```powershell
PS> Get-WorkItem 1 | ConvertTo-Json
{
    "id":  1,
    "rev":  15,
    "fields":  {
                   "System.AreaPath":  "testproject",
                   "System.TeamProject":  "testproject",
                   "System.IterationPath":  "testproject",
                   "System.WorkItemType":  "Task",
                   "System.State":  "New",
                   "System.Reason":  "New",
                   "System.AssignedTo":  "McLaughlin, Tom \u003ctom.mclaughlin@Nebraska.gov\u003e",
                   "System.CreatedDate":  "2018-10-22T20:53:15.1Z",
                   "System.CreatedBy":  "McLaughlin, Tom \u003ctom.mclaughlin@Nebraska.gov\u003e",
                   "System.ChangedDate":  "2018-10-25T20:43:26.997Z",
                   "System.ChangedBy":  "McLaughlin, Tom \u003ctom.mclaughlin@Nebraska.gov\u003e",
                   "System.CommentCount":  3,
                   "System.Title":  "test asdfad fasd f asdf asdfasdfasdf asd",
                   "Microsoft.VSTS.Common.StateChangeDate":  "2018-10-22T20:53:15.1Z",
                   "Microsoft.VSTS.Common.Priority":  2,
                   "Custom.ServicePortalTicketId":  "SR1540500206920",
                   "System.Description":  "\u003cdiv\u003easdf\u003c/div\u003e\u003cdiv\u003easdf\u003c/div\u003e\u003cdiv\u003easdf\u003c/div\u003e\u003cdiv\u003easdf\u003c/div\u003e\u003cdiv\u003easdf\u003c/div\u003e"
               },
    "_links":  {
                   "self":  {
                                "href":  "https://dev.azure.com/tommclaughlin/_apis/wit/workItems/1"
                            },
                   "workItemUpdates":  {
                                           "href":  "https://dev.azure.com/tommclaughlin/_apis/wit/workItems/1/updates"
                                       },
                   "workItemRevisions":  {
                                             "href":  "https://dev.azure.com/tommclaughlin/_apis/wit/workItems/1/revisions"
                                         },
                   "workItemHistory":  {
                                           "href":  "https://dev.azure.com/tommclaughlin/_apis/wit/workItems/1/history"
                                       },
                   "html":  {
                                "href":  "https://dev.azure.com/tommclaughlin/web/wi.aspx?pcguid=636b4784-c2cb-4309-98bc-7fa8e559b748\u0026id=1"
                            },
                   "workItemType":  {
                                        "href":  "https://dev.azure.com/tommclaughlin/dc5329bd-bc74-48bb-af94-500843428988/_apis/wit/workItemTypes/Task"
                                    },
                   "fields":  {
                                  "href":  "https://dev.azure.com/tommclaughlin/_apis/wit/fields"
                              }
               },
    "url":  "https://dev.azure.com/tommclaughlin/_apis/wit/workItems/1"
}

```


