CLASS lcl_buffer DEFINITION.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_buffer.
             INCLUDE TYPE ztbooking_t04 AS data.
    TYPES:   flag TYPE c LENGTH 1,
           END OF ty_buffer,

           tt_bookings TYPE  SORTED TABLE OF ty_buffer WITH UNIQUE KEY booking.

    CLASS-DATA mt_buffer  TYPE  tt_bookings.

ENDCLASS.

CLASS lhc_booking DEFINITION FINAL INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS create FOR MODIFY
      IMPORTING it_entities FOR CREATE booking.

    METHODS delete FOR MODIFY
      IMPORTING it_keys FOR DELETE booking.

    METHODS update FOR MODIFY
      IMPORTING it_entities FOR UPDATE booking.

    METHODS lock FOR LOCK
      IMPORTING it_keys FOR LOCK booking.

    METHODS read FOR READ
      IMPORTING it_keys FOR READ booking RESULT et_result.

ENDCLASS.

CLASS lhc_booking IMPLEMENTATION.

  METHOD create.

    IF it_entities IS NOT INITIAL.
      " if there are creates, then we need to know the maximum booking number.
      SELECT SINGLE MAX( Booking ) FROM ztbooking_t04 INTO @DATA(lv_max_booking).
    ENDIF.

    LOOP AT it_entities INTO DATA(ls_entity).
      " next booking number
      lv_max_booking += 1.
      ls_entity-%data-Booking = lv_max_booking.
      " handle field LastChangedAt
      GET TIME STAMP FIELD DATA(lv_tsl).
      ls_entity-%data-LastChangedAt = lv_tsl.

      " insert as created into buffer
      INSERT VALUE #( flag = 'C' data = CORRESPONDING #( ls_entity-%data ) )
        INTO TABLE lcl_buffer=>mt_buffer.

      " tell framework about new key if a content id (%cid) is used:
      IF ls_entity-%cid IS NOT INITIAL.
        INSERT VALUE #( %cid = ls_entity-%cid booking = ls_entity-Booking )
          INTO TABLE mapped-booking.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD delete.

    LOOP AT it_keys INTO DATA(ls_key).
      " check for content id (%cid) handling
      IF ls_key-Booking IS INITIAL.
        ls_key-Booking = mapped-booking[ %cid = ls_key-%cid_ref ]-Booking.
      ENDIF.

      READ TABLE lcl_buffer=>mt_buffer WITH KEY booking = ls_key-Booking
            ASSIGNING FIELD-SYMBOL(<ls_buffer>).
      IF sy-subrc = 0.
        " already in buffer, check why
        IF <ls_buffer>-flag = 'C'.
          " delete after create => just remove from buffer
          DELETE TABLE lcl_buffer=>mt_buffer WITH TABLE KEY booking = ls_key-Booking.
        ELSE.
          <ls_buffer>-flag = 'D'.
        ENDIF.
      ELSE.
        " not yet in buffer
        INSERT VALUE #( flag = 'D' booking = ls_key-Booking ) INTO TABLE lcl_buffer=>mt_buffer.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD update.

    IF it_entities IS NOT INITIAL.
      LOOP AT it_entities INTO DATA(ls_update).
        " check for content id (%cid) handling
        IF ls_update-Booking IS INITIAL.
          ls_update-Booking = mapped-booking[ %cid = ls_update-%cid_ref ]-booking.
        ENDIF.
        " search in buffer
        READ TABLE lcl_buffer=>mt_buffer WITH KEY booking = ls_update-Booking ASSIGNING FIELD-SYMBOL(<ls_buffer>).
        IF sy-subrc <> 0.
          " not yet in buffer, read from table

          SELECT SINGLE * FROM ztbooking_t04 WHERE booking = @ls_update-Booking INTO @DATA(ls_db).
          INSERT VALUE #( flag = 'U' data = ls_db ) INTO TABLE lcl_buffer=>mt_buffer ASSIGNING <ls_buffer>.
        ENDIF.

        IF ls_update-%control-customername IS NOT INITIAL..
          <ls_buffer>-customername = ls_update-customername.
        ENDIF.

        IF ls_update-%control-cost IS NOT INITIAL..
          <ls_buffer>-cost = ls_update-cost.
        ENDIF.

        IF ls_update-%control-dateoftravel IS NOT INITIAL.
          <ls_buffer>-dateoftravel = ls_update-dateoftravel.
        ENDIF.

        IF ls_update-%control-currencycode IS NOT INITIAL.
          <ls_buffer>-currencycode = Ls_update-currencycode.
        ENDIF.

        GET TIME STAMP FIELD DATA(lv_tsl).
        <ls_buffer>-lastchangedat = lv_tsl. "handling for field LastChangedAt (for ETag)

      ENDLOOP.
    ENDIF.

  ENDMETHOD.

  METHOD lock.

    " provide the appropriate lock handling if required

  ENDMETHOD.

  METHOD read.

    LOOP AT it_keys INTO DATA(ls_key).
      " check if it is in buffer (and not deleted).
      READ TABLE lcl_buffer=>mt_buffer WITH KEY booking = ls_key-Booking INTO DATA(ls_booking).
      IF sy-subrc = 0 AND ls_booking-flag <> 'U'.
        INSERT CORRESPONDING #( ls_booking-data ) INTO TABLE et_result.
      ELSE.
        SELECT SINGLE * FROM ztbooking_t04 WHERE booking = @ls_key-Booking INTO @DATA(LS_db).
        IF sy-subrc = 0.
          INSERT CORRESPONDING #( ls_db ) INTO TABLE et_result.
        ELSE.
          INSERT VALUE #( booking = ls_key-Booking ) INTO TABLE failed-booking.
        ENDIF.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

CLASS lsc_ZI_BOOKING_T004 DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS check_before_save REDEFINITION.

    METHODS finalize          REDEFINITION.

    METHODS save              REDEFINITION.

ENDCLASS.

CLASS lsc_ZI_BOOKING_T004 IMPLEMENTATION.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD finalize.
  ENDMETHOD.

  METHOD save.

    DATA lt_data TYPE STANDARD TABLE OF ztbooking_t04.

    " find all rows in buffer with flag = created
    lt_data = VALUE #( FOR row IN lcl_buffer=>mt_buffer WHERE ( flag = 'C' ) ( row-data ) ).
    IF lt_data IS NOT INITIAL.
      INSERT ztbooking_t04 FROM TABLE @lt_data.
    ENDIF.

    " find all rows in buffer with flag = updated
    lt_data = VALUE #( FOR row IN lcl_buffer=>mt_buffer WHERE ( flag = 'U' ) ( row-data ) ).
    IF lt_data IS NOT INITIAL.
      UPDATE ztbooking_t04 FROM TABLE @lt_data.
    ENDIF.

    " find all rows in buffer with flag = deleted
    lt_data = VALUE #( FOR row IN lcl_buffer=>mt_buffer WHERE ( flag = 'D' ) ( row-data ) ).
    IF lt_data IS NOT INITIAL.
      DELETE ztbooking_t04 FROM TABLE @lt_data.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
