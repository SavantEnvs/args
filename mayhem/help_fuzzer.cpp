#include <cstdint>
#include <sstream>
#include <string>

#include <fuzzer/FuzzedDataProvider.h>
#include <args.hxx>

// Drives ArgumentParser::Help() with fuzz-controlled HelpParams (width, indents, gutter) and
// fuzz-controlled descriptions, so the width/indent arithmetic of the help formatter is exercised.
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    FuzzedDataProvider fdp(data, size);

    args::ArgumentParser parser(fdp.ConsumeRandomLengthString(64), fdp.ConsumeRandomLengthString(64));
    parser.Prog(fdp.ConsumeRandomLengthString(32));

    args::HelpFlag help(parser, "help", "Displays this help menu", {'h', "help"});
    args::Group group(parser, fdp.ConsumeRandomLengthString(32));
    args::Flag flag(group, fdp.ConsumeRandomLengthString(16), fdp.ConsumeRandomLengthString(64), {'f', "flag"});
    args::ValueFlag<std::string> value(group, fdp.ConsumeRandomLengthString(16), fdp.ConsumeRandomLengthString(64), {'v', "value"});
    args::Positional<std::string> positional(parser, fdp.ConsumeRandomLengthString(16), fdp.ConsumeRandomLengthString(64));

    auto &p = parser.helpParams;
    p.width = fdp.ConsumeIntegralInRange<unsigned>(0, 120);
    p.progindent = fdp.ConsumeIntegralInRange<unsigned>(0, 60);
    p.progtailindent = fdp.ConsumeIntegralInRange<unsigned>(0, 60);
    p.descriptionindent = fdp.ConsumeIntegralInRange<unsigned>(0, 60);
    p.flagindent = fdp.ConsumeIntegralInRange<unsigned>(0, 60);
    p.helpindent = fdp.ConsumeIntegralInRange<unsigned>(0, 60);
    p.eachgroupindent = fdp.ConsumeIntegralInRange<unsigned>(0, 20);
    p.gutter = fdp.ConsumeIntegralInRange<unsigned>(0, 20);
    p.showTerminator = fdp.ConsumeBool();

    std::ostringstream out;
    parser.Help(out);
    return 0;
}
