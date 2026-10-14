@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Materials available for serial fetching'
@ObjectModel.resultSet.sizeCategory: #XS
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_OC_MATERIAL_VH
  as select distinct from ZI_OC_SERIAL_DOC as doc
    inner join I_SerialNumberMaterialDoc_2 as serial
      on serial.MaterialDocument = doc.MaterialDocument
      and serial.MaterialDocumentYear = doc.MaterialDocumentYear
      and serial.MaterialDocumentItem = doc.MaterialDocumentItem
{
  key doc.OrderNo,
  key doc.Material
}
where serial.SerialNumber <> ''
union
select distinct from I_ManufacturingOrder as ord
  inner join I_SerialNumberManufacturingOrd as serial
    on serial.ManufacturingOrder = ord.ManufacturingOrder
{
  key ord.ManufacturingOrder as OrderNo,
  key ord.Material as Material
}
where ( ord.ManufacturingOrderType = 'ZP02'
     or ord.ManufacturingOrderType = 'YP02' )
  and serial.SerialNumber <> ''
