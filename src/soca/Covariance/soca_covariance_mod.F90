! (C) Copyright 2017- UCAR.
!
! This software is licensed under the terms of the Apache Licence Version 2.0
! which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

!> Structure holding configuration variables for the 3d error
!! covariance matrices of the SOCA analysis.

module soca_covariance_mod
  use config_mod
  use iso_c_binding
  use kinds
  use oobump_mod, only: bump_read_conf
  use soca_fields
  use soca_geom_mod_c
  use soca_geom_mod, only : soca_geom
  use soca_utils
  use type_bump
  use type_nam
  use random_mod
  use variables_mod

  implicit none

  private
  public :: soca_cov_setup, soca_cov_delete, soca_cov_C_mult, soca_cov_sqrt_C_mult
  
  !> Fortran derived type to hold configuration data for the SOCA background/model covariance
  type :: soca_pert
    real(kind=kind_real) :: T, S, SSH, AICE, HICE
  end type soca_pert
  type, public :: soca_cov
     type(bump_type), allocatable :: ocean_conv(:)  !< Ocean convolution op from bump
     type(bump_type), allocatable :: seaice_conv(:) !< Seaice convolution op from bump
     integer,         allocatable :: seaice_mask(:,:)
     type(soca_field),    pointer :: bkg            !< Background field (or first guess)
     logical                      :: initialized = .false.
     type(soca_pert)              :: pert_scale
     real(kind=kind_real)         :: ocn_l0
     real(kind=kind_real)         :: ice_l0
     type(oops_vars)              :: vars           !< Apply B to vars
   contains
     procedure :: setup => soca_cov_setup
     procedure :: delete => soca_cov_delete
     procedure :: mult => soca_cov_C_mult
     procedure :: sqrt_C_mult => soca_cov_sqrt_C_mult
  end type soca_cov

  ! ------------------------------------------------------------------------------
