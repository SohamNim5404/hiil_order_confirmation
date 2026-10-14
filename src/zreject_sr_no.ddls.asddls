@AbapCatalog.sqlViewName: 'ZREJ_CDS'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Rejected Serial No CDS'
@Metadata.ignorePropagatedAnnotations: true
define view ZREJECT_SR_NO
  as select from    ZI_ORDER_CONFIRMATION as A
    left outer join ZI_SERIAL_DISPOSITION as B on A.ConfirmId = B.ConfirmId
{
  key     A.OrderNo,
       B.SerialNo,
          A.order_type,
          A.group_defn as SHIFT,
          A.postingdate,
          B.Rejected,
          B.ReasonText
}
