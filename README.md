[![Build Status](https://travis-ci.com/JCSDA-internal/soca.svg?branch=develop)](https://travis-ci.com/JCSDA-internal/soca)
[![Documentation Status](https://readthedocs.com/projects/jointcenterforsatellitedataassimilation-soca/badge/?version=develop)](https://jointcenterforsatellitedataassimilation-soca.readthedocs-hosted.com/en/develop/?badge=develop)
[![codecov](https://codecov.io/gh/JCSDA-internal/soca/branch/develop/graph/badge.svg?token=uFJ62a68D7)](https://codecov.io/gh/jcsda-internal/soca)
JEDI encapsulation of MOM6

(C) Copyright 2017-2020 UCAR.

This software is licensed under the terms of the Apache Licence Version 2.0 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

See the [soca ReadTheDocs](https://jointcenterforsatellitedataassimilation-soca.readthedocs-hosted.com/en/latest/?badge=latest) page for more documentation.

## Building

1. If building as part of the larger SOCA coupled system, see the [soca-bundle](https://github.com/JCSDA/soca-bundle)

2. If building the MOM6 SOCA component: unlike other JEDI projects, this project contains its own bundle, it can be built as follows
```
git clone https://github.com/JCSDA/soca.git
mkdir -p soca_build
cd soca_build
ecbuild ../soca/bundle
cd soca
make -j 4
```

3. If building the same way travis-ci builds the MOM6 SOCA bundle:
```
export MAIN_REPO=soca
export LIB_REPOS="fms gsw mom6 crtm fckit atlas oops saber ioda ufo ioda-converters"
export BUILD_OPT=""
export BUILD_OPT_crtm="-DBUILD_CRTM=ON"
export BUILD_OPT_oops="-DENABLE_QG_MODEL=OFF -DENABLE_LORENZ95_MODEL=OFF"
export BUILD_OPT_ufo="-DLOCAL_PATH_TESTFILES_IODA=NONE"
export BUILD_OPT_soca="-DSOCA_TESTS_FORC_DEFAULT_TOL=ON -DCRTM_FIX_DIR=../../repo.src/crtm/fix"
export MATCH_REPOS="atlas oops saber ioda ioda-converters ufo soca"
export LFS_REPOS=""
export REPO_CACHE="/path/to/somewhere/repo.cache"
mkdir -p repo.src
cd repo.src
git clone https://github.com/JCSDA/soca.git
cd ..
./repo.src/soca/.github/travisci/prep.sh
 ./repo.src/soca/.github/travisci/build.sh
```

See the [JEDI Documentation](https://jointcenterforsatellitedataassimilation-jedi-docs.readthedocs-hosted.com/en/latest/) for additional details on how to setup, build, and test JEDI projects.
