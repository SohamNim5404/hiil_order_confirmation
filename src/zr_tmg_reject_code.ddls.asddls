@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'Rejection Code Item'
define view entity ZR_TMG_REJECT_CODE
  as select from ztmg_reject_code

  association to parent ZR_TMG_REJECT_HDR as _Header
    on $projection.Order_Type = _Header.Order_Type
{
  key order_type as Order_Type,
  key rejection_code as RejectionCode,

      rejection_text as RejectionText,
      sortsequence as  sortsequence,

      @Semantics.user.createdBy: true
      created_by as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at as CreatedAt,

      @Semantics.user.lastChangedBy: true
      last_changed_by as LastChangedBy,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at as LastChangedAt,

@Semantics.systemDateTime.localInstanceLastChangedAt: true
local_last_changed_at as ItemLocalLastChangedAt,

      _Header
}
