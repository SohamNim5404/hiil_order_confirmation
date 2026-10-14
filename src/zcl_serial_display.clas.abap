CLASS zcl_serial_display DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.
ENDCLASS.


CLASS zcl_serial_display IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.

  IF line_exists(
    it_requested_calc_elements[
      table_line = `SERIALNODISPLAY`
    ]
  ).
    INSERT `SERIALNO` INTO TABLE et_requested_orig_elements.
  ENDIF.

ENDMETHOD.

METHOD if_sadl_exit_calc_element_read~calculate.

  TYPES:
    BEGIN OF ty_serial,
      SerialNo        TYPE string,
      SerialNoDisplay TYPE string,
    END OF ty_serial.

  DATA lt_serials TYPE STANDARD TABLE OF ty_serial
    WITH EMPTY KEY.

  lt_serials = CORRESPONDING #( it_original_data ).

  LOOP AT lt_serials ASSIGNING FIELD-SYMBOL(<ls_serial>).

    DATA(lv_display) = <ls_serial>-SerialNo.

    SHIFT lv_display LEFT DELETING LEADING '0'.

    IF lv_display IS INITIAL
       AND <ls_serial>-SerialNo IS NOT INITIAL.
      lv_display = '0'.
    ENDIF.

    <ls_serial>-SerialNoDisplay = lv_display.

  ENDLOOP.

  ct_calculated_data = CORRESPONDING #( lt_serials ).

ENDMETHOD.

ENDCLASS.
