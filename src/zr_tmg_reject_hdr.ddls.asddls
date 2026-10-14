@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@EndUserText.label: 'Rejection Code Upload Header'

define root view entity ZR_TMG_REJECT_HDR
  as select from ztmg_reject_hdr

  composition [0..*] of ZR_TMG_REJECT_CODE as _Items
{
  key order_type as Order_Type,

      order_type_description as OrderTypeDescription,

      @Semantics.largeObject: {
        mimeType: 'MimeType',
        fileName: 'FileName',
        acceptableMimeTypes: [
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        ],
        contentDispositionPreference: #ATTACHMENT
      }
      attachment as Attachment,

      @Semantics.mimeType: true
      mime_type as MimeType,

      file_name as FileName,

      upload_status  as UploadStatus,
      upload_message as UploadMessage,

      @Semantics.user.createdBy: true
      created_by as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at as CreatedAt,

      @Semantics.user.lastChangedBy: true
      last_changed_by as LastChangedBy,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at as LastChangedAt,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Items
}
