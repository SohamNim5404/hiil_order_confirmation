@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'Order Scrap Items'

define view entity ZC_ORDER_SCRAP
  as projection on ZI_ORDER_SCRAP
{
  key ScrapItemId,

      ConfirmId,
      ScrapMaterial,
      Scrapdesc,
      StorageLocation,
      ScrapQty,
      Scrapunit,
      DISPLAYSCRAPUNIT,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,

      _OrderConfirmation : redirected to parent ZC_ORDER_CONFIRMATION
}
