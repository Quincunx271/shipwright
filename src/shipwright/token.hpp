/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

#pragma once

#include <string_view>
#include <tuple>
#include <variant>

#include <shipwright/debug_print.hpp>

namespace shipwright {
    enum class token_type
    {
        unknown,
        space,
        newline,
        identifier,
        lparen,
        rparen,

        bracket_argument,

        // quote,

        // escape sequences

        bracket_comment,
        line_comment,
    };

    std::ostream& operator<<(
        std::ostream& lhs, debug_print<token_type> const& rhs);

    struct token
    {
        std::string_view text;
        token_type type;
        // Not salient. Mostly determinable from `text` and `type`.
        std::string_view full_text;
    };

    inline bool operator==(token const& lhs, token const& rhs)
    {
        // Compare types first; that's the cheaper comparison
        return std::tie(lhs.type, lhs.text) == std::tie(rhs.type, rhs.text);
    }

    inline bool operator!=(token const& lhs, token const& rhs)
    {
        return !(lhs == rhs);
    }

    std::ostream& operator<<(std::ostream& lhs, debug_print<token> const& rhs);
}