contains
  ! ------------------------------------------------------------------------------

  !> Setup for the SOCA model's 3d error covariance matrices (B and Q_i)

  !> This routine queries the configuration for the parameters that define the
  !! covariance matrix, and stores the relevant values in the
  !! error covariance structure.

  subroutine soca_cov_setup(self, c_conf, geom, bkg, vars)
    class(soca_cov),       intent(inout) :: self   !< The covariance structure
    type(c_ptr),              intent(in) :: c_conf !< The configuration
    type(soca_geom),          intent(in) :: geom   !< Geometry
    type(soca_field), target, intent(in) :: bkg    !< Background
    type(oops_vars),          intent(in) :: vars   !< List of variables
    
    character(len=3)  :: domain
    integer :: isc, iec, jsc, jec, i, j, ivar
    logical :: init_seaice, init_ocean
    
    ! Setup list of variables to apply B on
    self%vars = vars
    
    ! Set default ensemble perturbation scales to 1.0
    self%pert_scale%T = 1.0
    self%pert_scale%S = 1.0
    self%pert_scale%SSH = 1.0
    self%pert_scale%AICE = 1.0
    self%pert_scale%HICE = 1.0

    ! Overwrite scales if they exist
    if (config_element_exists(c_conf,"pert_T")) then
       self%pert_scale%T = config_get_real(c_conf,"pert_T")
    end if
    if (config_element_exists(c_conf,"pert_S")) then
       self%pert_scale%S = config_get_real(c_conf,"pert_S")
    end if
    if (config_element_exists(c_conf,"pert_SSH")) then
       self%pert_scale%SSH = config_get_real(c_conf,"pert_SSH")
    end if
    if (config_element_exists(c_conf,"pert_AICE")) then
       self%pert_scale%AICE = config_get_real(c_conf,"pert_AICE")
    end if
    if (config_element_exists(c_conf,"pert_HICE")) then
       self%pert_scale%HICE = config_get_real(c_conf,"pert_HICE")
    end if

    ! Setup ocean and ice decorrelation length scales
    self%ocn_l0 = 500.0d3
    self%ice_l0 = 500.0d3
    if (config_element_exists(c_conf,"ocean_corr_scale")) then
       self%ocn_l0 = config_get_real(c_conf,"ocean_corr_scale")
    end if
    if (config_element_exists(c_conf,"ice_corr_scale")) then
       self%ice_l0 = config_get_real(c_conf,"ice_corr_scale")
    end if

    ! Associate background
    self%bkg => bkg

    ! Indices for compute domain (no halo)
    isc = bkg%geom%isc ; iec = bkg%geom%iec
    jsc = bkg%geom%jsc ; jec = bkg%geom%jec

    ! Define seaice mask from background seaice fraction
    allocate(self%seaice_mask(isc:iec, jsc:jec))
    self%seaice_mask = 0
    do i = isc, iec
       do j = jsc, jec
          if (sum(bkg%seaice%cicen(i, j, 2:), 1) * bkg%geom%mask2d(i, j) .gt. 0.0) then
             self%seaice_mask(i, j) = 1
          else
             self%seaice_mask(i, j) = 0
          end if
       end do
    end do

    ! Determine what convolution op to initialize
    init_seaice = .false.
    init_ocean = .false.    
    do ivar = 1, self%vars%nv
       select case(trim(self%vars%fldnames(ivar)))
       case('cicen')
          init_seaice = .true.
       case('hicen')
          init_seaice = .true.
       case('tocn')
          init_ocean = .true.
       case('socn')
          init_ocean = .true.
       case('ssh')
          init_ocean = .true.
       end select
    end do
    
    ! Initialize ocean bump if tocn or socn or ssh are in self%vars
    domain = 'ocn'
    allocate(self%ocean_conv(1))
    if (init_ocean) then    
       call soca_bump_correlation(self, self%ocean_conv(1), geom, c_conf, domain)
    end if

    ! Initialize seaice bump if cicen or hicen are in self%vars
    domain = 'ice'
    allocate(self%seaice_conv(1))
    if (init_seaice) then
       call soca_bump_correlation(self, self%seaice_conv(1), geom, c_conf, domain)
    end if
    
    self%initialized = .true.

  end subroutine soca_cov_setup

  ! ------------------------------------------------------------------------------

  !> Delete for the SOCA model's 3d error covariance matrices

  subroutine soca_cov_delete(self)
    class(soca_cov), intent(inout) :: self       !< The covariance structure

    call self%ocean_conv(1)%dealloc()
    call self%seaice_conv(1)%dealloc()
    deallocate(self%ocean_conv)
    deallocate(self%seaice_conv)
    nullify(self%bkg)
    deallocate(self%seaice_mask)
    self%initialized = .false.

  end subroutine soca_cov_delete

  ! ------------------------------------------------------------------------------

  subroutine soca_cov_C_mult(self, dx)
    class(soca_cov),  intent(inout) :: self !< The covariance structure
    type(soca_field), intent(inout) :: dx   !< Input: Increment
                                            !< Output: C dx
    integer :: icat, izo, ivar

    do ivar = 1, self%vars%nv
       select case(trim(self%vars%fldnames(ivar)))
          ! Apply convolution to forcing             
          case('sw')
             call soca_2d_convol(dx%ocnsfc%sw_rad(:,:),      self%ocean_conv(1), dx%geom)
          case('lw')             
             call soca_2d_convol(dx%ocnsfc%lw_rad(:,:),      self%ocean_conv(1), dx%geom)
          case('lhf')
             call soca_2d_convol(dx%ocnsfc%latent_heat(:,:), self%ocean_conv(1), dx%geom)
          case('shf')             
             call soca_2d_convol(dx%ocnsfc%sens_heat(:,:),   self%ocean_conv(1), dx%geom)
          case('us')             
             call soca_2d_convol(dx%ocnsfc%fric_vel(:,:),    self%ocean_conv(1), dx%geom)

          ! Apply convolution to ocean
          case('ssh')
             call soca_2d_convol(dx%ssh(:,:), self%ocean_conv(1), dx%geom)
          case('tocn')             
             do izo = 1,dx%geom%nzo
                call soca_2d_convol(dx%tocn(:,:,izo), self%ocean_conv(1), dx%geom)
             end do
          case('socn')             
             do izo = 1,dx%geom%nzo
                call soca_2d_convol(dx%socn(:,:,izo), self%ocean_conv(1), dx%geom)
             end do             

          ! Apply convolution to sea-ice
          case('cicen')
             do icat = 1, dx%geom%ncat
                call soca_2d_convol(dx%seaice%cicen(:,:,icat+1), self%seaice_conv(1), dx%geom)
             end do
          case('hicen')                          
             do icat = 1, dx%geom%ncat
                call soca_2d_convol(dx%seaice%hicen(:,:,icat), self%seaice_conv(1), dx%geom)
             end do
          end select
       end do

  end subroutine soca_cov_C_mult

  ! ------------------------------------------------------------------------------

  subroutine soca_cov_sqrt_C_mult(self, dx)
    class(soca_cov),  intent(inout) :: self !< The covariance structure
    type(soca_field), intent(inout) :: dx   !< Input: Increment
                                            !< Output: C^1/2 dx
    integer :: icat, izo, ivar

    do ivar = 1, self%vars%nv
       select case(trim(self%vars%fldnames(ivar)))
          ! Apply C^1/2 to forcing             
          case('sw')
             call soca_2d_sqrt_convol(dx%ocnsfc%sw_rad(:,:), &
                  &self%ocean_conv(1), dx%geom, self%pert_scale%SSH)
          case('lw')
             call soca_2d_sqrt_convol(dx%ocnsfc%lw_rad(:,:), &
                  &self%ocean_conv(1), dx%geom, self%pert_scale%SSH)
          case('lhf')
             call soca_2d_sqrt_convol(dx%ocnsfc%latent_heat(:,:), &
                  &self%ocean_conv(1), dx%geom, self%pert_scale%SSH)
          case('shf')
             call soca_2d_sqrt_convol(dx%ocnsfc%sens_heat(:,:), &
                  &self%ocean_conv(1), dx%geom, self%pert_scale%SSH)
          case('us')
             call soca_2d_sqrt_convol(dx%ocnsfc%fric_vel(:,:), &
                  &self%ocean_conv(1), dx%geom, self%pert_scale%SSH)

          ! Apply C^1/2 to ocean
          case('ssh')
             call soca_2d_sqrt_convol(dx%ssh, &
                  &self%ocean_conv(1), dx%geom, self%pert_scale%SSH)             
          case('tocn')             
             do izo = 1,dx%geom%nzo
                call soca_2d_sqrt_convol(dx%tocn(:,:,izo), &
                     &self%ocean_conv(1), dx%geom, self%pert_scale%T)
             end do
          case('socn')             
             do izo = 1,dx%geom%nzo
                call soca_2d_sqrt_convol(dx%socn(:,:,izo), &
                     &self%ocean_conv(1), dx%geom, self%pert_scale%S)
             end do             

          ! Apply C^1/2 to sea-ice
          case('cicen')                          
             do icat = 1, dx%geom%ncat
                call soca_2d_sqrt_convol(dx%seaice%cicen(:,:,icat+1), &
                     &self%seaice_conv(1), dx%geom, self%pert_scale%AICE)
             end do
          case('hicen')                          
             do icat = 1, dx%geom%ncat
                call soca_2d_sqrt_convol(dx%seaice%hicen(:,:,icat), &
                     &self%seaice_conv(1), dx%geom, self%pert_scale%HICE)
             end do
          end select
       end do

  end subroutine soca_cov_sqrt_C_mult

  ! ------------------------------------------------------------------------------

  subroutine soca_bump_correlation(self, horiz_convol, geom, c_conf, domain)
    class(soca_cov), intent(inout) :: self   !< The covariance structure
    type(bump_type), intent(inout) :: horiz_convol
    type(soca_geom),    intent(in) :: geom
    type(c_ptr),        intent(in) :: c_conf         !< Handle to configuration
    character(len=3),   intent(in) :: domain

    !Grid stuff
    integer :: isc, iec, jsc, jec, jjj, jz, il, ib
    character(len=1024) :: subr = 'model_write'

    !bump stuff
    integer :: nc0a, nl0, nv, nts
    real(kind=kind_real), allocatable :: lon(:), lat(:), area(:), vunit(:,:)
    real(kind=kind_real), allocatable :: rosrad(:)
    logical, allocatable :: lmask(:,:)
    integer, allocatable :: imask(:,:)

    real(kind_real), allocatable :: rh(:,:,:,:)     !< Horizontal support radius for covariance (in m)
    real(kind_real), allocatable :: rv(:,:,:,:)     !< Vertical support radius
    real(kind_real), allocatable :: var(:,:,:,:)

    !--- Initialize geometry to be passed to NICAS
    ! Indices for compute domain (no halo)
    isc = geom%isc ; iec = geom%iec ; jsc = geom%jsc ; jec = geom%jec

    nv = 1                                     !< Number of variables
    nl0 = 1                                    !< Number of independent levels
    nts = 1                                    !< Number of time slots
    nc0a = (iec - isc + 1) * (jec - jsc + 1 )  !< Total number of grid cells in the compute domain

    allocate( lon(nc0a), lat(nc0a), area(nc0a) )
    allocate( vunit(nc0a,nl0) )
    allocate( imask(nc0a, nl0), lmask(nc0a, nl0) )

    lon = reshape( geom%lon(isc:iec, jsc:jec), (/nc0a/) )
    lat = reshape( geom%lat(isc:iec, jsc:jec), (/nc0a/) )
    area = reshape( geom%cell_area(isc:iec, jsc:jec), (/nc0a/) )

    ! Setup land or ice mask
    jz = 1
    if (domain.eq.'ocn') then
       imask(1:nc0a,jz) = int(reshape( geom%mask2d(isc:iec, jsc:jec), (/nc0a/)))
    end if
    if (domain.eq.'ice') then
       imask(1:nc0a,jz) = int(reshape( self%seaice_mask(isc:iec, jsc:jec), (/nc0a/)))
    end if

    lmask = .false.
    where (imask.eq.1)
       lmask=.true.
    end where

    ! No vertical convolution, set dummy vertical unit
    vunit = 1.0d0

    ! Initialize bump namelist/parameters
    call horiz_convol%nam%init()
    horiz_convol%nam%verbosity = 'none'
    call bump_read_conf(c_conf, horiz_convol)

    if (domain.eq.'ocn') horiz_convol%nam%prefix = 'ocn'
    if (domain.eq.'ice') horiz_convol%nam%prefix = 'ice'

    ! Compute convolution weight
    call horiz_convol%setup_online(nc0a,nl0,nv,nts,lon,lat,area,vunit,lmask)

    if (horiz_convol%nam%new_nicas) then
       ! Allocation
       allocate(rosrad(nc0a))
       allocate(rh(nc0a,nl0,nv,nts))
       allocate(rv(nc0a,nl0,nv,nts))
       allocate(var(nc0a,nl0,nv,nts))

       ! Setup Rossby radius
       rosrad = reshape( geom%rossby_radius(isc:iec, jsc:jec), (/nc0a/) )

       ! Setup horizontal decorrelation length scales
       if (domain.eq.'ocn') then
          do jjj=1,nc0a
             rh(jjj,1,1,1)=self%ocn_l0 + rosrad(jjj)
          end do
       end if
       if (domain.eq.'ice') then
          rh = self%ice_l0
       end if
       rv=1.0 ! Vertical scales not used, set to something
       var=1.0

       ! Copy length-scales into BUMP
       call horiz_convol%set_parameter('cor_rh',rh)
       call horiz_convol%set_parameter('cor_rv',rv)
       call horiz_convol%set_parameter('var',var)

       ! Clean up
       deallocate(rosrad,rh,rv,var)
    end if

    ! Run BUMP drivers
    call horiz_convol%run_drivers()

    ! Clean up
    deallocate(lon, lat, area, vunit, imask, lmask)

  end subroutine soca_bump_correlation

  ! ------------------------------------------------------------------------------

  subroutine soca_2d_convol(dx, horiz_convol, geom)
    real(kind=kind_real), intent(inout) :: dx(:,:)
    type(bump_type),      intent(inout) :: horiz_convol
    type(soca_geom),         intent(in) :: geom

    real(kind=kind_real), allocatable :: tmp_incr(:,:,:,:)

    ! Allocate unstructured tmp_increment and make copy of dx
    call geom%struct2unstruct(dx(:,:), tmp_incr)

    ! Apply 2D convolution
    call horiz_convol%apply_nicas(tmp_incr)

    ! copy unstructured tmp_incr to structured dx
    call geom%unstruct2struct(dx(:,:), tmp_incr)

    ! Clean up
    if (allocated(tmp_incr)) deallocate(tmp_incr)

  end subroutine soca_2d_convol

  ! ------------------------------------------------------------------------------

  subroutine soca_2d_sqrt_convol(dx, horiz_convol, geom, pert_scale)
    real(kind=kind_real), intent(inout) :: dx(:,:)
    type(bump_type),      intent(inout) :: horiz_convol
    type(soca_geom),         intent(in) :: geom
    real(kind=kind_real),    intent(in) :: pert_scale

    real(kind=kind_real), allocatable :: tmp_incr(:,:,:,:)
    real(kind=kind_real), allocatable :: pcv(:)
    integer, parameter :: rseed = 1 ! constant for reproducability of tests
                                    ! TODO: pass seed through config
    integer :: nn

    ! Allocate unstructured tmp_increment and make copy of dx
    call geom%struct2unstruct(dx(:,:), tmp_incr)

    ! Get control variable size
    call horiz_convol%get_cv_size(nn)
    allocate(pcv(nn))
    pcv = 0.0_kind_real
    call normal_distribution(pcv, 0.0_kind_real, 1.0_kind_real, rseed)
    pcv = pert_scale * pcv

    ! Apply C^1/2
    call horiz_convol%apply_nicas_sqrt(pcv, tmp_incr)

    ! Back to structured grid
    call geom%unstruct2struct(dx(:,:), tmp_incr)

    ! Clean up
    deallocate(pcv)
    if (allocated(tmp_incr)) deallocate(tmp_incr)

  end subroutine soca_2d_sqrt_convol

end module soca_covariance_mod