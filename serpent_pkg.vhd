library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package serpent_pkg is    

    -- types
    type state_type is (
        sRESET, 
        sIDLE,
        sLOAD_DATA,
        sKEYSCHEDULE,
        sFINISHED
    );
    type keyschedule_type is array (integer range -2 to  32) of std_logic_vector(127 downto 0); -- to store all round keys
    type expansion_type   is array (integer range -8 to   3) of std_logic_vector( 31 downto 0); -- helpfull for key expansion
    type lookup_type      is array (integer range  0 to  15) of std_logic_vector(  3 downto 0);
    type sbox_type        is array (integer range  0 to   7) of lookup_type;
    type permutation_type is array (integer range  0 to 127) of integer range 0 to 127;

    -- constant values
    constant PHI : std_logic_vector(31 downto 0) := x"9e3779b9";
    constant SBOX : sbox_type := (
        (x"3", x"8", x"f", x"1", x"a", x"6", x"5", x"b", x"e", x"d", x"4", x"2", x"7", x"0", x"9", x"c"),
        (x"f", x"c", x"2", x"7", x"9", x"0", x"5", x"a", x"1", x"b", x"e", x"8", x"6", x"d", x"3", x"4"),
	    (x"8", x"6", x"7", x"9", x"3", x"c", x"a", x"f", x"d", x"1", x"e", x"4", x"0", x"b", x"5", x"2"),
	    (x"0", x"f", x"b", x"8", x"c", x"9", x"6", x"3", x"d", x"1", x"2", x"4", x"a", x"7", x"5", x"e"),
	    (x"1", x"f", x"8", x"3", x"c", x"0", x"b", x"6", x"2", x"5", x"4", x"a", x"9", x"e", x"7", x"d"),
	    (x"f", x"5", x"2", x"b", x"4", x"a", x"9", x"c", x"0", x"3", x"e", x"8", x"d", x"6", x"7", x"1"),
	    (x"7", x"2", x"c", x"5", x"8", x"4", x"6", x"b", x"e", x"9", x"1", x"f", x"d", x"3", x"a", x"0"),
	    (x"1", x"d", x"f", x"0", x"e", x"8", x"2", x"b", x"7", x"4", x"c", x"a", x"9", x"3", x"5", x"6")
    );
    constant IP : permutation_type := (
         0, 32, 64,  96,  1, 33, 65,  97,  2, 34, 66,  98,  3, 35, 67,  99,
         4, 36, 68, 100,  5, 37, 69, 101,  6, 38, 70, 102,  7, 39, 71, 103,
         8, 40, 72, 104,  9, 41, 73, 105, 10, 42, 74, 106, 11, 43, 75, 107,
        12, 44, 76, 108, 13, 45, 77, 109, 14, 46, 78, 110, 15, 47, 79, 111,
        16, 48, 80, 112, 17, 49, 81, 113, 18, 50, 82, 114, 19, 51, 83, 115,
        20, 52, 84, 116, 21, 53, 85, 117, 22, 54, 86, 118, 23, 55, 87, 119,
        24, 56, 88, 120, 25, 57, 89, 121, 26, 58, 90, 122, 27, 59, 91, 123,
        28, 60, 92, 124, 29, 61, 93, 125, 30, 62, 94, 126, 31, 63, 95, 127
    );
    constant FP : permutation_type := (
         0,  4,  8, 12, 16, 20, 24, 28, 32,  36,  40,  44,  48,  52,  56,  60,
        64, 68, 72, 76, 80, 84, 88, 92, 96, 100, 104, 108, 112, 116, 120, 124,
         1,  5,  9, 13, 17, 21, 25, 29, 33,  37,  41,  45,  49,  53,  57,  61,
        65, 69, 73, 77, 81, 85, 89, 93, 97, 101, 105, 109, 113, 117, 121, 125,
         2,  6, 10, 14, 18, 22, 26, 30, 34,  38,  42,  46,  50,  54,  58,  62,
        66, 70, 74, 78, 82, 86, 90, 94, 98, 102, 106, 110, 114, 118, 122, 126,
         3,  7, 11, 15, 19, 23, 27, 31, 35,  39,  43,  47,  51,  55,  59,  63,
        67, 71, 75, 79, 83, 87, 91, 95, 99, 103, 107, 111, 115, 119, 123, 127
    );

    -- functions (ordered by time of apearance)
    function ExpandKey (previous, current: std_logic_vector(127 downto 0); ks_round : integer range 0 to 32) return std_logic_vector;
    function ApplySboxForKey (data : std_logic_vector(127 downto 0); index : integer range 0 to 7) return std_logic_vector;
    function InitialPermutation (data : std_logic_vector(127 downto 0)) return std_logic_vector;
    function AddRoundKey (data, round_key : std_logic_vector(127 downto 0)) return std_logic_vector;
    function ApplySbox (data : std_logic_vector(127 downto 0); index : integer range 0 to 7) return std_logic_vector;
    function LinearTransformation(data : std_logic_vector(127 downto 0)) return std_logic_vector;
    function FinalPermutation (data : std_logic_vector(127 downto 0)) return std_logic_vector;

