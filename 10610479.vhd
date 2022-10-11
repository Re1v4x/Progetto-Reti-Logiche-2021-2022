----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 15.08.2022 18:49:55
-- Design Name: 
-- Module Name: project_reti_logiche - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
    port (
        i_clk       : in std_logic;
        i_rst       : in std_logic;
        i_start     : in std_logic;
        i_data      : in std_logic_vector(7 downto 0);
        o_address   : out std_logic_vector(15 downto 0);
        o_done      : out std_logic;
        o_en        : out std_logic;
        o_we        : out std_logic;
        o_data      : out std_logic_vector(7 downto 0)
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is

    type state_type is (IDLE, FETCH_W, GET_W, WAITRAM, FETCHWORD, GETWORD, CONV, WRITE1, WRITE2, DONE);
    type conv_state is (OO, OI, IO, II);                                        --O per stato 0, I per stato 1
    signal cur_state, next_state : state_type;                                  --segnali per stato FSM
    signal c_state, n_state : conv_state;                                       --segnali per sstato CON
    signal done_next, en_next, we_next : std_logic := '0';
    signal data_next : std_logic_vector(7 downto 0) := "00000000";
    signal o_address_next : std_logic_vector(15 downto 0) := "0000000000000000";
    signal address_next, address_cur : std_logic_vector(15 downto 0) := "0000000000000001";
    
    signal wrAddr, wrAddr_next : std_logic_vector(15 downto 0) := "0000001111100111";                                              --999 in binario
    signal counter, counter_next : integer range 0 to 8 := 8;
    signal cur_word, next_word : std_logic_vector(7 downto 0) := "00000000";
    signal words, words_next : integer range 0 to 255 := 0;
    signal finished, finished_next, readAdd, readAdd_next, convert, convert_next : boolean := FALSE;                                         --Per sincronizzare FSM e CON
    signal z_data, z_data_next : std_logic_vector(15 downto 0) := "0000000000000000";
    signal z1_data, z1_data_next : std_logic_vector(7 downto 0) := "00000000"; 
    signal z2_data, z2_data_next : std_logic_vector(7 downto 0) := "00000000";
    
begin

state_reg : process(i_clk, i_rst)
    begin
    if i_rst = '1' then
        cur_state <= IDLE;
        c_state <= OO;
        --Lista segnali in valori di default
        
        convert <= FALSE;
        address_cur <= "0000000000000001";
        wrAddr <= "0000001111100111";
        words <= 0;
    elsif (rising_edge(i_clk)) then
        o_done <= done_next;
        o_en <= en_next;
        o_we <= we_next;
        o_data <= data_next;
        o_address <= o_address_next;
        cur_state <= next_state;
        --valori segnali aggiornati con la loro controparte next ottenuta da altri processi
        wrAddr <= wrAddr_next;
        words <= words_next;
        cur_word <= next_word;
        address_cur <= address_next;
        readAdd <= readAdd_next;
        --aggiornamento della macchina CON:
        counter <= counter_next;
        convert <= convert_next;
        z_data <= z_data_next;
        z1_data <= z1_data_next;
        z2_data <= z2_data_next;
        c_state <= n_state;
        finished <= finished_next;
        
    end if;
end process;

FSM : process(cur_state, i_start, i_data, readAdd, finished, cur_word, words, address_cur, convert, z_data, z1_data, z2_data)
    
    begin
    
    done_next <= '0';
    en_next <= '0';
    we_next <= '0';
    data_next <= "00000000";
    o_address_next <= "0000000000000000";
    
    convert_next <= convert;
    next_word <= cur_word;
    wrAddr_next <= wrAddr;
    words_next <= words;
    next_state <= cur_state;
    address_next <= address_cur;
    readAdd_next <= readAdd;
    
    case cur_state is
        when IDLE =>
            if(i_start = '1') then
                next_state <= FETCH_W;
            end if;
        when FETCH_W =>
            en_next <= '1';
            we_next <= '0';
            if (readAdd = FALSE) then
                o_address_next <= "0000000000000000";
            end if;
            next_state <= WAITRAM;
        when GET_W =>
            if(readAdd = FALSE) then
                words_next <= conv_integer(i_data);
                readAdd_next <= TRUE;
                next_state <= FETCHWORD;
            end if;
        when WAITRAM =>
            if (readAdd = FALSE) then
                next_state <= GET_W;
            else
                next_state <= GETWORD;
            end if;
        when FETCHWORD =>
            if words = 0 then
                done_next <= '1';
                next_state <= DONE;
            else
                o_address_next <= address_cur;
                en_next <= '1';
                we_next <= '0';
                next_state <= WAITRAM;
            end if;
        when GETWORD =>
            next_word <= i_data;
            next_state <= CONV;
            convert_next <= TRUE;
        when CONV =>
            if (finished = TRUE) then
                o_address_next <= address_cur + wrAddr;
                data_next <= z1_data;
                en_next <= '1';
                we_next <= '1';
                next_state <= WRITE1;
                convert_next <= FALSE;
            end if;
        when WRITE1 =>
            o_address_next <= address_cur + wrAddr + "0000000000000001";
            data_next <= z2_data;
            en_next <= '1';
            we_next <= '1';
            if address_cur = words then
                done_next <= '1';
                next_state <= DONE;
            else
                next_state <= WRITE2;
                wrAddr_next <= wrAddr + "0000000000000001";
            end if;
        when WRITE2 =>
            next_state <= FETCHWORD;
            address_next <= address_cur + "0000000000000001";
        when DONE =>
            if (i_start = '0') then
                wrAddr_next <= "0000001111100111";
                address_next <= "0000000000000001";
                next_state <= IDLE;
                readAdd_next <= FALSE;
            end if;
    end case;
end process;

CON :    process(convert, cur_word, counter, finished, cur_state)
    begin
    
    finished_next <= FALSE;
    z_data_next <= z_data;
    n_state <= c_state;
    z_data_next <= z_data;
    z1_data_next <= z1_data;
    z2_data_next <= z2_data;
    counter_next <= counter;
    
    if (cur_state = CONV and counter = 0) then
        finished_next <= TRUE;
        z1_data_next <= z_data(15 downto 8);
        z2_data_next <= z_data(7 downto 0);
        counter_next <= 8;
    elsif (cur_state = CONV and convert = TRUE and finished = FALSE) then
        case c_state is
            when OO =>
                if cur_word(counter - 1) = '0' then
                    n_state <= OO;
                    z_data_next <= z_data(13 downto 0) & "00";
                else
                    n_state <= IO;
                    z_data_next <= z_data(13 downto 0) & "11";
                end if;
            when OI =>
                if cur_word(counter - 1) = '0' then
                    n_state <= OO;
                    z_data_next <= z_data(13 downto 0) & "11";
                else
                    n_state <= IO;
                    z_data_next <= z_data(13 downto 0) & "00";
                end if;
            when IO =>
                if cur_word(counter - 1) = '0' then
                    n_state <= OI;
                    z_data_next <= z_data(13 downto 0) & "01";
                else
                    n_state <= II;
                    z_data_next <= z_data(13 downto 0) & "10";
                end if;
            when II =>
                if cur_word(counter - 1) = '0' then
                    n_state <= OI;
                    z_data_next <= z_data(13 downto 0) & "10";
                else
                    n_state <= II;
                    z_data_next <= z_data(13 downto 0) & "01";
                end if;
        end case;
        counter_next <= counter - 1;
    elsif cur_state = IDLE then
        n_state <= OO;
        z_data_next <= "0000000000000000";
        z1_data_next <= "00000000";
        z2_data_next <= "00000000";
        counter_next <= 8;
    end if;
end process;

end Behavioral;
