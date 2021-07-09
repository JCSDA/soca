# (C) Copyright 2017-2020 UCAR.
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.


################################################################################
# SOCA
################################################################################

cmake_minimum_required( VERSION 3.12 )
project( soca VERSION 0.0.0 LANGUAGES C CXX Fortran)

find_package(ecbuild 3.3.2 REQUIRED)
include( ecbuild_system NO_POLICY_SCOPE )
ecbuild_declare_project()

list( APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
include( soca_compiler_flags )

################################################################################
# Dependencies
################################################################################
find_package( NetCDF REQUIRED COMPONENTS Fortran)
find_package( gsl-lite REQUIRED HINTS $ENV{gsl_list_DIR})
find_package( eckit  1.11.6   REQUIRED)
find_package( fckit  0.7.0    REQUIRED)
find_package( atlas  0.20.2   REQUIRED)
find_package( oops   1.0.0    REQUIRED)
find_package( saber  1.0.0    REQUIRED)
find_package( ioda   1.0.0    REQUIRED)
find_package( ufo    1.0.0    REQUIRED)
find_package( fms    2020.4.0 REQUIRED)
find_package( mom6   2020.4.0 REQUIRED)
find_package( crtm   2.2.3)
include_directories( ${NETCDF_INCLUDE_DIRS} )

<<<<<<< HEAD
# eckit
ecbuild_use_package( PROJECT eckit VERSION 1.1.0 REQUIRED )
include_directories( ${ECKIT_INCLUDE_DIRS} )
link_libraries( ${ECKIT_LIBRARIES} )

# fckit
ecbuild_use_package( PROJECT fckit VERSION 0.4.1 REQUIRED )
include_directories( ${FCKIT_INCLUDE_DIRS} )

# atlas
ecbuild_use_package( PROJECT atlas VERSION 0.18.1 REQUIRED )
include_directories( ${ATLAS_INCLUDE_DIRS} )

# oops
ecbuild_use_package( PROJECT oops VERSION 0.1.0 REQUIRED )
include_directories( ${OOPS_INCLUDE_DIRS} )

# saber
ecbuild_use_package( PROJECT saber VERSION 0.0.1 REQUIRED )
include_directories( ${SABER_INCLUDE_DIRS} )

# ioda
ecbuild_use_package( PROJECT ioda VERSION 0.1.0 REQUIRED )
include_directories( ${IODA_INCLUDE_DIRS} )

# ufo
ecbuild_use_package( PROJECT ufo VERSION 0.1.0 REQUIRED )
include_directories( ${UFO_INCLUDE_DIRS} )

# fms
ecbuild_use_package( PROJECT fms REQUIRED )
include_directories( ${FMS_INCLUDE_DIRS} )

# mom6
ecbuild_use_package( PROJECT mom6 REQUIRED )
include_directories( ${MOM6_INCLUDE_DIRS} )

# MPI
ecbuild_find_mpi( COMPONENTS CXX Fortran REQUIRED )
ecbuild_include_mpi()
link_libraries(${MPI_CXX_LIBRARIES} ${MPI_Fortran_LIBRARIES})

# crtm
ecbuild_use_package( PROJECT crtm VERSION 2.2.3 )

# fv3-jedi for coupled H
ecbuild_use_package( PROJECT fv3jedi )
include_directories( ${FV3JEDI_INCLUDE_DIRS} )


################################################################################
# Definitions
################################################################################

################################################################################
# Export package info
################################################################################
list( APPEND SOCA_TPLS LAPACK MPI NetCDF )

set( SOCA_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/src
                       ${CMAKE_CURRENT_BINARY_DIR}/src
                       ${CMAKE_Fortran_MODULE_DIRECTORY} )
set( SOCA_LIBRARIES soca )

get_directory_property( SOCA_DEFINITIONS COMPILE_DEFINITIONS )

foreach( _tpl ${SOCA_TPLS} )
string( TOUPPER ${_tpl} TPL )
list( APPEND SOCA_EXTRA_DEFINITIONS   ${${TPL}_DEFINITIONS}  ${${TPL}_TPL_DEFINITIONS}  )
list( APPEND SOCA_EXTRA_INCLUDE_DIRS  ${${TPL}_INCLUDE_DIRS} ${${TPL}_TPL_INCLUDE_DIRS} )
list( APPEND SOCA_EXTRA_LIBRARIES     ${${TPL}_LIBRARIES}    ${${TPL}_TPL_LIBRARIES}    )
endforeach()
=======
>>>>>>> develop

################################################################################
# Sources
################################################################################
set( SOCA_LINKER_LANGUAGE CXX)

add_subdirectory( src )
add_subdirectory( test )

# Build Doxygen documentation
add_subdirectory( Documents )

if(ECBUILD_INSTALL_FORTRAN_MODULES)
  install(DIRECTORY ${CMAKE_Fortran_MODULE_DIRECTORY}/${CMAKE_CFG_INTDIR} DESTINATION ${INSTALL_INCLUDE_DIR} )
endif()

################################################################################
# Finalise configuration
################################################################################

# prepares a tar.gz of the sources and/or binaries
ecbuild_install_project( NAME soca )

# print the summary of the configuration
ecbuild_print_summary()
