/* Copyright (c) Taylor Richberger <taylor@axfive.net>
 * This code is released under the license described in the LICENSE file
 *
 * Compiled with the compiler's exception support switched off (see
 * CMakeLists.txt and meson.build), so anything in args.hxx that needs
 * exceptions outside of the ARGS_NOEXCEPT guards breaks this test at compile
 * time.
 */

#define ARGS_NOEXCEPT
#include "test_common.hxx"

#include <args.hxx>

#include "test_helpers.hxx"

int main()
{
    args::ArgumentParser p("parser");
    args::CompletionFlag c(p, {"completion"});
    args::Flag f(p, "foo", "description", {'f', "foo"});
    args::MapFlag<std::string, int> m(p, "map", "description", {'m', "map"}, {{"alpha", 1}, {"beta", 2}});

    p.ParseArgs(std::vector<std::string>{"--map", "beta", "-f"});
    test::require(p.GetError() == args::Error::None);
    test::require(args::get(m) == 2);

    // Completion replies are assembled by args::detail::Join.
    p.ParseArgs(std::vector<std::string>{"--completion", "bash", "2", "test", "--map", ""});
    test::require(p.GetError() == args::Error::Completion);
    test::require(args::get(c) == "alpha\nbeta");

    return 0;
}
