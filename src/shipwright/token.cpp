/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

#include "./token.hpp"

#include <cassert>
#include <ostream>
#include <string_view>

#include <frozen/map.h>

using shipwright::token_type;

namespace {
    constexpr auto type_stringify
        = frozen::make_map<token_type, std::string_view>({
            {token_type::unknown, "unknown"},
            {token_type::space, "space"},
            {token_type::newline, "newline"},
            {token_type::identifier, "identifier"},
            {token_type::lparen, "lparen"},
            {token_type::rparen, "rparen"},
            {token_type::bracket_argument, "bracket_argument"},
            {token_type::quote, "quote"},
            {token_type::quoted_piece, "quoted_piece"},
            {token_type::variable_reference_open, "variable_reference_open"},
            {token_type::variable_reference_piece, "variable_reference_piece"},
            {token_type::variable_reference_close, "variable_reference_close"},
            {token_type::bracket_comment, "bracket_comment"},
            {token_type::line_comment, "line_comment"},
        });
}

namespace shipwright {
    std::ostream& operator<<(
        std::ostream& lhs, debug_print<token_type> const& rhs)
    {
        auto const lookup = type_stringify.find(rhs.value);
        assert(lookup != type_stringify.end());

        return lhs << lookup->second;
    }

    std::ostream& operator<<(std::ostream& lhs, debug_print<token> const& rhs)
    {
        return lhs << '<' << shipwright::debug_print(rhs.value.type) << ": \""
                   << rhs.value.text << "\">";
    }
}
