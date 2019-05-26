/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

#pragma once

#include <cstddef>
#include <iterator>
#include <memory>
#include <type_traits>
#include <utility>

#include <catch2/catch.hpp>

namespace shipwright::test {
    template <typename Range>
    using range_iterator_t = std::decay_t<decltype(std::begin(std::declval<Range>()))>;

    template <typename Range,
        typename T = decltype(*std::declval<range_iterator_t<Range const&>>())>
    class Each : public Catch::Generators::IGenerator<T>
    {
        Range const& range;
        range_iterator_t<Range> iter;

    public:
        Each(Range const& range)
            : range{range}
            , iter{std::begin(this->range)}
        {}

        T const& get() const override
        {
            return *iter;
        }

        bool next() override
        {
            return ++iter == std::end(range);
        }
    };

    template <typename Range>
    auto each(Range const& range)
    {
        using value_type = decltype(*std::declval<range_iterator_t<Range const&>>());

        return Catch::Generators::GeneratorWrapper<value_type>{
            std::unique_ptr<Catch::Generators::IGenerator<value_type>>(
                std::make_unique<Each<Range>>(range)),
        };
    }
}
