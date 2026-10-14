@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Valid serial source document items'
define view entity ZI_OC_SERIAL_DOC
  as select from I_MaterialDocumentItem_2 as item
    inner join I_ManufacturingOrder as ord
      on ord.ManufacturingOrder = item.OrderID
    left outer join I_MaterialDocumentItem_2 as reversal
      on reversal.OrderID = item.OrderID
      and reversal.ReversedMaterialDocument = item.MaterialDocument
      and ( reversal.GoodsMovementType = '261'
         or reversal.GoodsMovementType = '262' )
{
  key item.MaterialDocumentYear,
  key item.MaterialDocument,
  key item.MaterialDocumentItem,
      item.OrderID as OrderNo,
      item.Material,
      item.Batch
}
where ( item.GoodsMovementType = '261'
     or item.GoodsMovementType = '262' )
  and item.ReversedMaterialDocument = ''
  and reversal.MaterialDocument is null
  and ord.ManufacturingOrderType <> 'ZP02'
  and ord.ManufacturingOrderType <> 'YP02'
