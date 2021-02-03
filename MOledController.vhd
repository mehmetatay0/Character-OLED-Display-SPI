-- Written by mehmetatay257@gmail.com
-- Device is NHD-0420DZW-AG5

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MOledController is
generic (
    GSysClk : integer := 100   -- Ex: 50ms * 100MHz -> 50.000 * 100Hz
);       
port (
    PISys_Clk   : in std_logic;
    PISys_Rst   : in std_logic;
    PBSPI_Clk   : buffer std_logic;
    PBSPI_SS    : buffer std_logic;
    PISPI_MISO  : in std_logic;
    POSPI_MOSI  : out std_logic
);
end MOledController;

architecture Behavioral of MOledController is

component MOledInitialize is
generic (
    GSysClk : integer := 100
);
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
end component;

component MOledDisplay is
generic (
    GSysClk : integer := 100   
);                             
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

end component;

-- for initialize
signal SSPI_Clk1   : std_logic;
signal SSPI_SS1    : std_logic;
signal SSPI_MISO1  : std_logic;
signal SSPI_MOSI1  : std_logic;

signal SInit_En  : std_logic;
signal SInit_Rst : std_logic;
signal SInit_Fin : std_logic;

-- for display
signal SSPI_Clk2   : std_logic;
signal SSPI_SS2    : std_logic;
signal SSPI_MISO2  : std_logic;
signal SSPI_MOSI2  : std_logic;

signal SDisp_En  : std_logic;
signal SDisp_Rst : std_logic;
signal SDisp_Fin : std_logic;

-- Module Signals
type machine is (Idle, Init, Display);
signal state : machine := Init;
signal init_state : integer := 0;
signal disp_state : integer := 0;


begin

-- Select SPI
PBSPI_Clk  <= SSPI_Clk1 when (state = Init) else
              SSPI_Clk2;
PBSPI_SS   <= SSPI_SS1 when (state = Init) else
              SSPI_SS2;
POSPI_MOSI <= SSPI_MOSI1 when (state = Init) else
              SSPI_MOSI2;

-- Process
process (PISys_Clk, PISys_Rst)
begin
    if PISys_Rst = '0' then
        
    elsif PISys_Clk'event and PISys_Clk = '1' then
        case state is
            when Idle =>
                
            when Init =>
                case init_state is
                    when 0 =>
                        SInit_En <= '1';
                        init_state <= 1;
                        SInit_Rst <= '1';
                    when 1 =>
                        SInit_En <= '0';
                        if SInit_Fin = '1' then
                            init_state <= 0;
                            SInit_Rst <= '0';
                            state <= Display;
                        end if;
                    when others =>
                        null;
                end case;

            when Display =>
                case disp_state is
                    when 0 =>
                        SDisp_En <= '1';
                        disp_state <= 1;
                        SDisp_Rst <= '1';
                    when 1 =>
                        SDisp_En <= '0';
                        if SDisp_Fin = '1' then
                            disp_state <= 0;
                            SDisp_Rst <= '0';
                            state <= Idle;
                        end if;
                    when others =>
                        null;
                end case;
                
            when others =>
                null;
        end case;



    end if;
end process;

-- Component Instantiation
OledInitialize : MOledInitialize
    generic map (
        GSysClk => 100
    )
    port map (
        PISys_Clk   => PISys_Clk,
        PISys_En    => SInit_En,
        PISys_Rst   => SInit_Rst,
        POSys_Fin   => SInit_Fin,
        PBSPI_Clk   => SSPI_Clk1,
        PBSPI_SS    => SSPI_SS1,
        PISPI_MISO  => SSPI_MISO1,
        POSPI_MOSI  => SSPI_MOSI1
    );

OledDisplay : MOledDisplay
    generic map (
        GSysClk => 100
    )
    port map (
        PISys_Clk   => PISys_Clk,
        PISys_En    => SDisp_En,
        PISys_Rst   => SDisp_Rst,
        POSys_Fin   => SDisp_Fin,
        PBSPI_Clk   => SSPI_Clk2,
        PBSPI_SS    => SSPI_SS2,
        PISPI_MISO  => SSPI_MISO2,
        POSPI_MOSI  => SSPI_MOSI2
    );

end Behavioral;
