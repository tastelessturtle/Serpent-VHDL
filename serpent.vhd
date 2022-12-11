-----------------------------------------------------------------------------
-- SERPENT cipher implementation in VHDL
-----------------------------------------------------------------------------
-- NAME:        serpent
-----------------------------------------------------------------------------
-- DESCRIPTION: This unit implements the SERPENT cipher in VHDL with
--              configurable plaintext and key. It does only implement
--              encryption of data.
-----------------------------------------------------------------------------
-- CHANGELOG:
--   10-12-2022 Created the repo.
--   11-12-2022 Finished first implementation.
-----------------------------------------------------------------------------
-- AUTHOR:      Erik Hagenaars
-----------------------------------------------------------------------------
-- LICENSE:     MIT License 
-----------------------------------------------------------------------------
-- Copyright (c) 2022 Erik Hagenaars
-----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- custom library which implements types, constant and functions
-- all cryptographic functions/implementations can be found there
library work;
use work.serpent_pkg.all;

-----------------------------------------------------------------------------
-- ENTITY serpent
-----------------------------------------------------------------------------
-- PORTS out
--   clk        Generic clock in signal for switching registers.
--   rst        Generic reset signal, active HIGH.
--   start      Start signal for starting the encryption.
--   plaintext  Configurable plaintext input.
--   userkey    Configurable userkey input.
-----------------------------------------------------------------------------
-- PORTS out
--   busy       When encrypting will signal HIGH and not accept new input.
--   valid      When output is valid will be HIGH for one clockcycle.
--   ciphertext Encrypted output which will be valid for one clockcycle.
-----------------------------------------------------------------------------
entity serpent is
    port(
        -- generic signals
        clk : in std_logic;
        rst : in std_logic;

        -- control signals
        start : in  std_logic;
        busy  : out std_logic := '0';
        valid : out std_logic := '0';

        -- data
        plaintext  : in  std_logic_vector(127 downto 0);
        userkey    : in  std_logic_vector(255 downto 0);
        ciphertext : out std_logic_vector(127 downto 0)
    );
end entity serpent;

-----------------------------------------------------------------------------
-- ARCHITECTURE serpent
-----------------------------------------------------------------------------
-- The Architecture of the entity implements a Finite State Machine (FSM) in
-- two processes:
--   (i)  fsm_logic: implements the state output and switching conditions
--   (ii) fsm_switching: implements the actual switching of states and
--        counters
-- Description of the states can be found in `serpent_pkg.vhd`. No FSM
-- diagram is provided.
-----------------------------------------------------------------------------
-- SIGNALS internal
--   (next)_state   Used for managing the FSM states.
--   (next)_ks_cnt  Counter to manage the keyschedule round.
--   (next)_en_cnt  Counter to manage the encryption round.
--   keyschedule    Registers to store all the round keys.
--   intermediate   Register to store intermediate values during encryption.
-----------------------------------------------------------------------------
-- VARIABLES
--   temp           Temporary variable for one clockcycle.
--   expansion      Stores the expansion round keys. Since the expansion is
--                  done on previous expansions and not the round keys.
-----------------------------------------------------------------------------
architecture rtl of serpent is
    -- FSM signals with counters
    signal state, next_state   : state_type            := sRESET;
    signal ks_cnt, next_ks_cnt : integer range 0 to 32 := 0;
    signal en_cnt, next_en_cnt : integer range 0 to 32 := 0;

    -- keyschedule and intermediate
    signal keyschedule  : keyschedule_type               := (others => (others => '0'));
    signal intermediate : std_logic_vector(127 downto 0) := (others => '0'); 
