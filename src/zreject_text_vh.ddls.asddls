@AbapCatalog.sqlViewName: 'ZREJECT_VH'
@AbapCatalog.compiler.compareFilter: true
//@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VALUE HELP'
@Metadata.ignorePropagatedAnnotations: true
define view ZREJECT_TEXT_VH as select from ZR_TMG_REJECT_CODE
{
   key Order_Type,
    key RejectionCode,
    RejectionText
//    CreatedBy,
//    CreatedAt,
//    LastChangedBy,
//    LastChangedAt,
//    LocalLastChangedAt
}
