module plugin_manager
  use iso_c_binding
  implicit none
  private

  integer(c_int), parameter :: max_plugins = 100
  integer(c_int) :: plugin_count = 0
  type, public :: plugin_type
    character(len=256) :: name
    type(c_funptr) :: init_func
    type(c_funptr) :: execute_func
    type(c_funptr) :: cleanup_func
  end type plugin_type

  type(plugin_type), dimension(:), allocatable :: plugins

contains

  subroutine initialize_plugin_system
    allocate(plugins(max_plugins))
    plugin_count = 0
  end subroutine initialize_plugin_system

  logical function load_plugin(filename)
    character(len=*), intent(in) :: filename
    integer(c_int) :: lib_handle, init_status
    type(c_funptr) :: init_func_ptr, execute_func_ptr, cleanup_func_ptr
    character(len=512) :: lib_name
    character(len=:), allocatable :: c_lib_name

    if (plugin_count >= max_plugins) then
      load_plugin = .false.
      return
    end if

    write(lib_name, '(A)') trim(filename)
    call c_str_to_fstring(trim(filename), c_lib_name)

    lib_handle = c_lib_open(c_loc(lib_name))
    if (lib_handle == 0) then
      load_plugin = .false.
      return
    end if

    call c_lib_sym(lib_handle, 'plugin_init', init_func_ptr)
    call c_lib_sym(lib_handle, 'plugin_execute', execute_func_ptr)
    call c_lib_sym(lib_handle, 'plugin_cleanup', cleanup_func_ptr)

    if (c_funptr_is_null(init_func_ptr) .or. c_funptr_is_null(execute_func_ptr) .or. c_funptr_is_null(cleanup_func_ptr)) then
      call c_lib_close(lib_handle)
      load_plugin = .false.
      return
    end if

    plugin_count = plugin_count + 1
    plugins(plugin_count)%name = trim(filename)
    plugins(plugin_count)%init_func = init_func_ptr
    plugins(plugin_count)%execute_func = execute_func_ptr
    plugins(plugin_count)%cleanup_func = cleanup_func_ptr

    call c_lib_close(lib_handle)
    load_plugin = .true.
  end function load_plugin

  subroutine execute_plugins
    integer :: i
    do i = 1, plugin_count
      call call_plugin_init(plugins(i)%init_func)
      call call_plugin_execute(plugins(i)%execute_func)
    end do
  end subroutine execute_plugins

  subroutine cleanup_plugins
    integer :: i
    do i = plugin_count, 1, -1
      call call_plugin_cleanup(plugins(i)%cleanup_func)
    end do
    deallocate(plugins)
    plugin_count = 0
  end subroutine cleanup_plugins

  subroutine call_plugin_init(func)
    type(c_funptr), intent(in) :: func
    interface
      subroutine plugin_init() bind(c)
      end subroutine plugin_init
    end interface
    call c_f_procpointer(func, plugin_init)
    call plugin_init()
  end subroutine call_plugin_init

  subroutine call_plugin_execute(func)
    type(c_funptr), intent(in) :: func
    interface
      subroutine plugin_execute() bind(c)
      end subroutine plugin_execute
    end interface
    call c_f_procpointer(func, plugin_execute)
    call plugin_execute()
  end subroutine call_plugin_execute

  subroutine call_plugin_cleanup(func)
    type(c_funptr), intent(in) :: func
    interface
      subroutine plugin_cleanup() bind(c)
      end subroutine plugin_cleanup
    end interface
    call c_f_procpointer(func, plugin_cleanup)
    call plugin_cleanup()
  end subroutine call_plugin_cleanup

  function c_lib_open(name_ptr) result(handle)
    type(c_ptr), intent(in) :: name_ptr
    integer(c_int) :: handle
    interface
      function c_dlopen(name, flag) bind(c, name='dlopen')
        import :: c_char, c_int
        character(kind=c_char), dimension(*) :: name
        integer(c_int), value :: flag
        type(c_ptr) :: c_dlopen
      end function c_dlopen

      integer(c_int), parameter :: RTLD_LAZY = 1
    end interface
    handle = c_loc(c_dlopen(name_ptr, RTLD_LAZY))
  end function c_lib_open

  subroutine c_lib_close(handle)
    integer(c_int), intent(in) :: handle
    interface
      subroutine c_dlclose(handle) bind(c, name='dlclose')
        import :: c_int
        integer(c_int), value :: handle
      end subroutine c_dlclose
    end interface
    call c_dlclose(handle)
  end subroutine c_lib_close

  subroutine c_lib_sym(handle, symbol_name, func_ptr)
    integer(c_int), intent(in) :: handle
    character(len=*), intent(in) :: symbol_name
    type(c_funptr), intent(out) :: func_ptr
    interface
      subroutine c_dlsym(handle, name, sym)
        import :: c_int, c_char, c_funptr
        integer(c_int), value :: handle
        character(kind=c_char), dimension(*) :: name
        type(c_funptr) :: sym
      end subroutine c_dlsym
    end interface
    call c_dlsym(handle, trim(symbol_name)//char(0), func_ptr)
  end subroutine c_lib_sym

  function c_funptr_is_null(fp) result(is_null)
    type(c_funptr), intent(in) :: fp
    logical :: is_null
    is_null = c_associated(fp) .and. c_f_procpointer(fp, null())
  end function c_funptr_is_null

  subroutine c_str_to_fstring(c_str, fortran_str)
    character(len=*), intent(in) :: c_str
    character(len=:), allocatable, intent(out) :: fortran_str
    integer :: len_c
    len_c = index(c_str, char(0))
    if (len_c == 0) len_c = len_trim(c_str)
    allocate(character(len=len_c) :: fortran_str)
    fortran_str = c_str(1:len_c)
  end subroutine c_str_to_fstring

end module plugin_manager