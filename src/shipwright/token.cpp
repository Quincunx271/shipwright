/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

#include "./token.hpp"

#include <cassert>
#include <ostream>

namespace shipwright {
    std::ostream& operator<<(
        std::ostream& lhs, debug_print<token_type> const& rhs)
    {
        switch (rhs.value) {
        case token_type::unknown:
            return lhs << "unknown";
        case token_type::space:
            return lhs << "space";
        case token_type::newline:
            return lhs << "newline";
        case token_type::identifier:
            return lhs << "identifier";
        default:
            assert(false && "Unknown token type");
            return lhs << "<<invalid-type>>";
        }
    }

    std::ostream& operator<<(std::ostream& lhs, debug_print<token> const& rhs)
    {
        return lhs << '<' << shipwright::debug_print(rhs.value.type) << ": \""
                   << rhs.value.text << "\">";
    }
}
