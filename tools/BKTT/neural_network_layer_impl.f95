module neural_network_module
  implicit none
  private
  public :: create_layer, forward_pass, backward_pass, update_weights

  type :: layer_type
    integer :: input_size
    integer :: output_size
    real, allocatable :: weights(:,:)
    real, allocatable :: biases(:)
    real, allocatable :: input(:)
    real, allocatable :: output(:)
    real, allocatable :: delta(:)
    real, allocatable :: weight_gradients(:,:)
    real, allocatable :: bias_gradients(:)
  end type layer_type

contains

  function create_layer(input_dim, output_dim) result(layer)
    integer, intent(in) :: input_dim, output_dim
    type(layer_type) :: layer
    integer :: i, j
    layer%input_size = input_dim
    layer%output_size = output_dim
    allocate(layer%weights(output_dim, input_dim))
    allocate(layer%biases(output_dim))
    allocate(layer%input(input_dim))
    allocate(layer%output(output_dim))
    allocate(layer%delta(output_dim))
    allocate(layer%weight_gradients(output_dim, input_dim))
    allocate(layer%bias_gradients(output_dim))
    do i = 1, output_dim
      do j = 1, input_dim
        call random_number(layer%weights(i,j))
        layer%weights(i,j) = (layer%weights(i,j) - 0.5) * 2.0
      end do
      call random_number(layer%biases(i))
      layer%biases(i) = (layer%biases(i) - 0.5) * 2.0
    end do
  end function create_layer

  subroutine forward_pass(layer, input_vector)
    type(layer_type), intent(inout) :: layer
    real, intent(in) :: input_vector(:)
    integer :: i, j
    layer%input = input_vector
    do i = 1, layer%output_size
      layer%output(i) = 0.0
      do j = 1, layer%input_size
        layer%output(i) = layer%output(i) + layer%weights(i,j) * input_vector(j)
      end do
      layer%output(i) = layer%output(i) + layer%biases(i)
    end do
    call relu_activation(layer%output)
  end subroutine forward_pass

  subroutine relu_activation(vector)
    real, intent(inout) :: vector(:)
    integer :: i
    do i = 1, size(vector)
      if (vector(i) < 0.0) then
        vector(i) = 0.0
      end if
    end do
  end subroutine relu_activation

  subroutine backward_pass(layer, target, learning_rate)
    type(layer_type), intent(inout) :: layer
    real, intent(in) :: target(:)
    real, intent(in) :: learning_rate
    integer :: i, j
    real :: error(:)
    allocate(error(size(target)))
    error = target - layer%output
    call relu_derivative(layer%output, layer%delta)
    layer%delta = error * layer%delta
    do i = 1, layer%output_size
      do j = 1, layer%input_size
        layer%weight_gradients(i,j) = layer%delta(i) * layer%input(j)
      end do
      layer%bias_gradients(i) = layer%delta(i)
    end do
    call update_weights(layer, learning_rate)
  end subroutine backward_pass

  subroutine relu_derivative(output_vector, delta_vector)
    real, intent(in) :: output_vector(:)
    real, intent(out) :: delta_vector(:)
    integer :: i
    do i = 1, size(output_vector)
      if (output_vector(i) > 0.0) then
        delta_vector(i) = 1.0
      else
        delta_vector(i) = 0.0
      end if
    end do
  end subroutine relu_derivative

  subroutine update_weights(layer, learning_rate)
    type(layer_type), intent(inout) :: layer
    real, intent(in) :: learning_rate
    integer :: i, j
    do i = 1, layer%output_size
      do j = 1, layer%input_size
        layer%weights(i,j) = layer%weights(i,j) + learning_rate * layer%weight_gradients(i,j)
      end do
      layer%biases(i) = layer%biases(i) + learning_rate * layer%bias_gradients(i)
    end do
  end subroutine update_weights

  subroutine initialize_network(network, layer_dims, num_layers)
    type(layer_type), allocatable, intent(out) :: network(:)
    integer, intent(in) :: layer_dims(:)
    integer, intent(in) :: num_layers
    integer :: i
    allocate(network(num_layers))
    do i = 1, num_layers
      network(i) = create_layer(layer_dims(i), layer_dims(i+1))
    end do
  end subroutine initialize_network

  subroutine forward_network(network, input_vector)
    type(layer_type), intent(inout) :: network(:)
    real, intent(in) :: input_vector(:)
    real :: temp_input(:)
    integer :: i, n
    temp_input = input_vector
    do i = 1, size(network)
      call forward_pass(network(i), temp_input)
      temp_input = network(i)%output
    end do
  end subroutine forward_network

  subroutine train_network(network, input_data, target_data, num_samples, epochs, learning_rate)
    type(layer_type), allocatable :: network(:)
    real, intent(in) :: input_data(:, :)
    real, intent(in) :: target_data(:, :)
    integer, intent(in) :: num_samples, epochs
    real, intent(in) :: learning_rate
    integer :: e, i
    do e = 1, epochs
      do i = 1, num_samples
        call forward_network(network, input_data(:, i))
        call backward_pass(network(size(network)), target_data(:, i), learning_rate)
      end do
    end do
  end subroutine train_network

end module neural_network_module