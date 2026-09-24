#include "server/common.h"

#include <cmath>
#include <cstdint>
#include <cstdlib>

bool str_to_dbl(const std::string& s, double& out) {
    char *endp = NULL;
    out = std::strtod(s.c_str(), &endp);
    return endp == s.c_str() + s.size() && !std::isnan(out);
}

bool str_to_int(const std::string& s, int64_t& out) {
    char *endp = NULL;
    out = std::strtoll(s.c_str(), &endp, 10);
    return endp == s.c_str() + s.size() && !std::isnan(out);
}
