-- Written by mehmetatay257@gmail.com
-- Device is NHD-0420DZW-AG5

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MOledDisplay is
generic (
    GSysClk : integer := 100   -- Ex: 50ms * 100MHz -> 50.000 * 100Hz
);                                                  -- WaitValue * GSysClk
port (
    PISys_Clk   : in std_logic;
    PISys_En    : in std_logic;
    PISys_Rst   : in std_logic;
    POSys_Fin   : out std_logic;
    PBSPI_Clk   : buffer std_logic;
    PBSPI_SS    : buffer std_logic;
    PISPI_MISO  : in std_logic;
    POSPI_MOSI  : out std_logic
);

end MOledDisplay;

architecture Behavioral of MOledDisplay is

-- SPI MASTER DECLARATION
component SPIMaster IS
  GENERIC(
    slaves  : INTEGER := 4;  --number of spi slaves
    d_width : INTEGER := 2); --data bus width
  PORT(
    clock   : IN     STD_LOGIC;                             --system clock
    reset_n : IN     STD_LOGIC;                             --asynchronous reset
    enable  : IN     STD_LOGIC;                             --initiate transaction
    cpol    : IN     STD_LOGIC;                             --spi clock polarity
    cpha    : IN     STD_LOGIC;                             --spi clock phase
    cont    : IN     STD_LOGIC;                             --continuous mode command
    clk_div : IN     INTEGER;                               --system clock cycles per 1/2 period of sclk
    addr    : IN     INTEGER;                               --address of slave
    tx_data : IN     STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --data to transmit
    miso    : IN     STD_LOGIC;                             --master in, slave out
    sclk    : BUFFER STD_LOGIC;                             --spi clock
    ss_n    : BUFFER STD_LOGIC;                             --slave select
    mosi    : OUT    STD_LOGIC;                             --master out, slave in
    busy    : OUT    STD_LOGIC;                             --busy / data ready signal
    rx_data : OUT    STD_LOGIC_VECTOR(d_width-1 DOWNTO 0)); --data received
END component;

-- SPI MASTER SIGNALS
signal SSPI_Rst : std_logic;
signal SSPI_En  : std_logic; 
signal SSPI_TXData : std_logic_vector(9 downto 0);
signal SSPI_Busy    : std_logic;
signal SSPI_RXData  : std_logic_vector(9 downto 0);

-- Module Signals
type machine is (Idle, Display, WaitState, SPISend);
signal state : machine := Idle;
signal ReturnToBefore : machine := Display;
signal after_state  : integer := 0;
signal init_state : integer := 0;

signal SClockCounter : integer := 0;
signal WaitValue : integer := 0;

signal SSPIBusyPrev : std_logic := '0';
signal SBusyCounter : integer := 0;
signal SDataSend  : std_logic_vector(9 downto 0);


