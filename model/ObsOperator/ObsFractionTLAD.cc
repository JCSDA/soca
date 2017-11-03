
#include "model/ObsOperator/ObsFractionTLAD.h"

#include "util/Logger.h"
#include "model/ModelAtLocations/Gom.h"
#include "model/ObsBias.h"
#include "model/ObsBiasIncrement.h"
#include "model/ObsSpace/ObsSpace.h"
#include "model/ObsVector/ObsVec.h"
#include "model/Variables/Variables.h"


using oops::Log;

// -----------------------------------------------------------------------------
namespace mom5cice5 {
// -----------------------------------------------------------------------------

ObsFractionTLAD::ObsFractionTLAD(const ObsSpace &, const int & keyOperStrm)
  : keyOperStrm_(keyOperStrm), varin_()
{
  int keyVarin;
  // NOT IMPLEMENTED YET
  mom5cice5_obsoper_inputs_f90(keyOperStrm_, keyVarin);
  varin_.reset(new Variables(keyVarin));
  Log::trace() << "ObsFractionTLAD created" << std::endl;
}

// -----------------------------------------------------------------------------

ObsFractionTLAD::~ObsFractionTLAD() {
  Log::trace() << "ObsFractionTLAD destrcuted" << std::endl;
}

// -----------------------------------------------------------------------------

void ObsFractionTLAD::setTrajectory(const Gom &, const ObsBias &) {}

// -----------------------------------------------------------------------------

void ObsFractionTLAD::obsEquivTL(const Gom & gom, ObsVec & ovec,
                               const ObsBiasIncrement & bias) const {
  // NOT IMPLEMENTED YET
  mom5cice5_fraction_equiv_tl_f90(gom.toFortran(), ovec.toFortran(), bias.fraction());
}

// -----------------------------------------------------------------------------

void ObsFractionTLAD::obsEquivAD(Gom & gom, const ObsVec & ovec,
                               ObsBiasIncrement & bias) const {
  // NOT IMPLEMENTED YET  
  mom5cice5_fraction_equiv_ad_f90(gom.toFortran(), ovec.toFortran(), bias.fraction());
}

// -----------------------------------------------------------------------------

}  // namespace mom5cice5