begin
    -- FSM logic procedure
    fsm_logic : process(state, start, ks_cnt, en_cnt) is
        -- temporary variables
        variable temp : std_logic_vector(127 downto 0);
        variable expansion : keyschedule_type;
    begin
        -- switch case for state machine
        case state is
            when sRESET =>
                -- external signals
                busy       <= '1';
                valid      <= '0';
                ciphertext <= (others => '0');

                -- internal signals
                next_ks_cnt  <= 0;
                next_en_cnt  <= 0;
                keyschedule  <= (others => (others => '0'));
                intermediate <= (others => '0');

                -- variables
                temp      := (others => '0');
                expansion := (others => (others => '0'));

                -- change state
                next_state <= sIDLE;

            when sIDLE =>
                -- external signals
                busy       <= '0';
                valid      <= '0';
                ciphertext <= (others => '0');

                -- internal signals
                next_ks_cnt  <= 0;
                next_en_cnt  <= 0;
                keyschedule  <= (others => (others => '0'));
                intermediate <= (others => '0');

                -- variables
                temp      := (others => '0');
                expansion := (others => (others => '0'));

                -- switch cases
                if start = '1' then
                    next_state <= sLOAD_DATA;
                end if;

            when sLOAD_DATA =>
                -- signal to be busy
                busy <= '1';
                
                -- load key and plaintext
                intermediate  <= plaintext;
                expansion(-2) := userkey(127 downto 0);
                expansion(-1) := userkey(255 downto 128);

                -- change state
                next_state <= sKEYSCHEDULE;
            
            when sKEYSCHEDULE =>
                -- expand keys, SBOX and initial poermutation
                expansion(ks_cnt)   := ExpandKey(expansion(ks_cnt-2), expansion(ks_cnt-1), ks_cnt);
                temp                := ApplySboxForKey(expansion(ks_cnt), (32+3-ks_cnt) mod 8);
                keyschedule(ks_cnt) <= InitialPermutation(temp);

                -- switch based on counter, we apply 33 rounds (0 to 32)
                if ks_cnt < 32 then
                    next_ks_cnt <= ks_cnt + 1;
                else
                    next_ks_cnt <= 0;
                    next_state  <= sINIT_PERM;
                end if;

            when sINIT_PERM=>
                -- apply initial permutation and go to next state
                intermediate <= InitialPermutation(intermediate);
                
                -- change state
                next_state <= sADD_ROUND_KEY;

            when sADD_ROUND_KEY =>
                -- add round key
                intermediate <= AddRoundKey(intermediate, keyschedule(en_cnt));

                -- change state, when counter is 32, we apply the last xXOR and go to final permutation
                if en_cnt = 32 then
                    next_en_cnt <= 0;
                    next_state <= sFINAL_PERM;
                else
                    next_state <= sSBOX;
                end if;
                

            when sSBOX =>
                -- apply sbox
                intermediate <= ApplySbox(intermediate, en_cnt mod 8);

                -- change state, always add one counter here, since ROUN_KEY needs to know if it is te last round
                -- this can cause some confusion but is a nice way to not add a seperate signal
                next_en_cnt <= en_cnt + 1;
                if en_cnt < 31 then
                    next_state <= sLIN_TRANSFORM;
                else
                    next_state <= sADD_ROUND_KEY;
                end if;

            when sLIN_TRANSFORM =>
                -- apply linear transformation
                intermediate <= LinearTransformation(intermediate);

                -- change state
                next_state <= sADD_ROUND_KEY;


            when sFINAL_PERM =>
                -- apply final permutation
                intermediate <= FinalPermutation(intermediate);

                -- change state
                next_state <= sFINISHED;


            when sFINISHED =>
                -- state, not busy any more and valid signal for one clockcycle
                busy       <= '0';
                valid      <= '1';
                ciphertext <= intermediate;

                -- go to next state immediately
                next_state <= sIDLE;

            -- fallback when unknown state is reached
            when others =>
                next_state <= sRESET;
        end case;
    end process fsm_logic;

    -- FSM switching procedure including reset
    fsm_switching : process(clk) is
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- no need to put all declarations here since this is done in sRESET
                state <= sRESET;
            else
                -- switch the state and all internal counters
                state  <= next_state;
                ks_cnt <= next_ks_cnt;
                en_cnt <= next_en_cnt;
            end if;
        end if;
    end process fsm_switching;

end architecture rtl;