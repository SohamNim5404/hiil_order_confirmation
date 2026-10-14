"Message class: ZORDER_CONF. Maintain the accompanying SE91 texts first.
TYPES:
  BEGIN OF ty_message,
    number TYPE symsgno,
    v1     TYPE symsgv,
    v2     TYPE symsgv,
    v3     TYPE symsgv,
    v4     TYPE symsgv,
  END OF ty_message.

CLASS lcl_confirmation_buffer DEFINITION.
  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_entry,
        confirm_id TYPE sysuuid_x16,
        pid        TYPE abp_behv_pid,
      END OF ty_entry.

    CLASS-DATA entries TYPE STANDARD TABLE OF ty_entry
      WITH EMPTY KEY.

ENDCLASS.

CLASS lcl_confirmation_buffer IMPLEMENTATION.
ENDCLASS.

CLASS lcl_material_buffer DEFINITION.
  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_entry,
        confirm_id TYPE sysuuid_x16,
        pid        TYPE abp_behv_pid,
      END OF ty_entry.

    CLASS-DATA entries TYPE STANDARD TABLE OF ty_entry
      WITH EMPTY KEY.

ENDCLASS.

CLASS lcl_material_buffer IMPLEMENTATION.
ENDCLASS.

CLASS lhc_orderconfirmation DEFINITION
  INHERITING FROM cl_abap_behavior_handler.


  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_loading_reject,
        serialno   TYPE zi_serial_disposition-serialno,
        material   TYPE zi_serial_disposition-material,
        reasoncode TYPE zi_serial_disposition-reasoncode,
        reasontext TYPE zi_serial_disposition-reasontext,
        remarks    TYPE zi_serial_disposition-remarks,
      END OF ty_loading_reject,
      tt_loading_rejects TYPE STANDARD TABLE OF ty_loading_reject WITH EMPTY KEY,
      tt_serial_rows     TYPE STANDARD TABLE OF zi_serial_disposition WITH EMPTY KEY.

    CLASS-METHODS getloadingrejects
      IMPORTING is_header   TYPE zi_order_confirmation
      EXPORTING et_rejects  TYPE tt_loading_rejects
                ev_quantity TYPE decfloat34
                ev_error TYPE ty_message.
    CLASS-METHODS checkloadingsnapshot
      IMPORTING is_header       TYPE zi_order_confirmation
                it_serials      TYPE tt_serial_rows
      RETURNING VALUE(rv_error) TYPE ty_message.

  PRIVATE SECTION.

    METHODS get_instance_authorizations
      FOR INSTANCE AUTHORIZATION
      IMPORTING
                keys
                  REQUEST requested_authorizations
                  FOR orderconfirmation
      RESULT    result.



    METHODS get_instance_features
      FOR INSTANCE FEATURES
      IMPORTING
                keys   REQUEST requested_features
                  FOR orderconfirmation
      RESULT    result.


    METHODS setinitialstatus
      FOR DETERMINE ON MODIFY
      IMPORTING keys
                  FOR orderconfirmation~setinitialstatus.

    METHODS invalidateorderfetch
      FOR DETERMINE ON MODIFY
      IMPORTING keys
                  FOR orderconfirmation~invalidateorderfetch.

    METHODS validateorderfetched
      FOR VALIDATE ON SAVE
      IMPORTING keys
                  FOR orderconfirmation~validateorderfetched.

    METHODS validatesourcematerial
      FOR VALIDATE ON SAVE
      IMPORTING keys
                  FOR orderconfirmation~validatesourcematerial.

    METHODS validatetotalquantity
      FOR VALIDATE ON SAVE
      IMPORTING keys
                  FOR orderconfirmation~validatetotalquantity.


    METHODS validateserialcount
      FOR VALIDATE ON SAVE
      IMPORTING keys
                  FOR orderconfirmation~validateserialcount.

    METHODS fetchorderdata
      FOR MODIFY
      IMPORTING
                keys
                  FOR ACTION orderconfirmation~fetchorderdata
      RESULT    result.

    METHODS loadserials
      FOR MODIFY
      IMPORTING
                keys
                  FOR ACTION orderconfirmation~loadserials
      RESULT    result.


    METHODS submitandpost
      FOR MODIFY
      IMPORTING
                keys
                  FOR ACTION orderconfirmation~submitandpost
      RESULT    result.

    METHODS postmaterialdocument
      FOR MODIFY
      IMPORTING
                keys
                  FOR ACTION orderconfirmation~postmaterialdocument
      RESULT    result.

    METHODS cancelconfirmation FOR MODIFY
      IMPORTING keys
                  FOR ACTION orderconfirmation~cancelconfirmation
      RESULT    result.

    METHODS cancelloadedserials FOR MODIFY
      IMPORTING keys
                  FOR ACTION orderconfirmation~cancelloadedserials
      RESULT    result.

    METHODS validateloadingrejections FOR VALIDATE ON SAVE
      IMPORTING keys FOR orderconfirmation~validateloadingrejections.

ENDCLASS.


