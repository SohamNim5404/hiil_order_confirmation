@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'Rejection Code Upload Header'

define root view entity ZC_TMG_REJECT_HDR
  provider contract transactional_query
  as projection on ZR_TMG_REJECT_HDR
{
  key Order_Type,

      OrderTypeDescription,
      Attachment,
      MimeType,
      FileName,
      UploadStatus,
      UploadMessage,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Items : redirected to composition child ZC_TMG_REJECT_CODE
}