-- Display Memory
type DisplayMemory is array (0 to 3, 0 to 19) of std_logic_vector(7 downto 0);
constant DisplayMemoryData : DisplayMemory := (
--     0      1      2      3      4      5     6       7      8      9     10     11     12     13     14     15     16     17     18     19
    (x"20", x"20", x"54", x"68", x"69", x"73", x"20", x"69", x"73", x"20", x"54", x"65", x"73", x"74", x"20", x"20", x"20", x"20", x"20", x"20"),  -- 0
    (x"20", x"4E", x"48", x"48", x"2D", x"41", x"47", x"35", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20"),  -- 1
    (x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20"),  -- 2
    (x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"4F", x"4E")   -- 3
);
signal column : integer := 0;
signal row    : integer := 0;


begin

process (PISys_Clk, PISys_Rst)
begin
    if (PISys_Rst = '0') then   -- Reset
        SSPI_Rst <= '0';
        state <= Idle;
        SDataSend <= (others => '0');


    elsif (PISys_Clk'event and PISys_Clk = '1') then
        case state is
            when Idle =>
                if PISys_En = '1' then
                    POSys_Fin <= '0';          -- Wait for Enable
                    state <= Display;
                    init_state <= 0;
                    SSPI_Rst <= '1';
                    row <= 0;
                    column <= 0;
                else
                    POSys_Fin <= '0';                    
                end if;

            when Display =>
                ReturnToBefore <= Display;
                case init_state is
                    when 0 =>
                        SDataSend <= "00" & "10000000";                         -- set line 1
                        WaitValue <= 600;
                        state <= SPISend;
                        after_state <= 1;

                    when 1 =>                                     
                        SDataSend <= "10" & DisplayMemoryData(row,column);      -- line 1
                        WaitValue <= 600;
                        state <= SPISend;
                        column <= column + 1;
                        if column > 19 then
                            column <= 0;
                            row <= row + 1;
                            after_state <= 2;
                        end if;

                    when 2 =>
                        SDataSend <= "00" & "11000000";                         -- set line 2
                        WaitValue <= 600;
                        state <= SPISend;
                        after_state <= 3;

                    when 3 =>                                     
                        SDataSend <= "10" & DisplayMemoryData(row,column);      -- line 2
                        WaitValue <= 600;
                        state <= SPISend;
                        column <= column + 1;
                        if column > 19 then
                            column <= 0;
                            row <= row + 1;
                            after_state <= 4;
                        end if;

                    when 4 =>
                        SDataSend <= "00" & "10010100";                         -- set line 3
                        WaitValue <= 600;
                        state <= SPISend;
                        after_state <= 5;
                    
                    when 5 =>                                     
                        SDataSend <= "10" & DisplayMemoryData(row,column);      -- line 3
                        WaitValue <= 600;
                        state <= SPISend;
                        column <= column + 1;
                        if column > 19 then
                            column <= 0;
                            row <= row + 1;
                            after_state <= 6;
                        end if;

                    when 6 =>
                        SDataSend <= "00" & "11010100";                         -- set line 4
                        WaitValue <= 600;
                        state <= SPISend;
                        after_state <= 7;

                    when 7 =>                                     
                        SDataSend <= "10" & DisplayMemoryData(row,column);      -- line 4
                        WaitValue <= 600;
                        state <= SPISend;
                        column <= column + 1;
                        if column > 19 then
                            column <= 0;
                            row <= row + 1;
                            after_state <= 8;
                        end if;

                    when 8 =>
                        POSys_Fin <= '1';
                        state <= Idle;

                    when others =>
                        null;
                end case;
                 
            when WaitState =>
                if (SClockCounter < (WaitValue * GSysClk - 1)) then -- Wait State
                    SClockCounter <= SClockCounter + 1;             -- WaitValue unit is usn
                else
                    SClockCounter <= 0;
                    state <= ReturnToBefore;
                end if;

            when SPISend =>
                SSPIBusyPrev <= SSPI_Busy;

                if (SSPIBusyPrev = '0' and SSPI_Busy = '1') then
                SBusyCounter <= SBusyCounter + 1;
                end if;
                case SBusyCounter is
                    when 0 =>
                        SSPI_En <= '1';
                        SSPI_TXData <= SDataSend;
                    when 1 =>
                        SSPI_En <= '0';
                        if (SSPI_Busy = '0') then
                            SBusyCounter <= 0;
                            SSPIBusyPrev <= '0';
                            state <= WaitState;
                            init_state <= after_state;
                        end if;
                    when others => null;
                end case;

            when others =>
                null;
        end case;    

    end if;
end process;


-- SPI MASTER INSTANTATION
SPI_INIT: SPIMaster
    generic map (
        slaves  => 1,   
        d_width => 10
    )
    port map (
        clock   => PISys_Clk,
        reset_n => SSPI_Rst,    -- Set 1 
        enable  => SSPI_En,
        cpol    => '1',         -- CPOL is 1 for OLED
        cpha    => '1',         -- CPHA is 1 for OLED
        cont    => '0',         -- CONTINOUS MODE
        clk_div => 32,          -- CLOK DIVIDE
        addr    => 0,
        tx_data => SSPI_TXData, -- DATA for SEND
        miso    => PISPI_MISO,  
        sclk    => PBSPI_Clk,   -- SPI CLOCK
        ss_n    => PBSPI_SS,    -- SELECT SLAVE
        mosi    => POSPI_MOSI,     
        busy    => SSPI_Busy,   -- SPI Busy signal
        rx_data => SSPI_RXData
    );

end Behavioral;
