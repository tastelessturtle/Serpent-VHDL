library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.serpent_pkg.all;

entity serpent is
    port(
        -- generic signals
        clk : in std_logic;
        rst : in std_logic;

        -- control signals
        start : in  std_logic;
        busy  : out std_logic := '0';

        -- data
        plaintext  : in  std_logic_vector(127 downto 0);
        userkey    : in  std_logic_vector(255 downto 0);
        ciphertext : out std_logic_vector(127 downto 0)
    );
end entity serpent;

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
        variable temp : std_logic_vector(127 downto 0); -- used for temporary values between encryption
        variable expansion : keyschedule_type;          -- used for key expansion (since we do not expand on round keys)
    begin
        case state is
            -- reset signals are set before going to IDLE
            when sRESET =>
                busy       <= '1';
                ciphertext <= (others => '0');
                next_state <= sIDLE;

            -- wait for start signal to start encryption
            when sIDLE =>
                -- state
                busy       <= '0';
                ciphertext <= (others => '0');

                -- switch cases
                if start = '1' then
                    next_state <= sLOAD_DATA;
                end if;

            -- load the key and plaintext
            when sLOAD_DATA =>
                -- state
                busy <= '1';
                
                -- load key and plaintext
                intermediate  <= plaintext;
                expansion(-2) := userkey(127 downto 0);
                expansion(-1) := userkey(255 downto 128);

                -- change state
                next_state <= sKEYSCHEDULE;
            
            -- for each round generate a round key (32 times)
            when sKEYSCHEDULE =>
                -- expand keys, SBOX
                expansion(ks_cnt)   := ExpandKey(expansion(ks_cnt-2), expansion(ks_cnt-1), ks_cnt);
                temp                := ApplySboxForKey(expansion(ks_cnt), (32+3-ks_cnt) mod 8);
                keyschedule(ks_cnt) <= InitialPermutation(temp);

                -- switch based on counter
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

                -- change state
                if en_cnt = 32 then
                    next_en_cnt <= 0;
                    next_state <= sFINAL_PERM;
                else
                    next_state <= sSBOX;
                end if;
                

            when sSBOX =>
                -- apply sbox
                intermediate <= ApplySbox(intermediate, en_cnt mod 8);

                -- change state
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


            -- put busy down with valid ciphertext
            when sFINISHED =>
                -- state
                busy       <= '0';
                ciphertext <= intermediate;

                -- reset internal signals
                intermediate <= (others => '0');
                keyschedule  <= (others => (others => '0'));

                -- go to next state immediately
                next_state <= sIDLE;

            -- fallback when unknown state is reacheds
            when others =>
                next_state <= sRESET;
        end case;
    end process fsm_logic;

    -- FSM switching procedure including reset
    fsm_switching : process(clk) is
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= sRESET;
            else
                state  <= next_state;
                ks_cnt <= next_ks_cnt;
                en_cnt <= next_en_cnt;
            end if;
        end if;
    end process fsm_switching;

end architecture rtl;