CLASS lhc_orderconfirmation IMPLEMENTATION.

  METHOD get_instance_authorizations.

    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation
        FIELDS ( orderno status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orders).

    result = VALUE #(
      FOR ls_order IN lt_orders
      (
        %tky = ls_order-%tky

        %update = COND #(
          WHEN requested_authorizations-%update = if_abap_behv=>mk-on
          THEN COND #(
            WHEN ls_order-orderno IS INITIAL
              OR ls_order-status = 'CREATED'
            THEN if_abap_behv=>auth-allowed
            ELSE if_abap_behv=>auth-unauthorized
          )
        )

        %delete = COND #(
          WHEN requested_authorizations-%delete = if_abap_behv=>mk-on
          THEN COND #(
            WHEN ls_order-orderno IS INITIAL
              OR ls_order-status = 'CREATED'
            THEN if_abap_behv=>auth-allowed
            ELSE if_abap_behv=>auth-unauthorized
          )
        )
      )
    ).

  ENDMETHOD.

  METHOD get_instance_features.

    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation
        FIELDS ( orderno status serialsposted )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orders).

    result = VALUE #(
      FOR ls_order IN lt_orders
      (
        %tky = ls_order-%tky

        %features-%delete = COND #(
          WHEN ls_order-orderno IS INITIAL
            OR ls_order-status = 'CREATED'
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled
        )

        %features-%action-edit = COND #(
          WHEN ls_order-orderno IS INITIAL
            OR ls_order-status = 'CREATED'
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled
        )

        "Step 1: Submit and Post
        %features-%action-submitandpost = COND #(
          WHEN ls_order-status = 'CREATED'
            AND ls_order-serialsposted = abap_false
            AND ls_order-%is_draft = if_abap_behv=>mk-off
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled
        )

        "Step 2: Post Loaded Serials after successful posting
        %features-%action-postmaterialdocument = COND #(
          WHEN ls_order-status = 'PART_POST'
            AND ls_order-serialsposted = abap_false
            AND ls_order-%is_draft = if_abap_behv=>mk-off
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled
        )

        "Cancellation step 1: Cancel Confirmation
        %features-%action-cancelconfirmation = COND #(
          WHEN ( ls_order-status = 'PART_POST'
    OR ls_order-status = 'POSTED' )
  AND ls_order-%is_draft = if_abap_behv=>mk-off
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled
        )

        "Cancellation step 2: Cancel Loaded Serials
        %features-%action-cancelloadedserials = COND #(
          WHEN ls_order-status = 'CANCELLED'
            AND ls_order-serialsposted = abap_true
            AND ls_order-%is_draft = if_abap_behv=>mk-off
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled
        )
      )
    ).

  ENDMETHOD.

  METHOD setinitialstatus.

    MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
   ENTITY orderconfirmation
     UPDATE FIELDS ( status hidematerialselection )
     WITH VALUE #(
       FOR key IN keys
       (
         %tky = key-%tky
         status = 'CREATED'
         hidematerialselection = abap_true
       )
     ).

  ENDMETHOD.

  METHOD invalidateorderfetch.

    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation
        FIELDS ( fetchedorderno )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation
        UPDATE FIELDS ( fetchedorderno )
        WITH VALUE #(
          FOR ls_header IN lt_headers
          WHERE (
            %is_draft = if_abap_behv=>mk-on
            AND fetchedorderno IS NOT INITIAL
          )
          (
            %tky           = ls_header-%tky
            fetchedorderno = ''
          )
        ).

  ENDMETHOD.

  METHOD validateorderfetched.

    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation
        FIELDS ( orderno fetchedorderno status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers INTO DATA(ls_header).

      "Clear previous validation messages
      APPEND VALUE #(
        %tky = ls_header-%tky
        %state_area = 'ORDER_FETCH'
      ) TO reported-orderconfirmation.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %state_area = 'REMAINING_QUANTITY'
      ) TO reported-orderconfirmation.

      "Apply only to new confirmations
      IF ls_header-status IS NOT INITIAL
         AND ls_header-status <> 'CREATED'.
        CONTINUE.
      ENDIF.

      DATA(lv_order_no) = ls_header-orderno.
      DATA(lv_fetched_order_no) = ls_header-fetchedorderno.

      lv_order_no = |{ lv_order_no ALPHA = IN }|.
      lv_fetched_order_no = |{ lv_fetched_order_no ALPHA = IN }|.

      IF ls_header-orderno IS INITIAL
         OR ls_header-fetchedorderno IS INITIAL
         OR lv_order_no <> lv_fetched_order_no.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %state_area = 'ORDER_FETCH'
          %element-orderno = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '071'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-orderconfirmation.

        CONTINUE.
      ENDIF.

      "Read current quantities; avoid DCL checks in save validation
      SELECT SINGLE
        FROM i_manufacturingorder WITH PRIVILEGED ACCESS
        FIELDS mfgorderplannedtotalqty,
               mfgorderconfirmedyieldqty,
               mfgorderconfirmedscrapqty
        WHERE manufacturingorder = @lv_order_no
        INTO @DATA(ls_current_order).

      DATA(lv_error) = VALUE ty_message( ).

      IF sy-subrc <> 0.
        lv_error = VALUE ty_message( number = '001' ).
      ELSE.

        DATA(lv_remaining_qty) =
            ls_current_order-mfgorderplannedtotalqty
          - ls_current_order-mfgorderconfirmedyieldqty
          - ls_current_order-mfgorderconfirmedscrapqty.

        IF lv_remaining_qty <= 0.
          lv_error =
            VALUE ty_message( number = '002' ).
        ENDIF.

      ENDIF.

      IF lv_error IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %state_area = 'REMAINING_QUANTITY'
          %element-orderno = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-orderconfirmation.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validatesourcematerial.
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation
        FIELDS ( selectedmaterial loadedsourcematerial status order_type )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers INTO DATA(ls_header).
      APPEND VALUE #(
        %tky = ls_header-%tky
        %state_area = 'SOURCE_MATERIAL'
      ) TO reported-orderconfirmation.

      IF ls_header-order_type <> 'ZP09'.
        CONTINUE.
      ENDIF.

      "Selection validation applies to confirmations still being prepared
      IF ls_header-status IS NOT INITIAL
         AND ls_header-status <> 'CREATED'.
        CONTINUE.
      ENDIF.

      READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY orderconfirmation BY \_serials
          FIELDS ( serialno )
          WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_serials)
        FAILED DATA(ls_read_failed).

      DATA(lv_error) = VALUE ty_message( ).
      IF ls_read_failed IS NOT INITIAL.
        lv_error = VALUE ty_message( number = '003' ).
      ELSEIF lt_serials IS NOT INITIAL
         AND ( ls_header-loadedsourcematerial IS INITIAL
            OR ls_header-selectedmaterial <> ls_header-loadedsourcematerial ).
        lv_error = VALUE ty_message( number = '004' ).
      ENDIF.

      IF lv_error IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_header-%tky )
          TO failed-orderconfirmation.
        APPEND VALUE #(
          %tky = ls_header-%tky
          %state_area = 'SOURCE_MATERIAL'
          %element-selectedmaterial = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-orderconfirmation.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validatetotalquantity.

    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation
        FIELDS ( qtytoconfirm scrapqty loadingrejectionqty remainingqty )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers INTO DATA(ls_header).

      "Clear the previous validation message
      APPEND VALUE #(
        %tky        = ls_header-%tky
        %state_area = 'TOTAL_QUANTITY'
      ) TO reported-orderconfirmation.

      DATA(lv_total) =
        CONV decfloat34( ls_header-qtytoconfirm )
        + CONV decfloat34( ls_header-scrapqty )
        + CONV decfloat34( ls_header-loadingrejectionqty ).

      DATA(lv_error) = VALUE ty_message( ).

      IF ls_header-qtytoconfirm < 0
         OR ls_header-scrapqty < 0
         OR ls_header-loadingrejectionqty < 0.

        lv_error = VALUE ty_message( number = '005' ).

      ELSEIF lv_total > ls_header-remainingqty.

        lv_error =
          VALUE ty_message( number = '006' ).

      ENDIF.

      IF lv_error IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky                  = ls_header-%tky
          %state_area           = 'TOTAL_QUANTITY'
          %element-qtytoconfirm = if_abap_behv=>mk-on
          %element-scrapqty     = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-orderconfirmation.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD validateserialcount.

    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation
        FIELDS ( qtytoconfirm scrapqty loadingrejectionqty )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers INTO DATA(ls_header).

      "Clear previous validation message
      APPEND VALUE #(
        %tky        = ls_header-%tky
        %state_area = 'SERIAL_COUNT'
      ) TO reported-orderconfirmation.

      READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY orderconfirmation BY \_serials
          FIELDS ( approved rejected )
          WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_serials)
        FAILED DATA(ls_read_failed).

      DATA(lv_approved) = 0.
      DATA(lv_rejected) = 0.
      DATA(lv_error) = VALUE ty_message( ).

      IF ls_read_failed IS NOT INITIAL.

        lv_error = VALUE ty_message( number = '007' ).

      ELSE.

        LOOP AT lt_serials INTO DATA(ls_serial).

          IF ls_serial-approved = abap_true
             AND ls_serial-rejected = abap_true.

            lv_error =
              VALUE ty_message( number = '008' ).
            EXIT.

          ENDIF.

          IF ls_serial-approved = abap_true.
            lv_approved += 1.
          ENDIF.

          IF ls_serial-rejected = abap_true.
            lv_rejected += 1.
          ENDIF.

        ENDLOOP.

        IF lv_error IS INITIAL.

          IF CONV decfloat34( lv_approved )
               <> CONV decfloat34( ls_header-qtytoconfirm )
             OR CONV decfloat34( lv_rejected )
               <> ( CONV decfloat34( ls_header-scrapqty )
                    + CONV decfloat34( ls_header-loadingrejectionqty ) ).

            lv_error =
     VALUE ty_message( number = '009'
          v1 = |{ ls_header-qtytoconfirm NUMBER = RAW DECIMALS = 0 }|
          v2 = |{ ls_header-scrapqty + ls_header-loadingrejectionqty NUMBER = RAW DECIMALS = 0 }|
          v3 = |{ lv_approved }|
          v4 = |{ lv_rejected }| ).

          ENDIF.

        ENDIF.

      ENDIF.

      IF lv_error IS NOT INITIAL.

        "Fail header only once
        IF NOT line_exists(
             failed-orderconfirmation[
               %tky = ls_header-%tky
             ]
           ).

          APPEND VALUE #(
            %tky = ls_header-%tky
          ) TO failed-orderconfirmation.

        ENDIF.

        "Return serial validation message
        APPEND VALUE #(
          %tky        = ls_header-%tky
          %state_area = 'SERIAL_COUNT'

          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )

        ) TO reported-orderconfirmation.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD fetchorderdata.

    DATA:
      lv_loading_rejection_qty TYPE p LENGTH 8 DECIMALS 3,
      lv_order_external        TYPE c LENGTH 12.

    "Read Order Number from current draft
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation
        FIELDS ( orderno scrapqty qtytoconfirm  )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers)
      FAILED failed.

    LOOP AT lt_headers INTO DATA(ls_header).

      "Validation: Order Number is mandatory
      IF ls_header-orderno IS INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky

          %element-orderno =
                if_abap_behv=>mk-on

          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '072'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-orderconfirmation.

        CONTINUE.

      ENDIF.

      DATA(lv_order_no) = ls_header-orderno.
      lv_order_no = |{ lv_order_no ALPHA = IN }|.

      "Read manufacturing-order data
      SELECT SINGLE
        FROM i_manufacturingorder
        FIELDS material,
              batch,
              mfgorderscheduledstartdate,
              mfgorderscheduledenddate,
              mfgorderscheduledstarttime,
              mfgorderscheduledendtime,
               productionplant,
               manufacturingordertype,
               mfgorderplannedtotalqty,
               mfgorderconfirmedyieldqty,
               mfgorderconfirmedscrapqty
        WHERE manufacturingorder = @lv_order_no
        INTO @DATA(ls_order).

      "Validation: Order must exist
      IF sy-subrc <> 0.

        APPEND VALUE #(
          %tky = ls_header-%tky

          %element-orderno =
            if_abap_behv=>mk-on

          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '073'
            severity = if_abap_behv_message=>severity-error
            v1       = |{ ls_header-orderno }|
          )
        ) TO reported-orderconfirmation.

        CONTINUE.

      ENDIF.

      "ZP01/YP01 orders must be confirmed through CO11N
      IF ls_order-manufacturingordertype = 'ZP01'
         OR ls_order-manufacturingordertype = 'YP01'.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %element-orderno = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '074'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-orderconfirmation.

        CONTINUE.
      ENDIF.

      "release status
      SELECT SINGLE
     FROM i_manufacturingorderstatus
     FIELDS statuscode,
            statusisactive
     WHERE manufacturingorder = @lv_order_no
       AND statuscode          = 'I0002'
     INTO @DATA(ls_release_status).

      IF sy-subrc <> 0
         OR ls_release_status-statusisactive IS INITIAL.

        "Mark Fetch Order Data as failed
        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        "Show error
        APPEND VALUE #(
          %tky = ls_header-%tky
          %element-orderno = if_abap_behv=>mk-on

          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '075'
            severity = if_abap_behv_message=>severity-error
            v1       = |{ ls_header-orderno }|
          )
        ) TO reported-orderconfirmation.

        CONTINUE.

      ENDIF.


      "Validation: Batch is mandatory
      IF ls_order-batch IS INITIAL.

        "Mark the RAP operation as FAILED
        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        "Return ERROR message
        APPEND VALUE #(
          %tky = ls_header-%tky
          %element-batch_number = if_abap_behv=>mk-on

          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '076'
            severity = if_abap_behv_message=>severity-error
            v1       = |{ ls_header-orderno }|
          )
        ) TO reported-orderconfirmation.

        CONTINUE.

      ENDIF.

      SELECT SINGLE
           FROM i_productdescription
           FIELDS productdescription
           WHERE product  = @ls_order-material
             AND language = @sy-langu
           INTO @DATA(lv_mat_desc).

      SELECT SINGLE
           FROM i_manufacturingorderoperation
           FIELDS manufacturingorderoperation_2,workcenterinternalid,productionunit,
            opqtytobaseqtydnmntr,opqtytobaseqtynmrtr
           WHERE manufacturingorder  = @lv_order_no
           INTO @DATA(lv_operation).

      SELECT SINGLE
        FROM i_workcenter
        FIELDS workcenter
        WHERE workcenterinternalid  = @lv_operation-workcenterinternalid
        INTO @DATA(lv_workcenter).



      "Fetch saved Loading Rejection quantity for this exact order context
      CLEAR: lv_loading_rejection_qty, lv_order_external.
      lv_order_external = |{ lv_order_no ALPHA = OUT }|.

      SELECT SUM( loadingrejqty )
        FROM zi_load_rej_hdr
        WITH PRIVILEGED ACCESS
        WHERE ( prodorder = @lv_order_no
             OR prodorder = @lv_order_external )
          AND ordertype = @ls_order-manufacturingordertype
          AND plant = @ls_order-productionplant
          AND batchnumber = @ls_order-batch
          AND material = @ls_order-material
        INTO @lv_loading_rejection_qty.

      "Calculate Remaining Quantity
      DATA(lv_remaining_qty) =
          ( ls_order-mfgorderplannedtotalqty - ls_order-mfgorderconfirmedyieldqty -  ls_order-mfgorderconfirmedscrapqty ).


      DATA(lv_confirmed_qty_wt) =  ( ls_header-qtytoconfirm + ls_header-scrapqty ) *
       ( lv_operation-opqtytobaseqtydnmntr / lv_operation-opqtytobaseqtynmrtr ).

      "Validation: Remaining Quantity must be greater than zero
      IF lv_remaining_qty <= 0.

        APPEND VALUE #(
          %tky = ls_header-%tky

          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '077'
            severity = if_abap_behv_message=>severity-error
            v1       = |{ ls_header-orderno }|
          )
        ) TO reported-orderconfirmation.


      ENDIF.

      "Update fetched data in the current draft
      MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY orderconfirmation
          UPDATE FIELDS (
            material
            mat_desc
            plant
            batch_number
            postingdate
            start_end_date
            starttime
            endtime
            unit
            displayunit
            order_type
            orderqty
            confirmedqty
            confirmedscrapqty
            remainingqty
            operation
            workcenter
            weightqty
            loadingrejectionqty
          )
          WITH VALUE #(
            (
              %tky         = ls_header-%tky
              material     = ls_order-material
              mat_desc     = lv_mat_desc
              plant        = ls_order-productionplant
              batch_number = ls_order-batch
              postingdate  = ls_order-mfgorderscheduledstartdate
              start_end_date = ls_order-mfgorderscheduledenddate
              starttime      = ls_order-mfgorderscheduledstarttime
              endtime        = ls_order-mfgorderscheduledendtime
              unit     = lv_operation-productionunit
              displayunit = COND #(
                                   WHEN lv_operation-productionunit = 'ST'
                                    THEN 'PC'
                                     ELSE lv_operation-productionunit
                        )
              order_type   = ls_order-manufacturingordertype
              orderqty     = ls_order-mfgorderplannedtotalqty
              confirmedqty = ls_order-mfgorderconfirmedyieldqty
              confirmedscrapqty = ls_order-mfgorderconfirmedscrapqty
              remainingqty = lv_remaining_qty
              operation    = lv_operation-manufacturingorderoperation_2
              loadingrejectionqty = lv_loading_rejection_qty
              weightqty  = lv_confirmed_qty_wt
              workcenter   = lv_workcenter )
          )
        FAILED DATA(lt_update_failed)
        REPORTED DATA(lt_update_reported).

      "Pass update failures to RAP
      APPEND LINES OF lt_update_failed-orderconfirmation
        TO failed-orderconfirmation.

      "Pass update messages to RAP
      APPEND LINES OF lt_update_reported-orderconfirmation
        TO reported-orderconfirmation.

      "Success message

      "Only fetch scrap materials when header update was successful
      IF lt_update_failed-orderconfirmation IS INITIAL.

        "====================================================
        "ADD SCRAP MATERIAL FETCH LOGIC HERE
        "====================================================

        "1. Read movement type 531 components
        SELECT FROM i_productionordercomponent AS comp
  LEFT OUTER JOIN i_productdescription AS txt
    ON txt~product = comp~material
   AND txt~language = @sy-langu

  FIELDS
    comp~material,
    txt~productdescription,
    comp~storagelocation,
    comp~requiredquantity,
    comp~baseunit

  WHERE comp~productionorder = @lv_order_no
    AND comp~goodsmovementtype = '531'
    AND comp~matlcompismarkedforbackflush = 'X'

  INTO TABLE @DATA(lt_scrap_components).

        DELETE lt_scrap_components
          WHERE material IS INITIAL.


        "2. Read existing scrap rows
        READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
          ENTITY orderconfirmation BY \_scrapitems
            FIELDS ( scrapitemid )
            WITH VALUE #(
              (
                %tky = ls_header-%tky
              )
            )
          RESULT DATA(lt_existing_scrap).


        "3. Delete old rows to avoid duplicates
        IF lt_existing_scrap IS NOT INITIAL.

          MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
            ENTITY scrapitem
              DELETE FROM VALUE #(
                FOR ls_existing_scrap IN lt_existing_scrap
                (
                  %tky = ls_existing_scrap-%tky
                )
              )
            FAILED DATA(lt_scrap_delete_failed)
            REPORTED DATA(lt_scrap_delete_reported).

          APPEND LINES OF lt_scrap_delete_failed-scrapitem
            TO failed-scrapitem.

          APPEND LINES OF lt_scrap_delete_reported-scrapitem
            TO reported-scrapitem.

        ENDIF.


        "4. Create new scrap rows
        IF lt_scrap_components IS NOT INITIAL.

          MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
            ENTITY orderconfirmation
              CREATE BY \_scrapitems AUTO FILL CID
                FIELDS (
                  scrapmaterial
                  scrapdesc
                  storagelocation
                  scrapqty
                  scrapunit
                  displayscrapunit
                )
                WITH VALUE #(
                  (
                    %tky      = ls_header-%tky
                    %is_draft = ls_header-%is_draft

                    %target = VALUE #(
                      FOR ls_component IN lt_scrap_components
                      (
                        %is_draft       = ls_header-%is_draft
                        scrapmaterial   = ls_component-material
                        scrapdesc       = ls_component-productdescription
                        storagelocation = ls_component-storagelocation

                        scrapqty = COND #(
                          WHEN ls_component-requiredquantity < 0
                          THEN ls_component-requiredquantity * -1
                          ELSE ls_component-requiredquantity
                        )
                        scrapunit       = ls_component-baseunit
                        displayscrapunit = COND #(
  WHEN ls_component-baseunit = 'ST'
  THEN 'PC'
  ELSE ls_component-baseunit
)
                      )
                    )
                  )
                )
            MAPPED DATA(lt_scrap_mapped)
            FAILED DATA(lt_scrap_create_failed)
            REPORTED DATA(lt_scrap_create_reported).

          APPEND LINES OF lt_scrap_create_failed-orderconfirmation
            TO failed-orderconfirmation.

          APPEND LINES OF lt_scrap_create_failed-scrapitem
            TO failed-scrapitem.

          APPEND LINES OF lt_scrap_create_reported-orderconfirmation
            TO reported-orderconfirmation.

          APPEND LINES OF lt_scrap_create_reported-scrapitem
            TO reported-scrapitem.

        ENDIF.

        "------------------------------------------------------------
        "Production Activity: fetch values and create six fixed rows
        "------------------------------------------------------------

        "Read values for the operation selected earlier in this method
        SELECT FROM i_manufacturingorderoperation AS op

          LEFT OUTER JOIN i_standardworkfmlaparamgroup AS grp
            ON grp~standardworkformulaparamgroup =
               op~standardworkformulaparamgroup

          FIELDS
            op~manufacturingorderoperation_2 AS operation,
            op~operationreferencequantity,
            op~workcenterstandardworkqty1,
            op~workcenterstandardworkqty2,
            op~workcenterstandardworkqty3,
            op~workcenterstandardworkqty4,
            op~workcenterstandardworkqty5,
            op~workcenterstandardworkqty6,

            op~workcenterstandardworkqtyunit1,
            op~workcenterstandardworkqtyunit2,
            op~workcenterstandardworkqtyunit3,
            op~workcenterstandardworkqtyunit4,
            op~workcenterstandardworkqtyunit5,
            op~workcenterstandardworkqtyunit6,

            grp~standardworkformulaparam1,
            grp~standardworkformulaparam2,
            grp~standardworkformulaparam3,
            grp~standardworkformulaparam4,
            grp~standardworkformulaparam5,
            grp~standardworkformulaparam6

          WHERE op~manufacturingorder = @lv_order_no
            AND op~manufacturingorderoperation_2 =
                @lv_operation-manufacturingorderoperation_2

          INTO TABLE @DATA(lt_activity_source).

        "Do not silently choose between multiple matching operations
        IF lines( lt_activity_source ) > 1.

          APPEND VALUE #(
            %tky = ls_header-%tky
          ) TO failed-orderconfirmation.

          APPEND VALUE #(
            %tky = ls_header-%tky
            %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '078'
            severity = if_abap_behv_message=>severity-error
          )
          ) TO reported-orderconfirmation.

          CONTINUE.

        ENDIF.

        "An empty structure allows six blank/default rows when no data exists
        DATA ls_activity_source LIKE LINE OF lt_activity_source.

        CLEAR ls_activity_source.

        READ TABLE lt_activity_source
          INDEX 1
          INTO ls_activity_source.

        IF ls_activity_source-operationreferencequantity <= 0.

          APPEND VALUE #(
            %tky = ls_header-%tky
          ) TO failed-orderconfirmation.

          APPEND VALUE #(
            %tky = ls_header-%tky
            %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '079'
            severity = if_abap_behv_message=>severity-error
          )
          ) TO reported-orderconfirmation.

          CONTINUE.

        ENDIF.

        DATA:
          lv_activity_slot  TYPE n LENGTH 1,
          lv_activity_param TYPE ztb_order_act-activity_param,
          lv_activity_name  TYPE ztb_order_act-activity_name,
          lv_activity_qty   TYPE ztb_order_act-activity_qty,
          lv_activity_unit  TYPE ztb_order_act-activity_unit.

        DATA lt_activity_create TYPE TABLE FOR CREATE
          zi_order_confirmation\_activities.

        CLEAR lt_activity_create.

        APPEND INITIAL LINE TO lt_activity_create
          ASSIGNING FIELD-SYMBOL(<activity_request>).

        <activity_request>-%tky = ls_header-%tky.
        <activity_request>-%is_draft = ls_header-%is_draft.

        "Always build all six rows
        DO 6 TIMES.

          lv_activity_slot = sy-index.

          CLEAR:
            lv_activity_param,
            lv_activity_name,
            lv_activity_qty,
            lv_activity_unit.

          DATA(lv_param_field) =
            |STANDARDWORKFORMULAPARAM{ lv_activity_slot }|.

          DATA(lv_qty_field) =
            |WORKCENTERSTANDARDWORKQTY{ lv_activity_slot }|.

          DATA(lv_unit_field) =
            |WORKCENTERSTANDARDWORKQTYUNIT{ lv_activity_slot }|.

          "Parameter for this slot
          ASSIGN COMPONENT lv_param_field
            OF STRUCTURE ls_activity_source
            TO FIELD-SYMBOL(<activity_param>).

          IF sy-subrc = 0.
            lv_activity_param = <activity_param>.
          ENDIF.

          "Quantity for this slot
          ASSIGN COMPONENT lv_qty_field
            OF STRUCTURE ls_activity_source
            TO FIELD-SYMBOL(<activity_qty>).

          IF sy-subrc = 0.


            lv_activity_qty =
                           ( CONV decfloat34( <activity_qty> )
                             / CONV decfloat34(
                                 ls_activity_source-operationreferencequantity ) )
                           * ( CONV decfloat34( lv_confirmed_qty_wt ) ).
          ENDIF.

          "Unit for this slot
          ASSIGN COMPONENT lv_unit_field
            OF STRUCTURE ls_activity_source
            TO FIELD-SYMBOL(<activity_unit>).

          IF sy-subrc = 0.
            lv_activity_unit = <activity_unit>.
          ENDIF.

          "Use the parameter ID to find its description
          IF lv_activity_param IS NOT INITIAL.

            SELECT SINGLE
              FROM i_standardworkformulaparamtext
              FIELDS standardworkformulaparamname
              WHERE standardworkformulaparameter = @lv_activity_param
                AND language = @sy-langu
              INTO @lv_activity_name.

          ENDIF.

          "Skip empty activity slots
          IF lv_activity_param IS INITIAL
             AND lv_activity_name IS INITIAL
             AND lv_activity_qty IS INITIAL
             AND lv_activity_unit IS INITIAL.
            CONTINUE.
          ENDIF.

          APPEND VALUE #(
            %is_draft = ls_header-%is_draft

            operation =
              lv_operation-manufacturingorderoperation_2

            activityslot  = lv_activity_slot
            activitylabel = |Activity { lv_activity_slot }|
            activityparam = lv_activity_param
            activityname  = lv_activity_name
            activityqty   = lv_activity_qty
            activityunit  = lv_activity_unit
            displayactivityunit = COND #(
             WHEN lv_activity_unit = 'STD'
             THEN 'HRS'
             ELSE lv_activity_unit
)

          ) TO <activity_request>-%target.

        ENDDO.

        "Read existing rows before replacing them
        READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
          ENTITY orderconfirmation BY \_activities
            ALL FIELDS
            WITH VALUE #( ( %tky = ls_header-%tky ) )
          RESULT DATA(lt_existing_activities)
          FAILED DATA(ls_activity_read_failed)
          REPORTED DATA(ls_activity_read_reported).

        APPEND LINES OF ls_activity_read_reported-orderconfirmation
          TO reported-orderconfirmation.

        APPEND LINES OF ls_activity_read_reported-activity
          TO reported-activity.

        IF ls_activity_read_failed IS NOT INITIAL.

          APPEND VALUE #(
            %tky = ls_header-%tky
          ) TO failed-orderconfirmation.

          APPEND VALUE #(
            %tky = ls_header-%tky
            %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '080'
            severity = if_abap_behv_message=>severity-error
          )
          ) TO reported-orderconfirmation.

          CONTINUE.

        ENDIF.

        "Delete the previous snapshot to prevent duplicates
        IF lt_existing_activities IS NOT INITIAL.

          MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
            ENTITY activity
              DELETE FROM VALUE #(
                FOR ls_existing_activity IN lt_existing_activities
                ( %tky = ls_existing_activity-%tky )
              )
            FAILED DATA(ls_activity_delete_failed)
            REPORTED DATA(ls_activity_delete_reported).

          APPEND LINES OF ls_activity_delete_failed-activity
            TO failed-activity.

          APPEND LINES OF ls_activity_delete_reported-activity
            TO reported-activity.

          IF ls_activity_delete_failed IS NOT INITIAL.

            APPEND VALUE #(
              %tky = ls_header-%tky
            ) TO failed-orderconfirmation.

            CONTINUE.

          ENDIF.

        ENDIF.

        "Create six refreshed activity rows
        MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
          ENTITY orderconfirmation
            CREATE BY \_activities AUTO FILL CID
              FIELDS (
                operation
                activityslot
                activitylabel
                activityparam
                activityname
                activityqty
                activityunit
                displayactivityunit
              )
              WITH lt_activity_create

          FAILED DATA(ls_activity_create_failed)
          REPORTED DATA(ls_activity_create_reported).

        APPEND LINES OF ls_activity_create_failed-orderconfirmation
          TO failed-orderconfirmation.

        APPEND LINES OF ls_activity_create_failed-activity
          TO failed-activity.

        APPEND LINES OF ls_activity_create_reported-orderconfirmation
          TO reported-orderconfirmation.

        APPEND LINES OF ls_activity_create_reported-activity
          TO reported-activity.

        IF ls_activity_create_failed IS NOT INITIAL.

          IF NOT line_exists(
            failed-orderconfirmation[ %tky = ls_header-%tky ]
          ).

            APPEND VALUE #(
              %tky = ls_header-%tky
            ) TO failed-orderconfirmation.

          ENDIF.

          CONTINUE.

        ENDIF.

        "Do not mark fetching successful if scrap processing failed
        IF ( lt_existing_scrap IS NOT INITIAL
             AND lt_scrap_delete_failed IS NOT INITIAL )
           OR ( lt_scrap_components IS NOT INITIAL
                AND lt_scrap_create_failed IS NOT INITIAL ).
          CONTINUE.
        ENDIF.

        "Remember which order was successfully fetched
        MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
          ENTITY orderconfirmation
           UPDATE FIELDS ( fetchedorderno hidematerialselection )
            WITH VALUE #(
              (
                %tky = ls_header-%tky
                fetchedorderno = lv_order_no
                hidematerialselection = xsdbool(
                  ls_order-manufacturingordertype <> 'ZP09'
                )
              )
            )
          FAILED DATA(ls_fetch_mark_failed)
          REPORTED DATA(ls_fetch_mark_reported).

        APPEND LINES OF ls_fetch_mark_failed-orderconfirmation
          TO failed-orderconfirmation.

        APPEND LINES OF ls_fetch_mark_reported-orderconfirmation
          TO reported-orderconfirmation.

        IF ls_fetch_mark_failed IS NOT INITIAL.
          CONTINUE.
        ENDIF.

        "5. Existing success message
        APPEND VALUE #(
          %tky = ls_header-%tky

          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '081'
            severity = if_abap_behv_message=>severity-success
            v1       = |{ ls_header-orderno }|
          )
        ) TO reported-orderconfirmation.

      ENDIF.

    ENDLOOP.

    "Read the updated draft data
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_updated_headers)
      FAILED DATA(lt_read_failed)
      REPORTED DATA(lt_read_reported).

    "Pass read failures and messages to RAP
    APPEND LINES OF lt_read_failed-orderconfirmation
      TO failed-orderconfirmation.

    APPEND LINES OF lt_read_reported-orderconfirmation
      TO reported-orderconfirmation.

    "Return updated data to the Fiori screen
    result = VALUE #(
      FOR ls_updated_header IN lt_updated_headers
      (
        %tky   = ls_updated_header-%tky
        %param = ls_updated_header
      )
    ).

  ENDMETHOD.



  METHOD loadserials.

    TYPES:
      BEGIN OF ty_load_serial,
        serialnumber TYPE i_serialnumbermaterialdoc_2-serialnumber,
      END OF ty_load_serial.

    DATA:
      lt_serials TYPE STANDARD TABLE OF ty_load_serial
                   WITH EMPTY KEY,
      lv_error TYPE ty_message.

    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers)
      FAILED failed.

    LOOP AT lt_headers INTO DATA(ls_header).

      CLEAR:
        lt_serials,
        lv_error.

      DATA(lv_use_material_selection) = xsdbool( ls_header-order_type = 'ZP09' ).

      "Validate header
      IF ls_header-%is_draft = if_abap_behv=>mk-off.
        lv_error = VALUE ty_message( number = '010' ).

      ELSEIF ls_header-orderno IS INITIAL.
        lv_error = VALUE ty_message( number = '011' ).

      ELSEIF lv_use_material_selection = abap_true
         AND ls_header-selectedmaterial IS INITIAL.
        lv_error = VALUE ty_message( number = '012' ).

      ELSEIF lv_use_material_selection = abap_true
         AND ls_header-fetchedorderno IS INITIAL.
        lv_error = VALUE ty_message( number = '013' ).

      ELSEIF ls_header-material IS INITIAL.
        lv_error = VALUE ty_message( number = '014' ).
      ENDIF.

      IF lv_error IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-orderconfirmation.

        CONTINUE.
      ENDIF.

      getloadingrejects( EXPORTING is_header = CORRESPONDING #( ls_header )
        IMPORTING et_rejects = DATA(lt_loading_rejects)
                  ev_quantity = DATA(lv_loading_quantity)
                  ev_error = DATA(lv_loading_error) ).
      IF lv_loading_error IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_header-%tky ) TO failed-orderconfirmation.
        APPEND VALUE #( %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_loading_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_loading_error-v1
            v2       = lv_loading_error-v2
            v3       = lv_loading_error-v3
            v4       = lv_loading_error-v4
          )
        ) TO reported-orderconfirmation.
        CONTINUE.
      ENDIF.

      DATA(lv_load_order) = ls_header-orderno.
      lv_load_order = |{ lv_load_order ALPHA = IN }|.

      IF lv_use_material_selection = abap_true.
        DATA(lv_fetched_order) = ls_header-fetchedorderno.
        lv_fetched_order = |{ lv_fetched_order ALPHA = IN }|.

        SELECT SINGLE FROM zi_oc_material_vh
          FIELDS material
          WHERE orderno = @lv_load_order
            AND material = @ls_header-selectedmaterial
          INTO @DATA(lv_valid_material).

        IF sy-subrc <> 0 OR lv_fetched_order <> lv_load_order.
          APPEND VALUE #( %tky = ls_header-%tky ) TO failed-orderconfirmation.
          APPEND VALUE #(
            %tky = ls_header-%tky
            %element-selectedmaterial = if_abap_behv=>mk-on
            %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '082'
            severity = if_abap_behv_message=>severity-error
          )
          ) TO reported-orderconfirmation.
          CONTINUE.
        ENDIF.

      ENDIF.

      DATA(lv_order_external) =
        |{ lv_load_order ALPHA = OUT }|.

      DATA(lv_use_kiln_mapping) = xsdbool(
        ls_header-order_type = 'ZP07'
        OR ls_header-order_type = 'YP07'
      ).

      "ZP02/YP02: fetch serials directly from the manufacturing order
      IF ls_header-order_type = 'ZP02'
         OR ls_header-order_type = 'YP02'.

        SELECT FROM i_serialnumbermanufacturingord
          FIELDS DISTINCT serialnumber
          WHERE manufacturingorder = @lv_load_order
          INTO TABLE @lt_serials.

        DELETE lt_serials WHERE serialnumber IS INITIAL.

        IF lt_serials IS INITIAL AND lt_loading_rejects IS INITIAL.
          lv_error =
            VALUE ty_message( number = '015'
          v1 = |{ ls_header-orderno }| ).
        ENDIF.

      ELSE.

        "Filter source document items by the user's selected material
        SELECT FROM zi_oc_serial_doc AS item
          INNER JOIN i_serialnumbermaterialdoc_2 AS serial
            ON serial~materialdocument = item~materialdocument
           AND serial~materialdocumentyear = item~materialdocumentyear
           AND serial~materialdocumentitem = item~materialdocumentitem
          FIELDS DISTINCT item~material, item~batch, serial~serialnumber
          WHERE item~orderno = @lv_load_order
            AND ( @lv_use_material_selection = @abap_false
               OR item~material = @ls_header-selectedmaterial )
          INTO TABLE @DATA(lt_source_serials).

        DELETE lt_source_serials
          WHERE serialnumber IS INITIAL.

        IF lt_source_serials IS INITIAL AND lt_loading_rejects IS INITIAL.
          lv_error =
            VALUE ty_message( number = '015'
          v1 = |{ ls_header-orderno }| ).
        ENDIF.


        "Validate all mappings before modifying draft rows
        IF lv_error IS INITIAL.

          IF lv_use_kiln_mapping = abap_true.

            LOOP AT lt_source_serials INTO DATA(ls_source).

              DATA(lv_glazed_serial) =
        |{ ls_source-serialnumber ALPHA = OUT }|.

              SELECT FROM zc_kiln_itm
                FIELDS
                  kilnmaterial,
                  kilnserialno
                WHERE glazedmaterial = @ls_source-material
                  AND glazedbatchno  = @ls_source-batch
                  AND glazedserialno = @lv_glazed_serial
                INTO TABLE @DATA(lt_mapping).

              IF lt_mapping IS INITIAL.
                lv_error =
                  VALUE ty_message( number = '016'
          v1 = |{ ls_source-serialnumber ALPHA = OUT }| ).
                EXIT.
              ENDIF.

              IF lines( lt_mapping ) > 1.
                lv_error =
                  VALUE ty_message( number = '017'
          v1 = |{ ls_source-serialnumber ALPHA = OUT }| ).
                EXIT.
              ENDIF.

              DATA(ls_mapping) = lt_mapping[ 1 ].

              IF ls_mapping-kilnserialno IS INITIAL.
                lv_error =
                  VALUE ty_message( number = '016'
          v1 = |{ ls_source-serialnumber ALPHA = OUT }| ).
                EXIT.
              ENDIF.

              "Serial rows are posted against the header material
              IF ls_mapping-kilnmaterial <> ls_header-material.
                lv_error =
                  VALUE ty_message( number = '018' ).
                EXIT.
              ENDIF.

              APPEND VALUE #(
                serialnumber = ls_mapping-kilnserialno
              ) TO lt_serials.

            ENDLOOP.

          ELSE.

            lt_serials = CORRESPONDING #( lt_source_serials ).

          ENDIF.

        ENDIF.

      ENDIF.

      IF lv_error IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-orderconfirmation.

        CONTINUE.
      ENDIF.


      "Include saved loading rejects even if the normal serial source omits them.
      LOOP AT lt_loading_rejects INTO DATA(ls_loading_candidate).
        DATA(lv_present) = abap_false.
        LOOP AT lt_serials INTO DATA(ls_normal_candidate).
          IF condense( |{ ls_normal_candidate-serialnumber ALPHA = OUT }| ) =
             condense( |{ ls_loading_candidate-serialno ALPHA = OUT }| ).
            lv_present = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_present = abap_false.
          APPEND VALUE #( serialnumber = ls_loading_candidate-serialno ) TO lt_serials.
        ENDIF.
      ENDLOOP.

      SORT lt_serials BY serialnumber.

      DELETE ADJACENT DUPLICATES FROM lt_serials
        COMPARING serialnumber.

      "Serials used by other confirmations
      SELECT FROM ztb_serial_dis AS serial
        INNER JOIN ztb__order_hdr AS header
          ON header~confirm_id = serial~confirm_id
        FIELDS DISTINCT
          serial~serial_no,
          serial~material
        WHERE ( header~order_no = @lv_load_order
             OR header~order_no = @lv_order_external )
          AND ( header~status = 'PART_POST'
             OR header~status = 'POSTED' )
          AND header~confirm_id <> @ls_header-confirmid
          AND serial~cancelled_ser_no <> @abap_true
          AND ( serial~approved = @abap_true
             OR serial~rejected = @abap_true )
        INTO TABLE @DATA(lt_used_serials).

      "Exclude used serials from the new candidates
      DATA lt_available_serials LIKE lt_serials.
      CLEAR lt_available_serials.
      LOOP AT lt_serials INTO DATA(ls_candidate).
        DATA(lv_candidate_used) = abap_false.
        LOOP AT lt_used_serials INTO DATA(ls_used)
          WHERE material = ls_header-material.
          IF condense( |{ ls_candidate-serialnumber ALPHA = OUT }| ) =
             condense( |{ ls_used-serial_no ALPHA = OUT }| ).
            lv_candidate_used = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_candidate_used = abap_false.
          APPEND ls_candidate TO lt_available_serials.
        ENDIF.
      ENDLOOP.
      lt_serials = lt_available_serials.

      IF lt_serials IS INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '083'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-orderconfirmation.

        CONTINUE.
      ENDIF.

      "Read existing draft serials
      READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY orderconfirmation BY \_serials
          FIELDS ( serialno material order_type )
          WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_existing)
        FAILED DATA(ls_existing_failed)
        REPORTED DATA(ls_existing_reported).

      APPEND LINES OF ls_existing_failed-orderconfirmation
        TO failed-orderconfirmation.

      APPEND LINES OF ls_existing_failed-serialdisposition
        TO failed-serialdisposition.

      APPEND LINES OF ls_existing_reported-orderconfirmation
        TO reported-orderconfirmation.

      APPEND LINES OF ls_existing_reported-serialdisposition
        TO reported-serialdisposition.

      IF ls_existing_failed IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      "Prevent mixing source materials, including legacy loaded rows
      IF lv_use_material_selection = abap_true
         AND lt_existing IS NOT INITIAL
         AND ls_header-loadedsourcematerial <> ls_header-selectedmaterial.
        APPEND VALUE #( %tky = ls_header-%tky ) TO failed-orderconfirmation.
        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '084'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-orderconfirmation.
        CONTINUE.
      ENDIF.

      DATA lt_remove LIKE lt_existing.
      CLEAR lt_remove.

      "Check existing rows before deleting or updating anything
      LOOP AT lt_existing INTO DATA(ls_existing).

        DATA(lv_existing_used) = abap_false.
        LOOP AT lt_used_serials INTO DATA(ls_existing_used)
          WHERE material = ls_existing-material.
          IF condense( |{ ls_existing_used-serial_no ALPHA = OUT }| ) =
             condense( |{ ls_existing-serialno ALPHA = OUT }| ).
            lv_existing_used = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_existing_used = abap_true.

          APPEND ls_existing TO lt_remove.
          CONTINUE.

        ENDIF.

        IF lv_use_kiln_mapping = abap_true.

          IF ls_existing-material <> ls_header-material
             OR NOT line_exists(
               lt_serials[
                 serialnumber = ls_existing-serialno
               ]
             ).

            lv_error =
              VALUE ty_message( number = '019' ).
            EXIT.

          ENDIF.

        ENDIF.

      ENDLOOP.

      IF lv_error IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-orderconfirmation.

        CONTINUE.
      ENDIF.

      "Remove rows already used by other confirmations
      IF lt_remove IS NOT INITIAL.

        MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
          ENTITY serialdisposition
            DELETE FROM VALUE #(
              FOR ls_remove IN lt_remove
              ( %tky = ls_remove-%tky )
            )
          FAILED DATA(ls_remove_failed)
          REPORTED DATA(ls_remove_reported).

        APPEND LINES OF ls_remove_failed-serialdisposition
          TO failed-serialdisposition.

        APPEND LINES OF ls_remove_reported-serialdisposition
          TO reported-serialdisposition.

        IF ls_remove_failed IS NOT INITIAL.

          APPEND VALUE #(
            %tky = ls_header-%tky
          ) TO failed-orderconfirmation.

          CONTINUE.
        ENDIF.

        LOOP AT lt_remove INTO DATA(ls_removed).

          DELETE lt_existing
            WHERE serialno = ls_removed-serialno.

        ENDLOOP.

      ENDIF.

      "Refresh display values without clearing approval decisions
      IF lt_existing IS NOT INITIAL.

        MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
          ENTITY serialdisposition
            UPDATE FIELDS ( order_type serialnodisplay )
            WITH VALUE #(
              FOR ls_existing_update IN lt_existing
              (
                %tky = ls_existing_update-%tky
                order_type = ls_header-order_type
                serialnodisplay =
                  |{ ls_existing_update-serialno ALPHA = OUT }|
              )
            )
          FAILED DATA(ls_update_failed)
          REPORTED DATA(ls_update_reported).

        APPEND LINES OF ls_update_failed-serialdisposition
          TO failed-serialdisposition.

        APPEND LINES OF ls_update_reported-serialdisposition
          TO reported-serialdisposition.

        IF ls_update_failed IS NOT INITIAL.

          APPEND VALUE #(
            %tky = ls_header-%tky
          ) TO failed-orderconfirmation.

          CONTINUE.
        ENDIF.

      ENDIF.

      "Create only serials not already loaded
      DATA lt_missing_serials LIKE lt_serials.
      CLEAR lt_missing_serials.
      LOOP AT lt_serials INTO DATA(ls_missing_candidate).
        DATA(lv_already_loaded) = abap_false.
        LOOP AT lt_existing INTO DATA(ls_loaded)
          WHERE material = ls_header-material.
          IF condense( |{ ls_missing_candidate-serialnumber ALPHA = OUT }| ) =
             condense( |{ ls_loaded-serialno ALPHA = OUT }| ).
            lv_already_loaded = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_already_loaded = abap_false.
          APPEND ls_missing_candidate TO lt_missing_serials.
        ENDIF.
      ENDLOOP.
      lt_serials = lt_missing_serials.

      IF lt_serials IS NOT INITIAL.

        MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
          ENTITY orderconfirmation
            CREATE BY \_serials AUTO FILL CID
              FIELDS (
                serialno
                serialnodisplay
                material
                order_type
              )
              WITH VALUE #(
                (
                  %tky = ls_header-%tky
                  %is_draft = ls_header-%is_draft

                  %target = VALUE #(
                    FOR ls_serial IN lt_serials
                    (
                      %is_draft = ls_header-%is_draft
                      serialno = ls_serial-serialnumber
                      serialnodisplay =
                        |{ ls_serial-serialnumber ALPHA = OUT }|
                      material = ls_header-material
                      order_type = ls_header-order_type
                    )
                  )
                )
              )
          FAILED DATA(ls_create_failed)
          REPORTED DATA(ls_create_reported).

        APPEND LINES OF ls_create_failed-orderconfirmation
          TO failed-orderconfirmation.

        APPEND LINES OF ls_create_failed-serialdisposition
          TO failed-serialdisposition.

        APPEND LINES OF ls_create_reported-orderconfirmation
          TO reported-orderconfirmation.

        APPEND LINES OF ls_create_reported-serialdisposition
          TO reported-serialdisposition.

        IF ls_create_failed IS NOT INITIAL.
          CONTINUE.
        ENDIF.

      ENDIF.


      "Read new and existing serials and synchronize Loading Rejection ownership.
      READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY orderconfirmation BY \_serials ALL FIELDS
        WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_sync_serials)
        FAILED DATA(ls_sync_read_failed).
      IF ls_sync_read_failed IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_header-%tky ) TO failed-orderconfirmation.
        APPEND VALUE #( %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '085'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-orderconfirmation.
        CONTINUE.
      ENDIF.

      DATA lt_loading_updates TYPE TABLE FOR UPDATE zi_serial_disposition.
      CLEAR lt_loading_updates.
      LOOP AT lt_sync_serials INTO DATA(ls_sync_serial).
        DATA(lv_is_loading) = abap_false.
        LOOP AT lt_loading_rejects INTO DATA(ls_loading_reject).
          IF ls_sync_serial-material = ls_loading_reject-material
             AND condense( |{ ls_sync_serial-serialno ALPHA = OUT }| ) =
                 condense( |{ ls_loading_reject-serialno ALPHA = OUT }| ).
            lv_is_loading = abap_true.
            APPEND VALUE #(
              %tky = ls_sync_serial-%tky
              isloadingrejection = abap_true
              approved = abap_false
              rejected = abap_true
              reasoncode = ls_loading_reject-reasoncode
              reasontext = ls_loading_reject-reasontext
              remarks = ls_loading_reject-remarks
            ) TO lt_loading_updates.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_is_loading = abap_false AND ls_sync_serial-isloadingrejection = abap_true.
          "The source rejection was removed: release only previously imported fields.
          APPEND VALUE #(
            %tky = ls_sync_serial-%tky
            isloadingrejection = abap_false
            approved = abap_false rejected = abap_false
            reasoncode = '' reasontext = '' remarks = ''
          ) TO lt_loading_updates.
        ENDIF.
      ENDLOOP.

      IF lt_loading_updates IS NOT INITIAL.
        MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
          ENTITY serialdisposition
          UPDATE FIELDS ( isloadingrejection approved rejected reasoncode reasontext remarks )
          WITH lt_loading_updates
          FAILED DATA(ls_loading_update_failed)
          REPORTED DATA(ls_loading_update_reported).
        APPEND LINES OF ls_loading_update_failed-orderconfirmation TO failed-orderconfirmation.
        APPEND LINES OF ls_loading_update_failed-serialdisposition TO failed-serialdisposition.
        APPEND LINES OF ls_loading_update_reported-orderconfirmation TO reported-orderconfirmation.
        APPEND LINES OF ls_loading_update_reported-serialdisposition TO reported-serialdisposition.
        IF ls_loading_update_failed IS NOT INITIAL.
          APPEND VALUE #( %tky = ls_header-%tky ) TO failed-orderconfirmation.
          CONTINUE.
        ENDIF.
      ENDIF.

      MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY orderconfirmation
          UPDATE FIELDS ( loadedsourcematerial loadingrejectionqty )
          WITH VALUE #( (
            %tky = ls_header-%tky
            loadingrejectionqty = lv_loading_quantity
            loadedsourcematerial = COND #( WHEN lv_use_material_selection = abap_true
                                          THEN ls_header-selectedmaterial ELSE '' )
          ) )
        FAILED DATA(ls_source_update_failed)
        REPORTED DATA(ls_source_update_reported).

      APPEND LINES OF ls_source_update_failed-orderconfirmation
        TO failed-orderconfirmation.
      APPEND LINES OF ls_source_update_reported-orderconfirmation
        TO reported-orderconfirmation.
      IF ls_source_update_failed IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '086'
            severity = if_abap_behv_message=>severity-success
            v1       = |{ lines( lt_serials ) }|
          )
      ) TO reported-orderconfirmation.

    ENDLOOP.

    "Return the updated header
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_updated_headers).

    result = VALUE #(
      FOR ls_updated_header IN lt_updated_headers
      (
        %tky = ls_updated_header-%tky
        %param = ls_updated_header
      )
    ).

  ENDMETHOD.



  METHOD submitandpost.

    DATA lv_posting_date TYPE d.
    DATA lv_current_time TYPE t.
    DATA lv_timestamp TYPE timestamp.

    TRY.
        DATA(lv_timezone) =
          cl_abap_context_info=>get_user_time_zone( ).

      CATCH cx_abap_context_info_error.
        APPEND VALUE #(
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '087'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-orderconfirmation.
        RETURN.
    ENDTRY.

    GET TIME STAMP FIELD lv_timestamp.

    CONVERT TIME STAMP lv_timestamp
      TIME ZONE lv_timezone
      INTO DATE lv_posting_date
           TIME lv_current_time.
    "Read current custom headers
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers)
      FAILED DATA(ls_read_failed)
      REPORTED DATA(ls_read_reported).

    APPEND LINES OF ls_read_failed-orderconfirmation
      TO failed-orderconfirmation.

    APPEND LINES OF ls_read_reported-orderconfirmation
      TO reported-orderconfirmation.

    LOOP AT lt_headers INTO DATA(ls_header).


      DATA(lv_total_scrap) = CONV decfloat34( ls_header-scrapqty )
        + CONV decfloat34( ls_header-loadingrejectionqty ).

      "Validate before requesting standard posting
      DATA(lv_error) = VALUE ty_message( ).

      IF ls_header-%is_draft = if_abap_behv=>mk-on.
        lv_error = VALUE ty_message( number = '020' ).

      ELSEIF ls_header-orderno IS INITIAL.
        lv_error = VALUE ty_message( number = '021' ).

      ELSEIF ls_header-operation IS INITIAL.
        lv_error = VALUE ty_message( number = '022' ).

      ELSEIF ls_header-postingdate IS INITIAL.
        lv_error = VALUE ty_message( number = '023' ).

      ELSEIF ls_header-unit IS INITIAL.
        lv_error = VALUE ty_message( number = '024' ).

      ELSEIF ls_header-qtytoconfirm < 0
          OR ls_header-scrapqty < 0
          OR ls_header-loadingrejectionqty < 0.
        lv_error = VALUE ty_message( number = '025' ).

      ELSEIF ls_header-qtytoconfirm = 0
         AND lv_total_scrap = 0.
        lv_error = VALUE ty_message( number = '026' ).

      ENDIF.

      IF lv_error IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-orderconfirmation.

        CONTINUE.

      ENDIF.


      "Recheck serial decisions and source data immediately before first-BO posting.
      READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY orderconfirmation BY \_serials ALL FIELDS
        WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_post_serials)
        FAILED DATA(ls_post_serial_failed).
      IF ls_post_serial_failed IS NOT INITIAL.
        lv_error = VALUE ty_message( number = '027' ).
      ELSEIF ls_header-status <> 'CREATED'.
        lv_error = VALUE ty_message( number = '028' ).
      ELSE.
        lv_error = checkloadingsnapshot(
          is_header = CORRESPONDING #( ls_header )
          it_serials = CORRESPONDING #( lt_post_serials ) ).
      ENDIF.
      DATA(lv_approved_count) = 0.
      DATA(lv_rejected_count) = 0.
      IF lv_error IS INITIAL.
        LOOP AT lt_post_serials INTO DATA(ls_post_serial).
          IF ls_post_serial-approved = abap_true AND ls_post_serial-rejected = abap_true.
            lv_error = VALUE ty_message( number = '029' ).
            EXIT.
          ENDIF.
          IF ls_post_serial-approved = abap_true.
            lv_approved_count += 1.
          ENDIF.
          IF ls_post_serial-rejected = abap_true.
            lv_rejected_count += 1.
            IF ls_post_serial-reasontext IS INITIAL.
              lv_error = VALUE ty_message( number = '030' ).
              EXIT.
            ENDIF.
          ENDIF.
        ENDLOOP.
        IF lv_error IS INITIAL.
          IF CONV decfloat34( lv_approved_count ) <> ls_header-qtytoconfirm
             OR CONV decfloat34( lv_rejected_count ) <> lv_total_scrap.
            lv_error = VALUE ty_message( number = '031' ).
          ELSEIF ls_header-qtytoconfirm + lv_total_scrap > ls_header-remainingqty.
            lv_error = VALUE ty_message( number = '032' ).
          ENDIF.
        ENDIF.
      ENDIF.
      IF lv_error IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_header-%tky ) TO failed-orderconfirmation.
        APPEND VALUE #( %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-orderconfirmation.
        CONTINUE.
      ENDIF.

      "Read scrap items belonging to this header
      READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY orderconfirmation BY \_scrapitems
          ALL FIELDS
          WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_scrap_items)
        FAILED DATA(ls_scrap_read_failed)
        REPORTED DATA(ls_scrap_read_reported).

      APPEND LINES OF ls_scrap_read_failed-orderconfirmation
        TO failed-orderconfirmation.

      APPEND LINES OF ls_scrap_read_failed-scrapitem
        TO failed-scrapitem.

      APPEND LINES OF ls_scrap_read_reported-orderconfirmation
        TO reported-orderconfirmation.

      APPEND LINES OF ls_scrap_read_reported-scrapitem
        TO reported-scrapitem.

      IF ls_scrap_read_failed IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '088'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-orderconfirmation.

        IF NOT line_exists(
          failed-orderconfirmation[ %tky = ls_header-%tky ]
        ).
          APPEND VALUE #(
            %tky = ls_header-%tky
          ) TO failed-orderconfirmation.
        ENDIF.

        CONTINUE.

      ENDIF.

      "Validate scrap movement rows
      CLEAR lv_error.

      LOOP AT lt_scrap_items INTO DATA(ls_scrap_check).

        IF ls_scrap_check-scrapqty < 0.
          lv_error = VALUE ty_message( number = '033' ).
          EXIT.
        ENDIF.

        IF ls_scrap_check-scrapqty > 0
           AND ( ls_scrap_check-scrapmaterial IS INITIAL
              OR ls_scrap_check-storagelocation IS INITIAL ).
          lv_error =
            VALUE ty_message( number = '034' ).
          EXIT.
        ENDIF.

      ENDLOOP.

      IF lv_error IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-orderconfirmation.

        CONTINUE.

      ENDIF.

      "Normalize order number using the standard BO field type
      DATA ls_standard_header
        TYPE STRUCTURE FOR CREATE i_productionordconfirmationtp.

      ls_standard_header-orderid = ls_header-orderno.
      ls_standard_header-orderid =
        |{ ls_standard_header-orderid ALPHA = IN }|.

      "Build movement rows only for positive quantities
      DATA lt_movements TYPE TABLE FOR CREATE
        i_productionordconfirmationtp\_prodnordconfmatldocitm.

      CLEAR lt_movements.

      IF lt_scrap_items IS NOT INITIAL.
        "The association request is added only if it has targets
        DATA ls_movement_request LIKE LINE OF lt_movements.
        CLEAR ls_movement_request.
        ls_movement_request-%cid_ref = 'CONF_1'.

        LOOP AT lt_scrap_items INTO DATA(ls_scrap)
          WHERE scrapqty > 0.

          APPEND VALUE #(
            %cid = |MAT_{ sy-tabix }|

            orderid             = ls_standard_header-orderid
            material            = ls_scrap-scrapmaterial
            plant               = ls_header-plant
            storagelocation     = ls_scrap-storagelocation
            goodsmovementtype   = '531'
            entryunitsapcode            = ls_scrap-scrapunit
            quantityinentryunit = ls_scrap-scrapqty
          ) TO ls_movement_request-%target.

        ENDLOOP.

        IF ls_movement_request-%target IS NOT INITIAL.
          APPEND ls_movement_request TO lt_movements.
        ENDIF.

      ENDIF.

      DATA(lv_confirmation_unit) = ls_header-unit.

      IF lv_confirmation_unit = 'ST'.
        lv_confirmation_unit = 'PC'.
      ENDIF.


      "Read saved production activity rows
      READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY orderconfirmation BY \_activities
          ALL FIELDS
          WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_post_activities)
        FAILED DATA(ls_act_failed)
        REPORTED DATA(ls_act_reported).

      APPEND LINES OF ls_act_failed-orderconfirmation
        TO failed-orderconfirmation.
      APPEND LINES OF ls_act_failed-activity
        TO failed-activity.

      APPEND LINES OF ls_act_reported-orderconfirmation
        TO reported-orderconfirmation.
      APPEND LINES OF ls_act_reported-activity
        TO reported-activity.

      CLEAR lv_error.

      IF ls_act_failed IS NOT INITIAL.
        lv_error = VALUE ty_message( number = '035' ).
      ENDIF.

      DATA ls_act_values
        TYPE STRUCTURE FOR CREATE i_productionordconfirmationtp.

      CLEAR ls_act_values.

      IF lv_error IS INITIAL.

        LOOP AT lt_post_activities INTO DATA(ls_act).

          IF ls_act-activityqty < 0.
            lv_error = VALUE ty_message( number = '036' ).
            EXIT.
          ENDIF.

          IF ls_act-activityqty <> 0
             AND ls_act-activityunit IS INITIAL.
            lv_error = VALUE ty_message( number = '037' ).
            EXIT.
          ENDIF.

          CASE ls_act-activityslot.
            WHEN '1'.
              ls_act_values-opconfirmedworkquantity1 = ls_act-activityqty.
              ls_act_values-opworkquantityunit1 = ls_act-activityunit.

            WHEN '2'.
              ls_act_values-opconfirmedworkquantity2 = ls_act-activityqty.
              ls_act_values-opworkquantityunit2 = ls_act-activityunit.

            WHEN '3'.
              ls_act_values-opconfirmedworkquantity3 = ls_act-activityqty.
              ls_act_values-opworkquantityunit3 = ls_act-activityunit.

            WHEN '4'.
              ls_act_values-opconfirmedworkquantity4 = ls_act-activityqty.
              ls_act_values-opworkquantityunit4 = ls_act-activityunit.

            WHEN '5'.
              ls_act_values-opconfirmedworkquantity5 = ls_act-activityqty.
              ls_act_values-opworkquantityunit5 = ls_act-activityunit.

            WHEN '6'.
              ls_act_values-opconfirmedworkquantity6 = ls_act-activityqty.
              ls_act_values-opworkquantityunit6 = ls_act-activityunit.

            WHEN OTHERS.
              lv_error = VALUE ty_message( number = '038' ).
              EXIT.
          ENDCASE.

        ENDLOOP.

      ENDIF.

      IF lv_error IS NOT INITIAL.

        IF NOT line_exists(
          failed-orderconfirmation[ %tky = ls_header-%tky ]
        ).
          APPEND VALUE #(
            %tky = ls_header-%tky
          ) TO failed-orderconfirmation.
        ENDIF.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-orderconfirmation.

        CONTINUE.

      ENDIF.

      "Create standard confirmation and associated movements
      MODIFY ENTITIES OF i_productionordconfirmationtp

        ENTITY productionorderconfirmation

          CREATE FIELDS (
            orderid
            sequence
            orderoperation
            plant
            workcenter
            postingdate
            confirmedexecutionstartdate
            confirmedexecutionstarttime
            confirmedexecutionenddate
            confirmedexecutionendtime
            shiftgrouping
            shiftdefinition
            finalconfirmationtype
            confirmationyieldquantity
            confirmationscrapquantity
            confirmationunit

            opconfirmedworkquantity1
            workquantityunit1sapcode
            opconfirmedworkquantity2
          workquantityunit2sapcode
            opconfirmedworkquantity3
            workquantityunit3sapcode
            opconfirmedworkquantity4
            workquantityunit4sapcode
            opconfirmedworkquantity5
            workquantityunit5sapcode
            opconfirmedworkquantity6
            workquantityunit6sapcode


          )

          WITH VALUE #(
            (
              %cid = 'CONF_1'

              orderid        = ls_standard_header-orderid
              sequence       = '000000'
              orderoperation = ls_header-operation
              plant          = ls_header-plant
              workcenter     = ls_header-workcenter

               postingdate = ls_header-postingdate

              confirmedexecutionstartdate = ls_header-start_end_date
              confirmedexecutionenddate   = lv_posting_date

             confirmedexecutionstarttime = ls_header-starttime
                confirmedexecutionendtime   = ls_header-endtime

              shiftgrouping         = 'PP'
              shiftdefinition       = ls_header-group_defn
                finalconfirmationtype = COND #(
                                                 WHEN ls_header-remainingqty =
                                                 ls_header-qtytoconfirm + lv_total_scrap
                                                      THEN 'X'
                                                      ELSE space
                                                    )
              confirmationyieldquantity =
                ls_header-qtytoconfirm
              confirmationscrapquantity =
                lv_total_scrap
            confirmationunitsapcode = ls_header-unit

                            opconfirmedworkquantity1 =
                ls_act_values-opconfirmedworkquantity1
              workquantityunit1sapcode =
                ls_act_values-opworkquantityunit1

              opconfirmedworkquantity2 =
                ls_act_values-opconfirmedworkquantity2
              workquantityunit2sapcode =
                ls_act_values-opworkquantityunit2

              opconfirmedworkquantity3 =
                ls_act_values-opconfirmedworkquantity3
               workquantityunit3sapcode =
                ls_act_values-opworkquantityunit3

                opconfirmedworkquantity4 =
                  ls_act_values-opconfirmedworkquantity4
                workquantityunit4sapcode =
                  ls_act_values-opworkquantityunit4

                opconfirmedworkquantity5 =
                  ls_act_values-opconfirmedworkquantity5
                workquantityunit5sapcode =
                  ls_act_values-opworkquantityunit5

                opconfirmedworkquantity6 =
                  ls_act_values-opconfirmedworkquantity6
                workquantityunit6sapcode =
                  ls_act_values-opworkquantityunit6

            )
          )

          CREATE BY \_prodnordconfmatldocitm
            FIELDS (
              orderid
              material
              plant
              storagelocation
              goodsmovementtype
              entryunitsapcode
              quantityinentryunit
            )
            WITH lt_movements

        MAPPED DATA(ls_post_mapped)
        FAILED DATA(ls_post_failed)
        REPORTED DATA(ls_post_reported).

      "Show standard confirmation messages
      LOOP AT ls_post_reported-productionorderconfirmation
        INTO DATA(ls_conf_message).

        IF ls_conf_message-%msg IS BOUND.
          APPEND VALUE #(
            %tky = ls_header-%tky
            %msg = ls_conf_message-%msg
          ) TO reported-orderconfirmation.
        ENDIF.

      ENDLOOP.

      "Show standard goods movement messages
      LOOP AT ls_post_reported-prodorderconfmatldocitem
        INTO DATA(ls_gm_message).

        IF ls_gm_message-%msg IS BOUND.
          APPEND VALUE #(
            %tky = ls_header-%tky
            %msg = ls_gm_message-%msg
          ) TO reported-orderconfirmation.
        ENDIF.

      ENDLOOP.

      IF ls_post_failed IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '089'
            severity = if_abap_behv_message=>severity-error
            v1       = |{ ls_header-orderno }|
          )
        ) TO reported-orderconfirmation.

        CONTINUE.

      ENDIF.


      LOOP AT ls_post_mapped-productionorderconfirmation
  INTO DATA(ls_created_confirmation)
  WHERE %cid = 'CONF_1'.

        APPEND VALUE #(
          confirm_id = ls_header-confirmid
          pid        = ls_created_confirmation-%pid
        ) TO lcl_confirmation_buffer=>entries.

      ENDLOOP.

      "Successful posting -> mark as POSTED
      MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
   ENTITY orderconfirmation
     UPDATE FIELDS ( status postingdate )
     WITH VALUE #(
       (
         %tky        = ls_header-%tky
        status = 'PART_POST'
         postingdate = lv_posting_date
       )
     )
   FAILED DATA(ls_update_failed)
   REPORTED DATA(ls_update_reported).

      APPEND LINES OF ls_update_failed-orderconfirmation
        TO failed-orderconfirmation.

      APPEND LINES OF ls_update_reported-orderconfirmation
        TO reported-orderconfirmation.

      IF ls_update_failed IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      ls_header-status = 'PART_POST'.
      ls_header-postingdate = lv_posting_date.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '090'
            severity = if_abap_behv_message=>severity-success
            v1       = |{ ls_header-orderno }|
          )
      ) TO reported-orderconfirmation.
      "Return the successfully processed custom header
      APPEND VALUE #(
        %tky   = ls_header-%tky
        %param = ls_header
      ) TO result.

    ENDLOOP.

  ENDMETHOD.

  METHOD postmaterialdocument.

    DATA:
      lv_error TYPE ty_message,
      lv_storage_location TYPE
        i_materialdocumentitem_2-storagelocation,
      lv_order            TYPE
        i_manufacturingorder-manufacturingorder.

    DATA lt_serial_request TYPE TABLE FOR CREATE
      i_materialdocumentitemtp\_serialnumber.

    "Read selected order confirmations
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers)
      FAILED DATA(ls_read_failed)
      REPORTED DATA(ls_read_reported).

    APPEND LINES OF ls_read_failed-orderconfirmation
      TO failed-orderconfirmation.

    APPEND LINES OF ls_read_reported-orderconfirmation
      TO reported-orderconfirmation.

    LOOP AT lt_headers INTO DATA(ls_header).

      CLEAR:
        lv_error,
        lv_storage_location,
        lv_order,
        lt_serial_request.

      "Validate header
      IF ls_header-%is_draft = if_abap_behv=>mk-on.
        lv_error = VALUE ty_message( number = '039' ).

      ELSEIF ls_header-serialsposted = abap_true.
        lv_error = VALUE ty_message( number = '040' ).

      ELSEIF ls_header-status <> 'PART_POST'.
        lv_error = VALUE ty_message( number = '041' ).

      ELSEIF ls_header-orderno IS INITIAL.
        lv_error = VALUE ty_message( number = '042' ).

      ELSEIF ls_header-material IS INITIAL.
        lv_error = VALUE ty_message( number = '043' ).

      ELSEIF ls_header-plant IS INITIAL.
        lv_error = VALUE ty_message( number = '044' ).

      ELSEIF ls_header-postingdate IS INITIAL.
        lv_error = VALUE ty_message( number = '045' ).

      ELSEIF ls_header-qtytoconfirm <= 0.
        lv_error = VALUE ty_message( number = '046' ).

      ENDIF.


      IF lv_error IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-orderconfirmation.

        CONTINUE.

      ENDIF.

      "Validate standard price before posting loaded serials
      SELECT FROM i_productvaluationbasic
        FIELDS standardprice
        WHERE product       = @ls_header-material
          AND valuationarea = @ls_header-plant
        INTO TABLE @DATA(lt_product_prices).

      CLEAR lv_error.

      IF lt_product_prices IS INITIAL.

        lv_error =
          VALUE ty_message( number = '047'
          v1 = |{ ls_header-material }|
          v2 = |{ ls_header-plant }| ).

      ELSEIF line_exists( lt_product_prices[ standardprice = 0 ] ).

        lv_error =
          VALUE ty_message( number = '048'
          v1 = |{ ls_header-material }|
          v2 = |{ ls_header-plant }| ).

      ENDIF.

      IF lv_error IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %element-material = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-orderconfirmation.

        CONTINUE.

      ENDIF.

      "Read serial numbers and scrap details
      READ ENTITIES OF zi_order_confirmation IN LOCAL MODE

        ENTITY orderconfirmation BY \_serials
          ALL FIELDS
          WITH VALUE #(
            ( %tky = ls_header-%tky )
          )
          RESULT DATA(lt_serials)

        ENTITY orderconfirmation BY \_scrapitems
          ALL FIELDS
          WITH VALUE #(
            ( %tky = ls_header-%tky )
          )
          RESULT DATA(lt_scrap_items)

        FAILED DATA(ls_child_failed)
        REPORTED DATA(ls_child_reported).

      APPEND LINES OF ls_child_reported-orderconfirmation
        TO reported-orderconfirmation.

      APPEND LINES OF ls_child_reported-serialdisposition
        TO reported-serialdisposition.

      APPEND LINES OF ls_child_reported-scrapitem
        TO reported-scrapitem.

      IF ls_child_failed IS NOT INITIAL.
        lv_error = VALUE ty_message( number = '049' ).
      ENDIF.



      "Determine receiving storage location from Manufacturing Order Item
      IF lv_error IS INITIAL.

        "Normalize manufacturing order number first
        lv_order = ls_header-orderno.
        lv_order = |{ lv_order ALPHA = IN }|.

        "Get storage location from Manufacturing Order Item
        SELECT SINGLE
          FROM i_manufacturingorderitem
          FIELDS storagelocation
          WHERE manufacturingorder = @lv_order
            AND manufacturingorderitem = '0001'
          INTO @lv_storage_location.

        IF sy-subrc <> 0 OR lv_storage_location IS INITIAL.
          lv_error =
            VALUE ty_message( number = '050' ).
        ENDIF.

      ENDIF.

      "Keep approved, non-rejected serials for the header material
      DATA(lt_approved) = lt_serials.

      DELETE lt_approved WHERE approved <> abap_true.
      DELETE lt_approved WHERE rejected = abap_true.
      DELETE lt_approved WHERE isloadingrejection = abap_true.
      DELETE lt_approved WHERE material <> ls_header-material.

      IF lv_error IS INITIAL.

        IF lt_approved IS INITIAL.

          lv_error = VALUE ty_message( number = '051' ).

        ELSEIF line_exists(
          lt_approved[ serialno = space ]
        ).

          lv_error = VALUE ty_message( number = '052' ).

        ELSE.

          SORT lt_approved BY serialno.

          DATA(lv_serial_count) = lines( lt_approved ).

          DELETE ADJACENT DUPLICATES FROM lt_approved
            COMPARING serialno.

          IF lines( lt_approved ) <> lv_serial_count.

            lv_error = VALUE ty_message( number = '053' ).

          ELSEIF lines( lt_approved ) <> ls_header-qtytoconfirm.

            lv_error =
              VALUE ty_message( number = '054' ).

          ENDIF.

        ENDIF.

      ENDIF.

      IF lv_error IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-orderconfirmation.

        CONTINUE.

      ENDIF.

      "Normalize manufacturing order number
      lv_order = ls_header-orderno.
      lv_order = |{ lv_order ALPHA = IN }|.

      "Request identifiers linking header, item and serials
      DATA(lv_header_cid) = |H_{ ls_header-confirmid }|.
      DATA(lv_item_cid)   = |I_{ ls_header-confirmid }|.

      APPEND INITIAL LINE TO lt_serial_request
        ASSIGNING FIELD-SYMBOL(<serial_request>).

      <serial_request>-%cid_ref = lv_item_cid.

      LOOP AT lt_approved INTO DATA(ls_serial).

        APPEND VALUE #(
          %cid         = |S_{ ls_header-confirmid }_{ sy-tabix }|
          serialnumber = ls_serial-serialno
        ) TO <serial_request>-%target.

      ENDLOOP.

      "Create material document, item and serial-number children
      MODIFY ENTITIES OF i_materialdocumenttp

        ENTITY materialdocument

          CREATE FIELDS (
            documentdate
            postingdate
            goodsmovementcode
          )
          WITH VALUE #(
            (
              %cid              = lv_header_cid
              documentdate      = ls_header-postingdate
              postingdate       = ls_header-postingdate
              goodsmovementcode = '02'
            )
          )

          CREATE BY \_materialdocumentitem
            FIELDS (
              material
              plant
              storagelocation
              batch
              goodsmovementtype
              manufacturingorder
              manufacturingorderitem
              goodsmovementrefdoctype
              quantityinentryunit
              entryunit
            )
            WITH VALUE #(
              (
                %cid_ref = lv_header_cid

                %target = VALUE #(
                  (
                    %cid                    = lv_item_cid
                    material                = ls_header-material
                    plant                   = ls_header-plant
                    storagelocation         = lv_storage_location
                    batch                   = ls_header-batch_number
                    goodsmovementtype       = '101'
                    manufacturingorder      = lv_order
                    manufacturingorderitem  = '0001'
                    goodsmovementrefdoctype = 'F'
                    quantityinentryunit     = ls_header-qtytoconfirm
                    entryunit               = ls_header-unit
                  )
                )
              )
            )

        ENTITY materialdocumentitem

          CREATE BY \_serialnumber
            FIELDS ( serialnumber )
            WITH lt_serial_request

        MAPPED DATA(ls_md_mapped)
        FAILED DATA(ls_md_failed)
        REPORTED DATA(ls_md_reported).

      "Forward material-document header messages
      LOOP AT ls_md_reported-materialdocument
        INTO DATA(ls_header_message).

        IF ls_header_message-%msg IS BOUND.

          APPEND VALUE #(
            %tky = ls_header-%tky
            %msg = ls_header_message-%msg
          ) TO reported-orderconfirmation.

        ENDIF.

      ENDLOOP.

      "Forward material-document item messages
      LOOP AT ls_md_reported-materialdocumentitem
        INTO DATA(ls_item_message).

        IF ls_item_message-%msg IS BOUND.

          APPEND VALUE #(
            %tky = ls_header-%tky
            %msg = ls_item_message-%msg
          ) TO reported-orderconfirmation.

        ENDIF.

      ENDLOOP.

      "Forward serial-number messages
      LOOP AT ls_md_reported-materialdocumentitemserialno
        INTO DATA(ls_serial_message).

        IF ls_serial_message-%msg IS BOUND.

          APPEND VALUE #(
            %tky = ls_header-%tky
            %msg = ls_serial_message-%msg
          ) TO reported-orderconfirmation.

        ENDIF.

      ENDLOOP.

      IF ls_md_failed IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '091'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-orderconfirmation.

        CONTINUE.

      ENDIF.

      LOOP AT ls_md_mapped-materialdocument
  INTO DATA(ls_created_document)
  WHERE %cid = lv_header_cid.

        APPEND VALUE #(
          confirm_id = ls_header-confirmid
          pid        = ls_created_document-%pid
        ) TO lcl_material_buffer=>entries.

      ENDLOOP.

      MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
  ENTITY orderconfirmation
   UPDATE FIELDS ( status serialsposted )
    WITH VALUE #(
      (
        %tky          = ls_header-%tky
        serialsposted = abap_true
        status = 'POSTED'
      )
    )
  FAILED DATA(ls_flag_failed)
  REPORTED DATA(ls_flag_reported).

      APPEND LINES OF ls_flag_failed-orderconfirmation
        TO failed-orderconfirmation.

      APPEND LINES OF ls_flag_reported-orderconfirmation
        TO reported-orderconfirmation.

      IF ls_flag_failed IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      ls_header-serialsposted = abap_true.
      ls_header-status = 'POSTED'.

      "Return the order confirmation to the UI
      APPEND VALUE #(
        %tky   = ls_header-%tky
        %param = ls_header
      ) TO result.

      "Final posting is completed by the RAP save sequence
      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '092'
            severity = if_abap_behv_message=>severity-information
          )
      ) TO reported-orderconfirmation.

    ENDLOOP.

  ENDMETHOD.

  METHOD cancelconfirmation.

    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers)
      FAILED DATA(ls_read_failed)
      REPORTED DATA(ls_read_reported).

    APPEND LINES OF ls_read_failed-orderconfirmation
      TO failed-orderconfirmation.

    APPEND LINES OF ls_read_reported-orderconfirmation
      TO reported-orderconfirmation.

    LOOP AT lt_headers INTO DATA(ls_header).

      DATA(lv_error) = VALUE ty_message( ).

      IF ls_header-%is_draft = if_abap_behv=>mk-on.
        lv_error = VALUE ty_message( number = '055' ).

      ELSEIF ls_header-status <> 'POSTED'
    AND ls_header-status <> 'PART_POST'.
        lv_error = VALUE ty_message( number = '056' ).

      ELSEIF ls_header-confirmationgroup IS INITIAL
          OR ls_header-confirmationcount IS INITIAL.
        lv_error = VALUE ty_message( number = '057' ).
      ENDIF.

      IF lv_error IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-orderconfirmation.

        CONTINUE.
      ENDIF.


      "Reverse the exact original confirmation
      MODIFY ENTITIES OF i_productionordconfirmationtp
        ENTITY productionorderconfirmation
          EXECUTE cancelprodnordconf
          FROM VALUE #(
            (
              %tky-confirmationgroup =
                ls_header-confirmationgroup
              %tky-confirmationcount =
                ls_header-confirmationcount
            )
          )
        FAILED DATA(ls_cancel_failed)
        REPORTED DATA(ls_cancel_reported).

      LOOP AT ls_cancel_reported-productionorderconfirmation
        INTO DATA(ls_message).

        IF ls_message-%msg IS BOUND.
          APPEND VALUE #(
            %tky = ls_header-%tky
            %msg = ls_message-%msg
          ) TO reported-orderconfirmation.
        ENDIF.

      ENDLOOP.

      IF ls_cancel_failed IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '093'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-orderconfirmation.

        CONTINUE.
      ENDIF.

      "Saved together with the reversal in the RAP transaction
      MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY orderconfirmation
          UPDATE FIELDS ( status )
          WITH VALUE #(
            (
              %tky   = ls_header-%tky
              status = 'CANCELLED'
            )
          )
        FAILED DATA(ls_update_failed)
        REPORTED DATA(ls_update_reported).

      APPEND LINES OF ls_update_failed-orderconfirmation
        TO failed-orderconfirmation.

      APPEND LINES OF ls_update_reported-orderconfirmation
        TO reported-orderconfirmation.

      IF ls_update_failed IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
             %tky = ls_header-%tky
             %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '094'
            severity = if_abap_behv_message=>severity-success
            v1       = |{ ls_header-orderno }|
          )
           ) TO reported-orderconfirmation.


      READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY orderconfirmation
          ALL FIELDS
          WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_updated).

      LOOP AT lt_updated INTO DATA(ls_updated).
        APPEND VALUE #(
          %tky   = ls_updated-%tky
          %param = ls_updated
        ) TO result.
      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.

  METHOD cancelloadedserials.

    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers)
      FAILED DATA(ls_read_failed)
      REPORTED DATA(ls_read_reported).

    APPEND LINES OF ls_read_failed-orderconfirmation
      TO failed-orderconfirmation.

    APPEND LINES OF ls_read_reported-orderconfirmation
      TO reported-orderconfirmation.

    DATA(lv_reversal_date) =
      cl_abap_context_info=>get_system_date( ).

    DATA lv_cnt TYPE i.

    LOOP AT lt_headers INTO DATA(ls_header).

      DATA(lv_error) = VALUE ty_message( ).

      IF ls_header-%is_draft = if_abap_behv=>mk-on.
        lv_error = VALUE ty_message( number = '055' ).

      ELSEIF ls_header-serialsposted <> abap_true.
        lv_error = VALUE ty_message( number = '058' ).

      ELSEIF ls_header-materialdocument IS INITIAL
          OR ls_header-materialdocumentyear IS INITIAL.
        lv_error = VALUE ty_message( number = '059' ).
      ENDIF.

      IF lv_error IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-orderconfirmation.

        CONTINUE.
      ENDIF.


      "Cancel the entire original material document
      MODIFY ENTITIES OF i_materialdocumenttp
        ENTITY materialdocument
          EXECUTE cancel
          FROM VALUE #(
            (
              %tky-materialdocument =
                ls_header-materialdocument
              %tky-materialdocumentyear =
                ls_header-materialdocumentyear
              %tky-%is_draft = if_abap_behv=>mk-off
              %param-postingdate = lv_reversal_date
            )
          )
        RESULT DATA(lt_cancel_result)
        FAILED DATA(ls_cancel_failed)
        REPORTED DATA(ls_cancel_reported).

      LOOP AT ls_cancel_reported-materialdocument
        INTO DATA(ls_header_message).

        IF ls_header_message-%msg IS BOUND.
          APPEND VALUE #(
            %tky = ls_header-%tky
            %msg = ls_header_message-%msg
          ) TO reported-orderconfirmation.
        ENDIF.

      ENDLOOP.

      LOOP AT ls_cancel_reported-materialdocumentitem
        INTO DATA(ls_item_message).

        IF ls_item_message-%msg IS BOUND.
          APPEND VALUE #(
            %tky = ls_header-%tky
            %msg = ls_item_message-%msg
          ) TO reported-orderconfirmation.
        ENDIF.

      ENDLOOP.

      IF ls_cancel_failed IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-orderconfirmation.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '095'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-orderconfirmation.

        CONTINUE.
      ENDIF.


      "------------------------------------------------------
      " Mark serial numbers as cancelled
      "------------------------------------------------------

      READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY orderconfirmation BY \_serials
          ALL FIELDS
          WITH VALUE #(
            ( %tky = ls_header-%tky )
          )
        RESULT DATA(lt_cancelled_serials)
        FAILED DATA(ls_serial_read_failed).

      IF ls_serial_read_failed IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '096'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-orderconfirmation.

        CONTINUE.

      ENDIF.


      MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY serialdisposition
          UPDATE FIELDS ( cancelledserialno )
          WITH VALUE #(
            FOR ls_serial IN lt_cancelled_serials
            WHERE (
                 approved = abap_true
              OR rejected = abap_true
            )
            (
              %tky              = ls_serial-%tky
              cancelledserialno = abap_true
            )
          )
        FAILED DATA(ls_serial_update_failed)
        REPORTED DATA(ls_serial_update_reported).

      IF ls_serial_update_failed IS NOT INITIAL.

        APPEND VALUE #(
          %tky = ls_header-%tky
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '097'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-orderconfirmation.

        CONTINUE.

      ENDIF.

      "Persist this change with the reversal transaction
      MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY orderconfirmation
          UPDATE FIELDS ( serialsposted )
          WITH VALUE #(
            (
              %tky          = ls_header-%tky
              serialsposted = abap_false
            )
          )
        FAILED DATA(ls_update_failed)
        REPORTED DATA(ls_update_reported).

      APPEND LINES OF ls_update_failed-orderconfirmation
        TO failed-orderconfirmation.

      APPEND LINES OF ls_update_reported-orderconfirmation
        TO reported-orderconfirmation.

      IF ls_update_failed IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '098'
            severity = if_abap_behv_message=>severity-success
            v1       = |{ ls_header-orderno }|
          )
      ) TO reported-orderconfirmation.

      READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY orderconfirmation
          ALL FIELDS
          WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_updated_headers).

      LOOP AT lt_updated_headers INTO DATA(ls_updated_header).
        APPEND VALUE #(
          %tky   = ls_updated_header-%tky
          %param = ls_updated_header
        ) TO result.
      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.


  METHOD getloadingrejects.
    CLEAR: et_rejects, ev_quantity, ev_error.
    IF is_header-orderno IS INITIAL OR is_header-order_type IS INITIAL
       OR is_header-material IS INITIAL OR is_header-batch_number IS INITIAL.
      RETURN.
    ENDIF.
    DATA lv_order TYPE c LENGTH 12.
    DATA lv_external_order TYPE c LENGTH 12.
    lv_order = is_header-orderno.
    lv_order = |{ lv_order ALPHA = IN WIDTH = 12 }|.
    lv_external_order = |{ lv_order ALPHA = OUT }|.

    "Only active/saved Loading Rejection headers and items are read.
    SELECT headeruuid, loadingrejqty
      FROM zi_load_rej_hdr
      WHERE ( prodorder = @lv_order OR prodorder = @lv_external_order )
        AND ordertype = @is_header-order_type
        AND plant = @is_header-plant
        AND batchnumber = @is_header-batch_number
        AND material = @is_header-material
      INTO TABLE @DATA(lt_loading_headers).

    IF lt_loading_headers IS INITIAL.
      RETURN.
    ENDIF.

    "Exclude serials already used by another active posted confirmation.
    SELECT s~serialno, s~material
      FROM zi_order_confirmation AS h
      INNER JOIN zi_serial_disposition AS s ON s~confirmid = h~confirmid
      WHERE ( h~orderno = @lv_order OR h~orderno = @lv_external_order )
        AND h~order_type = @is_header-order_type
        AND h~batch_number = @is_header-batch_number
        AND h~confirmid <> @is_header-confirmid
        AND ( h~status = 'POSTED' OR h~status = 'PART_POST' )
        AND ( s~approved = @abap_true OR s~rejected = @abap_true )
        AND s~cancelledserialno <> @abap_true
      INTO TABLE @DATA(lt_used).

    LOOP AT lt_loading_headers INTO DATA(ls_loading_header).
      SELECT serialno, material, rejcode, reasontext, remarks
        FROM zi_load_rej_itm
        WHERE headeruuid = @ls_loading_header-headeruuid AND reject = @abap_true
        INTO TABLE @DATA(lt_loading_items).

      IF CONV decfloat34( lines( lt_loading_items ) ) <> ls_loading_header-loadingrejqty.
        ev_error = VALUE ty_message( number = '060' ).
        RETURN.
      ENDIF.

      LOOP AT lt_loading_items INTO DATA(ls_loading_item).
        "Respect the source-material selection used by ZP09.
        IF is_header-order_type = 'ZP09' AND is_header-selectedmaterial IS NOT INITIAL
           AND ls_loading_item-material <> is_header-selectedmaterial.
          CONTINUE.
        ENDIF.

        DATA ls_target TYPE ty_loading_reject.
        CLEAR ls_target.
        ls_target-serialno = ls_loading_item-serialno.
        ls_target-material = is_header-material.
        ls_target-reasoncode = ls_loading_item-rejcode.
        ls_target-reasontext = ls_loading_item-reasontext.
        ls_target-remarks = ls_loading_item-remarks.
        DATA(lv_source_serial) = condense( |{ ls_loading_item-serialno ALPHA = OUT }| ).

        IF is_header-order_type = 'ZP07' OR is_header-order_type = 'YP07'.
          SELECT glazedserialno, kilnserialno, kilnmaterial
            FROM zi_kiln_itm
            WHERE glazedmaterial = @ls_loading_item-material
              AND kilnmaterial = @is_header-material
              AND kilnbatchno = @is_header-batch_number
            INTO TABLE @DATA(lt_mappings).
          DATA(lv_matches) = 0.
          LOOP AT lt_mappings INTO DATA(ls_mapping).
            IF condense( |{ ls_mapping-glazedserialno ALPHA = OUT }| ) = lv_source_serial
               AND ls_mapping-kilnserialno IS NOT INITIAL.
              lv_matches += 1.
              ls_target-serialno = ls_mapping-kilnserialno.
              ls_target-material = ls_mapping-kilnmaterial.
            ENDIF.
          ENDLOOP.
          IF lv_matches <> 1.
            ev_error = VALUE ty_message( number = '061'
          v1 = |{ lv_source_serial }| ).
            RETURN.
          ENDIF.
        ENDIF.

        DATA(lv_target_serial) = condense( |{ ls_target-serialno ALPHA = OUT }| ).
        DATA(lv_used) = abap_false.
        LOOP AT lt_used INTO DATA(ls_used).
          IF ls_used-material = ls_target-material
             AND condense( |{ ls_used-serialno ALPHA = OUT }| ) = lv_target_serial.
            lv_used = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_used = abap_true.
          CONTINUE.
        ENDIF.
        IF ls_target-reasontext IS INITIAL.
          ev_error = VALUE ty_message( number = '062'
          v1 = |{ lv_source_serial }| ).
          RETURN.
        ENDIF.
        LOOP AT et_rejects INTO DATA(ls_already).
          IF ls_already-material = ls_target-material
             AND condense( |{ ls_already-serialno ALPHA = OUT }| ) = lv_target_serial.
            ev_error = VALUE ty_message( number = '063'
          v1 = |{ lv_target_serial }| ).
            RETURN.
          ENDIF.
        ENDLOOP.
        APPEND ls_target TO et_rejects.
      ENDLOOP.
    ENDLOOP.
    "For an unconsumed complete order this equals the saved Loading Rejection Qty.
    "Partial confirmations use only still-available loading rejection serials.
    ev_quantity = lines( et_rejects ).
  ENDMETHOD.

  METHOD checkloadingsnapshot.
    CLEAR rv_error.
    "Posted/cancelled records retain their historical snapshot for cancellation.
    IF is_header-status <> 'CREATED'.
      RETURN.
    ENDIF.
    getloadingrejects( EXPORTING is_header = is_header
      IMPORTING et_rejects = DATA(lt_loading) ev_quantity = DATA(lv_quantity)
                ev_error = rv_error ).
    IF rv_error IS NOT INITIAL.
      RETURN.
    ENDIF.
    IF is_header-loadingrejectionqty <> lv_quantity.
      rv_error = VALUE ty_message( number = '064' ).
      RETURN.
    ENDIF.
    LOOP AT lt_loading INTO DATA(ls_loading).
      DATA(lv_found) = abap_false.
      DATA(lv_loading_serial) = condense( |{ ls_loading-serialno ALPHA = OUT }| ).
      LOOP AT it_serials INTO DATA(ls_serial).
        IF ls_serial-material <> ls_loading-material
           OR condense( |{ ls_serial-serialno ALPHA = OUT }| ) <> lv_loading_serial.
          CONTINUE.
        ENDIF.
        lv_found = abap_true.
        IF ls_serial-isloadingrejection <> abap_true
           OR ls_serial-approved <> abap_false OR ls_serial-rejected <> abap_true
           OR ls_serial-reasoncode <> ls_loading-reasoncode
           OR ls_serial-reasontext <> ls_loading-reasontext
           OR ls_serial-remarks <> ls_loading-remarks.
          rv_error = VALUE ty_message( number = '065'
          v1 = |{ lv_loading_serial }| ).
          RETURN.
        ENDIF.
      ENDLOOP.
      IF lv_found = abap_false.
        rv_error = VALUE ty_message( number = '066'
          v1 = |{ lv_loading_serial }| ).
        RETURN.
      ENDIF.
    ENDLOOP.
    LOOP AT it_serials INTO ls_serial WHERE isloadingrejection = abap_true.
      lv_found = abap_false.
      DATA(lv_serial) = condense( |{ ls_serial-serialno ALPHA = OUT }| ).
      LOOP AT lt_loading INTO ls_loading.
        IF ls_serial-material = ls_loading-material
           AND lv_serial = condense( |{ ls_loading-serialno ALPHA = OUT }| ).
          lv_found = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_found = abap_false.
        rv_error = VALUE ty_message( number = '067'
          v1 = |{ lv_serial }| ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateloadingrejections.
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers) FAILED DATA(ls_read_failed).
    LOOP AT ls_read_failed-orderconfirmation INTO DATA(ls_failed).
      APPEND VALUE #( %tky = ls_failed-%tky ) TO failed-orderconfirmation.
    ENDLOOP.
    LOOP AT lt_headers INTO DATA(ls_header).
      APPEND VALUE #( %tky = ls_header-%tky %state_area = 'LOADING_REJECTION' )
        TO reported-orderconfirmation.
      IF ls_header-status <> 'CREATED'.
        CONTINUE.
      ENDIF.
      READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY orderconfirmation BY \_serials ALL FIELDS
        WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_serials) FAILED DATA(ls_serial_failed).
      DATA(lv_error) = VALUE ty_message( ).
      IF ls_serial_failed IS NOT INITIAL.
        lv_error = VALUE ty_message( number = '068' ).
      ELSE.
        lv_error = checkloadingsnapshot(
          is_header = CORRESPONDING #( ls_header )
          it_serials = CORRESPONDING #( lt_serials ) ).
      ENDIF.
      IF lv_error IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_header-%tky ) TO failed-orderconfirmation.
        APPEND VALUE #( %tky = ls_header-%tky %state_area = 'LOADING_REJECTION'
          %element-loadingrejectionqty = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-orderconfirmation.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_serialdisposition DEFINITION
  INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS selectapproved
      FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR serialdisposition~selectapproved.

    METHODS selectrejected
      FOR DETERMINE ON MODIFY
      IMPORTING
        keys FOR serialdisposition~selectrejected.

    METHODS validatedisposition
      FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR serialdisposition~validatedisposition.

    METHODS approveallitems
      FOR MODIFY
      IMPORTING
                keys   FOR ACTION serialdisposition~approveallitems
      RESULT    result.

    METHODS unapproveallitems
      FOR MODIFY
      IMPORTING
                keys   FOR ACTION serialdisposition~unapproveallitems
      RESULT    result.

    METHODS setrejectionremarks FOR DETERMINE ON MODIFY
      IMPORTING keys
                  FOR serialdisposition~setrejectionremarks.

    "Add this method
    METHODS get_instance_features
      FOR INSTANCE FEATURES
      IMPORTING
                keys   REQUEST requested_features
                  FOR serialdisposition
      RESULT    result.


    METHODS validateloadingsource FOR VALIDATE ON SAVE
      IMPORTING keys FOR serialdisposition~validateloadingsource.
    METHODS precheck_update FOR PRECHECK
      IMPORTING entities FOR UPDATE serialdisposition.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE serialdisposition.

