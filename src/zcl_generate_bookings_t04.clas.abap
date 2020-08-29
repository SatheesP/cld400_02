CLASS zcl_generate_bookings_t04 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .

  PROTECTED SECTION.

  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_generate_bookings_t04 IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    DATA: lt_bookings TYPE STANDARD TABLE OF ztbooking_t04.

    GET TIME STAMP FIELD DATA(lv_ts1).

    lt_bookings = VALUE #( ( booking = 1
                             customername = 'Sathees'
                             numberofpassengers = 3
                             emailaddress = 'xyz@gmail.come'
                             country = 'INDIA'
                             dateofbooking = '20200828142344'
                             dateoftravel  = '20200829142344'
                             cost = '1234.50'
                             currencycode = 'INR'
                             lastchangedat = lv_ts1 )

                            ( booking = 2
                             customername = 'Demi'
                             numberofpassengers = 2
                             emailaddress = 'demi@gmail.come'
                             country = 'US'
                             dateofbooking = '20200828142344'
                             dateoftravel  = '20200829142344'
                             cost = '123456789.00'
                             currencycode = 'USD'
                             lastchangedat = lv_ts1 )
                              ).

    DELETE FROM ztbooking_t04.

    INSERT ztbooking_t04 FROM TABLE @lt_bookings.

    SELECT * FROM ztbooking_t04 INTO TABLE @DATA(lt_booking_read).
    out->write( sy-dbcnt ).
    out->write( lt_booking_read ).

  ENDMETHOD.

ENDCLASS.
