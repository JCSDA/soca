/*
 * (C) Copyright 2017 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include <vector>

#include "soca/Model/Model.h"

#include "eckit/config/Configuration.h"

#include "oops/util/DateTime.h"
#include "oops/util/Logger.h"

#include "soca/Fields/Fields.h"
#include "ModelFortran.h"
#include "soca/Geometry/Geometry.h"
#include "soca/ModelBias.h"
#include "soca/State/State.h"

using oops::Log;

namespace soca {
  // -----------------------------------------------------------------------------
  static oops::ModelMaker<Traits, Model> makermodel_("SOCA");
  // -----------------------------------------------------------------------------
  Model::Model(const Geometry & resol, const eckit::Configuration & model)
    : keyConfig_(0), tstep_(0), geom_(resol), vars_(model)
  {
    Log::trace() << "Model::Model" << std::endl;
    Log::trace() << "Model vars: " << vars_ << std::endl;
    tstep_ = util::Duration(model.getString("tstep"));
    const eckit::Configuration * configc = &model;
    soca_setup_f90(&configc, geom_.toFortran(), keyConfig_);
    Log::trace() << "Model created" << std::endl;
  }
  // -----------------------------------------------------------------------------
  Model::~Model() {
    soca_delete_f90(keyConfig_);
    Log::trace() << "Model destructed" << std::endl;
  }
  // -----------------------------------------------------------------------------
  void Model::initialize(State & xx) const {
    ASSERT(xx.fields().isForModel(true));
    soca_initialize_integration_f90(keyConfig_, xx.fields().toFortran());
    Log::debug() << "Model::initialize" << xx.fields() << std::endl;
  }
  // -----------------------------------------------------------------------------
  void Model::step(State & xx, const ModelBias &) const {
    ASSERT(xx.fields().isForModel(true));
    Log::trace() << "Model::Time: " << xx.validTime() << std::endl;
    util::DateTime * modeldate = &xx.validTime();
    soca_propagate_f90(keyConfig_, xx.fields().toFortran(), &modeldate);
    xx.validTime() += tstep_;
  }
  // -----------------------------------------------------------------------------
  void Model::finalize(State & xx) const {
    ASSERT(xx.fields().isForModel(true));
    soca_finalize_integration_f90(keyConfig_, xx.fields().toFortran());
    Log::debug() << "Model::finalize" << xx.fields() << std::endl;
  }
  // -----------------------------------------------------------------------------
  int Model::saveTrajectory(State & xx, const ModelBias &) const {
    ASSERT(xx.fields().isForModel(true));
    int ftraj = 0;
    xx.validTime() += tstep_;
    return ftraj;
  }
  // -----------------------------------------------------------------------------
  void Model::print(std::ostream & os) const {
    os << "Model::print not implemented";
  }
  // -----------------------------------------------------------------------------
}  // namespace soca