ENDCLASS.


CLASS lhc_serialdisposition IMPLEMENTATION.

  METHOD selectapproved.

    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition
        FIELDS ( approved isloadingrejection )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition
        UPDATE FIELDS ( rejected )
        WITH VALUE #(
          FOR ls_item IN lt_items
          WHERE ( approved = abap_true AND isloadingrejection = abap_false )
          (
            %tky     = ls_item-%tky
            rejected = abap_false
          )
        ).

  ENDMETHOD.


  METHOD selectrejected.

    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition
        FIELDS ( rejected isloadingrejection )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition
        UPDATE FIELDS ( approved )
        WITH VALUE #(
          FOR ls_item IN lt_items
          WHERE ( rejected = abap_true AND isloadingrejection = abap_false )
          (
            %tky     = ls_item-%tky
            approved = abap_false
          )
        ).

  ENDMETHOD.


  METHOD validatedisposition.

    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition
        FIELDS (
          approved
          rejected
          reasontext
        )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    LOOP AT lt_items INTO DATA(ls_item).

      "Invalidate the previous disposition state message before rechecking
      APPEND VALUE #(
        %tky = ls_item-%tky
        %state_area = 'DISPOSITION'
        %path-orderconfirmation-%tky = VALUE #(
          confirmid = ls_item-confirmid
          %is_draft = ls_item-%is_draft
        )
      ) TO reported-serialdisposition.

      "Both cannot be selected
      IF ls_item-approved = abap_true
         AND ls_item-rejected = abap_true.

        APPEND VALUE #(
          %tky = ls_item-%tky
        ) TO failed-serialdisposition.

        APPEND VALUE #(
          %tky              = ls_item-%tky
          %state_area = 'DISPOSITION'
          %path-orderconfirmation-%tky = VALUE #(
            confirmid = ls_item-confirmid
            %is_draft = ls_item-%is_draft
          )
          %element-approved = if_abap_behv=>mk-on
          %element-rejected = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '099'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-serialdisposition.

        CONTINUE.

      ENDIF.

      "Reason Text required when rejected
      IF ls_item-rejected = abap_true
         AND ls_item-reasontext IS INITIAL.

        APPEND VALUE #(
          %tky = ls_item-%tky
        ) TO failed-serialdisposition.

        APPEND VALUE #(
          %tky                = ls_item-%tky
          %state_area = 'DISPOSITION'
          %path-orderconfirmation-%tky = VALUE #(
            confirmid = ls_item-confirmid
            %is_draft = ls_item-%is_draft
          )
          %element-reasontext = if_abap_behv=>mk-on
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '100'
            severity = if_abap_behv_message=>severity-error
          )
        ) TO reported-serialdisposition.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD approveallitems.

    "Find the parent order of the selected serial row
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition BY \_orderconfirmation
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    "Read every serial belonging to that parent order
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation BY \_serials
        FIELDS ( approved rejected reasontext isloadingrejection )
        WITH CORRESPONDING #( lt_headers )
      RESULT DATA(lt_serials).

    "Approve all serials
    MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition
        UPDATE FIELDS ( approved rejected reasontext )
        WITH VALUE #(
          FOR ls_serial IN lt_serials
          WHERE ( isloadingrejection = abap_false )
          (
            %tky       = ls_serial-%tky
            approved   = abap_true
            rejected   = abap_false
            reasontext = ''
          )
        ).

    "Return the originally selected serial row
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #(
      FOR ls_result IN lt_result
      (
        %tky   = ls_result-%tky
        %param = ls_result
      )
    ).

  ENDMETHOD.
  METHOD unapproveallitems.

    "Find the parent order of the selected serial row
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition BY \_orderconfirmation
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    "Read every serial belonging to that parent order
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY orderconfirmation BY \_serials
        FIELDS ( approved rejected reasontext isloadingrejection )
        WITH CORRESPONDING #( lt_headers )
      RESULT DATA(lt_serials).

    "Unapprove all serials
    MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition
        UPDATE FIELDS ( approved rejected reasontext )
        WITH VALUE #(
          FOR ls_serial IN lt_serials
          WHERE ( isloadingrejection = abap_false )
          (
            %tky       = ls_serial-%tky
            approved   = abap_false
            rejected   = abap_false
            reasontext = ''
          )
        ).

    "Return the originally selected serial row
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #(
      FOR ls_result IN lt_result
      (
        %tky   = ls_result-%tky
        %param = ls_result
      )
    ).

  ENDMETHOD.

  METHOD setrejectionremarks.

    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition
      FIELDS ( rejected remarks isloadingrejection )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_serials)
      FAILED DATA(ls_read_failed)
      REPORTED DATA(ls_read_reported).

    LOOP AT ls_read_reported-orderconfirmation
      INTO DATA(ls_read_header_message).

      APPEND VALUE #(
        %tky = ls_read_header_message-%tky
        %msg = ls_read_header_message-%msg
      ) TO reported-orderconfirmation.

    ENDLOOP.

    LOOP AT ls_read_reported-serialdisposition
      INTO DATA(ls_read_serial_message).

      APPEND VALUE #(
        %tky = ls_read_serial_message-%tky
        %msg = ls_read_serial_message-%msg
      ) TO reported-serialdisposition.

    ENDLOOP.

    DATA lt_updates TYPE TABLE FOR UPDATE zi_serial_disposition.

    LOOP AT lt_serials INTO DATA(ls_serial).

      IF ls_serial-isloadingrejection = abap_true.
        CONTINUE.
      ENDIF.

      IF ls_serial-rejected = abap_true.

        "Set the default only when Remarks is blank
        IF ls_serial-remarks IS INITIAL.

          APPEND VALUE #(
            %tky    = ls_serial-%tky
            remarks = 'Unloading Rejection'
          ) TO lt_updates.

        ENDIF.

      ELSE.

        "Clear only the automatic default
        IF ls_serial-remarks = 'Unloading Rejection'.

          APPEND VALUE #(
            %tky    = ls_serial-%tky
            remarks = ''
          ) TO lt_updates.

        ENDIF.

      ENDIF.

    ENDLOOP.

    IF lt_updates IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition
      UPDATE FIELDS ( remarks )
      WITH lt_updates
      FAILED DATA(ls_update_failed)
      REPORTED DATA(ls_update_reported).

    LOOP AT ls_update_reported-orderconfirmation
      INTO DATA(ls_update_header_message).

      APPEND VALUE #(
        %tky = ls_update_header_message-%tky
        %msg = ls_update_header_message-%msg
      ) TO reported-orderconfirmation.

    ENDLOOP.

    LOOP AT ls_update_reported-serialdisposition
      INTO DATA(ls_update_serial_message).

      APPEND VALUE #(
        %tky = ls_update_serial_message-%tky
        %msg = ls_update_serial_message-%msg
      ) TO reported-serialdisposition.

    ENDLOOP.

    LOOP AT ls_update_failed-serialdisposition
      INTO DATA(ls_failed_serial).

      APPEND VALUE #(
        %tky = ls_failed_serial-%tky
        %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '101'
            severity = if_abap_behv_message=>severity-error
          )
      ) TO reported-serialdisposition.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_instance_features.
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition
      FIELDS ( approved rejected isloadingrejection )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_serials).
    result = VALUE #(
      FOR ls_serial IN lt_serials
      (
        %tky = ls_serial-%tky
        %update = COND #( WHEN ls_serial-isloadingrejection = abap_true
          THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
        %delete = COND #( WHEN ls_serial-isloadingrejection = abap_true
          THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
        %field-approved = COND #( WHEN ls_serial-isloadingrejection = abap_true
          THEN if_abap_behv=>fc-f-read_only ELSE if_abap_behv=>fc-f-unrestricted )
        %field-rejected = COND #( WHEN ls_serial-isloadingrejection = abap_true
          THEN if_abap_behv=>fc-f-read_only ELSE if_abap_behv=>fc-f-unrestricted )
        %field-reasoncode = COND #( WHEN ls_serial-isloadingrejection = abap_true
          THEN if_abap_behv=>fc-f-read_only ELSE if_abap_behv=>fc-f-unrestricted )
        %field-remarks = COND #( WHEN ls_serial-isloadingrejection = abap_true
          THEN if_abap_behv=>fc-f-read_only ELSE if_abap_behv=>fc-f-unrestricted )
        %field-reasontext = COND #(
          WHEN ls_serial-isloadingrejection = abap_false
            AND ls_serial-rejected = abap_true AND ls_serial-approved = abap_false
          THEN if_abap_behv=>fc-f-unrestricted ELSE if_abap_behv=>fc-f-read_only )
      )
    ).
  ENDMETHOD.


  METHOD validateloadingsource.
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items) FAILED DATA(ls_read_failed).
    LOOP AT ls_read_failed-serialdisposition INTO DATA(ls_failed).
      APPEND VALUE #( %tky = ls_failed-%tky ) TO failed-serialdisposition.
    ENDLOOP.
    DATA lt_checked_headers TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
    LOOP AT lt_items INTO DATA(ls_item).
      APPEND VALUE #( %tky = ls_item-%tky %state_area = 'LOADING_SOURCE'
        %path-orderconfirmation-%tky = VALUE #(
          confirmid = ls_item-confirmid %is_draft = ls_item-%is_draft )
      ) TO reported-serialdisposition.
      "Check the complete parent snapshot once, not once per changed serial.
      DATA(lv_header_key) = |{ ls_item-confirmid }_{ ls_item-%is_draft }|.
      INSERT lv_header_key INTO TABLE lt_checked_headers.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
        ENTITY serialdisposition BY \_orderconfirmation ALL FIELDS
        WITH VALUE #( ( %tky = ls_item-%tky ) )
        RESULT DATA(lt_headers).
      DATA(lv_error) = VALUE ty_message( ).
      IF lt_headers IS INITIAL.
        lv_error = VALUE ty_message( number = '069' ).
      ELSE.
        DATA(ls_header) = lt_headers[ 1 ].
        READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
          ENTITY orderconfirmation BY \_serials ALL FIELDS
          WITH VALUE #( ( %tky = ls_header-%tky ) )
          RESULT DATA(lt_serials) FAILED DATA(ls_serial_failed).
        IF ls_serial_failed IS NOT INITIAL.
          lv_error = VALUE ty_message( number = '070' ).
        ELSE.
          lv_error = lhc_orderconfirmation=>checkloadingsnapshot(
            is_header = CORRESPONDING #( ls_header )
            it_serials = CORRESPONDING #( lt_serials ) ).
        ENDIF.
      ENDIF.
      IF lv_error IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-serialdisposition.
        APPEND VALUE #( %tky = ls_item-%tky %state_area = 'LOADING_SOURCE'
          %path-orderconfirmation-%tky = VALUE #(
            confirmid = ls_item-confirmid %is_draft = ls_item-%is_draft )
          %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = lv_error-number
            severity = if_abap_behv_message=>severity-error
            v1       = lv_error-v1
            v2       = lv_error-v2
            v3       = lv_error-v3
            v4       = lv_error-v4
          )
        ) TO reported-serialdisposition.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD precheck_update.
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition FIELDS ( isloadingrejection )
      WITH CORRESPONDING #( entities )
      RESULT DATA(lt_items) FAILED DATA(ls_read_failed).
    LOOP AT ls_read_failed-serialdisposition INTO DATA(ls_failed).
      APPEND VALUE #( %tky = ls_failed-%tky ) TO failed-serialdisposition.
    ENDLOOP.
    LOOP AT lt_items INTO DATA(ls_item) WHERE isloadingrejection = abap_true.
      APPEND VALUE #( %tky = ls_item-%tky ) TO failed-serialdisposition.
      APPEND VALUE #( %tky = ls_item-%tky
        %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '102'
            severity = if_abap_behv_message=>severity-error
          )
      ) TO reported-serialdisposition.
    ENDLOOP.
  ENDMETHOD.

  METHOD precheck_delete.
    READ ENTITIES OF zi_order_confirmation IN LOCAL MODE
      ENTITY serialdisposition FIELDS ( isloadingrejection )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items) FAILED DATA(ls_read_failed).
    LOOP AT ls_read_failed-serialdisposition INTO DATA(ls_failed).
      APPEND VALUE #( %tky = ls_failed-%tky ) TO failed-serialdisposition.
    ENDLOOP.
    LOOP AT lt_items INTO DATA(ls_item) WHERE isloadingrejection = abap_true.
      APPEND VALUE #( %tky = ls_item-%tky ) TO failed-serialdisposition.
      APPEND VALUE #( %tky = ls_item-%tky
        %msg = new_message(
            id       = 'ZORDER_CONF'
            number   = '102'
            severity = if_abap_behv_message=>severity-error
          )
      ) TO reported-serialdisposition.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_zi_order_confirmation DEFINITION
  INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.


