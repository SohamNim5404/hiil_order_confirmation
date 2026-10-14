@EndUserText.label: 'Work Center Value Help'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Search.searchable: true
define view entity ZWORK_CEN_VH
  as select distinct from I_WorkCenter
{


      @EndUserText.label: 'Work Center'
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.7
  key WorkCenter as work_center
}
