/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

#include "./lexer.hpp"

#include <shipwright/token.test.hpp>

#include <catch2/catch.hpp>

#include <sstream>
#include <string>

TEST_CASE("Can parse individual tokens", "[lexer]")
{
    using shipwright::token;
    using shipwright::token_type;

    auto [input, expected] = GENERATE(table<std::string, token>({
        {" ", token{" ", token_type::space}},
        {"\t", token{"\t", token_type::space}},
        {"\t \t", token{"\t \t", token_type::space}},
        {"\n", token{"\n", token_type::newline}},
        {"(", token{"(", token_type::lparen}},
        {")", token{")", token_type::rparen}},
    }));

    shipwright::detail::lexer lex{input};

    REQUIRE(lex.advance());
    auto result = lex.read();

    CHECK(result == expected);

    REQUIRE_FALSE(lex.advance());
}
