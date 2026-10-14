@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'Rejection Code Item'

define view entity ZC_TMG_REJECT_CODE
  as projection on ZR_TMG_REJECT_CODE
{
  key Order_Type,
  key RejectionCode,

      RejectionText,
      sortsequence,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      ItemLocalLastChangedAt,

      _Header : redirected to parent ZC_TMG_REJECT_HDR
}
