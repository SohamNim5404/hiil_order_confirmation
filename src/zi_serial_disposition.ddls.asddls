@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Serial Number Disposition'

define view entity ZI_SERIAL_DISPOSITION
  as select from ztb_serial_dis

  association to parent ZI_ORDER_CONFIRMATION
    as _OrderConfirmation
    on $projection.ConfirmId = _OrderConfirmation.ConfirmId
{
  key confirm_id  as ConfirmId,
  key serial_no   as SerialNo,
      serial_no_display as serialnodisplay,
      material    as Material,
      order_type  as order_type,
      disposition as Disposition,
      reason_code as ReasonCode,
      approved as Approved,
rejected as Rejected,

      @Consumption.valueHelpDefinition: [{
        entity: {
          name: 'ZREJECT_TEXT_VH',
          element: 'RejectionText'
        },
        additionalBinding: [{
          localElement: 'order_type',
          element: 'Order_Type',
          usage: #FILTER
        }]
      }]
      reason_text as ReasonText,
     @UI.hidden: true
is_loading_rejection as IsLoadingRejection, 
      remarks     as Remarks,
     cancelled_ser_no    as CancelledSerialno,
      created_by  as CreatedBy,
      created_at  as CreatedAt,
      changed_by  as ChangedBy,
      changed_at  as ChangedAt,

      _OrderConfirmation
}
