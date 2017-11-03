
#include "model/ObsSpace/ObsHelp.h"

#include <string>

#include "util/Logger.h"
#include "model/ObsOperator/Observation.h"
#include "model/Fortran.h"
#include "eckit/config/Configuration.h"
#include "util/DateTime.h"
#include "util/Duration.h"

using oops::Log;

namespace mom5cice5 {

// -----------------------------------------------------------------------------

ObsHelp::ObsHelp(const eckit::Configuration & config) {
  const eckit::Configuration * configc = &config;
  mom5cice5_obsdb_setup_f90(keyHelp_, &configc);
  Log::trace() << "ObsHelp constructed" << std::endl;
}

// -----------------------------------------------------------------------------

ObsHelp::~ObsHelp() {
  mom5cice5_obsdb_delete_f90(keyHelp_);
  Log::trace() << "ObsHelp destructed" << std::endl;
}

// -----------------------------------------------------------------------------

void ObsHelp::putdb(const std::string & obsname, const std::string & col, const int & keyFvec) {
  Log::trace() << "ObsHelp:putdb obsname = " << obsname << ", col = " << col << std::endl;
  mom5cice5_obsdb_put_f90(keyHelp_, obsname.size(), obsname.c_str(), col.size(), col.c_str(), keyFvec);
}

// -----------------------------------------------------------------------------

void ObsHelp::getdb(const std::string & obsname, const std::string & col, int & keyFvec) const {
  Log::trace() << "ObsHelp:getdb obsname = " << obsname << ", col = " << col << std::endl;
  mom5cice5_obsdb_get_f90(keyHelp_, obsname.size(), obsname.c_str(), col.size(), col.c_str(), keyFvec);
}

// -----------------------------------------------------------------------------

int ObsHelp::locations(const std::string & obsname,
                               const util::DateTime & t1, const util::DateTime & t2) const {
  const util::DateTime * p1 = &t1;
  const util::DateTime * p2 = &t2;
  int key_locs;
  mom5cice5_obsdb_locations_f90(keyHelp_, obsname.size(), obsname.c_str(), &p1, &p2, key_locs);
  return key_locs;
}

// -----------------------------------------------------------------------------

void ObsHelp::generateDistribution(const eckit::Configuration & config, const std::string & obsname,
                                     const util::DateTime & t1, const util::DateTime & t2,
                                     unsigned int & nobs) {
  const eckit::Configuration * configc = &config;
  const util::Duration first(config.getString("begin"));
  const util::DateTime start(t1 + first);
  const util::Duration freq(config.getString("obs_period"));
  int nobstimes = 0;
  util::DateTime now(start);
  while (now <= t2) {
    ++nobstimes;
    now += freq;
  }
  const util::DateTime * bgn = &start;
  const util::Duration * stp = &freq;
  int iobs;
  mom5cice5_obsdb_generate_f90(keyHelp_, obsname.size(), obsname.c_str(), &configc,
                        &bgn, &stp, nobstimes, iobs);
  nobs = iobs;
}

// -----------------------------------------------------------------------------

int ObsHelp::nobs(const std::string & obsname) const {
  int iobs;
  mom5cice5_obsdb_nobs_f90(keyHelp_, obsname.size(), obsname.c_str(), iobs);
  return iobs;
}

// -----------------------------------------------------------------------------


}  // namespace mom5cice5