#!/bin/csh
set seed = 42
set rand_max = 32767
set -l learning_rate = 0.01
set -l epochs = 1000
set -l input_size = 3
set -l output_size = 2
set -l sample_count = 4

@ -l i = 0
@ -l j = 0
@ -l k = 0

set -g input_layer = (1 0.5 -1.5 0.3)
set -g target_output = (0 1)

set -g weights_input_hidden = ()
set -g weights_hidden_output = ()
set -g bias_hidden = ()
set -g bias_output = ()

while ( $i < $input_size )
    @ weights_input_hidden[$i+1] = ( $RANDOM % $rand_max / $rand_max * 2 - 1 )
    @ bias_hidden[$i+1] = ( $RANDOM % $rand_max / $rand_max * 2 - 1 )
    @ ++i
end

set -g hidden_layer = ()
set -g output_layer = ()

while ( $j < $output_size )
    @ weights_hidden_output[$j+1] = ( $RANDOM % $rand_max / $rand_max * 2 - 1 )
    @ bias_output[$j+1] = ( $RANDOM % $rand_max / $rand_max * 2 - 1 )
    @ ++j
end

set -g delta_weights_input_hidden = ()
set -g delta_weights_hidden_output = ()
set -g delta_bias_hidden = ()
set -g delta_bias_output = ()

@ -l e = 0
while ( $e < $epochs )
    set -g input_sample = (1 0.5 -1.5)
    set -g target = (0 1)
    set -g hidden_layer = ()
    set -g output_layer = ()
    set -g hidden_input = ()
    set -g output_input = ()
    set -g hidden_activation = ()
    set -g output_activation = ()
    @ i = 1
    while ( $i <= $input_size )
        @ sum = 0
        @ j = 1
        while ( $j <= $input_size )
            @ sum += $input_sample[$j] * $weights_input_hidden[$j]
            @ ++j
        end
        @ sum += $bias_hidden[$i]
        set hidden_input[$i] = $sum
        set hidden_activation[$i] = (1 / (1 + exp(-$sum)))
        @ ++i
    end
    set -g hidden_layer = $hidden_activation
    set -g output_input = ()
    set -g output_activation = ()
    @ i = 1
    while ( $i <= $output_size )
        @ sum = 0
        @ j = 1
        while ( $j <= $input_size )
            @ sum += $hidden_layer[$j] * $weights_hidden_output[$i]
            @ ++j
        end
        @ sum += $bias_output[$i]
        set output_input[$i] = $sum
        set output_activation[$i] = (1 / (1 + exp(-$sum)))
        @ ++i
    end
    set -g output_layer = $output_activation
    set -g errors = ()
    set -g delta_output = ()
    @ i = 1
    while ( $i <= $output_size )
        @ error = $target[$i] - $output_layer[$i]
        set errors[$i] = $error
        set delta_output[$i] = $error * $output_layer[$i] * (1 - $output_layer[$i])
        @ ++i
    end
    set -g delta_weights_hidden_output = ()
    @ i = 1
    while ( $i <= $output_size )
        @ j = 1
        while ( $j <= $input_size )
            @ delta_w = $learning_rate * $delta_output[$i] * $hidden_layer[$j]
            @ delta_weights_hidden_output[$i * $input_size + $j] = $delta_w
            @ ++j
        end
        @ delta_b = $learning_rate * $delta_output[$i]
        @ delta_bias_output[$i] = $delta_b
        @ ++i
    end
    set -g delta_hidden_layer = ()
    set -g delta_hidden = ()
    @ i = 1
    while ( $i <= $input_size )
        set sum = 0
        @ j = 1
        while ( $j <= $output_size )
            @ sum += $delta_output[$j] * $weights_hidden_output[$j * $input_size + $i]
            @ ++j
        end
        set delta_hidden_layer[$i] = $hidden_layer[$i] * (1 - $hidden_layer[$i]) * $sum
        @ delta_bh = $learning_rate * $delta_hidden_layer[$i]
        set delta_bias_hidden[$i] = $delta_bh
        @ ++i
    end
    set -g delta_weights_input_hidden = ()
    @ i = 1
    while ( $i <= $input_size )
        @ j = 1
        while ( $j <= $output_size )
            @ delta_w = $learning_rate * $delta_hidden_layer[$i] * $input_sample[$i]
            @ delta_weights_input_hidden[$i * $output_size + $j] = $delta_w
            @ ++j
        end
        @ ++i
    end
    @ i = 1
    while ( $i <= $output_size )
        @ j = 1
        while ( $j <= $input_size )
            @ index = ($j - 1) * $output_size + $i
            @ weights_hidden_output[$index] += $delta_weights_hidden_output[$i * $input_size + $j]
            @ ++j
        end
        @ bias = $bias_output[$i] + $delta_bias_output[$i]
        set bias_output[$i] = $bias
        @ ++i
    end
    @ i = 1
    while ( $i <= $input_size )
        @ weight_sum = 0
        @ j = 1
        while ( $j <= $output_size )
            @ index = ($i - 1) * $output_size + $j
            @ weight_sum += $delta_weights_input_hidden[$index]
            @ ++j
        end
        @ weight = $weights_input_hidden[$i] + $weight_sum
        set weights_input_hidden[$i] = $weight
        @ bias_h = $bias_hidden[$i] + $delta_bias_hidden[$i]
        set bias_hidden[$i] = $bias_h
        @ ++i
    end
    @ e += 1
end