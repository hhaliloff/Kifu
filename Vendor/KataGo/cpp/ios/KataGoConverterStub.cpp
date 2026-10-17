// The iOS target runs KataGo's MPSGraph GPU backend only. Model conversion to
// Core ML is deliberately excluded from the app binary, so this tiny link stub
// makes accidental ANE selection fail loudly instead of pulling Protobuf and
// Abseil into the mobile build.
#include "katagocoreml/KataGoConverter.hpp"

#include <stdexcept>

namespace katagocoreml {

void KataGoConverter::convert(
    const std::string&,
    const std::string&,
    const ConversionOptions&) {
  throw std::runtime_error("Core ML model conversion is unavailable in the iOS GPU-only build");
}

bool KataGoConverter::wouldBuildFullyFp32(int, bool) {
  // This query is only used to report the effective precision of the ANE path;
  // iOS app builds reject ANE device selection and use MPSGraph FP32 instead.
  return false;
}

}  // namespace katagocoreml
