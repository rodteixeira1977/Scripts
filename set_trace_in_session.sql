set verify off
set serveroutput on

define SID=&1

declare
  SerialNumber number;
  E_SESSION_NOT_FOUND exception;

  function GetSerial( pinSID in number ) return number is
    cursor CUR_GET_SERIAL ( pinSID number ) is
      select   SERIAL#
      from     V$SESSION
      where    SID = pinSID ;
    REC_GET_SERIAL CUR_GET_SERIAL%rowtype;
  begin
    open CUR_GET_SERIAL( pinSID );
    fetch CUR_GET_SERIAL into REC_GET_SERIAL;
      if not CUR_GET_SERIAL%found then
        raise E_SESSION_NOT_FOUND;
      end if;
    close CUR_GET_SERIAL;
    return REC_GET_SERIAL.SERIAL#;
  end;

  function GetTracingStatus( pinSID in number ) return boolean is
  begin
    return FALSE;
  end;

begin
  SerialNumber := GetSerial( &SID );
  dbms_output.put_line( 'enableing tracing in session ..: ' || to_char( &SID ) );
  dbms_output.put_line( 'the serial is .................: ' || to_char( SerialNumber ) );
  exec dbms_system.set_sql_trace_in_session( SID => &SID, SERIAL# => SerialNumber, SQL_TRACE => TRUE );

exception
  when E_SESSION_NOT_FOUND then begin
    dbms_output.put_line( 'The session could not be located.' );
  end;
end;
/
  
