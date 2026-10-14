@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Order Confirmation'
define root view entity ZI_ORDER_CONFIRMATION
  as select from ztb__order_hdr

  composition [0..*] of ZI_SERIAL_DISPOSITION as _Serials
  composition [0..*] of ZI_ORDER_SCRAP        as _ScrapItems
  composition [0..*] of ZI_ORDER_ACTIVITY     as _Activities
{
  key confirm_id              as ConfirmId,

      order_no                as OrderNo,
      fetched_order_no        as FetchedOrderNo,
      material                as Material,
      @EndUserText.label: 'Select Material'
      @Consumption.valueHelpDefinition: [{
        entity: {
          name: 'ZI_OC_MATERIAL_VH',
          element: 'Material'
        },
        additionalBinding: [{
          localElement: 'FetchedOrderNo',
          element: 'OrderNo',
          usage: #FILTER
        }]
      }]
      selected_material       as SelectedMaterial,

      @UI.hidden: true
      loaded_source_material  as LoadedSourceMaterial,
      mat_desc                as mat_desc,
      plant                   as Plant,
      batch_number,
      postingdate,
      start_end_date,
      start_time              as starttime,
      end_time                as endtime,
      unit,
      display_unit            as DISPLAYUNIT,

      @Consumption.valueHelpDefinition: [{
        entity: {
          name: 'ZSHIFT_DD',
          element: 'Shift'
        }
      }]
      group_defn,

      order_type              as order_type,
      @UI.hidden: true
      hide_material_selection as HideMaterialSelection,
      order_qty               as OrderQty,
      confirmed_qty           as ConfirmedQty,
      confirmed_scrap_qty     as confirmedscrapqty,
      remaining_qty           as RemainingQty,
      operation               as Operation,

      @Consumption.valueHelpDefinition: [{
        entity: {
          name: 'ZWORK_CEN_VH',
          element: 'work_center'
        }
      }]
      work_center             as WorkCenter,

      qty_to_confirm          as QtyToConfirm,
      scrap_qty               as ScrapQty,
      loading_rejection_qty   as loadingrejectionqty,
      weight_qty              as weightqty,
      vaccum_reading          as vaccumreading,
      vaccum_drop             as vaccumdrop,
      confirmation_group      as ConfirmationGroup,
      confirmation_count      as ConfirmationCount,
      material_document       as MaterialDocument,
      material_document_year  as MaterialDocumentYear,
      material_document_item  as MaterialDocumentItem,
      serials_posted          as SerialsPosted,

      @ObjectModel.text.element: ['StatusText']
      @UI.textArrangement: #TEXT_ONLY
      status                  as Status,

      cast(
      case status
      when 'PART_POST' then 'PART POSTED'
      else status
      end
      as abap.char(20)
      )                       as StatusText,

      case status
        when 'POSTED'    then 3
        when 'PART_POST' then 5
        when 'CREATED'   then 2
        when 'CANCELLED' then 1
        else 0
      end                     as statuscriticality,

      created                 as CreatedBy,
      createdat               as CreatedAt,
      last_changed_by         as ChangedBy,
      last_changed_at         as ChangedAt,

      _ScrapItems,
      _Serials,
      _Activities
}
