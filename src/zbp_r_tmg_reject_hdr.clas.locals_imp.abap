CLASS lhc_RejectHdr DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations
      FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations
        FOR RejectHdr
      RESULT result.

    METHODS ProcessExcel
      FOR MODIFY
      IMPORTING
        keys FOR ACTION RejectHdr~ProcessExcel
      RESULT result.

ENDCLASS.

CLASS lhc_RejectHdr IMPLEMENTATION.

  METHOD get_global_authorizations.

    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.

  ENDMETHOD.

 METHOD ProcessExcel.

    TYPES:
      BEGIN OF ty_excel_row,
        rejection_code TYPE string,
        rejection_text TYPE string,
      END OF ty_excel_row.

    DATA lt_excel_rows TYPE STANDARD TABLE OF ty_excel_row WITH EMPTY KEY.

    " Read header and uploaded attachment
    READ ENTITIES OF zr_tmg_reject_hdr IN LOCAL MODE
      ENTITY RejectHdr
        FIELDS ( Order_Type Attachment FileName MimeType )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers)
      FAILED DATA(lt_read_failed).

    LOOP AT lt_headers INTO DATA(ls_header).

      CLEAR lt_excel_rows.

      IF ls_header-Attachment IS INITIAL.
        APPEND VALUE #( %tky = ls_header-%tky ) TO failed-rejecthdr.
        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Attach an Excel file before processing'
          )
        ) TO reported-rejecthdr.
        CONTINUE.
      ENDIF.

      TRY.
          " Open XLSX document
          DATA(lo_excel) = xco_cp_xlsx=>document->for_file_content(
            ls_header-Attachment
          )->read_access( ).

          " Read first worksheet
          DATA(lo_worksheet) = lo_excel->get_workbook( )->worksheet->at_position( 1 ).

          IF lo_worksheet->exists( ) = abap_false.
            CONTINUE.
          ENDIF.

          " Build pattern to select data
          DATA(lo_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).

          DATA(lo_operation) = lo_worksheet->select( lo_pattern )->row_stream( )->operation->write_to( REF #( lt_excel_rows ) ).

          " Use string_value transformation
          lo_operation->set_value_transformation(
            xco_cp_xlsx_read_access=>value_transformation->string_value
          ).

          lo_operation->if_xco_xlsx_ra_operation~execute( ).

          " Clean data and pad single-digit numbers with leading zeros (e.g., '1' -> '01')
          LOOP AT lt_excel_rows ASSIGNING FIELD-SYMBOL(<excel_row>).
            CONDENSE <excel_row>-rejection_code NO-GAPS.
            CONDENSE <excel_row>-rejection_text.

            " Pad numeric codes to 2 digits for proper string sorting
            IF <excel_row>-rejection_code IS NOT INITIAL AND <excel_row>-rejection_code CO '0123456789'.
              <excel_row>-rejection_code = |{ CONV i( <excel_row>-rejection_code ) WIDTH = 2 PAD = '0' ALIGN = RIGHT }|.
            ENDIF.
          ENDLOOP.

          DELETE lt_excel_rows WHERE rejection_code IS INITIAL.

          IF lt_excel_rows IS INITIAL.
            APPEND VALUE #(
              %tky = ls_header-%tky
              %msg = new_message_with_text(
                severity = if_abap_behv_message=>severity-error
                text     = 'Excel file does not contain any data'
              )
            ) TO reported-rejecthdr.
            CONTINUE.
          ENDIF.

          " Create child records with explicit numeric conversion for sortsequence
          MODIFY ENTITIES OF zr_tmg_reject_hdr IN LOCAL MODE
            ENTITY RejectHdr
              CREATE BY \_Items AUTO FILL CID
              FIELDS ( RejectionCode RejectionText sortsequence )
              WITH VALUE #(
                (
                  Order_Type = ls_header-Order_Type
                  %is_draft  = if_abap_behv=>mk-on
                  %target    = VALUE #(
                    FOR ls_excel IN lt_excel_rows (
                      %is_draft     = if_abap_behv=>mk-on
                      RejectionCode = CONV #( ls_excel-rejection_code )
                      RejectionText = CONV #( ls_excel-rejection_text )
                      sortsequence  = COND #(
                        WHEN ls_excel-rejection_code CO '0123456789'
                        THEN CONV i( ls_excel-rejection_code )
                        ELSE 0
                      )
                    )
                  )
                )
              )
            FAILED DATA(lt_create_failed)
            REPORTED DATA(lt_create_reported).

          IF lt_create_failed-rejectitem IS INITIAL.
            MODIFY ENTITIES OF zr_tmg_reject_hdr IN LOCAL MODE
              ENTITY RejectHdr
                UPDATE FIELDS ( UploadStatus UploadMessage )
                WITH VALUE #(
                  (
                    %tky          = ls_header-%tky
                    UploadStatus  = 'PROCESSED'
                    UploadMessage = |{ lines( lt_excel_rows ) } rows processed|
                  )
                ).

            APPEND VALUE #(
              %tky = ls_header-%tky
              %msg = new_message_with_text(
                severity = if_abap_behv_message=>severity-success
                text     = |{ lines( lt_excel_rows ) } rows processed|
              )
            ) TO reported-rejecthdr.
          ELSE.
            APPEND VALUE #(
              %tky = ls_header-%tky
              %msg = new_message_with_text(
                severity = if_abap_behv_message=>severity-error
                text     = 'Some Excel rows could not be created'
              )
            ) TO reported-rejecthdr.
          ENDIF.

        CATCH cx_root INTO DATA(lx_error).
          APPEND VALUE #( %tky = ls_header-%tky ) TO failed-rejecthdr.
          APPEND VALUE #(
            %tky = ls_header-%tky
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text     = lx_error->get_text( )
            )
          ) TO reported-rejecthdr.
      ENDTRY.

    ENDLOOP.

    " Return updated header
    READ ENTITIES OF zr_tmg_reject_hdr IN LOCAL MODE
      ENTITY RejectHdr
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #(
      FOR ls_result IN lt_result (
        %tky   = ls_result-%tky
        %param = ls_result
      )
    ).

  ENDMETHOD.
ENDCLASS.
