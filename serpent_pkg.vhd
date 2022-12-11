library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package serpent_pkg is    

    -- all states of finite state machine
    type state_type is (
        sRESET,         -- reset all signals and variables to default value
        sIDLE,          -- wait for start signal to start encrypting
        sLOAD_DATA,     -- load the data provided

        sKEYSCHEDULE,   -- perform 32 round of keyschedule

        sINIT_PERM,     -- initial permutation of the data
        sADD_ROUND_KEY, -- add the round key
        sSBOX,          -- apply SBOX to data
        sLIN_TRANSFORM, -- apply linear transformation
        sFINAL_PERM,    -- final permutation of the data

        sFINISHED       -- output the result
    );

    -- all different array types
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
        return data xor round_key;
    end function AddRoundKey;

    -- apply the normal SBOX
    function ApplySbox (
        data  : std_logic_vector(127 downto 0);
        index : integer range 0 to 7
    ) return std_logic_vector is
        variable result : std_logic_vector(127 downto 0);
    begin
        -- apply SBOX
        for i in 0 to 31 loop
            result(127-i*4 downto 124-i*4) := SBOX(index)(to_integer(unsigned(data(127-i*4 downto 124-i*4))));
        end loop;

        -- return the result
        return result;
    end function ApplySbox;

    -- apply linear transformation on the data
    function LinearTransformation(
        data : std_logic_vector(127 downto 0)
    ) return std_logic_vector is
        variable result : std_logic_vector(127 downto 0);
    begin
        -- Linear Transform Table written out (to my knowledge no easy way to loop this other than cheating)
        result(  0) := data( 16) xor data( 52) xor data( 56) xor data( 70) xor data( 83) xor data( 94) xor data(105);
        result(  1) := data( 72) xor data(114) xor data(125);
        result(  2) := data(  2) xor data(  9) xor data( 15) xor data( 30) xor data( 76) xor data( 84) xor data(126);
        result(  3) := data( 36) xor data( 90) xor data(103);
        result(  4) := data( 20) xor data( 56) xor data( 60) xor data( 74) xor data( 87) xor data( 98) xor data(109);
        result(  5) := data(  1) xor data( 76) xor data(118);
        result(  6) := data(  2) xor data(  6) xor data( 13) xor data( 19) xor data( 34) xor data( 80) xor data( 88);
        result(  7) := data( 40) xor data( 94) xor data(107);
        result(  8) := data( 24) xor data( 60) xor data( 64) xor data( 78) xor data( 91) xor data(102) xor data(113);
        result(  9) := data(  5) xor data( 80) xor data(122);
        result( 10) := data(  6) xor data( 10) xor data( 17) xor data( 23) xor data( 38) xor data( 84) xor data( 92);
        result( 11) := data( 44) xor data( 98) xor data(111);
        result( 12) := data( 28) xor data( 64) xor data( 68) xor data( 82) xor data( 95) xor data(106) xor data(117);
        result( 13) := data(  9) xor data( 84) xor data(126);
        result( 14) := data( 10) xor data( 14) xor data( 21) xor data( 27) xor data( 42) xor data( 88) xor data( 96);
        result( 15) := data( 48) xor data(102) xor data(115);
        result( 16) := data( 32) xor data( 68) xor data( 72) xor data( 86) xor data( 99) xor data(110) xor data(121);
        result( 17) := data(  2) xor data( 13) xor data( 88);
        result( 18) := data( 14) xor data( 18) xor data( 25) xor data( 31) xor data( 46) xor data( 92) xor data(100);
        result( 19) := data( 52) xor data(106) xor data(119);
        result( 20) := data( 36) xor data( 72) xor data( 76) xor data( 90) xor data(103) xor data(114) xor data(125);
        result( 21) := data(  6) xor data( 17) xor data( 92);
        result( 22) := data( 18) xor data( 22) xor data( 29) xor data( 35) xor data( 50) xor data( 96) xor data(104);
        result( 23) := data( 56) xor data(110) xor data(123);
        result( 24) := data(  1) xor data( 40) xor data( 76) xor data( 80) xor data( 94) xor data(107) xor data(118);
        result( 25) := data( 10) xor data( 21) xor data( 96);
        result( 26) := data( 22) xor data( 26) xor data( 33) xor data( 39) xor data( 54) xor data(100) xor data(108);
        result( 27) := data( 60) xor data(114) xor data(127);
        result( 28) := data(  5) xor data( 44) xor data( 80) xor data( 84) xor data( 98) xor data(111) xor data(122);
        result( 29) := data( 14) xor data( 25) xor data(100);
        result( 30) := data( 26) xor data( 30) xor data( 37) xor data( 43) xor data( 58) xor data(104) xor data(112);
        result( 31) := data(  3) xor data(118);
        result( 32) := data(  9) xor data( 48) xor data( 84) xor data( 88) xor data(102) xor data(115) xor data(126);
        result( 33) := data( 18) xor data( 29) xor data(104);
        result( 34) := data( 30) xor data( 34) xor data( 41) xor data( 47) xor data( 62) xor data(108) xor data(116);
        result( 35) := data(  7) xor data(122);
        result( 36) := data(  2) xor data( 13) xor data( 52) xor data( 88) xor data( 92) xor data(106) xor data(119);
        result( 37) := data( 22) xor data( 33) xor data(108);
        result( 38) := data( 34) xor data( 38) xor data( 45) xor data( 51) xor data( 66) xor data(112) xor data(120);
        result( 39) := data( 11) xor data(126);
        result( 40) := data(  6) xor data( 17) xor data( 56) xor data( 92) xor data( 96) xor data(110) xor data(123);
        result( 41) := data( 26) xor data( 37) xor data(112);
        result( 42) := data( 38) xor data( 42) xor data( 49) xor data( 55) xor data( 70) xor data(116) xor data(124);
        result( 43) := data(  2) xor data( 15) xor data( 76);
        result( 44) := data( 10) xor data( 21) xor data( 60) xor data( 96) xor data(100) xor data(114) xor data(127);
        result( 45) := data( 30) xor data( 41) xor data(116);
        result( 46) := data(  0) xor data( 42) xor data( 46) xor data( 53) xor data( 59) xor data( 74) xor data(120);
        result( 47) := data(  6) xor data( 19) xor data( 80);
        result( 48) := data(  3) xor data( 14) xor data( 25) xor data(100) xor data(104) xor data(118);
        result( 49) := data( 34) xor data( 45) xor data(120);
        result( 50) := data(  4) xor data( 46) xor data( 50) xor data( 57) xor data( 63) xor data( 78) xor data(124);
        result( 51) := data( 10) xor data( 23) xor data( 84);
        result( 52) := data(  7) xor data( 18) xor data( 29) xor data(104) xor data(108) xor data(122);
        result( 53) := data( 38) xor data( 49) xor data(124);
        result( 54) := data(  0) xor data(  8) xor data( 50) xor data( 54) xor data( 61) xor data( 67) xor data( 82);
        result( 55) := data( 14) xor data( 27) xor data( 88);
        result( 56) := data( 11) xor data( 22) xor data( 33) xor data(108) xor data(112) xor data(126);
        result( 57) := data(  0) xor data( 42) xor data( 53);
        result( 58) := data(  4) xor data( 12) xor data( 54) xor data( 58) xor data( 65) xor data( 71) xor data( 86);
        result( 59) := data( 18) xor data( 31) xor data( 92);
        result( 60) := data(  2) xor data( 15) xor data( 26) xor data( 37) xor data( 76) xor data(112) xor data(116);
        result( 61) := data(  4) xor data( 46) xor data( 57);
        result( 62) := data(  8) xor data( 16) xor data( 58) xor data( 62) xor data( 69) xor data( 75) xor data( 90);
        result( 63) := data( 22) xor data( 35) xor data( 96);
        result( 64) := data(  6) xor data( 19) xor data( 30) xor data( 41) xor data( 80) xor data(116) xor data(120);
        result( 65) := data(  8) xor data( 50) xor data( 61);
        result( 66) := data( 12) xor data( 20) xor data( 62) xor data( 66) xor data( 73) xor data( 79) xor data( 94);
        result( 67) := data( 26) xor data( 39) xor data(100);
        result( 68) := data( 10) xor data( 23) xor data( 34) xor data( 45) xor data( 84) xor data(120) xor data(124);
        result( 69) := data( 12) xor data( 54) xor data( 65);
        result( 70) := data( 16) xor data( 24) xor data( 66) xor data( 70) xor data( 77) xor data( 83) xor data( 98);
        result( 71) := data( 30) xor data( 43) xor data(104);
        result( 72) := data(  0) xor data( 14) xor data( 27) xor data( 38) xor data( 49) xor data( 88) xor data(124);
        result( 73) := data( 16) xor data( 58) xor data( 69);
        result( 74) := data( 20) xor data( 28) xor data( 70) xor data( 74) xor data( 81) xor data( 87) xor data(102);
        result( 75) := data( 34) xor data( 47) xor data(108);
        result( 76) := data(  0) xor data(  4) xor data( 18) xor data( 31) xor data( 42) xor data( 53) xor data( 92);
        result( 77) := data( 20) xor data( 62) xor data( 73);
        result( 78) := data( 24) xor data( 32) xor data( 74) xor data( 78) xor data( 85) xor data( 91) xor data(106);
        result( 79) := data( 38) xor data( 51) xor data(112);
        result( 80) := data(  4) xor data(  8) xor data( 22) xor data( 35) xor data( 46) xor data( 57) xor data( 96);
        result( 81) := data( 24) xor data( 66) xor data( 77);
        result( 82) := data( 28) xor data( 36) xor data( 78) xor data( 82) xor data( 89) xor data( 95) xor data(110);
        result( 83) := data( 42) xor data( 55) xor data(116);
        result( 84) := data(  8) xor data( 12) xor data( 26) xor data( 39) xor data( 50) xor data( 61) xor data(100);
        result( 85) := data( 28) xor data( 70) xor data( 81);
        result( 86) := data( 32) xor data( 40) xor data( 82) xor data( 86) xor data( 93) xor data( 99) xor data(114);
        result( 87) := data( 46) xor data( 59) xor data(120);
        result( 88) := data( 12) xor data( 16) xor data( 30) xor data( 43) xor data( 54) xor data( 65) xor data(104);
        result( 89) := data( 32) xor data( 74) xor data( 85);
        result( 90) := data( 36) xor data( 90) xor data(103) xor data(118);
        result( 91) := data( 50) xor data( 63) xor data(124);
        result( 92) := data( 16) xor data( 20) xor data( 34) xor data( 47) xor data( 58) xor data( 69) xor data(108);
        result( 93) := data( 36) xor data( 78) xor data( 89);
        result( 94) := data( 40) xor data( 94) xor data(107) xor data(122);
        result( 95) := data(  0) xor data( 54) xor data( 67);
        result( 96) := data( 20) xor data( 24) xor data( 38) xor data( 51) xor data( 62) xor data( 73) xor data(112);
        result( 97) := data( 40) xor data( 82) xor data( 93);
        result( 98) := data( 44) xor data( 98) xor data(111) xor data(126);
        result( 99) := data(  4) xor data( 58) xor data( 71);
        result(100) := data( 24) xor data( 28) xor data( 42) xor data( 55) xor data( 66) xor data( 77) xor data(116);
        result(101) := data( 44) xor data( 86) xor data( 97);
        result(102) := data(  2) xor data( 48) xor data(102) xor data(115);
        result(103) := data(  8) xor data( 62) xor data( 75);
        result(104) := data( 28) xor data( 32) xor data( 46) xor data( 59) xor data( 70) xor data( 81) xor data(120);
        result(105) := data( 48) xor data( 90) xor data(101);
        result(106) := data(  6) xor data( 52) xor data(106) xor data(119);
        result(107) := data( 12) xor data( 66) xor data( 79);
        result(108) := data( 32) xor data( 36) xor data( 50) xor data( 63) xor data( 74) xor data( 85) xor data(124);
        result(109) := data( 52) xor data( 94) xor data(105);
        result(110) := data( 10) xor data( 56) xor data(110) xor data(123);
        result(111) := data( 16) xor data( 70) xor data( 83);
        result(112) := data(  0) xor data( 36) xor data( 40) xor data( 54) xor data( 67) xor data( 78) xor data( 89);
        result(113) := data( 56) xor data( 98) xor data(109);
        result(114) := data( 14) xor data( 60) xor data(114) xor data(127);
        result(115) := data( 20) xor data( 74) xor data( 87);
        result(116) := data(  4) xor data( 40) xor data( 44) xor data( 58) xor data( 71) xor data( 82) xor data( 93);
        result(117) := data( 60) xor data(102) xor data(113);
        result(118) := data(  3) xor data( 18) xor data( 72) xor data(114) xor data(118) xor data(125);
        result(119) := data( 24) xor data( 78) xor data( 91);
        result(120) := data(  8) xor data( 44) xor data( 48) xor data( 62) xor data( 75) xor data( 86) xor data( 97);
        result(121) := data( 64) xor data(106) xor data(117);
        result(122) := data(  1) xor data(  7) xor data( 22) xor data( 76) xor data(118) xor data(122);
        result(123) := data( 28) xor data( 82) xor data( 95);
        result(124) := data( 12) xor data( 48) xor data( 52) xor data( 66) xor data( 79) xor data( 90) xor data(101);
        result(125) := data( 68) xor data(110) xor data(121);
        result(126) := data(  5) xor data( 11) xor data( 26) xor data( 80) xor data(122) xor data(126);
        result(127) := data( 32) xor data( 86) xor data( 99); 
        
        -- return the result
        return result;
    end function LinearTransformation;

    -- apply the final permuation on the data
    function FinalPermutation (
        data : std_logic_vector(127 downto 0)
    ) return std_logic_vector is
        variable result : std_logic_vector(127 downto 0);
    begin
        -- apply final permutation on data
        for i in 0 to 127 loop
            result(i) := data(FP(i));
        end loop;
        
        -- return result
        return result;
    end function FinalPermutation;

end package body;