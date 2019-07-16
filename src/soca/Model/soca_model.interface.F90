!
! (C) Copyright 2017 UCAR
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
!

!> Setup the model

subroutine c_soca_setup(c_confspec, c_key_geom, c_key_model) bind (c,name='soca_setup_f90')

  use iso_c_binding
  use soca_model_mod
  use soca_geom_mod_c
  use soca_geom_mod, only: soca_geom
  use config_mod
  use duration_mod
  use kinds
  use mpi, only : mpi_comm_world
  use mpp_mod, only : mpp_init
  use mpp_domains_mod, only : mpp_domains_init
  use fms_io_mod, only : fms_io_init

  implicit none

  type(c_ptr),       intent(in) :: c_confspec   !< pointer to object of class Config
  integer(c_int),    intent(in) :: c_key_geom   !< Geometry
  integer(c_int), intent(inout) :: c_key_model  !< Key to configuration data

  type(soca_model), pointer :: model
  type(soca_geom),  pointer :: geom

  type(duration) :: dtstep
  character(len=20) :: ststep
  character(len=160) :: record
  integer :: int_logical
  real(c_double), dimension(2) :: tocn_minmax, socn_minmax

  call soca_geom_registry%get(c_key_geom, geom)
  call soca_model_registry%init()
  call soca_model_registry%add(c_key_model)
  call soca_model_registry%get(c_key_model, model)

  ! Get local grid size
  model%nx = geom%nx
  model%ny = geom%ny

  ! Setup time step
  ststep = config_get_string(c_confspec,len(ststep),"tstep")
  dtstep = trim(ststep)
  model%dt0 = duration_seconds(dtstep)

  ! Setup mom6 advance or identity model
  model%advance_mom6 = config_get_int(c_confspec,"advance_mom6")

  ! Setup defaults for clamping values in the model
  tocn_minmax=(/-999., -999./)
  socn_minmax=(/-999., -999./)
  call config_get_double_vector(c_confspec, "tocn_minmax", model%tocn_minmax, tocn_minmax)
  call config_get_double_vector(c_confspec, "socn_minmax", model%socn_minmax, socn_minmax)

  ! Initialize mom6
  call soca_setup(model)

  return
end subroutine c_soca_setup

! ------------------------------------------------------------------------------

!> Delete the model
subroutine c_soca_delete(c_key_conf) bind (c,name='soca_delete_f90')

  use soca_model_mod
  use iso_c_binding

  implicit none
  integer(c_int), intent(inout) :: c_key_conf  !< Key to configuration structure
  type(soca_model), pointer :: model

  call soca_model_registry%get(c_key_conf, model)
  call soca_delete(model)
  call soca_model_registry%remove(c_key_conf)

  return
end subroutine c_soca_delete

! ------------------------------------------------------------------------------
!> Prepare the model or integration
subroutine c_soca_initialize_integration(c_key_model, c_key_state) &
     & bind(c,name='soca_initialize_integration_f90')

  use iso_c_binding
  use soca_fields_mod_c
  use soca_model_mod
  use mpi, only: mpi_comm_world
  use mpp_mod, only: mpp_init
  use fms_mod, only: fms_init
  use fms_io_mod, only : fms_io_init
  use mpp_io_mod, only: mpp_open, mpp_close
  implicit none
  integer(c_int), intent(in) :: c_key_model  !< Configuration structure
  integer(c_int), intent(in) :: c_key_state  !< Model fields

  type(soca_model), pointer :: model
  type(soca_field), pointer :: flds
  integer :: unit

  call soca_field_registry%get(c_key_state,flds)
  call soca_model_registry%get(c_key_model, model)

  call soca_initialize_integration(model, flds)

end subroutine c_soca_initialize_integration

! ------------------------------------------------------------------------------

!> Checkpoint model
subroutine c_soca_finalize_integration(c_key_model, c_key_state) &
           bind(c,name='soca_finalize_integration_f90')

  use iso_c_binding
  use soca_fields_mod_c
  use soca_model_mod
  use mpi, only: mpi_comm_world
  use mpp_mod, only: mpp_init
  use fms_mod, only: fms_init
  use fms_io_mod, only : fms_io_init
  use mpp_io_mod, only: mpp_open, mpp_close
  implicit none
  integer(c_int), intent(in) :: c_key_model  !< Configuration structure
  integer(c_int), intent(in) :: c_key_state  !< Model fields

  type(soca_model), pointer :: model
  type(soca_field), pointer :: flds
  integer :: unit

  call soca_field_registry%get(c_key_state,flds)
  call soca_model_registry%get(c_key_model, model)

  call soca_finalize_integration(model, flds)

end subroutine c_soca_finalize_integration

! ------------------------------------------------------------------------------

!> Perform a timestep of the model
subroutine c_soca_propagate(c_key_model, c_key_state, c_key_date) bind(c,name='soca_propagate_f90')

  use iso_c_binding
  use datetime_mod
  use soca_fields_mod_c
  use soca_model_mod

  implicit none
  integer(c_int), intent(in) :: c_key_model  !< Config structure
  integer(c_int), intent(in) :: c_key_state  !< Model fields
  type(c_ptr), intent(inout) :: c_key_date   !< DateTime

  type(soca_model), pointer :: model
  type(soca_field), pointer :: flds
  type(datetime)            :: fldsdate

  call soca_model_registry%get(c_key_model, model)
  call soca_field_registry%get(c_key_state,flds)
  call c_f_datetime(c_key_date, fldsdate)

  call soca_propagate(model, flds, fldsdate)

  return
end subroutine c_soca_propagate