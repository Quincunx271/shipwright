/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

#include "./lexer.hpp"

#include <ostream>

namespace shipwright {
    std::ostream& operator<<(
        std::ostream& out, debug_print<lexer::sentinel> const&)
    {
        return out << "<<eof>>";
    }

    std::ostream& operator<<(
        std::ostream& out, debug_print<lexer::iterator> const& iter)
    {
        if (iter.value == lexer::sentinel{}) {
            return out << lexer::sentinel{};
        }
        return out << "<iterator." << iter.value.lexer_ << '>';
    }
}
