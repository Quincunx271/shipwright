/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

#pragma once

#include <string_view>

namespace shipwright::detail {
    class lexer
    {
    public:
        lexer();
        lexer(lexer const&) = delete;
        ~lexer();

        bool advance();

        std::string_view read() const;

    private:
        void* lexer_ = nullptr;
    };
}
