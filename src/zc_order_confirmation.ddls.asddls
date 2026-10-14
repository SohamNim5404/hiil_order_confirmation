@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Order Confirmation'
@Metadata.allowExtensions: true

define root view entity ZC_ORDER_CONFIRMATION
  provider contract transactional_query
  as projection on ZI_ORDER_CONFIRMATION
{
  key ConfirmId,

      @ObjectModel.text.element: [ 'mat_desc' ]
      @UI.textArrangement: #TEXT_LAST
      OrderNo,
      FetchedOrderNo,
      Material,
SelectedMaterial,

@UI.hidden: true
LoadedSourceMaterial,

      mat_desc,
      Plant,
      batch_number,
      postingdate,
      start_end_date,
      starttime,
      endtime,
      unit,
          DISPLAYUNIT,
      group_defn,
//      displaygroupdefn,
     order_type,

@UI.hidden: true
HideMaterialSelection,

OrderQty,
      ConfirmedQty,
      confirmedscrapqty,
      RemainingQty,
      Operation,
      WorkCenter,
      QtyToConfirm,
      ScrapQty,
      loadingrejectionqty,
      weightqty,
      vaccumreading,
      vaccumdrop,
      ConfirmationGroup,
      ConfirmationCount,
      MaterialDocument,
      MaterialDocumentItem,
      MaterialDocumentYear,
    SerialsPosted,

@ObjectModel.text.element: ['StatusText']
@UI.textArrangement: #TEXT_ONLY
Status,

StatusText,
statuscriticality,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,

      _Serials    : redirected to composition child ZC_SERIAL_DISPOSITION,
      _ScrapItems : redirected to composition child ZC_ORDER_SCRAP,
      _Activities : redirected to composition child ZC_ORDER_ACTIVITY

}
