@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Serial Number Disposition'
@Metadata.allowExtensions: true
define view entity ZC_SERIAL_DISPOSITION
  as projection on ZI_SERIAL_DISPOSITION
{
  key ConfirmId,
  key SerialNo,
  serialnodisplay,
//   @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_SERIAL_DISPLAY'
//      virtual SerialNoDisplay : abap.char(18),
    _OrderConfirmation.OrderNo as OrderId,
    _OrderConfirmation.postingdate as Postingdt,
      Material,
      Disposition,
      order_type,
      Approved,
      Rejected,
      ReasonCode,
ReasonText,
@UI.hidden: true
IsLoadingRejection,
      Remarks,
      CancelledSerialno,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,

      _OrderConfirmation : redirected to parent ZC_ORDER_CONFIRMATION
}
