@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Production Activity'
@Metadata.allowExtensions: true


define view entity ZC_ORDER_ACTIVITY
  as projection on ZI_ORDER_ACTIVITY
{
  key ActivityId,

      ConfirmId,
      Operation,
      ActivitySlot,
      ActivityLabel,
      ActivityParam,
      ActivityName,

//      @Semantics.quantity.unitOfMeasure: 'ActivityUnit'
      ActivityQty,

      ActivityUnit,
      DisplayActivityUnit,

      _OrderConfirmation :
        redirected to parent ZC_ORDER_CONFIRMATION
}
