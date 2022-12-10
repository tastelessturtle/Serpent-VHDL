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
    type keyschedule_type is array (integer range -2 to 32) of std_logic_vector(127 downto 0);

end package serpent_pkg;

package body serpent_pkg is
end package body;