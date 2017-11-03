
#include "model/Traits.h"
#include "oops/runs/Run.h"
#include "test/interface/ObsAuxControl.h"

int main(int argc,  char ** argv) {
  oops::Run run(argc, argv);
  test::ObsAuxControl<mom5cice5::Traits> tests;
  run.execute(tests);
  return 0;
};