CLASS lsc_zi_order_confirmation IMPLEMENTATION.

  METHOD save_modified.

    LOOP AT lcl_confirmation_buffer=>entries
      INTO DATA(ls_entry).

      CONVERT KEY OF i_productionordconfirmationtp
        FROM ls_entry-pid
        TO DATA(ls_confirmation_key).

      UPDATE ztb__order_hdr
        SET confirmation_group =
              @ls_confirmation_key-confirmationgroup,
            confirmation_count =
              @ls_confirmation_key-confirmationcount
        WHERE confirm_id = @ls_entry-confirm_id.

    ENDLOOP.

    LOOP AT lcl_material_buffer=>entries
  INTO DATA(ls_material_entry).

      CONVERT KEY OF i_materialdocumenttp
        FROM ls_material_entry-pid
        TO DATA(ls_material_key).

      UPDATE ztb__order_hdr
        SET material_document =
              @ls_material_key-materialdocument,
            material_document_year =
              @ls_material_key-materialdocumentyear
        WHERE confirm_id = @ls_material_entry-confirm_id.

    ENDLOOP.

    CLEAR lcl_material_buffer=>entries.

  ENDMETHOD.

  METHOD cleanup_finalize.
    CLEAR lcl_confirmation_buffer=>entries.
    CLEAR lcl_material_buffer=>entries.
  ENDMETHOD.

ENDCLASS.

