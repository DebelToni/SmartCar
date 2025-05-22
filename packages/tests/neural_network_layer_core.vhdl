library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity NeuralLayer is
    Generic (
        N_INPUTS  : integer := 16;
        N_NEURONS : integer := 8;
        DATA_WIDTH: integer := 16
    );
    Port (
        clk       : in  STD_LOGIC;
        reset     : in  STD_LOGIC;
        input_vec : in  STD_LOGIC_VECTOR(N_INPUTS * DATA_WIDTH - 1 downto 0);
        weights   : in  STD_LOGIC_VECTOR(N_NEURONS * N_INPUTS * DATA_WIDTH - 1 downto 0);
        bias      : in  STD_LOGIC_VECTOR(N_NEURONS * DATA_WIDTH - 1 downto 0);
        enable    : in  STD_LOGIC;
        output_neurons : out STD_LOGIC_VECTOR(N_NEURONS * DATA_WIDTH - 1 downto 0);
        done      : out STD_LOGIC
    );
end NeuralLayer;

architecture Behavioral of NeuralLayer is

    type neuron_array is array (0 to N_NEURONS -1) of signed(DATA_WIDTH -1 downto 0);
    type input_array  is array (0 to N_INPUTS -1) of signed(DATA_WIDTH -1 downto 0);
    type weight_matrix is array (0 to N_NEURONS -1, 0 to N_INPUTS -1) of signed(DATA_WIDTH -1 downto 0);

    signal input_vec_signed    : input_array;
    signal weights_signed      : weight_matrix;
    signal bias_signed         : neuron_array;
    signal neuron_sums         : neuron_array;
    signal temp_sum            : signed(DATA_WIDTH + integer(ceil(log2(real(N_INPUTS)))) -1 downto 0);
    signal compute_enable      : STD_LOGIC := '0';
    signal neuron_idx          : integer range 0 to N_NEURONS := 0;
    signal input_idx           : integer range 0 to N_INPUTS := 0;
    signal processing          : boolean := false;
    signal done_reg            : STD_LOGIC := '0';

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                neuron_idx <= 0;
                input_idx <= 0;
                processing <= false;
                done_reg <= '0';
            elsif enable = '1' then
                if not processing then
                    for i in 0 to N_INPUTS -1 loop
                        input_vec_signed(i) <= signed(input_vec(i*DATA_WIDTH + DATA_WIDTH -1 downto i*DATA_WIDTH));
                    end loop;
                    for n in 0 to N_NEURONS -1 loop
                        for i in 0 to N_INPUTS -1 loop
                            weights_signed(n, i) <= signed(weights((n * N_INPUTS + i)*DATA_WIDTH + DATA_WIDTH -1 downto (n * N_INPUTS + i)*DATA_WIDTH));
                        end loop;
                        bias_signed(n) <= signed(bias(n*DATA_WIDTH + DATA_WIDTH -1 downto n*DATA_WIDTH));
                    end loop;
                    neuron_idx <= 0;
                    processing <= true;
                    done_reg <= '0';
                else
                    if neuron_idx < N_NEURONS then
                        temp_sum <= (others => '0');
                        input_idx <= 0;
                        for i in 0 to N_INPUTS -1 loop
                            temp_sum <= temp_sum + resize(input_vec_signed(i), temp_sum'length) * resize(weights_signed(neuron_idx, i), temp_sum'length);
                        end loop;
                        temp_sum <= temp_sum + resize(bias_signed(neuron_idx), temp_sum'length);
                        neuron_sums(neuron_idx) <= signed(temp_sum(temp_sum'high downto temp_sum'high - DATA_WIDTH +1));
                        neuron_idx <= neuron_idx + 1;
                    else
                        processing <= false;
                        -- Activation function can be added here if needed
                        for n in 0 to N_NEURONS -1 loop
                            output_neurons(n*DATA_WIDTH + DATA_WIDTH -1 downto n*DATA_WIDTH) <= std_logic_vector(neuron_sums(n));
                        end loop;
                        done_reg <= '1';
                    end if;
                end if;
            else
                done_reg <= '0';
            end if;
        end if;
    end process;

    done <= done_reg;

end Behavioral;