end package serpent_pkg;

package body serpent_pkg is

    -- expand the next round key
    function ExpandKey (
        previous, current : std_logic_vector(127 downto 0); -- previous two round keys
        ks_round          : integer range 0 to 32           -- round number to be calculated
    ) return std_logic_vector is
        -- easy array to expand the key on
        variable w : expansion_type := (
            previous(31 downto 0), previous(63 downto 32), previous(95 downto 64), previous(127 downto 96),
            current( 31 downto 0), current( 63 downto 32), current( 95 downto 64), current( 127 downto 96),
            others => x"00000000"
        );
    begin
        -- expand key 4 times
        for i in 0 to 3 loop -- first all xors then the rotate
            w(i) := w(i-8) xor w(i-5) xor w(i-3) xor w(i-1) xor PHI xor std_logic_vector(to_unsigned(ks_round*4+i,32));
            w(i) := w(i)(20 downto 0) & w(i)(31 downto 21);
        end loop;
        
        -- return result
        return w(3) & w(2) & w(1) & w(0);
    end function ExpandKey;

    -- Apply the SBOX on round keys (which is different from normal SBOX during encryption)
    function ApplySboxForKey (
        data  : std_logic_vector(127 downto 0);
        index : integer range 0 to 7
    ) return std_logic_vector is
        variable result     : std_logic_vector(127 downto 0); -- for storing the result
        variable sbox_state : std_logic_vector(  3 downto 0); -- for input and output of the sbox
    begin
        -- for 32 pairs of 4 bits, apply SBOX
        for i in 0 to 31 loop
            -- apply sbox
            sbox_state := data(127-i) & data(95-i) & data(63-i) & data(31-i);
            sbox_state := SBOX(index)(to_integer(unsigned(sbox_state)));

            -- store sbox in result
            result(127-i) := sbox_state(3);
            result( 95-i) := sbox_state(2);
            result( 63-i) := sbox_state(1);
            result( 31-i) := sbox_state(0);
        end loop;

        -- return result
        return result;
    end function ApplySboxForKey;

    -- Apply the initial Pemutation on the data
    function InitialPermutation (
        data : std_logic_vector(127 downto 0)
    ) return std_logic_vector is
        variable result : std_logic_vector(127 downto 0);
    begin
        -- apply initial permutation on data
        for i in 0 to 127 loop
            result(i) := data(IP(i));
        end loop;
        
        -- return result
        return result;
    end function InitialPermutation;

    -- Add the round key on data
    function AddRoundKey (
        data, round_key : std_logic_vector(127 downto 0)
    ) return std_logic_vector is
    begin
        -- TODO
    end function AddRoundKey;

    -- apply the normal SBOX
    function ApplySbox (
        data  : std_logic_vector(127 downto 0);
        index : integer range 0 to 7) return std_logic_vector is
    begin
        -- TODO
    end function ApplySbox;

    -- apply linear transformation on the data
    function LinearTransformation(
        data : std_logic_vector(127 downto 0)
    ) return std_logic_vector is
    begin
        -- TODO
    end function LinearTransformation;

    -- apply the final permuation on the data
    function FinalPermutation (
        data : std_logic_vector(127 downto 0)
    ) return std_logic_vector is
    begin
        -- TODO
    end function FinalPermutation;

end package body;