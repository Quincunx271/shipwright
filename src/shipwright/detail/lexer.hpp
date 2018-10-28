/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

#pragma once

#include <string_view>

#include <shipwright/token.hpp>

namespace shipwright::detail {
    class lexer
    {
    public:
        explicit lexer(std::string_view text);
        lexer(lexer const&) = delete;
        ~lexer();

        bool advance();

        token read() const;

    private:
        void* lexer_ = nullptr;
        token current_token_ = {};
        token lookahead_token_ = {};
        bool lookahead_result_ = true;

        std::string_view input_;
    };
}
