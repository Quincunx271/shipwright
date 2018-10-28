/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

#pragma once

#include <string_view>
#include <variant>

#include <shipwright/debug_print.hpp>

namespace shipwright {
    enum class token_type
    {
        unknown,
        space,
        newline,
        identifier,
    };

    std::ostream& operator<<(
        std::ostream& lhs, debug_print<token_type> const& rhs);

    struct token
    {
        std::string_view text;
        token_type type;
    };

    std::ostream& operator<<(std::ostream& lhs, debug_print<token> const& rhs);
}
