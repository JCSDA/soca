
#include "model/Traits.h"
#include "model/Run/Run.h"
#include "test/interface/Geometry.h"

int main(int argc,  char ** argv) {
  //oops::Run run(argc, argv);
  soca::Run run(argc, argv);  
  test::Geometry<soca::Traits> tests;
  run.execute(tests);
  return 0;
};

