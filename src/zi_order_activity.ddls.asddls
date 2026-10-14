@EndUserText.label: 'Order Confirmation Activity'
@AccessControl.authorizationCheck: #NOT_REQUIRED

define view entity ZI_ORDER_ACTIVITY
  as select from ztb_order_act

  association to parent ZI_ORDER_CONFIRMATION
    as _OrderConfirmation
    on $projection.ConfirmId = _OrderConfirmation.ConfirmId
{
  key activity_id    as ActivityId,

      confirm_id     as ConfirmId,
      operation      as Operation,
      activity_slot  as ActivitySlot,
      activity_label as ActivityLabel,
      activity_param as ActivityParam,
      activity_name  as ActivityName,

//      @Semantics.quantity.unitOfMeasure: 'ActivityUnit'
      activity_qty   as ActivityQty,

//      @Semantics.unitOfMeasure: true
      activity_unit  as ActivityUnit,
      displayactivity_unit as DisplayActivityUnit,

      _OrderConfirmation
}
