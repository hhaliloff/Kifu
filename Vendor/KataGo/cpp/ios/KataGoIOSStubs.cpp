#include "../main.h"
#include "../tests/tests.h"

#include <string>

// The embedded GTP entry point references desktop-only diagnostics and the
// benchmark fixture accessor. kata-benchmark is explicitly disabled for the
// injected-stream bridge, so this app build only needs minimal link symbols.
namespace Version {

std::string getKataGoVersion() {
  return "1.18.2";
}

std::string getKataGoVersionForHelp() {
  return "KataGo v1.18.2 (iOS)";
}

std::string getKataGoVersionFullInfo() {
  return getKataGoVersionForHelp();
}

std::string getGitRevision() {
  return "embedded";
}

std::string getGitRevisionWithBackend() {
  return "embedded-metal";
}

}  // namespace Version

namespace TestCommon {

std::string getBenchmarkSGFData(int) {
  return {};
}

}  // namespace TestCommon
